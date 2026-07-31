class_name ProductionAudioTestSuite
extends RefCounted

const SHELL_SCENE: PackedScene = preload(
	"res://scenes/app/game_shell.tscn"
)
const TEST_PROFILE_PATH: String = "user://r15_audio/profile.json"
const TEST_SETTINGS_PATH: String = "user://r15_audio/settings.json"
const AUDIO_PATHS: PackedStringArray = [
	"res://assets/production/audio/ambient_glass_observation.wav",
	"res://assets/production/audio/ui_soft_confirm.wav",
	"res://assets/production/audio/glass_tap.wav",
	"res://assets/production/audio/water_drop.wav",
	"res://assets/production/audio/facility_place.wav",
	"res://assets/production/audio/gate_toggle.wav",
	"res://assets/production/audio/journal_open.wav",
	"res://assets/production/audio/chapter_complete.wav",
	"res://assets/production/audio/report_reveal.wav",
]
const EXPECTED_SHA256: PackedStringArray = [
	"b7c40e073c1ffe3a9131c1d0e502075ac122cbbc0ad67c947545a093f30ce3e3",
	"966d1962f010ac240e5617fdcdd15d325f3acc4f83dd189724683976f85153b2",
	"cfa4bdb44bf4b249a40fbd298e6ca71885ba696e4de0064f1d9f1e0490761002",
	"cc02570776eba2d4915e4b40014a75250943058e890a8ac3239000fd64a09330",
	"e401dead28da3ec84c913d11b5b0ac174324cbb0e6902e67ce96a43c367a166b",
	"8909a26b7cf4a10ee54aba1d88ae43e7f637c557dca850cb9e1ac552add55c9b",
	"569f5bccaa5192d4da181f58c8ca5b7ec6341130de5ce96bac0ac82c43e68fa9",
	"6f76dd02c691b4a822c1972e258eedf5269f4a4867d7b808540d62a84634d7c2",
	"99923ccac681f0aad4db42ac998f50fc7c8159d129fc202f409bcd458ae0860c",
]

var _assertion_count: int = 0
var _failure_count: int = 0


func run(scene_root: Node) -> void:
	_test_audio_package()
	_test_bus_layout_and_split_volume_controls(scene_root)
	_test_gameplay_cues_reinforce_visible_actions(scene_root)


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_audio_package() -> void:
	for index: int in AUDIO_PATHS.size():
		var path: String = AUDIO_PATHS[index]
		_expect_true(FileAccess.file_exists(path), "%s exists" % path)
		_expect_string(
			FileAccess.get_sha256(path),
			EXPECTED_SHA256[index],
			"%s matches its deterministic source hash" % path
		)
		var stream: AudioStreamWAV = load(path) as AudioStreamWAV
		_expect_true(stream != null, "%s imports as WAV" % path)
		if stream == null:
			continue
		_expect_int(stream.mix_rate, 44_100, "%s uses 44.1 kHz" % path)
		_expect_true(not stream.stereo, "%s is mono" % path)
		_expect_true(
			stream.get_length() > 0.05,
			"%s has a non-empty audible duration" % path
		)
	var ambient: AudioStreamWAV = load(AUDIO_PATHS[0]) as AudioStreamWAV
	_expect_true(
		ambient != null and ambient.get_length() >= 15.0,
		"ambient bed provides a long low-interference loop"
	)


