class_name SettingsStore
extends RefCounted

const FORMAT_VERSION: int = 2
const LEGACY_FORMAT_VERSION: int = 1
const DEFAULT_PATH: String = "user://settings.json"
const MAX_SETTINGS_BYTES: int = 32 * 1024

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


func save(settings: DemoSettingsState) -> Dictionary:
	if settings == null or not _is_safe_user_path(_path):
		return _failure("Settings destination is invalid")
	var payload: Dictionary = {
		"format_version": FORMAT_VERSION,
		"settings": settings.to_dictionary(),
	}
	var encoded: String = CanonicalSaveJson.encode(payload)
	if encoded.is_empty() or encoded.to_utf8_buffer().size() > MAX_SETTINGS_BYTES:
		return _failure("Settings data is invalid")
	var absolute_path: String = ProjectSettings.globalize_path(_path)
	var temporary_path: String = absolute_path + ".tmp"
	var parent_path: String = absolute_path.get_base_dir()
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		parent_path
	)
	if directory_error != OK and not DirAccess.dir_exists_absolute(parent_path):
		return _failure("Could not create settings directory")
	if FileAccess.file_exists(temporary_path):
		DirAccess.remove_absolute(temporary_path)
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _failure("Could not open temporary settings")
	file.store_string(encoded)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return _failure("Could not write temporary settings")
	var verify_result: Dictionary = _load_absolute(temporary_path)
	if not verify_result.get("ok", false):
		return _failure("Temporary settings verification failed")
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	var promote_error: Error = DirAccess.rename_absolute(
		temporary_path,
		absolute_path
	)
	if promote_error != OK:
		return _failure("Could not commit settings")
	return {"ok": true, "error": "", "path": _path}


func load_or_default(
	default_locale: String = "zh_CN",
	default_window_size: Vector2i = Vector2i(1280, 720),
	default_fullscreen: bool = false
) -> Dictionary:
	var fallback: DemoSettingsState = DemoSettingsState.new(
		default_locale,
		default_window_size,
		default_fullscreen
	)
	if not _is_safe_user_path(_path):
		return {
			"ok": false,
			"error": "Settings source is invalid",
			"settings": fallback,
			"used_defaults": true,
		}
	var absolute_path: String = ProjectSettings.globalize_path(_path)
	if not FileAccess.file_exists(absolute_path):
		return {
			"ok": true,
			"error": "",
			"settings": fallback,
			"used_defaults": true,
		}
	var result: Dictionary = _load_absolute(absolute_path)
	if not result.get("ok", false):
		result["settings"] = fallback
		result["used_defaults"] = true
		return result
	result["used_defaults"] = false
	return result


func delete_for_tests() -> void:
	if not _is_safe_user_path(_path):
		return
	var absolute_path: String = ProjectSettings.globalize_path(_path)
	for candidate: String in [absolute_path, absolute_path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


func _load_absolute(absolute_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return _failure("Could not open settings")
	var length: int = file.get_length()
	if length < 1 or length > MAX_SETTINGS_BYTES:
		file.close()
		return _failure("Settings size is invalid")
	var text: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return _failure("Settings JSON is invalid")
	var root: Dictionary = parser.data
	if (
		root.size() != 2
		or not root.has("format_version")
		or not root.has("settings")
		or (
			typeof(root["format_version"]) != TYPE_INT
			and typeof(root["format_version"]) != TYPE_FLOAT
		)
		or typeof(root["settings"]) != TYPE_DICTIONARY
	):
		return _failure("Settings format is invalid")
	var format_version: int = int(root["format_version"])
	if (
		format_version != FORMAT_VERSION
		and format_version != LEGACY_FORMAT_VERSION
	):
		return _failure("Settings format is unsupported")
	var settings: DemoSettingsState = DemoSettingsState.from_dictionary(
		root["settings"],
		format_version == FORMAT_VERSION
	)
	if settings == null:
		return _failure("Settings values are invalid")
	return {
		"ok": true,
		"error": "",
		"settings": settings,
		"migrated": format_version == LEGACY_FORMAT_VERSION,
	}


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
