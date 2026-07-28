class_name DemoLocalizationTestSuite
extends RefCounted

const TRANSLATION_CSV_PATH: String = "res://localization/v0_2.csv"
const PLAYER_COPY_SOURCE_PATHS: PackedStringArray = [
	"res://scripts/core/combined_observation_controller.gd",
	"res://scripts/view/worker_observation_panel.gd",
	"res://scripts/view/combined_habitat_view.gd",
	"res://scenes/main/combined_observation.tscn",
	"res://scenes/habitat/combined_habitat.tscn",
]

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_translation_table_is_complete_and_unique()
	_test_both_locales_are_registered_and_resolve_keys()
	_test_player_copy_sources_use_translation_keys()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_translation_table_is_complete_and_unique() -> void:
	var file: FileAccess = FileAccess.open(
		TRANSLATION_CSV_PATH,
		FileAccess.READ
	)
	_expect_true(file != null, "v0.2 translation CSV can be opened")
	if file == null:
		return
	var header: PackedStringArray = file.get_csv_line()
	_expect_true(
		header.size() >= 3
			and header[0] == "keys"
			and header[1] == "zh_CN"
			and header[2] == "en",
		"translation CSV declares key, Simplified Chinese, and English columns"
	)
	var seen_keys: Dictionary[String, bool] = {}
	var row_count: int = 0
	while file.get_position() < file.get_length():
		var row: PackedStringArray = file.get_csv_line()
		if row.is_empty() or (row.size() == 1 and row[0].is_empty()):
			continue
		row_count += 1
		_expect_true(
			row.size() >= 3,
			"translation row %d contains all required columns" % row_count
		)
		if row.size() < 3:
			continue
		var key: String = row[0]
		_expect_true(not key.is_empty(), "translation key is not empty")
		_expect_true(
			not seen_keys.has(key),
			"translation key %s appears only once" % key
		)
		_expect_true(
			not row[1].is_empty(),
			"Simplified Chinese value for %s is not empty" % key
		)
		_expect_true(
			not row[2].is_empty(),
			"English value for %s is not empty" % key
		)
		seen_keys[key] = true
	_expect_true(
		row_count >= 100,
		"translation table covers the complete M5 player-copy surface"
	)


func _test_both_locales_are_registered_and_resolve_keys() -> void:
	var previous_locale: String = TranslationServer.get_locale()
	var loaded_locales: PackedStringArray = (
		TranslationServer.get_loaded_locales()
	)
	_expect_true(
		loaded_locales.has("zh_CN"),
		"Simplified Chinese translation is registered"
	)
	_expect_true(
		loaded_locales.has("en"),
		"English translation is registered"
	)
	TranslationServer.set_locale("zh_CN")
	var chinese_title: String = TranslationServer.translate("UI_TITLE")
	TranslationServer.set_locale("en")
	var english_title: String = TranslationServer.translate("UI_TITLE")
	_expect_true(
		chinese_title != "UI_TITLE",
		"Simplified Chinese resolves the title key"
	)
	_expect_true(
		english_title != "UI_TITLE",
		"English resolves the title key"
	)
	_expect_true(
		chinese_title != english_title,
		"the two locales expose distinct player copy"
	)
	TranslationServer.set_locale(previous_locale)


func _test_player_copy_sources_use_translation_keys() -> void:
	for source_path: String in PLAYER_COPY_SOURCE_PATHS:
		var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
		_expect_true(file != null, "%s can be inspected" % source_path)
		if file == null:
			continue
		var source_text: String = file.get_as_text()
		_expect_true(
			not _contains_cjk_unified_ideograph(source_text),
			"%s does not embed Simplified Chinese player copy" % source_path
		)


func _contains_cjk_unified_ideograph(text: String) -> bool:
	for index: int in range(text.length()):
		var codepoint: int = text.unicode_at(index)
		if (
			(codepoint >= 0x3400 and codepoint <= 0x4DBF)
			or (codepoint >= 0x4E00 and codepoint <= 0x9FFF)
		):
			return true
	return false


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_failure_count += 1
	printerr("  %s - expected true, got false" % message)