func _test_bus_layout_and_split_volume_controls(scene_root: Node) -> void:
	for bus_name: StringName in [&"Master", &"Ambient", &"SFX"]:
		_expect_true(
			AudioServer.get_bus_index(bus_name) >= 0,
			"%s audio bus is registered" % bus_name
		)
	var shell: GameShellController = _create_shell(scene_root)
	var director: AudioDirector = shell.get_node("%AudioDirector") as AudioDirector
	_expect_true(
		director != null and director.get_ambient_stream() != null,
		"shell owns the looping production ambience"
	)
	if director == null:
		_destroy_shell(scene_root, shell)
		return
	if director != null and director.get_ambient_stream() != null:
		_expect_int(
			director.get_ambient_stream().loop_mode,
			AudioStreamWAV.LOOP_FORWARD,
			"shell ambience loops forward without a gameplay timer"
		)
		_expect_true(
			director.get_ambient_stream().loop_end > 0,
			"shell ambience exposes an explicit loop boundary"
		)
	_expect_int(
		director.get_supported_cue_ids().size(),
		8,
		"audio director exposes only the finite R15 cue set"
	)
	_expect_true(
		not director.play_cue(&"unknown"),
		"unknown cue identifiers are rejected"
	)
	var settings: DemoSettingsState = shell.get_settings_state()
	settings.set_master_volume(0.75)
	settings.set_ambient_volume(0.25)
	settings.set_effects_volume(0.55)
	director.apply_settings(settings)
	_expect_bus_linear_volume(&"Master", 0.75)
	_expect_bus_linear_volume(&"Ambient", 0.25)
	_expect_bus_linear_volume(&"SFX", 0.55)
	settings.set_ambient_volume(0.0)
	director.apply_settings(settings)
	_expect_true(
		AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambient")),
		"ambient can be muted without muting effects"
	)
	_expect_true(
		not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")),
		"effects remain available when ambience is muted"
	)
	_destroy_shell(scene_root, shell)


func _test_gameplay_cues_reinforce_visible_actions(scene_root: Node) -> void:
	var shell: GameShellController = _create_shell(scene_root)
	(shell.get_node("%NewGameButton") as Button).pressed.emit()
	var game: Act1TestTubeController = (
		shell.get_game_controller() as Act1TestTubeController
	)
	var effects: AudioStreamPlayer = shell.get_node(
		"%EffectsPlayer"
	) as AudioStreamPlayer
	_expect_true(game != null, "new profile exposes the Act 1 controller")
	if game != null:
		(game.get_node("%StartObservationButton") as Button).pressed.emit()
		(game.get_node("%JournalButton") as Button).pressed.emit()
		(game.get_node("%PredictionButton1") as Button).pressed.emit()
		(game.get_node("%JournalCloseButton") as Button).pressed.emit()
		(game.get_node("%CoverButton") as Button).pressed.emit()
		_expect_true(
			effects.stream
				== load("res://assets/production/audio/glass_tap.wav"),
			"accepted cover action selects the glass feedback cue"
		)
		_expect_true(
			game.get_latest_snapshot().act1.queen_care
				.light_cover_action_pending,
			"the same cue accompanies a visible queued state"
		)
		(game.get_node("%JournalButton") as Button).pressed.emit()
		_expect_true(
			effects.stream
				== load("res://assets/production/audio/journal_open.wav"),
			"opening the visible journal selects its feedback cue"
		)
		_expect_true(
			(game.get_node("%JournalPanel") as Control).visible,
			"journal feedback is never the only indication"
		)
	_destroy_shell(scene_root, shell)


func _create_shell(scene_root: Node) -> GameShellController:
	ProfileStore.new(TEST_PROFILE_PATH).delete_profile()
	SettingsStore.new(TEST_SETTINGS_PATH).delete_for_tests()
	var shell: GameShellController = SHELL_SCENE.instantiate()
	shell.profile_path_override = TEST_PROFILE_PATH
	shell.settings_path_override = TEST_SETTINGS_PATH
	shell.exit_application_on_request = false
	scene_root.add_child(shell)
	return shell


func _destroy_shell(scene_root: Node, shell: GameShellController) -> void:
	scene_root.remove_child(shell)
	shell.free()
	ProfileStore.new(TEST_PROFILE_PATH).delete_profile()
	SettingsStore.new(TEST_SETTINGS_PATH).delete_for_tests()
	for bus_name: StringName in [&"Master", &"Ambient", &"SFX"]:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			AudioServer.set_bus_mute(bus_index, false)
			AudioServer.set_bus_volume_db(bus_index, 0.0)


func _expect_bus_linear_volume(
	bus_name: StringName,
	expected: float
) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	var actual: float = db_to_linear(
		AudioServer.get_bus_volume_db(bus_index)
	)
	_assertion_count += 1
	if is_equal_approx(actual, expected):
		return
	_record_failure(
		"%s bus applies normalized volume" % bus_name,
		str(expected),
		str(actual)
	)


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", "false")


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _expect_string(
	actual: String,
	expected: String,
	message: String
) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, expected, actual)


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
