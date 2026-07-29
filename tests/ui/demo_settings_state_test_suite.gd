class_name DemoSettingsStateTestSuite
extends RefCounted

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_defaults_and_supported_values()
	_test_selection_rejects_invalid_indices()
	_test_locale_normalization_and_fullscreen_state()
	_test_accessibility_and_volume_settings()
	_test_rebindable_shortcuts()
	_test_dictionary_round_trip_and_validation()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_defaults_and_supported_values() -> void:
	var state: DemoSettingsState = DemoSettingsState.new()
	_expect_vector2i(
		state.get_windowed_resolution(),
		Vector2i(1280, 720),
		"default windowed resolution is 1280x720"
	)
	_expect_string(
		state.get_locale_code(),
		"zh_CN",
		"default locale is Simplified Chinese"
	)
	_expect_true(
		not state.is_fullscreen_requested(),
		"default display mode is windowed"
	)
	_expect_true(state.select_resolution(1), "1920x1080 can be selected")
	_expect_vector2i(
		state.get_windowed_resolution(),
		Vector2i(1920, 1080),
		"the selected resolution is returned"
	)
	_expect_true(state.select_locale(1), "temporary English can be selected")
	_expect_string(
		state.get_locale_code(),
		"en",
		"English locale selection is returned"
	)


func _test_selection_rejects_invalid_indices() -> void:
	var state: DemoSettingsState = DemoSettingsState.new()
	_expect_true(
		not state.select_resolution(-1),
		"negative resolution index is rejected"
	)
	_expect_true(
		not state.select_resolution(2),
		"out-of-range resolution index is rejected"
	)
	_expect_vector2i(
		state.get_windowed_resolution(),
		Vector2i(1280, 720),
		"invalid resolution selections do not mutate state"
	)
	_expect_true(
		not state.select_locale(-1),
		"negative locale index is rejected"
	)
	_expect_true(
		not state.select_locale(2),
		"out-of-range locale index is rejected"
	)
	_expect_string(
		state.get_locale_code(),
		"zh_CN",
		"invalid locale selections do not mutate state"
	)


func _test_locale_normalization_and_fullscreen_state() -> void:
	var english_state: DemoSettingsState = DemoSettingsState.new(
		"en_US",
		Vector2i(1920, 1080),
		true
	)
	_expect_string(
		english_state.get_locale_code(),
		"en",
		"regional English locales map to the supported English locale"
	)
	_expect_vector2i(
		english_state.get_windowed_resolution(),
		Vector2i(1920, 1080),
		"supported initial resolution is preserved"
	)
	_expect_true(
		english_state.is_fullscreen_requested(),
		"initial fullscreen preference is preserved"
	)
	english_state.set_fullscreen_requested(false)
	_expect_true(
		not english_state.is_fullscreen_requested(),
		"fullscreen preference can be disabled"
	)

	var unsupported_state: DemoSettingsState = DemoSettingsState.new(
		"fr_FR",
		Vector2i(1600, 900)
	)
	_expect_string(
		unsupported_state.get_locale_code(),
		"zh_CN",
		"unsupported locales fall back to Simplified Chinese"
	)
	_expect_vector2i(
		unsupported_state.get_windowed_resolution(),
		Vector2i(1280, 720),
		"unsupported resolutions fall back to 1280x720"
	)


func _test_accessibility_and_volume_settings() -> void:
	var state: DemoSettingsState = DemoSettingsState.new()
	_expect_float(
		state.get_ui_scale_factor(),
		1.0,
		"default UI scale is 100 percent"
	)
	_expect_true(state.select_ui_scale(1), "125 percent UI scale is supported")
	_expect_float(
		state.get_ui_scale_factor(),
		1.25,
		"selected 125 percent UI scale is returned"
	)
	_expect_true(state.select_ui_scale(2), "150 percent UI scale is supported")
	_expect_true(
		not state.select_ui_scale(3),
		"out-of-range UI scale is rejected"
	)
	state.set_reduced_motion(true)
	_expect_true(state.is_reduced_motion(), "reduced motion can be enabled")
	_expect_true(state.set_master_volume(0.35), "finite volume is accepted")
	_expect_float(
		state.get_master_volume(),
		0.35,
		"master volume stores a normalized value"
	)
	_expect_true(state.set_master_volume(2.0), "finite volume is clamped")
	_expect_float(
		state.get_master_volume(),
		1.0,
		"master volume clamps to one"
	)
	_expect_true(
		not state.set_master_volume(NAN),
		"NaN master volume is rejected"
	)
	_expect_true(
		state.set_ambient_volume(0.2),
		"finite ambient volume is accepted"
	)
	_expect_float(
		state.get_ambient_volume(),
		0.2,
		"ambient volume is stored independently"
	)
	_expect_true(
		state.set_effects_volume(0.65),
		"finite effects volume is accepted"
	)
	_expect_float(
		state.get_effects_volume(),
		0.65,
		"effects volume is stored independently"
	)
	_expect_true(
		state.set_effects_volume(-1.0),
		"finite effects volume is clamped"
	)
	_expect_float(
		state.get_effects_volume(),
		0.0,
		"effects volume clamps to zero"
	)
	_expect_true(
		not state.set_ambient_volume(INF),
		"infinite ambient volume is rejected"
	)


