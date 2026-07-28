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
const UI_SCALE_FACTORS: PackedFloat32Array = [
	1.0,
	1.25,
	1.5,
]

var _resolution_index: int = 0
var _locale_index: int = 0
var _fullscreen_requested: bool = false
var _ui_scale_index: int = 0
var _reduced_motion: bool = false
var _master_volume: float = 0.8


func _init(
	initial_locale: String = "zh_CN",
	initial_window_size: Vector2i = Vector2i(1280, 720),
	initial_fullscreen: bool = false,
	initial_ui_scale: float = 1.0,
	initial_reduced_motion: bool = false,
	initial_master_volume: float = 0.8
) -> void:
	_locale_index = _find_locale_index(initial_locale)
	_resolution_index = _find_resolution_index(initial_window_size)
	_fullscreen_requested = initial_fullscreen
	_ui_scale_index = _find_ui_scale_index(initial_ui_scale)
	_reduced_motion = initial_reduced_motion
	_master_volume = clampf(initial_master_volume, 0.0, 1.0)


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


func select_ui_scale(index: int) -> bool:
	if index < 0 or index >= UI_SCALE_FACTORS.size():
		return false
	_ui_scale_index = index
	return true


func get_ui_scale_index() -> int:
	return _ui_scale_index


func get_ui_scale_factor() -> float:
	return UI_SCALE_FACTORS[_ui_scale_index]


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value


func is_reduced_motion() -> bool:
	return _reduced_motion


func set_master_volume(value: float) -> bool:
	if is_nan(value) or is_inf(value):
		return false
	_master_volume = clampf(value, 0.0, 1.0)
	return true


func get_master_volume() -> float:
	return _master_volume


func to_dictionary() -> Dictionary:
	return {
		"resolution_index": _resolution_index,
		"locale": get_locale_code(),
		"fullscreen": _fullscreen_requested,
		"ui_scale_index": _ui_scale_index,
		"reduced_motion": _reduced_motion,
		"master_volume": _master_volume,
	}


static func from_dictionary(value: Dictionary) -> DemoSettingsState:
	var required_keys: Array[String] = [
		"resolution_index",
		"locale",
		"fullscreen",
		"ui_scale_index",
		"reduced_motion",
		"master_volume",
	]
	if value.size() != required_keys.size():
		return null
	for key: String in required_keys:
		if not value.has(key):
			return null
	if (
		not _is_integral_number(value["resolution_index"])
		or typeof(value["locale"]) != TYPE_STRING
		or typeof(value["fullscreen"]) != TYPE_BOOL
		or not _is_integral_number(value["ui_scale_index"])
		or typeof(value["reduced_motion"]) != TYPE_BOOL
		or (
			typeof(value["master_volume"]) != TYPE_INT
			and typeof(value["master_volume"]) != TYPE_FLOAT
		)
	):
		return null
	var volume: float = float(value["master_volume"])
	if is_nan(volume) or is_inf(volume) or volume < 0.0 or volume > 1.0:
		return null
	var state: DemoSettingsState = DemoSettingsState.new(
		String(value["locale"]),
		Vector2i(1280, 720),
		bool(value["fullscreen"]),
		1.0,
		bool(value["reduced_motion"]),
		volume
	)
	if (
		not state.select_resolution(int(value["resolution_index"]))
		or not state.select_ui_scale(int(value["ui_scale_index"]))
	):
		return null
	return state


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


func _find_ui_scale_index(scale_factor: float) -> int:
	for index: int in range(UI_SCALE_FACTORS.size()):
		if is_equal_approx(UI_SCALE_FACTORS[index], scale_factor):
			return index
	return 0


static func _is_integral_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number: float = float(value)
	return (
		not is_nan(number)
		and not is_inf(number)
		and number == floorf(number)
	)
