class_name SaveGameService
extends RefCounted

const CURRENT_FORMAT_VERSION: int = 1
const CURRENT_GAME_VERSION: String = "0.4.0-dev"
const CURRENT_CONTENT_MANIFEST_ID: String = (
	"colony-under-glass.r2-base.1"
)
const MAX_SAVE_BYTES: int = 4 * 1024 * 1024
const CHECKSUM_LENGTH: int = 64

enum FaultInjection {
	NONE,
	AFTER_TEMP_WRITE,
	AFTER_BACKUP_ROTATION,
}


func create_envelope(
	simulation: ColonySimulation,
	clock: SimulationClock,
	slot_id: String,
	saved_at_utc: String = ""
) -> Dictionary:
	if (
		simulation == null
		or clock == null
		or not simulation.is_ready()
		or not simulation.can_capture_save_boundary()
		or not _is_valid_slot_id(slot_id)
	):
		return {}
	var components: Dictionary = SimulationStateCodec.encode_simulation(
		simulation
	)
	if components.is_empty():
		return {}
	var simulation_tick: int = int(
		components["state_payload"]["simulation_tick"]
	)
	if clock.get_tick_index() != simulation_tick:
		return {}
	var frozen_config_hash: String = CanonicalSaveJson.sha256(
		components["frozen_config_bundle"]
	)
	if frozen_config_hash.is_empty():
		return {}
	var timestamp: String = saved_at_utc
	if timestamp.is_empty():
		timestamp = Time.get_datetime_string_from_system(true, true)
	var envelope: Dictionary = {
		"format_version": CURRENT_FORMAT_VERSION,
		"game_version": CURRENT_GAME_VERSION,
		"content_manifest_id": CURRENT_CONTENT_MANIFEST_ID,
		"frozen_config_hash": frozen_config_hash,
		"frozen_config_bundle": components["frozen_config_bundle"],
		"save_checksum": "",
		"slot_id": slot_id,
		"saved_at_utc": timestamp,
		"simulation_tick": simulation_tick,
		"clock_speed": clock.get_speed_multiplier(),
		"clock_paused": clock.is_paused(),
		"next_ids": components["next_ids"],
		"pending_commands": components["pending_commands"],
		"state_schema_id": SimulationStateCodec.CURRENT_SCHEMA_ID,
		"state_payload": components["state_payload"],
	}
	return seal_envelope(envelope)


func load_envelope(envelope: Dictionary) -> Dictionary:
	var verified_result: Dictionary = _verify_and_migrate_envelope(envelope)
	if not verified_result.get("ok", false):
		return verified_result
	var current: Dictionary = verified_result["envelope"]
	var restore_result: Dictionary = SimulationStateCodec.restore_simulation(
		current["frozen_config_bundle"],
		current["next_ids"],
		current["pending_commands"],
		current["state_payload"]
	)
	if not restore_result.get("ok", false):
		return restore_result
	var simulation: ColonySimulation = restore_result["simulation"]
	if (
		simulation.create_snapshot().simulation_tick
		!= int(current["simulation_tick"])
	):
		return _failure("Envelope Tick does not match restored state")
	var clock: SimulationClock = SimulationClock.new()
	if not clock.restore_save_boundary(
		int(current["simulation_tick"]),
		int(current["clock_speed"]),
		bool(current["clock_paused"])
	):
		return _failure("Clock state is invalid")
	return {
		"ok": true,
		"error": "",
		"simulation": simulation,
		"clock": clock,
		"envelope": current.duplicate(true),
		"migrated": bool(verified_result.get("migrated", false)),
	}


func encode_envelope(envelope: Dictionary) -> String:
	var verified_result: Dictionary = _verify_and_migrate_envelope(envelope)
	if not verified_result.get("ok", false):
		return ""
	return CanonicalSaveJson.encode(verified_result["envelope"])


