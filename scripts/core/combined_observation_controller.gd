class_name CombinedObservationController
extends Control

const SPECIES_A_DATA: SpeciesData = preload(
	"res://data/species/species_a.tres"
)
const COMBINED_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/combined_observation_slice.tres"
)

var _simulation_clock: SimulationClock
var _colony_simulation: ColonySimulation
var _latest_snapshot: GameSnapshot
var _player_annotation_state: PlayerAnnotationState
var _sugar_tool_armed: bool = false
var _fatal_simulation_error: String = ""

# Tests may replace these before _ready(). Both Resources are consumed only
# while ColonySimulation freezes the configuration at session construction.
var species_data_source: SpeciesData = SPECIES_A_DATA
var habitat_scenario_data_source: HabitatScenarioData = (
	COMBINED_SCENARIO_DATA
)

@onready var _status_label: Label = %StatusLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _habitat_view: CombinedHabitatView = %CombinedHabitatView
@onready var _worker_observation_panel: WorkerObservationPanel = (
	%WorkerIdentityPanel
)
@onready var _instruction_label: Label = %InstructionLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _tool_heading: Label = %ToolHeading
@onready var _stage_action_button: Button = %StageActionButton
@onready var _stage_controls: VBoxContainer = %StageControls
@onready var _emergence_card_label: Label = %EmergenceCardLabel
@onready var _humidity_card_label: Label = %HumidityCardLabel
@onready var _sugar_card_label: Label = %SugarCardLabel
@onready var _completion_panel: VBoxContainer = %CompletionPanel
@onready var _completion_label: Label = %CompletionLabel
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
	_stage_action_button.pressed.connect(_on_stage_action_button_pressed)
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
	if key_event == null or not key_event.pressed or key_event.echo:
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
			"模拟拒绝了非连续 Tick %d，观察已暂停。" % tick_index
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


