class_name CampaignState
extends RefCounted

enum Chapter {
	FOUNDING_OBSERVATION,
	ENVIRONMENTAL_CARE,
	ACT1_FOUNDING,
	ACT1_FIRST_WORKERS,
	ACT1_FORAGING_EXPANSION,
	ACT1_ENVIRONMENT_MANAGEMENT,
	ACT1_MODULAR_MIGRATION,
	ACT1_STABLE_COLONY_SUMMARY,
}

enum Status {
	ACTIVE,
	AWAITING_INFERENCE,
	COMPLETED,
}

const EVIDENCE_FIRST_WORKER: StringName = &"first_worker_emerged"
const EVIDENCE_HUMIDITY_RELOCATION: StringName = (
	&"brood_humidity_relocation"
)
const EVIDENCE_SUGAR_SHARING: StringName = &"sugar_foraging_complete"
const EVIDENCE_QUEEN_CARE: StringName = &"queen_brood_care"
const EVIDENCE_FIRST_PUPA: StringName = &"first_pupa_stable"
const EVIDENCE_FIRST_WORKER_CARE: StringName = (
	&"first_worker_brood_care"
)
const EVIDENCE_FIRST_NUTRIENT_EXCHANGE: StringName = (
	&"first_nutrient_exchange"
)
const EVIDENCE_FORAGING_ZONE_SCOUTED: StringName = (
	&"foraging_zone_scouted"
)
const EVIDENCE_FORAGING_SUGAR_CYCLE: StringName = (
	&"foraging_sugar_cycle"
)
const EVIDENCE_PROTEIN_CARE: StringName = &"protein_brood_care"
const EVIDENCE_WASTE_TRAY_CLEANED: StringName = &"waste_tray_cleaned"
const EVIDENCE_SMALL_COLONY_STABLE: StringName = &"small_colony_stable"
const EVIDENCE_HYDRATION_RESPONSE: StringName = &"hydration_response"
const EVIDENCE_POLLUTION_AVOIDANCE: StringName = &"pollution_avoidance"
const EVIDENCE_PARTIAL_MIGRATION: StringName = &"partial_migration"
const EVIDENCE_ENVIRONMENT_STABLE: StringName = &"environment_stable"
const EVIDENCE_DUAL_NEST_CONNECTED: StringName = &"dual_nest_connected"
const EVIDENCE_DUAL_NEST_SCOUTED: StringName = &"dual_nest_scouted"
const EVIDENCE_CORE_BROOD_MIGRATED: StringName = &"core_brood_migrated"
const EVIDENCE_QUEEN_MIGRATED: StringName = &"queen_migrated"
const EVIDENCE_FUNCTIONAL_ZONING: StringName = &"functional_zoning"
const EVIDENCE_FIRST_WORKER_HISTORY: StringName = (
	&"first_worker_history_reviewed"
)
const EVIDENCE_KEY_INTERVENTIONS: StringName = (
	&"key_interventions_reviewed"
)
const EVIDENCE_FINAL_LAYOUT_STABLE: StringName = (
	&"final_layout_stable"
)
const EVIDENCE_LONG_TERM_PATTERN: StringName = (
	&"long_term_colony_pattern"
)

const INFERENCE_FIRST_WORKER: StringName = &"brood_develops_into_workers"
const INFERENCE_FIRST_WORKER_RANDOM: StringName = &"worker_change_is_random"
const INFERENCE_FIRST_WORKER_DIRECTED: StringName = (
	&"player_directs_worker_development"
)
const INFERENCE_ENVIRONMENT: StringName = (
	&"workers_respond_to_environment"
)
const INFERENCE_ENVIRONMENT_IGNORED: StringName = (
	&"workers_ignore_environment"
)
const INFERENCE_ENVIRONMENT_DIRECTED: StringName = (
	&"player_directs_each_worker"
)
const INFERENCE_QUEEN_CARE: StringName = &"queen_cares_for_brood"
const INFERENCE_QUEEN_CARE_RANDOM: StringName = (
	&"queen_movement_is_random"
)
const INFERENCE_QUEEN_CARE_DIRECTED: StringName = (
	&"player_directs_queen_care"
)
const INFERENCE_WORKER_NUTRITION: StringName = (
	&"workers_share_nutrition_and_care"
)
const INFERENCE_WORKER_NUTRITION_RANDOM: StringName = (
	&"worker_feeding_is_random"
)
const INFERENCE_WORKER_NUTRITION_DIRECTED: StringName = (
	&"player_directs_each_feeding"
)
const INFERENCE_FORAGING_ROLES: StringName = (
	&"food_and_waste_need_distinct_facilities"
)
const INFERENCE_FORAGING_RANDOM: StringName = (
	&"foraging_roles_are_random"
)
const INFERENCE_FORAGING_DIRECTED: StringName = (
	&"player_directs_each_foraging_task"
)
const INFERENCE_ENVIRONMENT_GRADIENT: StringName = (
	&"workers_compare_environment_gradients"
)
const INFERENCE_ENVIRONMENT_MAXIMUM: StringName = (
	&"every_environment_value_should_be_maximum"
)
const INFERENCE_GRADIENT_DIRECTED: StringName = (
	&"player_directs_each_migration"
)
const INFERENCE_MIGRATION_CONDITIONS: StringName = (
	&"connection_and_gradients_enable_migration"
)
const INFERENCE_MIGRATION_DIRECTED: StringName = (
	&"player_orders_the_colony_to_migrate"
)
const INFERENCE_MIGRATION_SIZE: StringName = (
	&"the_largest_nest_always_wins"
)
const INFERENCE_LAYOUT_SHAPES_BEHAVIOR: StringName = (
	&"layout_shapes_long_term_behavior"
)
const INFERENCE_FINALE_RANDOM: StringName = (
	&"stable_colony_is_random"
)
const INFERENCE_FINALE_DIRECTED: StringName = (
	&"player_directs_every_long_term_task"
)

