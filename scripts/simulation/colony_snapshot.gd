class_name ColonySnapshot
extends RefCounted

var simulation_tick: int = 0
var lifecycle_active: bool = true
var queen_entity_id: int = 0
var queen_laid_egg_count: int = 0
var max_first_generation_brood: int = 0
var next_egg_tick: int = -1
var ants: Array[AntSnapshot] = []
var scenario_id: StringName = &""
var zones: Array[HabitatZoneSnapshot] = []
var humidity_adjustment_count: int = 0
var water_action_unlocked: bool = false
var water_action_available: bool = false
var water_action_pending: bool = false
var water_action_count: int = 0
var water_target_comfortable: bool = false
var observation_stable_ticks: int = 0
var brood_humidity_observation_unlocked: bool = false
var observation_events: Array[ObservationEvent] = []


func count_stage(stage: AntModel.LifeStage) -> int:
	var count: int = 0
	for ant: AntSnapshot in ants:
		if ant.life_stage == stage:
			count += 1
	return count


func find_zone(zone_id: StringName) -> HabitatZoneSnapshot:
	for zone: HabitatZoneSnapshot in zones:
		if zone.zone_id == zone_id:
			return zone
	return null


func find_ant(entity_id: int) -> AntSnapshot:
	for ant: AntSnapshot in ants:
		if ant.entity_id == entity_id:
			return ant
	return null


func count_active_relocations() -> int:
	var count: int = 0
	for ant: AntSnapshot in ants:
		if (
			ant.life_stage == AntModel.LifeStage.WORKER
			and ant.worker_task_state != WorkerTaskModel.State.IDLE
		):
			count += 1
	return count
