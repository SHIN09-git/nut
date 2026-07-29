class_name ProfileStore
extends RefCounted

const DEFAULT_PROFILE_PATH: String = "user://profiles/main.json"
const MAIN_SLOT_ID: String = "main"

var _profile_path: String
var _save_service: SaveGameService


func _init(profile_path: String = DEFAULT_PROFILE_PATH) -> void:
	_profile_path = profile_path
	_save_service = SaveGameService.new()


func save_envelope(envelope: Dictionary) -> Dictionary:
	if (
		not _is_safe_user_path(_profile_path)
		or envelope.is_empty()
		or String(envelope.get("slot_id", "")) != (
		MAIN_SLOT_ID
		)
	):
		return _failure("Main profile envelope is invalid")
	return _save_service.save_to_path(_profile_path, envelope)


func load_best() -> Dictionary:
	if not _is_safe_user_path(_profile_path):
		return _failure("Profile path is invalid")
	return _save_service.load_from_path(_profile_path)


func load_backup() -> Dictionary:
	if not _is_safe_user_path(_profile_path):
		return _failure("Profile path is invalid")
	return _save_service.load_backup_from_path(_profile_path)


func restore_backup() -> Dictionary:
	var backup_result: Dictionary = load_backup()
	if not backup_result.get("ok", false):
		return backup_result
	var save_result: Dictionary = save_envelope(backup_result["envelope"])
	if not save_result.get("ok", false):
		return save_result
	var restored_result: Dictionary = load_best()
	if restored_result.get("ok", false):
		restored_result["restored_backup"] = true
	return restored_result


func get_summary() -> Dictionary:
	var primary_exists: bool = _candidate_exists("")
	var backup_exists: bool = _candidate_exists(".bak")
	var temporary_exists: bool = _candidate_exists(".tmp")
	var load_result: Dictionary = load_best()
	if not load_result.get("ok", false):
		return {
			"available": false,
			"primary_exists": primary_exists,
			"backup_exists": backup_exists,
			"temporary_exists": temporary_exists,
			"error": load_result.get("error", "Profile is unavailable"),
		}
	var envelope: Dictionary = load_result["envelope"]
	var state_payload: Dictionary = envelope["state_payload"]
	var progress: Variant = state_payload.get("scenario_progress")
	var phase: int = -1
	if typeof(progress) == TYPE_DICTIONARY:
		phase = int(progress.get("phase", -1))
	var campaign: Variant = state_payload.get("campaign")
	var campaign_chapter: int = -1
	var campaign_completed: bool = false
	if typeof(campaign) == TYPE_DICTIONARY:
		campaign_chapter = int(campaign.get("chapter", -1))
		campaign_completed = (
			int(campaign.get("status", CampaignState.Status.ACTIVE))
			== CampaignState.Status.COMPLETED
		)
	var cards: Array = state_payload.get(
		"unlocked_observation_card_ids",
		[]
	)
	var recent_observation_id: String = ""
	if not cards.is_empty():
		recent_observation_id = String(cards[-1])
	var playtime := ProfilePlaytimeState.new()
	if not playtime.restore(envelope["profile_playtime"]):
		return _failure("Profile playtime metadata is invalid")
	return {
		"available": true,
		"primary_exists": primary_exists,
		"backup_exists": backup_exists,
		"temporary_exists": temporary_exists,
		"recovered_from": load_result.get("recovered_from", "primary"),
		"simulation_tick": int(envelope["simulation_tick"]),
		"simulation_seconds": (
			float(envelope["simulation_tick"])
			* SimulationClock.FIXED_STEP_SECONDS
		),
		"phase": phase,
		"campaign_chapter": campaign_chapter,
		"campaign_completed": campaign_completed,
		"active_play_seconds": playtime.get_active_seconds(),
		"chapter_active_seconds": (
			playtime.get_chapter_active_seconds(campaign_chapter)
		),
		"completion_active_seconds": (
			playtime.get_completion_active_seconds()
		),
		"playtime_has_legacy_gap": playtime.has_legacy_gap(),
		"saved_at_utc": String(envelope["saved_at_utc"]),
		"recent_observation_id": recent_observation_id,
		"error": "",
	}


func has_any_candidate() -> bool:
	return (
		_candidate_exists("")
		or _candidate_exists(".bak")
		or _candidate_exists(".tmp")
	)


func delete_profile() -> Dictionary:
	if not _is_safe_user_path(_profile_path):
		return _failure("Profile path is invalid")
	var absolute_path: String = ProjectSettings.globalize_path(_profile_path)
	for candidate: String in [
		absolute_path,
		absolute_path + ".bak",
		absolute_path + ".tmp",
	]:
		if FileAccess.file_exists(candidate):
			var error: Error = DirAccess.remove_absolute(candidate)
			if error != OK:
				return _failure("Could not delete the complete profile")
	return {
		"ok": not has_any_candidate(),
		"error": "" if not has_any_candidate() else "Profile remains on disk",
	}


func get_profile_path() -> String:
	return _profile_path


func _candidate_exists(suffix: String) -> bool:
	if not _is_safe_user_path(_profile_path):
		return false
	return FileAccess.file_exists(
		ProjectSettings.globalize_path(_profile_path) + suffix
	)


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


func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
