class_name DemoSettingsState
extends RefCounted

const WINDOWED_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
]
const SUPPORTED_LOCALES: PackedStringArray = [
	"zh_CN",
	"en",
]

var _resolution_index: int = 0
var _locale_index: int = 0
var _fullscreen_requested: bool = false


func _init(
	initial_locale: String = "zh_CN",
	initial_window_size: Vector2i = Vector2i(1280, 720),
	initial_fullscreen: bool = false
) -> void:
	_locale_index = _find_locale_index(initial_locale)
	_resolution_index = _find_resolution_index(initial_window_size)
	_fullscreen_requested = initial_fullscreen


func select_resolution(index: int) -> bool:
	if index < 0 or index >= WINDOWED_RESOLUTIONS.size():
		return false
	_resolution_index = index
	return true


func get_resolution_index() -> int:
	return _resolution_index


func get_windowed_resolution() -> Vector2i:
	return WINDOWED_RESOLUTIONS[_resolution_index]


func select_locale(index: int) -> bool:
	if index < 0 or index >= SUPPORTED_LOCALES.size():
		return false
	_locale_index = index
	return true


func get_locale_index() -> int:
	return _locale_index


func get_locale_code() -> String:
	return SUPPORTED_LOCALES[_locale_index]


func set_fullscreen_requested(value: bool) -> void:
	_fullscreen_requested = value


func is_fullscreen_requested() -> bool:
	return _fullscreen_requested


func _find_locale_index(locale_code: String) -> int:
	var normalized_locale: String = locale_code.to_lower()
	if normalized_locale.begins_with("en"):
		return 1
	return 0


func _find_resolution_index(window_size: Vector2i) -> int:
	for index: int in range(WINDOWED_RESOLUTIONS.size()):
		if WINDOWED_RESOLUTIONS[index] == window_size:
			return index
	return 0
