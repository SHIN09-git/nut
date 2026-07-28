class_name DemoSettingsStateTestSuite
extends RefCounted

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_defaults_and_supported_values()
	_test_selection_rejects_invalid_indices()
	_test_locale_normalization_and_fullscreen_state()


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


func _expect_vector2i(
	actual: Vector2i,
	expected: Vector2i,
	message: String
) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _record_failure(
	message: String,
	expected: String,
	actual: String
) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
