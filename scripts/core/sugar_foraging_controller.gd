class_name SugarForagingController
extends Control

const SPECIES_A_DATA: SpeciesData = preload("res://data/species/species_a.tres")
const SUGAR_FORAGING_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/sugar_foraging_slice.tres"
)
const FORAGING_OBSERVATION_TEXT: String = (
	"工蚁会把找到的糖水带回巢内，与同伴分享。"
)

var _simulation_clock: SimulationClock
var _colony_simulation: ColonySimulation
var _latest_snapshot: GameSnapshot
var _player_annotation_state: PlayerAnnotationState
var _sugar_tool_armed: bool = false
var _fatal_simulation_error: String = ""

# Tests and alternate launch scenes may replace these before _ready(). These
# Resources are consumed only while the simulation freezes its configuration.
var species_data_source: SpeciesData = SPECIES_A_DATA
var habitat_scenario_data_source: HabitatScenarioData = (
	SUGAR_FORAGING_SCENARIO_DATA
)

@onready var _status_label: Label = %StatusLabel
@onready var _habitat_view: SugarForagingHabitatView = %SugarForagingHabitatView
@onready var _worker_observation_panel: WorkerObservationPanel = %WorkerIdentityPanel
@onready var _observation_label: Label = %ObservationLabel
@onready var _instruction_label: Label = %InstructionLabel
@onready var _sugar_feedback_label: Label = %SugarFeedbackLabel
@onready var _sugar_tool_button: Button = %SugarToolButton
@onready var _sugar_controls: VBoxContainer = %SugarControls
@onready var _completion_panel: VBoxContainer = %CompletionPanel
@onready var _restart_button: Button = %RestartButton
@onready var _debug_panel: PanelContainer = %DebugPanel
@onready var _debug_label: Label = %DebugLabel
@onready var _debug_toggle_button: Button = %DebugToggleButton
@onready var _pause_button: Button = %PauseButton
@onready var _speed_1x_button: Button = %Speed1xButton
@onready var _speed_4x_button: Button = %Speed4xButton
@onready var _speed_16x_button: Button = %Speed16xButton


func _ready() -> void:
	_simulation_clock = SimulationClock.new()
	_player_annotation_state = PlayerAnnotationState.new()
	_colony_simulation = ColonySimulation.new(
		species_data_source,
		habitat_scenario_data_source
	)
	if not _colony_simulation.is_ready():
		_set_fatal_simulation_error(
			_colony_simulation.get_configuration_error()
		)
		return

	_simulation_clock.tick_requested.connect(_on_simulation_tick_requested)
	_habitat_view.worker_selection_requested.connect(
		_on_worker_selection_requested
	)
	_habitat_view.sugar_drop_requested.connect(
		_on_sugar_drop_requested
	)
	_habitat_view.sugar_tool_cancel_requested.connect(
		_on_sugar_tool_cancel_requested
	)
	_worker_observation_panel.name_commit_requested.connect(
		_on_worker_name_commit_requested
	)
	_pause_button.pressed.connect(_on_pause_button_pressed)
	_sugar_tool_button.pressed.connect(_on_sugar_tool_button_pressed)
	_restart_button.pressed.connect(_on_restart_button_pressed)
	_debug_toggle_button.pressed.connect(_toggle_debug_panel)
	_speed_1x_button.pressed.connect(
		_on_speed_button_pressed.bind(SimulationClock.NORMAL_SPEED)
	)
	_speed_4x_button.pressed.connect(
		_on_speed_button_pressed.bind(SimulationClock.FAST_SPEED)
	)
	_speed_16x_button.pressed.connect(
		_on_speed_button_pressed.bind(SimulationClock.VERY_FAST_SPEED)
	)

	_apply_game_snapshot()
	_update_control_state()
	_update_debug_panel()


func _process(delta: float) -> void:
	if _simulation_clock == null or not _fatal_simulation_error.is_empty():
		return
	_simulation_clock.advance(delta)
	if _fatal_simulation_error.is_empty():
		_habitat_view.set_interpolation_alpha(
			_simulation_clock.get_interpolation_alpha()
		)


func _input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if (
		key_event == null
		or not key_event.pressed
		or key_event.echo
	):
		return
	if key_event.keycode == KEY_F3:
		_toggle_debug_panel()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_ESCAPE and _sugar_tool_armed:
		_cancel_sugar_tool("已取消放置糖水。")
		get_viewport().set_input_as_handled()


func _on_simulation_tick_requested(
	tick_index: int,
	_tick_seconds: float
) -> void:
	if not _colony_simulation.advance_tick(tick_index):
		_set_fatal_simulation_error(
			"模拟拒绝了非连续 Tick %d，已暂停。" % tick_index
		)
		return
	_apply_game_snapshot()