const FACILITY_TEST_TUBE_NEST: StringName = &"test_tube_nest"
const FACILITY_LIGHT_COVER: StringName = &"light_cover"
const FACILITY_MICRO_FEEDING_PORT: StringName = &"micro_feeding_port"
const FACILITY_SMALL_FORAGING_BOX: StringName = &"small_foraging_box"
const FACILITY_MAGNIFIER: StringName = &"magnifier"
const FACILITY_SUGAR_STATION: StringName = &"sugar_station"
const FACILITY_PROTEIN_DISH: StringName = &"protein_dish"
const FACILITY_WASTE_TRAY: StringName = &"waste_tray"
const FACILITY_SPARE_TEST_TUBE: StringName = &"spare_test_tube"
const FACILITY_HYDRATION_MODULE: StringName = &"hydration_module"
const FACILITY_CONNECTOR_FAMILY: StringName = &"connector_family"
const FACILITY_DUAL_CHAMBER_NEST: StringName = &"dual_chamber_nest"

var chapter: Chapter = Chapter.FOUNDING_OBSERVATION
var status: Status = Status.ACTIVE
var chapter_entered_tick: int = 0
var completed_chapter_count: int = 0
var incorrect_inference_attempts: int = 0
var hint_tier: int = 0
var campaign_completed_tick: int = -1
var collected_evidence_ids: Dictionary[StringName, bool] = {}
var confirmed_inference_ids: Dictionary[StringName, bool] = {}
var unlocked_facility_type_ids: Dictionary[StringName, bool] = {}


func _init(
	initial_chapter: Chapter = Chapter.FOUNDING_OBSERVATION
) -> void:
	chapter = initial_chapter
	unlocked_facility_type_ids[FACILITY_TEST_TUBE_NEST] = true
	unlocked_facility_type_ids[FACILITY_LIGHT_COVER] = true
	if initial_chapter == Chapter.ACT1_FOUNDING:
		unlocked_facility_type_ids[FACILITY_MAGNIFIER] = true


func collect_evidence(evidence_id: StringName) -> bool:
	if evidence_id.is_empty() or collected_evidence_ids.has(evidence_id):
		return false
	collected_evidence_ids[evidence_id] = true
	return true


func confirm_inference(inference_id: StringName) -> bool:
	if inference_id.is_empty() or confirmed_inference_ids.has(inference_id):
		return false
	confirmed_inference_ids[inference_id] = true
	return true


func unlock_facility(type_id: StringName) -> bool:
	if type_id.is_empty() or unlocked_facility_type_ids.has(type_id):
		return false
	unlocked_facility_type_ids[type_id] = true
	return true


func copy_evidence_ids() -> Array[StringName]:
	return _copy_sorted_ids(collected_evidence_ids)


func copy_confirmed_inference_ids() -> Array[StringName]:
	return _copy_sorted_ids(confirmed_inference_ids)


func copy_unlocked_facility_type_ids() -> Array[StringName]:
	return _copy_sorted_ids(unlocked_facility_type_ids)


func _copy_sorted_ids(source: Dictionary[StringName, bool]) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in source:
		result.append(id)
	result.sort_custom(
		func(first: StringName, second: StringName) -> bool:
			return String(first) < String(second)
	)
	return result
