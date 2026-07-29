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
const ACTION_HELP: StringName = &"help"
const ACTION_JOURNAL: StringName = &"journal"
const ACTION_LAYOUT: StringName = &"layout"
const BINDABLE_ACTIONS: Array[StringName] = [
	ACTION_HELP,
	ACTION_JOURNAL,
	ACTION_LAYOUT,
]
const DEFAULT_HELP_KEY: Key = KEY_F1
const DEFAULT_JOURNAL_KEY: Key = KEY_J
const DEFAULT_LAYOUT_KEY: Key = KEY_L

var _resolution_index: int = 0
var _locale_index: int = 0
var _fullscreen_requested: bool = false
var _ui_scale_index: int = 0
var _reduced_motion: bool = false
var _master_volume: float = 0.8
var _ambient_volume: float = 0.42
var _effects_volume: float = 0.72
var _key_bindings: Dictionary[StringName, int] = {
	ACTION_HELP: DEFAULT_HELP_KEY,
	ACTION_JOURNAL: DEFAULT_JOURNAL_KEY,
	ACTION_LAYOUT: DEFAULT_LAYOUT_KEY,
}


func _init(
	initial_locale: String = "zh_CN",
	initial_window_size: Vector2i = Vector2i(1280, 720),
	initial_fullscreen: bool = false,
	initial_ui_scale: float = 1.0,
	initial_reduced_motion: bool = false,
	initial_master_volume: float = 0.8,
	initial_key_bindings: Dictionary = {},
	initial_ambient_volume: float = 0.42,
	initial_effects_volume: float = 0.72
) -> void:
	_locale_index = _find_locale_index(initial_locale)
	_resolution_index = _find_resolution_index(initial_window_size)
	_fullscreen_requested = initial_fullscreen
	_ui_scale_index = _find_ui_scale_index(initial_ui_scale)
	_reduced_motion = initial_reduced_motion
	_master_volume = clampf(initial_master_volume, 0.0, 1.0)
	_ambient_volume = clampf(initial_ambient_volume, 0.0, 1.0)
	_effects_volume = clampf(initial_effects_volume, 0.0, 1.0)
	if not initial_key_bindings.is_empty():
		_replace_key_bindings(initial_key_bindings)


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


func set_ambient_volume(value: float) -> bool:
	if is_nan(value) or is_inf(value):
		return false
	_ambient_volume = clampf(value, 0.0, 1.0)
	return true


func get_ambient_volume() -> float:
	return _ambient_volume


func set_effects_volume(value: float) -> bool:
	if is_nan(value) or is_inf(value):
		return false
	_effects_volume = clampf(value, 0.0, 1.0)
	return true


func get_effects_volume() -> float:
	return _effects_volume


func get_key_binding(action_id: StringName) -> int:
	return int(_key_bindings.get(action_id, KEY_NONE))


func get_key_binding_label(action_id: StringName) -> String:
	var keycode: int = get_key_binding(action_id)
	return (
		OS.get_keycode_string(keycode)
		if keycode != KEY_NONE else "—"
	)


func set_key_binding(action_id: StringName, keycode: int) -> bool:
	if not BINDABLE_ACTIONS.has(action_id) or not is_valid_binding_key(keycode):
		return false
	for other_action: StringName in BINDABLE_ACTIONS:
		if (
			other_action != action_id
			and get_key_binding(other_action) == keycode
		):
			return false
	_key_bindings[action_id] = keycode
	return true


func reset_key_bindings() -> void:
	_key_bindings = {
		ACTION_HELP: DEFAULT_HELP_KEY,
		ACTION_JOURNAL: DEFAULT_JOURNAL_KEY,
		ACTION_LAYOUT: DEFAULT_LAYOUT_KEY,
	}


func key_bindings_to_dictionary() -> Dictionary:
	return {
		String(ACTION_HELP): get_key_binding(ACTION_HELP),
		String(ACTION_JOURNAL): get_key_binding(ACTION_JOURNAL),
		String(ACTION_LAYOUT): get_key_binding(ACTION_LAYOUT),
	}