func _on_pause_button_pressed() -> void:
	var paused: bool = _simulation_clock.toggle_paused()
	if paused and _sugar_tool_armed:
		_cancel_sugar_tool("观察已暂停，放置操作已取消。")
	_habitat_view.set_visuals_paused(paused)
	_update_control_state()
	_update_debug_panel()


func _on_sugar_tool_button_pressed() -> void:
	if _sugar_tool_armed:
		_cancel_sugar_tool("已取消放置糖水。")
		return
	if _sugar_tool_button.disabled or not _can_arm_sugar_tool():
		return
	_set_sugar_tool_armed(true)
	_sugar_feedback_label.text = (
		"在右侧觅食区点击放置；点击其他区域或按 Esc 取消。"
	)
	_update_control_state()


func _on_sugar_drop_requested() -> void:
	if (
		not _sugar_tool_armed
		or _latest_snapshot == null
		or not _latest_snapshot.scenario.place_action_available
		or not _colony_simulation.submit_place_sugar_action()
	):
		_cancel_sugar_tool("当前无法放置糖水，请继续观察。")
		return

	_set_sugar_tool_armed(false)
	# The action remains queued until the next fixed Tick. Publishing the
	# same-Tick snapshot exposes only its authoritative pending state.
	_apply_game_snapshot()
	_sugar_feedback_label.text = (
		"糖水放置指令已提交；下一次模拟更新后才会出现在觅食区。"
	)


func _on_sugar_tool_cancel_requested() -> void:
	if not _sugar_tool_armed:
		return
	_cancel_sugar_tool("这里只能观察；糖水需要放在右侧觅食区。")


func _on_worker_selection_requested(entity_id: int) -> void:
	if (
		_latest_snapshot == null
		or not _player_annotation_state.select_worker(
			entity_id,
			_latest_snapshot.colony
		)
	):
		return
	_habitat_view.set_selected_worker_id(
		_player_annotation_state.get_selected_worker_id()
	)
	_update_worker_observation_panel()


func _on_worker_name_commit_requested(worker_name: String) -> void:
	if not _player_annotation_state.set_selected_worker_name(worker_name):
		return
	_update_worker_observation_panel()


func _on_restart_button_pressed() -> void:
	if (
		_restart_button.disabled
		or _latest_snapshot == null
		or _latest_snapshot.scenario.phase
			!= ForagingScenarioSnapshot.Phase.COMPLETED
	):
		return
	_restart_session()


func _on_speed_button_pressed(multiplier: int) -> void:
	_simulation_clock.set_speed_multiplier(multiplier)
	_update_control_state()
	_update_debug_panel()


func _toggle_debug_panel() -> void:
	_debug_panel.visible = not _debug_panel.visible
	_update_control_state()
	_update_debug_panel()


func _apply_game_snapshot() -> void:
	_latest_snapshot = _colony_simulation.create_game_snapshot()
	if (
		_latest_snapshot == null
		or _latest_snapshot.colony == null
		or _latest_snapshot.scenario == null
		or _latest_snapshot.observations == null
	):
		_set_fatal_simulation_error("模拟未能提供完整的觅食快照，已暂停。")
		return

	_player_annotation_state.reconcile_entities(_latest_snapshot.colony)
	_player_annotation_state.consume_events(
		_latest_snapshot.observations.events
	)
	if not _habitat_view.apply_snapshot(_latest_snapshot):
		_set_fatal_simulation_error("觅食区视图拒绝了模拟快照，已暂停。")
		return
	_habitat_view.set_selected_worker_id(
		_player_annotation_state.get_selected_worker_id()
	)

	if (
		_sugar_tool_armed
		and not _latest_snapshot.scenario.place_action_available
	):
		_set_sugar_tool_armed(false)

	_update_worker_observation_panel()
	_update_player_guidance()
	_update_control_state()
	_update_debug_panel()


func _update_worker_observation_panel() -> void:
	if (
		_worker_observation_panel == null
		or _player_annotation_state == null
	):
		return
	var selected_worker_id: int = (
		_player_annotation_state.get_selected_worker_id()
	)
	if _latest_snapshot == null or selected_worker_id < 0:
		_worker_observation_panel.reset_panel()
		return
	var worker_snapshot: AntSnapshot = _latest_snapshot.colony.find_ant(
		selected_worker_id
	)
	if (
		worker_snapshot == null
		or worker_snapshot.life_stage != AntModel.LifeStage.WORKER
	):
		_worker_observation_panel.reset_panel()
		return
	_worker_observation_panel.apply_selection(
		worker_snapshot,
		_player_annotation_state.get_worker_name(selected_worker_id),
		_player_annotation_state.get_recent_events(selected_worker_id)
	)


