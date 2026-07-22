class_name MainController
extends Control

const SPECIES_A_DATA: SpeciesData = preload("res://data/species/species_a.tres")

var _simulation_clock: SimulationClock
var _colony_simulation: ColonySimulation
var _last_observation: String = "观察：蚁后正在适应试管环境。"
var _fatal_simulation_error: String = ""

@onready var _status_label: Label = %StatusLabel
@onready var _tick_label: Label = %TickLabel
@onready var _simulation_time_label: Label = %SimulationTimeLabel
@onready var _queen_status_label: Label = %QueenStatusLabel
@onready var _stage_counts_label: Label = %StageCountsLabel
@onready var _individuals_label: Label = %IndividualsLabel
@onready var _milestone_note: Label = %MilestoneNote
@onready var _pause_button: Button = %PauseButton
@onready var _speed_1x_button: Button = %Speed1xButton
@onready var _speed_4x_button: Button = %Speed4xButton
@onready var _speed_16x_button: Button = %Speed16xButton


func _ready() -> void:
	_simulation_clock = SimulationClock.new()
	_colony_simulation = ColonySimulation.new(SPECIES_A_DATA)
	if not _colony_simulation.is_ready():
		_set_fatal_simulation_error(_colony_simulation.get_configuration_error())
		return
	_simulation_clock.tick_requested.connect(_on_simulation_tick_requested)
	_colony_simulation.egg_laid.connect(_on_egg_laid)
	_colony_simulation.life_stage_changed.connect(_on_life_stage_changed)

	_pause_button.pressed.connect(_on_pause_button_pressed)
	_speed_1x_button.pressed.connect(_on_speed_button_pressed.bind(
		SimulationClock.NORMAL_SPEED
	))
	_speed_4x_button.pressed.connect(_on_speed_button_pressed.bind(
		SimulationClock.FAST_SPEED
	))
	_speed_16x_button.pressed.connect(_on_speed_button_pressed.bind(
		SimulationClock.VERY_FAST_SPEED
	))

	_update_clock_labels()
	_update_control_state()
	_update_colony_labels()


func _process(delta: float) -> void:
	var processed_ticks: int = _simulation_clock.advance(delta)
	if processed_ticks > 0:
		_update_clock_labels()
		_update_colony_labels()


func _on_simulation_tick_requested(
	tick_index: int,
	_tick_seconds: float
) -> void:
	if not _colony_simulation.advance_tick(tick_index):
		_set_fatal_simulation_error(
			"生命周期拒绝了非连续 Tick %d，模拟已停止。" % tick_index
		)


func _on_egg_laid(entity_id: int, _simulation_tick: int) -> void:
	_last_observation = "观察记录：蚁后产下了 #%03d。" % entity_id


func _on_life_stage_changed(
	entity_id: int,
	previous_stage: AntModel.LifeStage,
	current_stage: AntModel.LifeStage,
	_simulation_tick: int
) -> void:
	_last_observation = (
		"观察记录：#%03d 从%s进入%s。"
		% [
			entity_id,
			AntModel.get_stage_display_name(previous_stage),
			AntModel.get_stage_display_name(current_stage),
		]
	)


func _on_pause_button_pressed() -> void:
	_simulation_clock.toggle_paused()
	_update_control_state()


func _on_speed_button_pressed(multiplier: int) -> void:
	_simulation_clock.set_speed_multiplier(multiplier)
	_update_control_state()


func _update_clock_labels() -> void:
	_tick_label.text = "固定 Tick：%d" % _simulation_clock.get_tick_index()
	_simulation_time_label.text = (
		"模拟时间：%.1f 秒" % _simulation_clock.get_simulation_time_seconds()
	)


func _update_control_state() -> void:
	if not _fatal_simulation_error.is_empty():
		_status_label.text = "模拟错误 · 已暂停"
		_pause_button.disabled = true
		_speed_1x_button.disabled = true
		_speed_4x_button.disabled = true
		_speed_16x_button.disabled = true
		return

	var speed_multiplier: int = _simulation_clock.get_speed_multiplier()
	var paused: bool = _simulation_clock.is_paused()

	_status_label.text = (
		"已暂停 · %d×" % speed_multiplier
		if paused
		else "运行中 · %d×" % speed_multiplier
	)
	_pause_button.text = "继续" if paused else "暂停"
	_speed_1x_button.disabled = speed_multiplier == SimulationClock.NORMAL_SPEED
	_speed_4x_button.disabled = speed_multiplier == SimulationClock.FAST_SPEED
	_speed_16x_button.disabled = speed_multiplier == SimulationClock.VERY_FAST_SPEED


func _update_colony_labels() -> void:
	var snapshot: ColonySnapshot = _colony_simulation.create_snapshot()
	_queen_status_label.text = (
		"● 蚁后  ·  已产卵 %d／%d"
		% [
			snapshot.queen_laid_egg_count,
			snapshot.max_first_generation_brood,
		]
	)
	_stage_counts_label.text = (
		"卵 %d    幼虫 %d    蛹 %d    工蚁 %d"
		% [
			snapshot.count_stage(AntModel.LifeStage.EGG),
			snapshot.count_stage(AntModel.LifeStage.LARVA),
			snapshot.count_stage(AntModel.LifeStage.PUPA),
			snapshot.count_stage(AntModel.LifeStage.WORKER),
		]
	)

	var individual_lines: PackedStringArray = []
	for ant: AntSnapshot in snapshot.ants:
		var stage_name: String = AntModel.get_stage_display_name(ant.life_stage)
		individual_lines.append(
			"%s  #%03d  %s"
			% [_get_stage_marker(ant.life_stage), ant.entity_id, stage_name]
		)

	_individuals_label.text = (
		"尚无幼体。"
		if individual_lines.is_empty()
		else "\n".join(individual_lines)
	)

	if snapshot.next_egg_tick >= 0 and snapshot.ants.is_empty():
		var remaining_ticks: int = snapshot.next_egg_tick - snapshot.simulation_tick
		_milestone_note.text = (
			"%s  距离首枚卵约 %.1f 模拟秒。"
			% [
				_last_observation,
				float(remaining_ticks) * SimulationClock.FIXED_STEP_SECONDS,
			]
		)
	else:
		_milestone_note.text = _last_observation


func _get_stage_marker(stage: AntModel.LifeStage) -> String:
	match stage:
		AntModel.LifeStage.EGG:
			return "○"
		AntModel.LifeStage.LARVA:
			return "≈"
		AntModel.LifeStage.PUPA:
			return "◇"
		AntModel.LifeStage.WORKER:
			return "●"
		_:
			return "?"


func _set_fatal_simulation_error(message: String) -> void:
	_fatal_simulation_error = message
	_last_observation = message
	if _simulation_clock != null:
		_simulation_clock.set_paused(true)
	if is_node_ready():
		_update_control_state()
		_milestone_note.text = message
