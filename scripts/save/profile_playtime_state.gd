class_name ProfilePlaytimeState
extends RefCounted

const FORMAT_VERSION: int = 1
const CHAPTER_SLOT_COUNT: int = 8
const MICROSECONDS_PER_SECOND: int = 1_000_000
const MAX_ACTIVE_MICROSECONDS: int = (
	100 * 365 * 24 * 60 * 60 * MICROSECONDS_PER_SECOND
)

var _active_microseconds: int = 0
var _chapter_active_microseconds: Array[int] = []
var _completion_active_microseconds: int = -1
var _has_legacy_gap: bool = false


func _init() -> void:
	reset()


func reset(has_legacy_gap: bool = false) -> void:
	_active_microseconds = 0
	_chapter_active_microseconds.clear()
	_chapter_active_microseconds.resize(CHAPTER_SLOT_COUNT)
	_chapter_active_microseconds.fill(0)
	_completion_active_microseconds = -1
	_has_legacy_gap = has_legacy_gap


func advance_seconds(
	seconds: float,
	chapter: int,
	campaign_completed: bool
) -> bool:
	if not is_finite(seconds) or seconds <= 0.0:
		return false
	var elapsed_microseconds: int = int(round(
		seconds * float(MICROSECONDS_PER_SECOND)
	))
	if (
		elapsed_microseconds <= 0
		or _active_microseconds
			> MAX_ACTIVE_MICROSECONDS - elapsed_microseconds
	):
		return false
	_active_microseconds += elapsed_microseconds
	if chapter >= 0 and chapter < CHAPTER_SLOT_COUNT:
		_chapter_active_microseconds[chapter] += elapsed_microseconds
	mark_completion_if_needed(campaign_completed)
	return true


func mark_completion_if_needed(campaign_completed: bool) -> void:
	if campaign_completed and _completion_active_microseconds < 0:
		_completion_active_microseconds = _active_microseconds


func restore(save_data: Dictionary) -> bool:
	if not is_valid_save_data(save_data):
		return false
	_active_microseconds = int(save_data["active_microseconds"])
	_chapter_active_microseconds.clear()
	for value: Variant in save_data["chapter_active_microseconds"]:
		_chapter_active_microseconds.append(int(value))
	_completion_active_microseconds = int(
		save_data["completion_active_microseconds"]
	)
	_has_legacy_gap = bool(save_data["has_legacy_gap"])
	return true


func create_save_data() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"active_microseconds": _active_microseconds,
		"chapter_active_microseconds": (
			_chapter_active_microseconds.duplicate()
		),
		"completion_active_microseconds": (
			_completion_active_microseconds
		),
		"has_legacy_gap": _has_legacy_gap,
	}


func get_active_seconds() -> float:
	return (
		float(_active_microseconds)
		/ float(MICROSECONDS_PER_SECOND)
	)


func get_chapter_active_seconds(chapter: int) -> float:
	if chapter < 0 or chapter >= CHAPTER_SLOT_COUNT:
		return 0.0
	return (
		float(_chapter_active_microseconds[chapter])
		/ float(MICROSECONDS_PER_SECOND)
	)


func get_completion_active_seconds() -> float:
	if _completion_active_microseconds < 0:
		return -1.0
	return (
		float(_completion_active_microseconds)
		/ float(MICROSECONDS_PER_SECOND)
	)


func has_legacy_gap() -> bool:
	return _has_legacy_gap


static func create_default_save_data(
	has_legacy_gap: bool = false
) -> Dictionary:
	var state := ProfilePlaytimeState.new()
	state.reset(has_legacy_gap)
	return state.create_save_data()


static func normalize_save_data(save_data: Dictionary) -> Dictionary:
	var state := ProfilePlaytimeState.new()
	if not state.restore(save_data):
		return {}
	return state.create_save_data()


static func is_valid_save_data(save_data: Dictionary) -> bool:
	var required_keys: Array[String] = [
		"format_version",
		"active_microseconds",
		"chapter_active_microseconds",
		"completion_active_microseconds",
		"has_legacy_gap",
	]
	if save_data.size() != required_keys.size():
		return false
	for key: String in required_keys:
		if not save_data.has(key):
			return false
	if (
		not _is_integral_number(save_data["format_version"])
		or int(save_data["format_version"]) != FORMAT_VERSION
		or not _is_nonnegative_bounded_int(
			save_data["active_microseconds"]
		)
		or typeof(save_data["chapter_active_microseconds"])
			!= TYPE_ARRAY
		or typeof(save_data["has_legacy_gap"]) != TYPE_BOOL
		or not _is_integral_number(
			save_data["completion_active_microseconds"]
		)
	):
		return false
	var active_microseconds: int = int(
		save_data["active_microseconds"]
	)
	var completion_microseconds: int = int(
		save_data["completion_active_microseconds"]
	)
	if (
		completion_microseconds < -1
		or completion_microseconds > active_microseconds
	):
		return false
	var chapter_values: Array = save_data[
		"chapter_active_microseconds"
	]
	if chapter_values.size() != CHAPTER_SLOT_COUNT:
		return false
	var chapter_sum: int = 0
	for value: Variant in chapter_values:
		if not _is_nonnegative_bounded_int(value):
			return false
		chapter_sum += int(value)
		if chapter_sum > active_microseconds:
			return false
	return true


static func _is_nonnegative_bounded_int(value: Variant) -> bool:
	return (
		_is_integral_number(value)
		and int(value) >= 0
		and int(value) <= MAX_ACTIVE_MICROSECONDS
	)


static func _is_integral_number(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var numeric: float = float(value)
	return is_finite(numeric) and numeric == floor(numeric)