func _update_player_guidance() -> void:
	if _latest_snapshot == null:
		return
	match _latest_snapshot.scenario.phase:
		ForagingScenarioSnapshot.Phase.COMPLETED:
			_set_completion_state(true)
			_observation_label.text = (
				"观察记录已解锁\n“%s”" % FORAGING_OBSERVATION_TEXT
			)
			_instruction_label.text = (
				"糖水已经带回巢内并完成分享。你完成了这次观察。"
			)
			_sugar_feedback_label.text = "工蚁回到了日常活动。"
		ForagingScenarioSnapshot.Phase.ACTIVE:
			_set_completion_state(false)
			_observation_label.text = (
				"观察记录尚未解锁\n继续追踪发现糖水的工蚁。"
			)
			_instruction_label.text = (
				"糖水已经出现。观察工蚁如何自主前往、采集并返回巢室。"
			)
			if _latest_snapshot.scenario.place_action_pending:
				_sugar_feedback_label.text = (
					"糖水会在下一次模拟更新时出现在觅食区。"
				)
			else:
				_sugar_feedback_label.text = (
					"无需指定工蚁；群落会自行分配这次觅食。"
				)
		_:
			_set_completion_state(false)
			_observation_label.text = (
				"观察记录尚未解锁\n先看看空闲工蚁分布在哪里。"
			)
			_instruction_label.text = (
				"准备一滴糖水，留意哪只工蚁最先改变行动。"
			)
			if not _sugar_tool_armed:
				_sugar_feedback_label.text = (
					"先启用糖水工具，再在右侧觅食区选择落点。"
				)


func _update_control_state() -> void:
	if not _fatal_simulation_error.is_empty():
		_status_label.text = "模拟错误 · 已暂停"
		_pause_button.disabled = true
		_sugar_tool_button.disabled = true
		_restart_button.disabled = true
		_speed_1x_button.disabled = true
		_speed_4x_button.disabled = true
		_speed_16x_button.disabled = true
		return

	var speed_multiplier: int = _simulation_clock.get_speed_multiplier()
	var paused: bool = _simulation_clock.is_paused()
	var completed: bool = (
		_latest_snapshot != null
		and _latest_snapshot.scenario.phase
			== ForagingScenarioSnapshot.Phase.COMPLETED
	)
	_status_label.text = (
		"已暂停 · %d×" % speed_multiplier
		if paused
		else (
			"观察完成 · %d×" % speed_multiplier
			if completed
			else "观察中 · %d×" % speed_multiplier
		)
	)
	_pause_button.text = "继续" if paused else "暂停"
	_speed_1x_button.disabled = speed_multiplier == SimulationClock.NORMAL_SPEED
	_speed_4x_button.disabled = speed_multiplier == SimulationClock.FAST_SPEED
	_speed_16x_button.disabled = speed_multiplier == SimulationClock.VERY_FAST_SPEED
	_debug_toggle_button.text = (
		"关闭调试" if _debug_panel.visible else "F3 调试"
	)

	_sugar_tool_button.text = (
		"取消放置" if _sugar_tool_armed else "准备放置糖水"
	)
	_sugar_tool_button.disabled = (
		not _sugar_tool_armed and not _can_arm_sugar_tool()
	)
	_restart_button.disabled = not completed


func _update_debug_panel() -> void:
	if not _debug_panel.visible or _latest_snapshot == null:
		return

	var scenario: ForagingScenarioSnapshot = _latest_snapshot.scenario
	var food_lines: PackedStringArray = []
	for food_source: FoodSourceSnapshot in _latest_snapshot.colony.food_sources:
		food_lines.append(
			"#%03d zone=%s portions=%d reserve=#%s carry=#%s"
			% [
				food_source.food_source_id,
				food_source.zone_id,
				food_source.remaining_portions,
				_format_optional_id(food_source.reserved_by_worker_id),
				_format_optional_id(food_source.carrier_worker_id),
			]
		)
	if food_lines.is_empty():
		food_lines.append("none")

	var worker_lines: PackedStringArray = []
	for ant: AntSnapshot in _latest_snapshot.colony.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			continue
		var task: ForagingTaskSnapshot = ant.foraging_task
		if task == null:
			worker_lines.append("#%03d  no task snapshot" % ant.entity_id)
			continue
		worker_lines.append(
			"#%03d  %s  food=#%s  target=%s  carry=%d  %d/%d"
			% [
				ant.entity_id,
				_get_task_state_name(task.state),
				_format_optional_id(task.target_food_source_id),
				_format_optional_zone(task.target_zone_id),
				task.carried_portions,
				task.elapsed_ticks,
				task.duration_ticks,
			]
		)

	_debug_label.text = (
		"Tick %d  |  speed %d×\n"
		+ "scenario=%s  phase=%s\n"
		+ "nest=%s  placement=%s\n"
		+ "action pending=%s  applied=%d\n"
		+ "observation card=%s\n\n"
		+ "food sources:\n%s\n\n"
		+ "workers:\n%s"
	) % [
		_latest_snapshot.simulation_tick,
		_simulation_clock.get_speed_multiplier(),
		scenario.scenario_id,
		_get_phase_name(scenario.phase),
		scenario.nest_zone_id,
		scenario.placement_zone_id,
		str(scenario.place_action_pending),
		scenario.place_action_count,
		str(
			scenario.phase
			== ForagingScenarioSnapshot.Phase.COMPLETED
		),
		"\n".join(food_lines),
		"\n".join(worker_lines),
	]


