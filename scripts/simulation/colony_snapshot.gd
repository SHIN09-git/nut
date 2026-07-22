class_name ColonySnapshot
extends RefCounted

var simulation_tick: int = 0
var queen_entity_id: int = 0
var queen_laid_egg_count: int = 0
var max_first_generation_brood: int = 0
var next_egg_tick: int = -1
var ants: Array[AntSnapshot] = []


func count_stage(stage: AntModel.LifeStage) -> int:
	var count: int = 0
	for ant: AntSnapshot in ants:
		if ant.life_stage == stage:
			count += 1
	return count
