class_name Act1ExperimentState
extends RefCounted

const PREDICTION_CARE_INCREASES: StringName = &"care_increases"
const PREDICTION_NO_VISIBLE_CHANGE: StringName = &"no_visible_change"
const PREDICTION_QUEEN_MOVES_AWAY: StringName = &"queen_moves_away"
const PREDICTION_WORKER_SHARES: StringName = &"worker_shares"
const PREDICTION_WORKER_STAYS: StringName = &"worker_stays"
const PREDICTION_DIRECT_CONTROL_REQUIRED: StringName = (
	&"direct_control_required"
)

var _prediction_by_chapter: Dictionary[int, StringName] = {}
var _baseline_care_count_by_chapter: Dictionary[int, int] = {}
var _baseline_sugar_count_by_chapter: Dictionary[int, int] = {}


func reset_session() -> void:
	_prediction_by_chapter.clear()
	_baseline_care_count_by_chapter.clear()
	_baseline_sugar_count_by_chapter.clear()


func get_prediction_ids(chapter: int) -> Array[StringName]:
	match chapter:
		CampaignState.Chapter.ACT1_FOUNDING:
			return [
				PREDICTION_CARE_INCREASES,
				PREDICTION_NO_VISIBLE_CHANGE,
				PREDICTION_QUEEN_MOVES_AWAY,
			]
		CampaignState.Chapter.ACT1_FIRST_WORKERS:
			return [
				PREDICTION_WORKER_SHARES,
				PREDICTION_WORKER_STAYS,
				PREDICTION_DIRECT_CONTROL_REQUIRED,
			]
	return []


func record_prediction(
	chapter: int,
	prediction_id: StringName,
	snapshot: GameSnapshot
) -> bool:
	if (
		snapshot == null
		or snapshot.campaign == null
		or snapshot.act1 == null
		or snapshot.nutrition == null
		or snapshot.campaign.chapter != chapter
		or has_prediction(chapter)
		or not get_prediction_ids(chapter).has(prediction_id)
		or _intervention_has_started(chapter, snapshot)
	):
		return false
	_prediction_by_chapter[chapter] = prediction_id
	_baseline_care_count_by_chapter[chapter] = (
		snapshot.act1.queen_care.completed_care_count
	)
	_baseline_sugar_count_by_chapter[chapter] = (
		snapshot.scenario.place_action_count
		if snapshot.scenario != null else 0
	)
	return true


func has_prediction(chapter: int) -> bool:
	return _prediction_by_chapter.has(chapter)


func get_prediction(chapter: int) -> StringName:
	return _prediction_by_chapter.get(chapter, &"")


func get_baseline_care_count(chapter: int) -> int:
	return _baseline_care_count_by_chapter.get(chapter, 0)


func get_baseline_sugar_count(chapter: int) -> int:
	return _baseline_sugar_count_by_chapter.get(chapter, 0)


func should_gate_intervention(
	chapter: int,
	snapshot: GameSnapshot
) -> bool:
	return (
		not has_prediction(chapter)
		and not _intervention_has_started(chapter, snapshot)
		and not get_prediction_ids(chapter).is_empty()
	)


func _intervention_has_started(
	chapter: int,
	snapshot: GameSnapshot
) -> bool:
	match chapter:
		CampaignState.Chapter.ACT1_FOUNDING:
			return (
				snapshot.act1.queen_care.light_cover_applied
				or snapshot.act1.queen_care.light_cover_action_pending
			)
		CampaignState.Chapter.ACT1_FIRST_WORKERS:
			return (
				snapshot.scenario != null
				and (
					snapshot.scenario.place_action_count > 0
					or snapshot.scenario.place_action_pending
				)
			)
	return true