func decode_envelope_text(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		return _failure("Save data exceeds the size limit")
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		return _failure("Save data is not valid JSON")
	if typeof(parser.data) != TYPE_DICTIONARY:
		return _failure("Save root must be an object")
	return _verify_and_migrate_envelope(parser.data)


func save_to_path(
	path: String,
	envelope: Dictionary,
	fault_injection: FaultInjection = FaultInjection.NONE
) -> Dictionary:
	if not _is_safe_user_path(path):
		return _failure("Save path must be a user:// file")
	var encoded: String = encode_envelope(envelope)
	if encoded.is_empty():
		return _failure("Envelope is invalid")
	var encoded_bytes: PackedByteArray = encoded.to_utf8_buffer()
	if encoded_bytes.size() > MAX_SAVE_BYTES:
		return _failure("Save data exceeds the size limit")

	var absolute_path: String = ProjectSettings.globalize_path(path)
	var temporary_path: String = absolute_path + ".tmp"
	var backup_path: String = absolute_path + ".bak"
	var parent_path: String = absolute_path.get_base_dir()
	var make_directory_error: Error = DirAccess.make_dir_recursive_absolute(
		parent_path
	)
	if make_directory_error != OK and not DirAccess.dir_exists_absolute(
		parent_path
	):
		return _failure("Could not create the save directory")
	_remove_if_present(temporary_path)
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _failure("Could not open the temporary save file")
	file.store_buffer(encoded_bytes)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return _failure("Could not write the temporary save file")
	if fault_injection == FaultInjection.AFTER_TEMP_WRITE:
		return _failure("Injected failure after temporary write")
	var temporary_result: Dictionary = _load_absolute_path(temporary_path)
	if not temporary_result.get("ok", false):
		return _failure(
			"Temporary save verification failed: %s"
			% temporary_result.get("error", "unknown error")
		)

	var primary_exists: bool = FileAccess.file_exists(absolute_path)
	if primary_exists:
		var current_result: Dictionary = _load_absolute_path(absolute_path)
		if current_result.get("ok", false):
			_remove_if_present(backup_path)
			var backup_error: Error = DirAccess.rename_absolute(
				absolute_path,
				backup_path
			)
			if backup_error != OK:
				return _failure("Could not rotate the previous save")
		else:
			_remove_if_present(absolute_path)
	if fault_injection == FaultInjection.AFTER_BACKUP_ROTATION:
		return _failure("Injected failure after backup rotation")

	var promote_error: Error = DirAccess.rename_absolute(
		temporary_path,
		absolute_path
	)
	if promote_error != OK:
		return _failure("Could not promote the temporary save")
	var committed_result: Dictionary = _load_absolute_path(absolute_path)
	if not committed_result.get("ok", false):
		return _failure("Committed save verification failed")
	return {
		"ok": true,
		"error": "",
		"path": path,
		"backup_available": FileAccess.file_exists(backup_path),
	}


func load_from_path(path: String) -> Dictionary:
	if not _is_safe_user_path(path):
		return _failure("Save path must be a user:// file")
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var candidates: Array[Dictionary] = [
		{"path": absolute_path, "source": "primary"},
		{"path": absolute_path + ".bak", "source": "backup"},
		{"path": absolute_path + ".tmp", "source": "temporary"},
	]
	var errors: PackedStringArray = []
	for candidate: Dictionary in candidates:
		if not FileAccess.file_exists(candidate["path"]):
			continue
		var result: Dictionary = _load_absolute_path(candidate["path"])
		if result.get("ok", false):
			result["recovered_from"] = candidate["source"]
			return result
		errors.append(
			"%s: %s" % [candidate["source"], result.get("error", "invalid")]
		)
	if errors.is_empty():
		return _failure("No save file was found")
	return _failure("No valid save candidate: " + "; ".join(errors))


func load_backup_from_path(path: String) -> Dictionary:
	if not _is_safe_user_path(path):
		return _failure("Save path must be a user:// file")
	var absolute_path: String = ProjectSettings.globalize_path(path) + ".bak"
	if not FileAccess.file_exists(absolute_path):
		return _failure("No backup save was found")
	var result: Dictionary = _load_absolute_path(absolute_path)
	if result.get("ok", false):
		result["recovered_from"] = "backup"
	return result


func seal_envelope(envelope: Dictionary) -> Dictionary:
	var sealed: Dictionary = envelope.duplicate(true)
	sealed["save_checksum"] = ""
	var checksum_input: Dictionary = sealed.duplicate(true)
	checksum_input.erase("save_checksum")
	var checksum: String = CanonicalSaveJson.sha256(checksum_input)
	if checksum.is_empty():
		return {}
	sealed["save_checksum"] = checksum
	return sealed


func _verify_and_migrate_envelope(envelope: Dictionary) -> Dictionary:
	var initial_error: String = _validate_outer_shape(envelope)
	if not initial_error.is_empty():
		return _failure(initial_error)
	if int(envelope["format_version"]) != CURRENT_FORMAT_VERSION:
		return _failure("Unsupported save format version")
	if String(envelope["content_manifest_id"]) != CURRENT_CONTENT_MANIFEST_ID:
		return _failure("Save content manifest is not compatible")
	if not _checksum_matches(envelope):
		return _failure("Save checksum does not match")
	if (
		CanonicalSaveJson.sha256(envelope["frozen_config_bundle"])
		!= String(envelope["frozen_config_hash"])
	):
		return _failure("Frozen configuration hash does not match")

	var migrated: bool = false
	var current: Dictionary = envelope.duplicate(true)
	match String(current["state_schema_id"]):
		SimulationStateCodec.CURRENT_SCHEMA_ID:
			pass
		SimulationStateCodec.PREVIOUS_SCHEMA_ID:
			var migration_result: Dictionary = _migrate_v1_to_v2(current)
			if not migration_result.get("ok", false):
				return migration_result
			current = migration_result["envelope"]
			migrated = true
		SimulationStateCodec.LEGACY_SCHEMA_ID:
			var migration_result: Dictionary = _migrate_v0_to_v1(current)
			if not migration_result.get("ok", false):
				return migration_result
			current = migration_result["envelope"]
			migration_result = _migrate_v1_to_v2(current)
			if not migration_result.get("ok", false):
				return migration_result
			current = migration_result["envelope"]
			migrated = true
		_:
			return _failure("Unsupported state schema")
	var current_error: String = _validate_current_envelope(current)
	if not current_error.is_empty():
		return _failure(current_error)
	return {
		"ok": true,
		"error": "",
		"envelope": current,
		"migrated": migrated,
	}


func _migrate_v0_to_v1(legacy: Dictionary) -> Dictionary:
	if typeof(legacy["pending_commands"]) != TYPE_ARRAY:
		return _failure("Legacy pending command queue is invalid")
	var legacy_next_ids: Variant = legacy["next_ids"]
	if (
		typeof(legacy_next_ids) != TYPE_DICTIONARY
		or legacy_next_ids.size() != 2
		or not legacy_next_ids.has("entity_id")
		or not legacy_next_ids.has("observation_event_id")
	):
		return _failure("Legacy next-ID payload is invalid")
	var migrated_commands: Array[Dictionary] = []
	var sequence_id: int = 1
	for command_type: Variant in legacy["pending_commands"]:
		if not _is_integral_number(command_type):
			return _failure("Legacy pending command type is invalid")
		migrated_commands.append({
			"sequence_id": sequence_id,
			"command_type": int(command_type),
		})
		sequence_id += 1
	var migrated: Dictionary = legacy.duplicate(true)
	migrated["state_schema_id"] = SimulationStateCodec.PREVIOUS_SCHEMA_ID
	migrated["pending_commands"] = migrated_commands
	migrated["next_ids"] = {
		"entity_id": legacy_next_ids["entity_id"],
		"observation_event_id": legacy_next_ids["observation_event_id"],
		"pending_command_sequence_id": sequence_id,
	}
	migrated = seal_envelope(migrated)
	if migrated.is_empty():
		return _failure("Legacy save migration could not be sealed")
	return {"ok": true, "error": "", "envelope": migrated}


func _migrate_v1_to_v2(previous: Dictionary) -> Dictionary:
	if (
		typeof(previous["pending_commands"]) != TYPE_ARRAY
		or typeof(previous["state_payload"]) != TYPE_DICTIONARY
	):
		return _failure("Previous save payload is invalid")
	var migrated_commands: Array[Dictionary] = []
	for command_value: Variant in previous["pending_commands"]:
		if (
			typeof(command_value) != TYPE_DICTIONARY
			or command_value.size() != 2
			or not command_value.has("sequence_id")
			or not command_value.has("command_type")
		):
			return _failure("Previous pending command record is invalid")
		migrated_commands.append({
			"sequence_id": command_value["sequence_id"],
			"command_type": command_value["command_type"],
			"argument_id": "",
		})
	var state_payload: Dictionary = previous["state_payload"].duplicate(true)
	if state_payload.has("campaign"):
		return _failure("Previous save unexpectedly contains campaign state")
	state_payload["campaign"] = _derive_campaign_for_v1(state_payload)
	var migrated: Dictionary = previous.duplicate(true)
	migrated["game_version"] = CURRENT_GAME_VERSION
	migrated["state_schema_id"] = SimulationStateCodec.CURRENT_SCHEMA_ID
	migrated["pending_commands"] = migrated_commands
	migrated["state_payload"] = state_payload
	migrated = seal_envelope(migrated)
	if migrated.is_empty():
		return _failure("Previous save migration could not be sealed")
	return {"ok": true, "error": "", "envelope": migrated}


func _derive_campaign_for_v1(state_payload: Dictionary) -> Variant:
	var progress: Variant = state_payload.get("scenario_progress")
	if progress == null:
		return null
	if typeof(progress) != TYPE_DICTIONARY:
		return {}
	var phase: int = int(progress.get("phase", -1))
	var evidence: Array[String] = []
	var inferences: Array[String] = []
	var facilities: Array[String] = [
		String(CampaignState.FACILITY_LIGHT_COVER),
		String(CampaignState.FACILITY_TEST_TUBE_NEST),
	]
	var chapter: int = CampaignState.Chapter.FOUNDING_OBSERVATION
	var status: int = CampaignState.Status.ACTIVE
	var completed_chapter_count: int = 0
	var chapter_entered_tick: int = 0
	if phase >= ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION:
		evidence.append(String(CampaignState.EVIDENCE_FIRST_WORKER))
		status = CampaignState.Status.AWAITING_INFERENCE
	if phase >= ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION:
		chapter = CampaignState.Chapter.ENVIRONMENTAL_CARE
		status = CampaignState.Status.ACTIVE
		completed_chapter_count = 1
		chapter_entered_tick = int(
			progress.get("phase_entered_tick", 0)
		)
		inferences.append(String(CampaignState.INFERENCE_FIRST_WORKER))
		facilities.append(
			String(CampaignState.FACILITY_MICRO_FEEDING_PORT)
		)
	if phase >= ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING:
		evidence.append(
			String(CampaignState.EVIDENCE_HUMIDITY_RELOCATION)
		)
	if phase >= ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY:
		evidence.append(String(CampaignState.EVIDENCE_SUGAR_SHARING))
		status = CampaignState.Status.AWAITING_INFERENCE
	return {
		"chapter": chapter,
		"status": status,
		"chapter_entered_tick": chapter_entered_tick,
		"completed_chapter_count": completed_chapter_count,
		"incorrect_inference_attempts": 0,
		"hint_tier": 0,
		"campaign_completed_tick": -1,
		"collected_evidence_ids": evidence,
		"confirmed_inference_ids": inferences,
		"unlocked_facility_type_ids": facilities,
	}


func _validate_outer_shape(envelope: Dictionary) -> String:
	var required_keys: Array[String] = [
		"format_version",
		"game_version",
		"content_manifest_id",
		"frozen_config_hash",
		"frozen_config_bundle",
		"save_checksum",
		"slot_id",
		"saved_at_utc",
		"simulation_tick",
		"clock_speed",
		"clock_paused",
		"next_ids",
		"pending_commands",
		"state_schema_id",
		"state_payload",
	]
	if envelope.size() != required_keys.size():
		return "Save envelope has unexpected fields"
	for key: String in required_keys:
		if not envelope.has(key):
			return "Save envelope is missing %s" % key
	if (
		not _is_integral_number(envelope["format_version"])
		or not _is_nonnegative_int(envelope["simulation_tick"])
		or not _is_integral_number(envelope["clock_speed"])
		or typeof(envelope["clock_paused"]) != TYPE_BOOL
		or typeof(envelope["game_version"]) != TYPE_STRING
		or typeof(envelope["content_manifest_id"]) != TYPE_STRING
		or typeof(envelope["frozen_config_hash"]) != TYPE_STRING
		or typeof(envelope["frozen_config_bundle"]) != TYPE_DICTIONARY
		or typeof(envelope["save_checksum"]) != TYPE_STRING
		or typeof(envelope["slot_id"]) != TYPE_STRING
		or typeof(envelope["saved_at_utc"]) != TYPE_STRING
		or typeof(envelope["next_ids"]) != TYPE_DICTIONARY
		or typeof(envelope["pending_commands"]) != TYPE_ARRAY
		or typeof(envelope["state_schema_id"]) != TYPE_STRING
		or typeof(envelope["state_payload"]) != TYPE_DICTIONARY
	):
		return "Save envelope contains an invalid value type"
	if (
		not _is_valid_slot_id(envelope["slot_id"])
		or String(envelope["saved_at_utc"]).is_empty()
		or String(envelope["frozen_config_hash"]).length()
			!= CHECKSUM_LENGTH
		or String(envelope["save_checksum"]).length() != CHECKSUM_LENGTH
	):
		return "Save envelope metadata is invalid"
	return ""


func _validate_current_envelope(envelope: Dictionary) -> String:
	if String(envelope["state_schema_id"]) != (
		SimulationStateCodec.CURRENT_SCHEMA_ID
	):
		return "State schema was not migrated to the current version"
	if int(envelope["clock_speed"]) not in [
		SimulationClock.NORMAL_SPEED,
		SimulationClock.FAST_SPEED,
		SimulationClock.VERY_FAST_SPEED,
	]:
		return "Clock speed is invalid"
	if (
		not envelope["state_payload"].has("simulation_tick")
		or not _is_nonnegative_int(
			envelope["state_payload"]["simulation_tick"]
		)
		or int(envelope["state_payload"]["simulation_tick"])
			!= int(envelope["simulation_tick"])
	):
		return "Envelope Tick does not match its state payload"
	if not _checksum_matches(envelope):
		return "Migrated save checksum does not match"
	if (
		CanonicalSaveJson.sha256(envelope["frozen_config_bundle"])
		!= String(envelope["frozen_config_hash"])
	):
		return "Migrated frozen configuration hash does not match"
	return ""


func _checksum_matches(envelope: Dictionary) -> bool:
	var checksum_input: Dictionary = envelope.duplicate(true)
	var expected_checksum: String = String(
		checksum_input.get("save_checksum", "")
	)
	checksum_input.erase("save_checksum")
	return (
		expected_checksum.length() == CHECKSUM_LENGTH
		and CanonicalSaveJson.sha256(checksum_input) == expected_checksum
	)


func _load_absolute_path(absolute_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return _failure("Could not open save file")
	var length: int = file.get_length()
	if length < 1 or length > MAX_SAVE_BYTES:
		file.close()
		return _failure("Save file size is invalid")
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK:
		return _failure("Could not read save file")
	var envelope_result: Dictionary = decode_envelope_text(text)
	if not envelope_result.get("ok", false):
		return envelope_result
	var load_result: Dictionary = load_envelope(
		envelope_result["envelope"]
	)
	if not load_result.get("ok", false):
		return load_result
	return load_result


func _remove_if_present(absolute_path: String) -> void:
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _is_valid_slot_id(slot_id: String) -> bool:
	if slot_id.is_empty() or slot_id.length() > 48:
		return false
	for character_index: int in slot_id.length():
		var codepoint: int = slot_id.unicode_at(character_index)
		var valid: bool = (
			(codepoint >= 48 and codepoint <= 57)
			or (codepoint >= 65 and codepoint <= 90)
			or (codepoint >= 97 and codepoint <= 122)
			or codepoint == 45
			or codepoint == 95
		)
		if not valid:
			return false
	return true


func _is_safe_user_path(path: String) -> bool:
	if not path.begins_with("user://"):
		return false
	var relative_path: String = path.trim_prefix("user://")
	if (
		relative_path.is_empty()
		or relative_path.ends_with("/")
		or relative_path.contains("\\")
		or relative_path.contains(":")
	):
		return false
	for segment: String in relative_path.split("/"):
		if segment.is_empty() or segment == "." or segment == "..":
			return false
	return true


func _is_integral_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number: float = float(value)
	return (
		not is_nan(number)
		and not is_inf(number)
		and number == floorf(number)
	)


func _is_nonnegative_int(value: Variant) -> bool:
	return _is_integral_number(value) and int(value) >= 0


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
