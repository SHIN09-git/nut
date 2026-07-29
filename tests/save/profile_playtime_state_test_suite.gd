class_name ProfilePlaytimeStateTestSuite
extends RefCounted

const FOUNDING_CHAPTER: int = CampaignState.Chapter.FOUNDING_OBSERVATION
const HUMIDITY_CHAPTER: int = CampaignState.Chapter.ENVIRONMENTAL_CARE

var _assertion_count: int = 0
var _failure_count: int = 0


func run() -> void:
	_test_default_state_is_empty_and_complete()
	_test_active_time_is_split_by_chapter()
	_test_first_completion_time_is_stable()
	_test_save_data_is_copy_isolated()
	_test_invalid_save_data_is_rejected()
	_test_legacy_gap_is_explicit()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_default_state_is_empty_and_complete() -> void:
	var state := ProfilePlaytimeState.new()
	var save_data: Dictionary = state.create_save_data()
	_expect_float(
		state.get_active_seconds(),
		0.0,
		"a new profile has no active observation time"
	)
	_expect_int(
		save_data["chapter_active_microseconds"].size(),
		ProfilePlaytimeState.CHAPTER_SLOT_COUNT,
		"playtime metadata reserves one stable slot per chapter enum"
	)
	_expect_true(
		ProfilePlaytimeState.is_valid_save_data(save_data),
		"default playtime metadata validates"
	)
	_expect_true(
		not state.has_legacy_gap(),
		"a newly tracked profile has no legacy evidence gap"
	)


func _test_active_time_is_split_by_chapter() -> void:
	var state := ProfilePlaytimeState.new()
	_expect_true(
		state.advance_seconds(1.25, FOUNDING_CHAPTER, false),
		"positive founding time advances"
	)
	_expect_true(
		state.advance_seconds(2.5, HUMIDITY_CHAPTER, false),
		"positive humidity time advances"
	)
	_expect_float(
		state.get_active_seconds(),
		3.75,
		"active time is independent of simulation Tick count"
	)
	_expect_float(
		state.get_chapter_active_seconds(FOUNDING_CHAPTER),
		1.25,
		"founding time remains in its chapter slot"
	)
	_expect_float(
		state.get_chapter_active_seconds(HUMIDITY_CHAPTER),
		2.5,
		"humidity time remains in its chapter slot"
	)
	_expect_true(
		not state.advance_seconds(0.0, FOUNDING_CHAPTER, false)
			and not state.advance_seconds(-1.0, FOUNDING_CHAPTER, false)
			and not state.advance_seconds(NAN, FOUNDING_CHAPTER, false),
		"nonpositive and nonfinite deltas are rejected"
	)


func _test_first_completion_time_is_stable() -> void:
	var state := ProfilePlaytimeState.new()
	state.advance_seconds(12.0, FOUNDING_CHAPTER, false)
	state.advance_seconds(3.0, HUMIDITY_CHAPTER, true)
	_expect_float(
		state.get_completion_active_seconds(),
		15.0,
		"first completion records effective observation time"
	)
	state.advance_seconds(5.0, HUMIDITY_CHAPTER, true)
	_expect_float(
		state.get_active_seconds(),
		20.0,
		"free observation continues to add profile time"
	)
	_expect_float(
		state.get_completion_active_seconds(),
		15.0,
		"free observation cannot overwrite first completion time"
	)


func _test_save_data_is_copy_isolated() -> void:
	var state := ProfilePlaytimeState.new()
	state.advance_seconds(4.5, FOUNDING_CHAPTER, false)
	var save_data: Dictionary = state.create_save_data()
	save_data["chapter_active_microseconds"][FOUNDING_CHAPTER] = 0
	_expect_float(
		state.get_chapter_active_seconds(FOUNDING_CHAPTER),
		4.5,
		"mutating returned playtime data cannot change live tracking"
	)
	var restored := ProfilePlaytimeState.new()
	_expect_true(
		restored.restore(state.create_save_data()),
		"valid playtime metadata restores"
	)
	_expect_float(
		restored.get_active_seconds(),
		4.5,
		"restored playtime preserves microsecond precision"
	)


func _test_invalid_save_data_is_rejected() -> void:
	var valid: Dictionary = (
		ProfilePlaytimeState.create_default_save_data()
	)
	var negative: Dictionary = valid.duplicate(true)
	negative["active_microseconds"] = -1
	var wrong_slots: Dictionary = valid.duplicate(true)
	wrong_slots["chapter_active_microseconds"] = [0]
	var chapter_exceeds_total: Dictionary = valid.duplicate(true)
	chapter_exceeds_total["chapter_active_microseconds"][
		FOUNDING_CHAPTER
	] = 1
	var future_completion: Dictionary = valid.duplicate(true)
	future_completion["completion_active_microseconds"] = 1
	var unexpected: Dictionary = valid.duplicate(true)
	unexpected["extra"] = true
	_expect_true(
		not ProfilePlaytimeState.is_valid_save_data(negative),
		"negative active time is rejected"
	)
	_expect_true(
		not ProfilePlaytimeState.is_valid_save_data(wrong_slots),
		"chapter slot count is schema validated"
	)
	_expect_true(
		not ProfilePlaytimeState.is_valid_save_data(
			chapter_exceeds_total
		),
		"chapter time cannot exceed total active time"
	)
	_expect_true(
		not ProfilePlaytimeState.is_valid_save_data(future_completion),
		"completion time cannot exceed total active time"
	)
	_expect_true(
		not ProfilePlaytimeState.is_valid_save_data(unexpected),
		"unexpected playtime fields are rejected"
	)


func _test_legacy_gap_is_explicit() -> void:
	var state := ProfilePlaytimeState.new()
	_expect_true(
		state.restore(
			ProfilePlaytimeState.create_default_save_data(true)
		),
		"legacy playtime metadata restores"
	)
	_expect_true(
		state.has_legacy_gap(),
		"migrated profiles preserve an explicit incomplete-history marker"
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


func _expect_float(
	actual: float,
	expected: float,
	message: String
) -> void:
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