func _can_arm_sugar_tool() -> bool:
	return (
		_fatal_simulation_error.is_empty()
		and _simulation_clock != null
		and not _simulation_clock.is_paused()
		and _latest_snapshot != null
		and _latest_snapshot.scenario.phase
			== ForagingScenarioSnapshot.Phase.AWAITING_PLACEMENT
		and _latest_snapshot.scenario.place_action_available
		and not _latest_snapshot.scenario.place_action_pending
	)


func _set_sugar_tool_armed(value: bool) -> void:
	_sugar_tool_armed = value
	if _habitat_view != null:
		_habitat_view.set_sugar_tool_armed(value)


func _cancel_sugar_tool(feedback_text: String) -> void:
	_set_sugar_tool_armed(false)
	if _sugar_feedback_label != null:
		_sugar_feedback_label.text = feedback_text
	_update_control_state()


func _set_completion_state(completed: bool) -> void:
	_sugar_controls.visible = not completed
	_completion_panel.visible = completed
	if completed:
		_set_sugar_tool_armed(false)


func _restart_session() -> void:
	if not _colony_simulation.restart_session():
		var restart_error: String = _colony_simulation.get_configuration_error()
		if restart_error.is_empty():
			restart_error = "无法从冻结配置重新开始观察。"
		_set_fatal_simulation_error(restart_error)
		return

	_fatal_simulation_error = ""
	_latest_snapshot = null
	_player_annotation_state.reset_session()
	_simulation_clock.reset()
	_set_sugar_tool_armed(false)
	_debug_panel.visible = false
	_debug_label.text = "等待第一份模拟快照……"
	_set_completion_state(false)
	_worker_observation_panel.reset_panel()
	_habitat_view.reset_projection()
	_habitat_view.set_visuals_paused(false)
	_apply_game_snapshot()


func _get_task_state_name(state: int) -> String:
	match state:
		ForagingTaskSnapshot.State.IDLE:
			return "IDLE"
		ForagingTaskSnapshot.State.SEEKING_FOOD:
			return "SEEKING_FOOD"
		ForagingTaskSnapshot.State.MOVING_TO_FOOD:
			return "MOVING_TO_FOOD"
		ForagingTaskSnapshot.State.COLLECTING:
			return "COLLECTING"
		ForagingTaskSnapshot.State.RETURNING_TO_NEST:
			return "RETURNING_TO_NEST"
		ForagingTaskSnapshot.State.SHARING:
			return "SHARING"
		_:
			return "UNKNOWN"


func _get_phase_name(phase: int) -> String:
	match phase:
		ForagingScenarioSnapshot.Phase.AWAITING_PLACEMENT:
			return "AWAITING_PLACEMENT"
		ForagingScenarioSnapshot.Phase.ACTIVE:
			return "ACTIVE"
		ForagingScenarioSnapshot.Phase.COMPLETED:
			return "COMPLETED"
		_:
			return "UNKNOWN"


func _format_optional_id(entity_id: int) -> String:
	return "%03d" % entity_id if entity_id >= 0 else "---"


func _format_optional_zone(zone_id: StringName) -> String:
	return String(zone_id) if not zone_id.is_empty() else "---"


func _set_fatal_simulation_error(message: String) -> void:
	_fatal_simulation_error = message
	if _simulation_clock != null:
		_simulation_clock.set_paused(true)
	if _habitat_view != null:
		_habitat_view.set_visuals_paused(true)
		_habitat_view.set_sugar_tool_armed(false)
	_sugar_tool_armed = false
	if is_node_ready():
		_observation_label.text = message
		_update_control_state()