func _on_stage_action_button_pressed() -> void:
	if _latest_snapshot == null or _stage_action_button.disabled:
		return
	match _latest_snapshot.sequence.phase:
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION:
			if _colony_simulation.submit_continue_observation_action():
				_apply_game_snapshot()
				_feedback_label.text = (
					"观察意图已提交；下一次模拟更新后进入环境观察。"
				)
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION:
			if _colony_simulation.submit_water_action():
				_apply_game_snapshot()
				_feedback_label.text = (
					"补水动作已提交；水分会在下一次模拟更新时渗入。"
				)
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING:
			if _sugar_tool_armed:
				_cancel_sugar_tool("已取消放置糖水。")
			elif _can_arm_sugar_tool():
				_set_sugar_tool_armed(true)
				_feedback_label.text = (
					"请在右侧觅食区点击落点；点击其他区域或按 Esc 取消。"
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
	_apply_game_snapshot()
	_feedback_label.text = (
		"糖水放置动作已提交；下一次模拟更新后才会出现在觅食区。"
	)


func _on_sugar_tool_cancel_requested() -> void:
	if _sugar_tool_armed:
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
	_update_player_guidance()


func _on_worker_name_commit_requested(worker_name: String) -> void:
	if _player_annotation_state.set_selected_worker_name(worker_name):
		_update_worker_observation_panel()
		_update_player_guidance()


func _on_restart_button_pressed() -> void:
	if (
		_latest_snapshot == null
		or not _latest_snapshot.sequence.completed
		or _restart_button.disabled
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
		or _latest_snapshot.sequence == null
	):
		_set_fatal_simulation_error(
			"模拟未能提供完整的连续观察快照，观察已暂停。"
		)
		return

	_player_annotation_state.reconcile_entities(_latest_snapshot.colony)
	_player_annotation_state.consume_events(
		_latest_snapshot.observations.events
	)
	if not _habitat_view.apply_snapshot(_latest_snapshot):
		_set_fatal_simulation_error("栖息地视图拒绝了模拟快照，观察已暂停。")
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
	_update_observation_cards()
	_update_player_guidance()
	_update_control_state()
	_update_debug_panel()


func _update_worker_observation_panel() -> void:
	var selected_worker_id: int = (
		_player_annotation_state.get_selected_worker_id()
	)
	if _latest_snapshot == null or selected_worker_id < 0:
		_worker_observation_panel.reset_panel()
		return
	var worker: AntSnapshot = _latest_snapshot.colony.find_ant(
		selected_worker_id
	)
	if worker == null or worker.life_stage != AntModel.LifeStage.WORKER:
		_worker_observation_panel.reset_panel()
		return
	_worker_observation_panel.apply_selection(
		worker,
		_player_annotation_state.get_worker_name(selected_worker_id),
		_player_annotation_state.get_recent_events(selected_worker_id)
	)


func _update_observation_cards() -> void:
	if _latest_snapshot == null:
		return
	_emergence_card_label.text = _format_card(
		_latest_snapshot.observations.has_card(
			_latest_snapshot.sequence.first_worker_observation_card_id
		),
		"第一只工蚁羽化"
	)
	_humidity_card_label.text = _format_card(
		_latest_snapshot.observations.has_card(
			_latest_snapshot.sequence.brood_humidity_observation_card_id
		),
		"工蚁把幼体搬向更合适的湿度"
	)
	_sugar_card_label.text = _format_card(
		_latest_snapshot.observations.has_card(
			_latest_snapshot.sequence.sugar_foraging_observation_card_id
		),
		"工蚁把糖水带回巢内分享"
	)


func _update_player_guidance() -> void:
	if _latest_snapshot == null:
		return
	var phase: ScenarioSequenceSnapshot.Phase = _latest_snapshot.sequence.phase
	_phase_label.text = _get_phase_heading(phase)
	_set_completion_state(
		phase == ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY
	)

	match phase:
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE:
			_tool_heading.text = "建群序幕"
			_instruction_label.text = (
				"观察蚁后身旁的晚期蛹。它已经接近羽化，留意轮廓变化。"
			)
			_feedback_label.text = "此时不需要干预，新的工蚁很快会出现。"
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION:
			_tool_heading.text = "认识个体"
			_instruction_label.text = (
				"点击刚羽化的工蚁。你可以给它起名，也可以直接继续观察。"
			)
			_feedback_label.text = (
				"选中与命名只属于本局记录，不会改变工蚁的自主行为。"
			)
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION:
			_tool_heading.text = "巢室环境"
			if not _latest_snapshot.colony.water_action_unlocked:
				_instruction_label.text = (
					"先观察工蚁如何重新安置幼体；第一次搬运完成后再干预。"
				)
				_feedback_label.text = "留意两个巢室的凝水与幼体位置。"
			elif _latest_snapshot.colony.water_target_comfortable:
				_instruction_label.text = (
					"水分已经明显增加。继续看工蚁是否重新评估幼体位置。"
				)
				_feedback_label.text = "不需要继续补水，等待群落恢复稳定。"
			else:
				_instruction_label.text = (
					"育幼室的凝水仍少。少量补水，观察搬运方向是否改变。"
				)
				_feedback_label.text = (
					"每次补水都先进入命令队列，并在下一固定 Tick 生效。"
				)
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING:
			_tool_heading.text = "糖水觅食"
			if _latest_snapshot.scenario.place_action_count == 0:
				_instruction_label.text = (
					"在右侧觅食区放一滴糖水，观察哪只工蚁自主发现它。"
				)
				if not _sugar_tool_armed:
					_feedback_label.text = (
						"先启用糖水工具，再在觅食区选择落点。"
					)
			else:
				_instruction_label.text = (
					"继续追踪工蚁发现、采集、返巢和分享的完整往返。"
				)
				_feedback_label.text = "无需指定工蚁，群落会自行分配任务。"
		ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY:
			_tool_heading.text = "观察总结"
			_instruction_label.text = (
				"同一只工蚁经历了羽化、幼体搬运与糖水觅食。"
			)
			_feedback_label.text = "三条因果线索已经记录完成。"
			_completion_label.text = _build_completion_summary()


func _update_control_state() -> void:
	if not _fatal_simulation_error.is_empty():
		_status_label.text = "模拟错误 · 已暂停"
		for button: Button in [
			_pause_button,
			_stage_action_button,
			_restart_button,
			_speed_1x_button,
			_speed_4x_button,
			_speed_16x_button,
		]:
			button.disabled = true
		return
	if _latest_snapshot == null:
		return

	var speed_multiplier: int = _simulation_clock.get_speed_multiplier()
	var paused: bool = _simulation_clock.is_paused()
	var completed: bool = _latest_snapshot.sequence.completed
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

	match _latest_snapshot.sequence.phase:
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE:
			_stage_action_button.text = "等待第一只工蚁羽化"
			_stage_action_button.disabled = true
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION:
			_stage_action_button.text = "继续观察环境"
			_stage_action_button.disabled = (
				paused
				or not _latest_snapshot.sequence.continue_action_available
			)
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION:
			_stage_action_button.text = (
				"补水正在渗入"
				if _latest_snapshot.colony.water_action_pending
				else (
					"继续观察搬运"
					if _latest_snapshot.colony.water_target_comfortable
					else "给育幼室少量补水"
				)
			)
			_stage_action_button.disabled = (
				paused or not _latest_snapshot.colony.water_action_available
			)
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING:
			_stage_action_button.text = (
				"取消放置" if _sugar_tool_armed else "准备放置糖水"
			)
			_stage_action_button.disabled = (
				paused
				or (
					not _sugar_tool_armed
					and not _can_arm_sugar_tool()
				)
			)
		ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY:
			_stage_action_button.disabled = true

	_restart_button.disabled = not completed


func _update_debug_panel() -> void:
	if not _debug_panel.visible or _latest_snapshot == null:
		return
	var zone_lines: PackedStringArray = []
	for zone: HabitatZoneSnapshot in _latest_snapshot.colony.zones:
		zone_lines.append(
			"%s  humidity=%.3f  available=%s  links=%s"
			% [
				zone.zone_id,
				zone.humidity,
				str(zone.available),
				",".join(zone.connected_zone_ids),
			]
		)
	var worker_lines: PackedStringArray = []
	for ant: AntSnapshot in _latest_snapshot.colony.ants:
		if ant.life_stage != AntModel.LifeStage.WORKER:
			continue
		var forage_state: int = (
			ant.foraging_task.state
			if ant.foraging_task != null
			else ForagingTaskSnapshot.State.IDLE
		)
		worker_lines.append(
			(
				"#%03d zone=%s relocate=%d brood=#%s carry=#%s"
				+ " forage=%d food=#%s sugar=%d"
			)
			% [
				ant.entity_id,
				ant.zone_id,
				ant.worker_task_state,
				_format_optional_id(ant.target_brood_id),
				_format_optional_id(ant.carried_brood_id),
				forage_state,
				_format_optional_id(
					ant.foraging_task.target_food_source_id
					if ant.foraging_task != null
					else -1
				),
				(
					ant.foraging_task.carried_portions
					if ant.foraging_task != null
					else 0
				),
			]
		)
	if worker_lines.is_empty():
		worker_lines.append("none")
	_debug_label.text = (
		"Tick %d | speed %d× | paused=%s\n"
		+ "phase=%s entered=%d first_worker=#%s\n"
		+ "continue pending=%s | water pending=%s | sugar pending=%s\n"
		+ "cards=%s\n\nzones:\n%s\n\nworkers:\n%s\n\n"
		+ "events=%d | AntViews=%d"
	) % [
		_latest_snapshot.simulation_tick,
		_simulation_clock.get_speed_multiplier(),
		str(_simulation_clock.is_paused()),
		_get_phase_name(_latest_snapshot.sequence.phase),
		_latest_snapshot.sequence.phase_entered_tick,
		_format_optional_id(
			_latest_snapshot.sequence.first_worker_entity_id
		),
		str(_latest_snapshot.sequence.continue_action_pending),
		str(_latest_snapshot.colony.water_action_pending),
		str(_latest_snapshot.scenario.place_action_pending),
		",".join(_latest_snapshot.observations.unlocked_card_ids),
		"\n".join(zone_lines),
		"\n".join(worker_lines),
		_latest_snapshot.observations.events.size(),
		_habitat_view.get_ant_view_count(),
	]


func _can_arm_sugar_tool() -> bool:
	return (
		_fatal_simulation_error.is_empty()
		and _simulation_clock != null
		and not _simulation_clock.is_paused()
		and _latest_snapshot != null
		and _latest_snapshot.sequence.phase
			== ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING
		and _latest_snapshot.scenario.place_action_available
		and not _latest_snapshot.scenario.place_action_pending
	)


func _set_sugar_tool_armed(value: bool) -> void:
	_sugar_tool_armed = value
	if _habitat_view != null:
		_habitat_view.set_sugar_tool_armed(value)


func _cancel_sugar_tool(feedback_text: String) -> void:
	_set_sugar_tool_armed(false)
	if _feedback_label != null:
		_feedback_label.text = feedback_text
	_update_control_state()


func _set_completion_state(completed: bool) -> void:
	_stage_controls.visible = not completed
	_completion_panel.visible = completed
	if completed:
		_set_sugar_tool_armed(false)


func _restart_session() -> void:
	if not _colony_simulation.restart_session():
		var message: String = _colony_simulation.get_configuration_error()
		if message.is_empty():
			message = "无法从冻结配置重新开始连续观察。"
		_set_fatal_simulation_error(message)
		return

	_fatal_simulation_error = ""
	_latest_snapshot = null
	_player_annotation_state.reset_session()
	_simulation_clock.reset()
	_set_sugar_tool_armed(false)
	_debug_panel.visible = false
	_debug_label.text = "等待第一份模拟快照……"
	_worker_observation_panel.reset_panel()
	_habitat_view.reset_projection()
	_habitat_view.set_visuals_paused(false)
	_apply_game_snapshot()


func _build_completion_summary() -> String:
	var first_worker_id: int = _latest_snapshot.sequence.first_worker_entity_id
	var display_name: String = _player_annotation_state.get_worker_name(
		first_worker_id
	)
	var subject: String = (
		display_name if not display_name.is_empty() else "第一只工蚁"
	)
	return (
		"%s从晚期蛹羽化，并在同一局中搬运幼体、发现糖水、返巢分享。"
		% subject
	)


func _get_phase_heading(phase: int) -> String:
	match phase:
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE:
			return "第 1/5 段 · 建群序幕"
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION:
			return "第 2/5 段 · 认识个体"
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION:
			return "第 3/5 段 · 湿度观察"
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING:
			return "第 4/5 段 · 糖水觅食"
		ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY:
			return "第 5/5 段 · 观察总结"
		_:
			return "连续观察"


func _get_phase_name(phase: int) -> String:
	match phase:
		ScenarioSequenceSnapshot.Phase.FOUNDING_PRELUDE:
			return "FOUNDING_PRELUDE"
		ScenarioSequenceSnapshot.Phase.IDENTITY_OBSERVATION:
			return "IDENTITY_OBSERVATION"
		ScenarioSequenceSnapshot.Phase.HUMIDITY_OBSERVATION:
			return "HUMIDITY_OBSERVATION"
		ScenarioSequenceSnapshot.Phase.SUGAR_FORAGING:
			return "SUGAR_FORAGING"
		ScenarioSequenceSnapshot.Phase.OBSERVATION_SUMMARY:
			return "OBSERVATION_SUMMARY"
		_:
			return "UNKNOWN"


func _format_card(unlocked: bool, label_text: String) -> String:
	return "%s  %s" % ["✓" if unlocked else "○", label_text]


func _format_optional_id(entity_id: int) -> String:
	return "%03d" % entity_id if entity_id >= 0 else "---"


func _set_fatal_simulation_error(message: String) -> void:
	_fatal_simulation_error = message
	if _simulation_clock != null:
		_simulation_clock.set_paused(true)
	if _habitat_view != null:
		_habitat_view.set_visuals_paused(true)
		_habitat_view.set_sugar_tool_armed(false)
	_sugar_tool_armed = false
	if is_node_ready():
		_instruction_label.text = message
		_update_control_state()
