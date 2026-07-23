class_name MainController
extends Control

const SPECIES_A_DATA: SpeciesData = preload("res://data/species/species_a.tres")
const HUMIDITY_SCENARIO_DATA: HabitatScenarioData = preload(
	"res://data/habitats/humidity_relocation_slice.tres"
)
const OBSERVATION_TEXT: String = "工蚁会把幼体搬向更合适的湿度区域。"

var _simulation_clock: SimulationClock
var _colony_simulation: ColonySimulation
var _latest_snapshot: ColonySnapshot
var _fatal_simulation_error: String = ""

# Tests and alternate launch scenes may replace these before _ready().  The
# Resources are consumed only to build the simulation's frozen configuration.
var species_data_source: SpeciesData = SPECIES_A_DATA
var habitat_scenario_data_source: HabitatScenarioData = HUMIDITY_SCENARIO_DATA

@onready var _status_label: Label = %StatusLabel
@onready var _habitat_view: HabitatView = %HabitatView
@onready var _observation_label: Label = %ObservationLabel
@onready var _instruction_label: Label = %InstructionLabel
@onready var _water_feedback_label: Label = %WaterFeedbackLabel
@onready var _water_button: Button = %WaterButton
@onready var _debug_panel: PanelContainer = %DebugPanel
@onready var _debug_label: Label = %DebugLabel
@onready var _debug_toggle_button: Button = %DebugToggleButton
@onready var _pause_button: Button = %PauseButton
@onready var _speed_1x_button: Button = %Speed1xButton
@onready var _speed_4x_button: Button = %Speed4xButton
@onready var _speed_16x_button: Button = %Speed16xButton


func _ready() -> void:
	_simulation_clock = SimulationClock.new()
	_colony_simulation = ColonySimulation.new(
		species_data_source,
		habitat_scenario_data_source
	)
	if not _colony_simulation.is_ready():
		_set_fatal_simulation_error(_colony_simulation.get_configuration_error())
		return

	_simulation_clock.tick_requested.connect(_on_simulation_tick_requested)
	_pause_button.pressed.connect(_on_pause_button_pressed)
	_water_button.pressed.connect(_on_water_button_pressed)
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

	_apply_colony_snapshot()
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
		or key_event.keycode != KEY_F3
	):
		return
	_toggle_debug_panel()
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
	_apply_colony_snapshot()


func _on_pause_button_pressed() -> void:
	var paused: bool = _simulation_clock.toggle_paused()
	_habitat_view.set_visuals_paused(paused)
	_update_control_state()
	_update_debug_panel()


func _on_water_button_pressed() -> void:
	if (
		_water_button.disabled
		or not _colony_simulation.submit_water_action()
	):
		return
	# The command is still applied only at the next fixed Tick.  Publishing the
	# same-Tick snapshot exposes its authoritative pending state to the UI.
	_apply_colony_snapshot()
	_water_feedback_label.text = "补水指令已提交；水分会在下一次模拟更新时渗入。"


func _on_speed_button_pressed(multiplier: int) -> void:
	_simulation_clock.set_speed_multiplier(multiplier)
	_update_control_state()
	_update_debug_panel()


func _toggle_debug_panel() -> void:
	_debug_panel.visible = not _debug_panel.visible
	_update_control_state()
	_update_debug_panel()


func _apply_colony_snapshot() -> void:
	_latest_snapshot = _colony_simulation.create_snapshot()
	if not _habitat_view.apply_snapshot(_latest_snapshot):
		_set_fatal_simulation_error("栖息地视图拒绝了模拟快照，已暂停。")
		return

	_update_player_guidance()
	_update_control_state()
	_update_debug_panel()