static func is_valid_binding_key(keycode: int) -> bool:
	var allowed_keys: Array[int] = [
		KEY_B,
		KEY_C,
		KEY_E,
		KEY_F,
		KEY_G,
		KEY_H,
		KEY_I,
		KEY_J,
		KEY_K,
		KEY_L,
		KEY_M,
		KEY_N,
		KEY_O,
		KEY_Q,
		KEY_T,
		KEY_U,
		KEY_V,
		KEY_X,
		KEY_Y,
		KEY_Z,
		KEY_F1,
		KEY_F2,
		KEY_F4,
		KEY_F5,
		KEY_F6,
		KEY_F7,
		KEY_F8,
		KEY_F9,
		KEY_F10,
		KEY_F11,
		KEY_F12,
	]
	return allowed_keys.has(keycode)


func to_dictionary() -> Dictionary:
	return {
		"resolution_index": _resolution_index,
		"locale": get_locale_code(),
		"fullscreen": _fullscreen_requested,
		"ui_scale_index": _ui_scale_index,
		"reduced_motion": _reduced_motion,
		"master_volume": _master_volume,
		"ambient_volume": _ambient_volume,
		"effects_volume": _effects_volume,
		"key_bindings": key_bindings_to_dictionary(),
	}


static func from_dictionary(
	value: Dictionary,
	require_key_bindings: bool = false,
	require_split_audio: bool = false
) -> DemoSettingsState:
	var required_keys: Array[String] = [
		"resolution_index",
		"locale",
		"fullscreen",
		"ui_scale_index",
		"reduced_motion",
		"master_volume",
	]
	var has_key_bindings: bool = value.has("key_bindings")
	var has_ambient_volume: bool = value.has("ambient_volume")
	var has_effects_volume: bool = value.has("effects_volume")
	if has_ambient_volume != has_effects_volume:
		return null
	var has_split_audio: bool = has_ambient_volume and has_effects_volume
	var expected_size: int = (
		required_keys.size()
		+ (1 if has_key_bindings else 0)
		+ (2 if has_split_audio else 0)
	)
	if (
		value.size() != expected_size
		or (require_key_bindings and not has_key_bindings)
		or (require_split_audio and not has_split_audio)
	):
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
	var ambient_volume: float = 0.42
	var effects_volume: float = 0.72
	if has_split_audio:
		if (
			(
				typeof(value["ambient_volume"]) != TYPE_INT
				and typeof(value["ambient_volume"]) != TYPE_FLOAT
			)
			or (
				typeof(value["effects_volume"]) != TYPE_INT
				and typeof(value["effects_volume"]) != TYPE_FLOAT
			)
		):
			return null
		ambient_volume = float(value["ambient_volume"])
		effects_volume = float(value["effects_volume"])
		if (
			is_nan(ambient_volume)
			or is_inf(ambient_volume)
			or ambient_volume < 0.0
			or ambient_volume > 1.0
			or is_nan(effects_volume)
			or is_inf(effects_volume)
			or effects_volume < 0.0
			or effects_volume > 1.0
		):
			return null
	var bindings: Dictionary = {}
	if has_key_bindings:
		if typeof(value["key_bindings"]) != TYPE_DICTIONARY:
			return null
		bindings = value["key_bindings"]
	var state: DemoSettingsState = DemoSettingsState.new(
		String(value["locale"]),
		Vector2i(1280, 720),
		bool(value["fullscreen"]),
		1.0,
		bool(value["reduced_motion"]),
		volume,
		bindings,
		ambient_volume,
		effects_volume
	)
	if (
		not state.select_resolution(int(value["resolution_index"]))
		or not state.select_ui_scale(int(value["ui_scale_index"]))
		or (
			not bindings.is_empty()
			and not state._bindings_match_dictionary(bindings)
		)
	):
		return null
	return state


func _replace_key_bindings(value: Dictionary) -> bool:
	if value.size() != BINDABLE_ACTIONS.size():
		return false
	var next_bindings: Dictionary[StringName, int] = {}
	var used_keys: Array[int] = []
	for action_id: StringName in BINDABLE_ACTIONS:
		var key: String = String(action_id)
		if (
			not value.has(key)
			or not _is_integral_number(value[key])
		):
			return false
		var keycode: int = int(value[key])
		if not is_valid_binding_key(keycode) or used_keys.has(keycode):
			return false
		next_bindings[action_id] = keycode
		used_keys.append(keycode)
	_key_bindings = next_bindings
	return true


func _bindings_match_dictionary(value: Dictionary) -> bool:
	for action_id: StringName in BINDABLE_ACTIONS:
		if (
			not value.has(String(action_id))
			or get_key_binding(action_id)
				!= int(value[String(action_id)])
		):
			return false
	return true


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
