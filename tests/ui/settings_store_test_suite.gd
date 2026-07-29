class_name SettingsStoreTestSuite
extends RefCounted

const TEST_SETTINGS_PATH: String = "user://r3_tests/settings.json"

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	var store: SettingsStore = SettingsStore.new(TEST_SETTINGS_PATH)
	store.delete_for_tests()
	_test_missing_file_uses_defaults(store)
	_test_settings_round_trip_is_independent(store)
	_test_legacy_settings_migrate_with_default_bindings(store)
	_test_corrupt_file_uses_safe_defaults(store)
	_test_unsafe_path_is_rejected()
	store.delete_for_tests()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_missing_file_uses_defaults(store: SettingsStore) -> void:
	var result: Dictionary = store.load_or_default()
	_expect_true(result.get("ok", false), "missing settings load succeeds")
	_expect_true(
		result.get("used_defaults", false),
		"missing settings are identified as defaults"
	)
	var state: DemoSettingsState = result["settings"]
	_expect_string(
		state.get_locale_code(),
		"zh_CN",
		"default settings use Simplified Chinese"
	)
	_expect_float(
		state.get_ui_scale_factor(),
		1.0,
		"default settings use 100 percent UI scale"
	)
	_expect_true(
		not state.is_reduced_motion(),
		"reduced motion is opt-in"
	)


func _test_settings_round_trip_is_independent(store: SettingsStore) -> void:
	var state: DemoSettingsState = DemoSettingsState.new()
	_expect_true(state.select_resolution(1), "test resolution is selectable")
	_expect_true(state.select_locale(1), "test locale is selectable")
	state.set_fullscreen_requested(true)
	_expect_true(state.select_ui_scale(2), "150 percent UI scale is selectable")
	state.set_reduced_motion(true)
	_expect_true(state.set_master_volume(0.35), "master volume is accepted")
	_expect_true(
		state.set_key_binding(DemoSettingsState.ACTION_HELP, KEY_H),
		"custom Help shortcut is accepted"
	)
	var save_result: Dictionary = store.save(state)
	_expect_true(save_result.get("ok", false), "settings commit succeeds")

	state.select_locale(0)
	state.select_ui_scale(0)
	state.set_reduced_motion(false)
	state.set_master_volume(1.0)
	var load_result: Dictionary = store.load_or_default()
	_expect_true(load_result.get("ok", false), "saved settings load")
	_expect_true(
		not load_result.get("used_defaults", true),
		"saved settings do not report fallback"
	)
	var restored: DemoSettingsState = load_result["settings"]
	_expect_string(restored.get_locale_code(), "en", "locale survives round trip")
	_expect_vector2i(
		restored.get_windowed_resolution(),
		Vector2i(1920, 1080),
		"window resolution survives round trip"
	)
	_expect_true(
		restored.is_fullscreen_requested(),
		"fullscreen preference survives round trip"
	)
	_expect_float(
		restored.get_ui_scale_factor(),
		1.5,
		"UI scale survives round trip"
	)
	_expect_true(
		restored.is_reduced_motion(),
		"reduced-motion preference survives round trip"
	)
	_expect_float(
		restored.get_master_volume(),
		0.35,
		"master volume survives round trip"
	)
	_expect_int(
		restored.get_key_binding(DemoSettingsState.ACTION_HELP),
		KEY_H,
		"custom shortcut survives round trip"
	)


func _test_legacy_settings_migrate_with_default_bindings(
	store: SettingsStore
) -> void:
	var legacy_settings: Dictionary = DemoSettingsState.new(
		"en",
		Vector2i(1920, 1080),
		false,
		1.25,
		true,
		0.6
	).to_dictionary()
	legacy_settings.erase("key_bindings")
	var legacy_payload: Dictionary = {
		"format_version": SettingsStore.LEGACY_FORMAT_VERSION,
		"settings": legacy_settings,
	}
	var absolute_path: String = ProjectSettings.globalize_path(
		TEST_SETTINGS_PATH
	)
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	_expect_true(file != null, "legacy settings fixture can be opened")
	if file == null:
		return
	file.store_string(CanonicalSaveJson.encode(legacy_payload))
	file.close()
	var result: Dictionary = store.load_or_default()
	_expect_true(result.get("ok", false), "legacy settings still load")
	_expect_true(
		result.get("migrated", false),
		"legacy settings are explicitly marked migrated"
	)
	var restored: DemoSettingsState = result["settings"]
	_expect_int(
		restored.get_key_binding(DemoSettingsState.ACTION_HELP),
		KEY_F1,
		"legacy settings receive the default Help shortcut"
	)
	_expect_int(
		restored.get_key_binding(DemoSettingsState.ACTION_JOURNAL),
		KEY_J,
		"legacy settings receive the default Journal shortcut"
	)


func _test_corrupt_file_uses_safe_defaults(store: SettingsStore) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(
		TEST_SETTINGS_PATH
	)
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	_expect_true(file != null, "corrupt settings fixture can be opened")
	if file == null:
		return
	file.store_string("{not-json")
	file.close()
	var result: Dictionary = store.load_or_default(
		"en",
		Vector2i(1920, 1080),
		false
	)
	_expect_true(
		not result.get("ok", true),
		"corrupt settings report a read failure"
	)
	_expect_true(
		result.get("used_defaults", false),
		"corrupt settings explicitly use defaults"
	)
	var fallback: DemoSettingsState = result["settings"]
	_expect_string(
		fallback.get_locale_code(),
		"en",
		"fallback respects the caller's safe locale"
	)


func _test_unsafe_path_is_rejected() -> void:
	var unsafe_store: SettingsStore = SettingsStore.new(
		"user://../settings.json"
	)
	var state: DemoSettingsState = DemoSettingsState.new()
	_expect_true(
		not unsafe_store.save(state).get("ok", false),
		"settings path traversal is rejected"
	)
	_expect_true(
		not unsafe_store.load_or_default().get("ok", true),
		"unsafe settings source reports failure"
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