func _update_player_guidance() -> void:
	if _latest_snapshot.brood_humidity_observation_unlocked:
		_observation_label.text = "观察记录已解锁\n“%s”" % OBSERVATION_TEXT
		_instruction_label.text = "群落已经恢复稳定。你完成了这次观察。"
		_water_feedback_label.text = "幼体已经安置妥当，工蚁回到了空闲状态。"
		return

	_observation_label.text = "观察记录尚未解锁\n先看工蚁如何选择幼体的位置。"
	if not _latest_snapshot.water_action_unlocked:
		_instruction_label.text = (
			"先观察，不要急着操作。注意工蚁从哪个巢室带走幼体。"
		)
		_water_feedback_label.text = "补水工具会在第一次搬运完成后开放。"
		return

	if _latest_snapshot.water_target_comfortable:
		_instruction_label.text = "水分正在稳定。继续观察工蚁是否改变搬运方向。"
		_water_feedback_label.text = "左室已完成本轮补水；等待群落自行调整。"
	else:
		_instruction_label.text = (
			"幼体的位置发生了变化。尝试给左室少量补水，再观察工蚁。"
		)
		if _latest_snapshot.water_action_pending:
			_water_feedback_label.text = "补水指令已提交；水分会在下一次模拟更新时渗入。"
		elif _latest_snapshot.water_action_count > 0:
			_water_feedback_label.text = "水分正在渗入；还可以再补少量水。"
		else:
			_water_feedback_label.text = "每次只加入少量水，避免一次改变过多。"


func _update_control_state() -> void:
	if not _fatal_simulation_error.is_empty():
		_status_label.text = "模拟错误 · 已暂停"
		_pause_button.disabled = true
		_water_button.disabled = true
		_speed_1x_button.disabled = true
		_speed_4x_button.disabled = true
		_speed_16x_button.disabled = true
		return

	var speed_multiplier: int = _simulation_clock.get_speed_multiplier()
	var paused: bool = _simulation_clock.is_paused()
	_status_label.text = (
		"已暂停 · %d×" % speed_multiplier
		if paused
		else "观察中 · %d×" % speed_multiplier
	)
	_pause_button.text = "继续" if paused else "暂停"
	_speed_1x_button.disabled = speed_multiplier == SimulationClock.NORMAL_SPEED
	_speed_4x_button.disabled = speed_multiplier == SimulationClock.FAST_SPEED
	_speed_16x_button.disabled = speed_multiplier == SimulationClock.VERY_FAST_SPEED
	_debug_toggle_button.text = "关闭调试" if _debug_panel.visible else "F3 调试"

	var can_water: bool = (
		not paused
		and _latest_snapshot != null
		and _latest_snapshot.water_action_available
	)
	_water_button.disabled = not can_water


func _update_debug_panel() -> void:
	if not _debug_panel.visible or _latest_snapshot == null:
		return
	var zone_lines: PackedStringArray = []
	for zone: HabitatZoneSnapshot in _latest_snapshot.zones:
		zone_lines.append("%s %.2f" % [zone.zone_id, zone.humidity])
	var worker_lines: PackedStringArray = []
	var reservation_lines: PackedStringArray = []
	for ant: AntSnapshot in _latest_snapshot.ants:
		if ant.life_stage == AntModel.LifeStage.WORKER:
			worker_lines.append(
				"#%03d  %s  target=#%s  zone=%s  carry=#%s"
				% [
					ant.entity_id,
					_get_task_state_name(ant.worker_task_state),
					_format_optional_id(ant.target_brood_id),
					_format_optional_zone(ant.target_zone_id),
					_format_optional_id(ant.carried_brood_id),
				]
			)
		elif ant.reserved_by_ant_id >= 0:
			reservation_lines.append(
				"#%03d→#%03d" % [ant.reserved_by_ant_id, ant.entity_id]
			)

	_debug_label.text = (
		"Tick %d  |  speed %d×\n"
		+ "%s\n"
		+ "water actions: %d  |  pending: %s\n"
		+ "active relocations: %d\n\n"
		+ "%s\n\nreservations: %s"
	) % [
		_latest_snapshot.simulation_tick,
		_simulation_clock.get_speed_multiplier(),
		"  |  ".join(zone_lines),
		_latest_snapshot.water_action_count,
		str(_latest_snapshot.water_action_pending),
		_latest_snapshot.count_active_relocations(),
		"\n".join(worker_lines),
		"none" if reservation_lines.is_empty() else ", ".join(reservation_lines),
	]


func _get_task_state_name(state: int) -> String:
	match state:
		WorkerTaskModel.State.IDLE:
			return "IDLE"
		WorkerTaskModel.State.MOVING_TO_BROOD:
			return "MOVING_TO_BROOD"
		WorkerTaskModel.State.PICKING_UP:
			return "PICKING_UP"
		WorkerTaskModel.State.CARRYING_TO_ZONE:
			return "CARRYING_TO_ZONE"
		WorkerTaskModel.State.DROPPING:
			return "DROPPING"
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
	if is_node_ready():
		_observation_label.text = message
		_update_control_state()