func _test_rebindable_shortcuts() -> void:
	var state: DemoSettingsState = DemoSettingsState.new()
	_expect_int(
		state.get_key_binding(DemoSettingsState.ACTION_HELP),
		KEY_F1,
		"help defaults to F1"
	)
	_expect_int(
		state.get_key_binding(DemoSettingsState.ACTION_JOURNAL),
		KEY_J,
		"journal defaults to J"
	)
	_expect_true(
		state.set_key_binding(DemoSettingsState.ACTION_HELP, KEY_H),
		"a supported unused letter can replace Help"
	)
	_expect_int(
		state.get_key_binding(DemoSettingsState.ACTION_HELP),
		KEY_H,
		"the remapped Help key is authoritative"
	)
	_expect_true(
		not state.set_key_binding(
			DemoSettingsState.ACTION_LAYOUT,
			KEY_J
		),
		"a key already used by another action is rejected"
	)
	_expect_true(
		not state.set_key_binding(
			DemoSettingsState.ACTION_LAYOUT,
			KEY_P
		),
		"fixed layout editing keys cannot be rebound"
	)
	state.reset_key_bindings()
	_expect_int(
		state.get_key_binding(DemoSettingsState.ACTION_HELP),
		KEY_F1,
		"reset restores the default Help binding"
	)


func _test_dictionary_round_trip_and_validation() -> void:
	var state: DemoSettingsState = DemoSettingsState.new(
		"en",
		Vector2i(1920, 1080),
		true,
		1.5,
		true,
		0.45
	)
	_expect_true(
		state.set_key_binding(DemoSettingsState.ACTION_HELP, KEY_H),
		"round-trip fixture accepts a custom Help key"
	)
	state.set_ambient_volume(0.3)
	state.set_effects_volume(0.6)
	var restored: DemoSettingsState = DemoSettingsState.from_dictionary(
		state.to_dictionary(),
		true,
		true
	)
	_expect_true(restored != null, "valid settings dictionary restores")
	if restored != null:
		_expect_string(restored.get_locale_code(), "en", "locale restores")
		_expect_vector2i(
			restored.get_windowed_resolution(),
			Vector2i(1920, 1080),
			"resolution restores"
		)
		_expect_float(
			restored.get_ui_scale_factor(),
			1.5,
			"UI scale restores"
		)
		_expect_true(
			restored.is_reduced_motion(),
			"reduced motion restores"
		)
		_expect_float(restored.get_master_volume(), 0.45, "volume restores")
		_expect_float(
			restored.get_ambient_volume(),
			0.3,
			"ambient volume restores"
		)
		_expect_float(
			restored.get_effects_volume(),
			0.6,
			"effects volume restores"
		)
		_expect_int(
			restored.get_key_binding(DemoSettingsState.ACTION_HELP),
			KEY_H,
			"custom shortcut restores"
		)
	var invalid: Dictionary = state.to_dictionary()
	invalid["ui_scale_index"] = 99
	_expect_true(
		DemoSettingsState.from_dictionary(invalid) == null,
		"unsupported UI scale in persisted settings is rejected"
	)
	invalid = state.to_dictionary()
	invalid["master_volume"] = NAN
	_expect_true(
		DemoSettingsState.from_dictionary(invalid) == null,
		"NaN persisted volume is rejected"
	)
	invalid = state.to_dictionary()
	invalid["ambient_volume"] = INF
	_expect_true(
		DemoSettingsState.from_dictionary(invalid) == null,
		"infinite persisted ambient volume is rejected"
	)
	invalid = state.to_dictionary()
	invalid.erase("effects_volume")
	_expect_true(
		DemoSettingsState.from_dictionary(invalid) == null,
		"split audio fields must appear together"
	)
	invalid = state.to_dictionary()
	var duplicate_bindings: Dictionary = invalid["key_bindings"]
	duplicate_bindings["layout"] = duplicate_bindings["journal"]
	_expect_true(
		DemoSettingsState.from_dictionary(invalid, true) == null,
		"duplicate persisted shortcuts are rejected"
	)
	var legacy: Dictionary = state.to_dictionary()
	legacy.erase("key_bindings")
	_expect_true(
		DemoSettingsState.from_dictionary(legacy) != null,
		"legacy settings without shortcuts receive safe defaults"
	)
	_expect_true(
		DemoSettingsState.from_dictionary(legacy, true) == null,
		"current settings require the shortcut bundle"
	)
	var pre_audio: Dictionary = state.to_dictionary()
	pre_audio.erase("ambient_volume")
	pre_audio.erase("effects_volume")
	_expect_true(
		DemoSettingsState.from_dictionary(pre_audio, true) != null,
		"pre-audio settings receive safe split-volume defaults"
	)
	_expect_true(
		DemoSettingsState.from_dictionary(pre_audio, true, true) == null,
		"current settings require split audio values"
	)


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", "false")


func _expect_string(actual: String, expected: String, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, expected, actual)


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _expect_vector2i(
	actual: Vector2i,
	expected: Vector2i,
	message: String
) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _expect_float(actual: float, expected: float, message: String) -> void:
	_assertion_count += 1
	if is_equal_approx(actual, expected):
		return
	_record_failure(message, str(expected), str(actual))


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
