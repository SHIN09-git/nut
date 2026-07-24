class_name WorkerObservationPanelTestSuite
extends RefCounted

const WORKER_ID: int = 10

var _assertion_count: int = 0
var _failure_count: int = 0
var _scene_root: Node


func run(scene_root: Node) -> void:
	_scene_root = scene_root
	_test_empty_and_selected_states_use_natural_language()
	_test_history_keeps_the_latest_four_events_in_input_order()
	_test_reset_clears_projected_selection_state()
	_test_button_and_line_edit_emit_name_requests()


func get_assertion_count() -> int:
	return _assertion_count


func get_failure_count() -> int:
	return _failure_count


func _test_empty_and_selected_states_use_natural_language() -> void:
	var panel: WorkerObservationPanel = _create_panel()
	var prompt: Label = panel.get_node("%WorkerPromptLabel") as Label
	var content: Control = panel.get_node("%SelectedWorkerContent") as Control
	var display_name: Label = panel.get_node("%WorkerDisplayNameLabel") as Label
	var current_behavior: Label = (
		panel.get_node("%WorkerCurrentBehaviorLabel") as Label
	)
	var name_button: Button = panel.get_node("%WorkerNameButton") as Button

	_expect_true(prompt.visible, "an empty panel shows its selection prompt")
	_expect_true(not content.visible, "an empty panel hides selected-worker details")
	_expect_true(name_button.disabled, "an empty panel disables name submission")

	var worker: AntSnapshot = _make_worker_snapshot(
		WorkerTaskModel.State.IDLE
	)
	panel.apply_selection(worker, "琥珀", [])
	_expect_true(not prompt.visible, "a selected worker hides the empty prompt")
	_expect_true(content.visible, "a selected worker reveals its details")
	_expect_string(display_name.text, "琥珀", "the panel projects the player name")
	_expect_true(not name_button.disabled, "a selected worker enables name submission")

	var behavior_keywords: Dictionary[int, String] = {
		WorkerTaskModel.State.IDLE: "休整",
		WorkerTaskModel.State.MOVING_TO_BROOD: "靠近",
		WorkerTaskModel.State.PICKING_UP: "拾起",
		WorkerTaskModel.State.CARRYING_TO_ZONE: "携带",
		WorkerTaskModel.State.DROPPING: "安置",
	}
	for state: int in behavior_keywords:
		worker.worker_task_state = state
		panel.apply_selection(worker, "琥珀", [])
		_expect_true(
			current_behavior.text.contains(behavior_keywords[state]),
			"worker task state %d receives a natural-language description"
			% state
		)
		_expect_true(
			not current_behavior.text.contains(str(WORKER_ID)),
			"current behavior does not expose the stable entity ID"
		)

	_destroy_panel(panel)


func _test_history_keeps_the_latest_four_events_in_input_order() -> void:
	var panel: WorkerObservationPanel = _create_panel()
	var events: Array[ObservationEvent] = [
		_make_event(
			101,
			5_001,
			ObservationEvent.Type.RELOCATION_STARTED
		),
		_make_event(
			102,
			5_002,
			ObservationEvent.Type.BROOD_PICKUP_STARTED
		),
		_make_event(
			103,
			5_003,
			ObservationEvent.Type.BROOD_CARRY_STARTED
		),
		_make_event(
			104,
			5_004,
			ObservationEvent.Type.BROOD_DROPPED
		),
		_make_event(
			105,
			5_005,
			ObservationEvent.Type.RELOCATION_STARTED
		),
	]
	panel.apply_selection(
		_make_worker_snapshot(WorkerTaskModel.State.IDLE),
		"",
		events
	)

	var visible_event_ids: Array[int] = panel.get_visible_event_ids()
	var visible_actor_ids: Array[int] = panel.get_visible_actor_ids()
	var history_text: String = (
		panel.get_node("%WorkerHistoryLabel") as Label
	).text
	_expect_int(visible_event_ids.size(), 4, "history is limited to four events")
	_expect_int_array(
		visible_event_ids,
		[102, 103, 104, 105],
		"history keeps the newest four event IDs in input order"
	)
	_expect_int_array(
		visible_actor_ids,
		[WORKER_ID, WORKER_ID, WORKER_ID, WORKER_ID],
		"visible history metadata preserves the caller-filtered actor IDs"
	)

	var pickup_index: int = history_text.find("拾起")
	var carry_index: int = history_text.find("携带")
	var drop_index: int = history_text.find("安置")
	var relocation_index: int = history_text.rfind("出发")
	_expect_true(
		pickup_index >= 0
		and carry_index > pickup_index
		and drop_index > carry_index
		and relocation_index > drop_index,
		"natural-language history preserves chronological input order"
	)
	_expect_true(
		not history_text.contains("101")
		and not history_text.contains("102")
		and not history_text.contains("105"),
		"history text does not expose event IDs"
	)
	_expect_true(
		not history_text.contains("5002")
		and not history_text.contains("5005"),
		"history text does not expose simulation Ticks"
	)
	_expect_true(
		not history_text.contains("BROOD_")
		and not history_text.contains("RELOCATION_STARTED"),
		"history text does not expose internal event enum names"
	)
	_expect_true(
		not history_text.contains(str(WORKER_ID)),
		"history text does not expose actor entity IDs"
	)

	_destroy_panel(panel)


func _test_reset_clears_projected_selection_state() -> void:
	var panel: WorkerObservationPanel = _create_panel()
	panel.apply_selection(
		_make_worker_snapshot(WorkerTaskModel.State.CARRYING_TO_ZONE),
		"月牙",
		[
			_make_event(
				1,
				20,
				ObservationEvent.Type.BROOD_CARRY_STARTED
			),
		]
	)
	var name_edit: LineEdit = panel.get_node("%WorkerNameEdit") as LineEdit
	name_edit.grab_focus()
	_expect_true(name_edit.has_focus(), "reset fixture first focuses the name field")
	panel.reset_panel()
	panel.reset_panel()

	var prompt: Label = panel.get_node("%WorkerPromptLabel") as Label
	var content: Control = panel.get_node("%SelectedWorkerContent") as Control
	var name_button: Button = panel.get_node("%WorkerNameButton") as Button
	_expect_true(prompt.visible, "reset restores the empty selection prompt")
	_expect_true(not content.visible, "reset hides selected-worker details")
	_expect_string(name_edit.text, "", "reset clears the editable player name")
	_expect_true(not name_edit.has_focus(), "reset releases keyboard focus from the name field")
	_expect_true(name_button.disabled, "reset disables name submission")
	_expect_int(
		panel.get_visible_event_ids().size(),
		0,
		"reset clears visible event metadata"
	)
	_expect_int(
		panel.get_visible_actor_ids().size(),
		0,
		"reset clears visible actor metadata"
	)

	panel.apply_selection(null, "ignored", [])
	_expect_true(prompt.visible, "a null selection remains in the reset state")

	_destroy_panel(panel)


func _test_button_and_line_edit_emit_name_requests() -> void:
	var panel: WorkerObservationPanel = _create_panel()
	var name_edit: LineEdit = panel.get_node("%WorkerNameEdit") as LineEdit
	var name_button: Button = panel.get_node("%WorkerNameButton") as Button
	var captured_names: PackedStringArray = []
	panel.name_commit_requested.connect(func(text: String) -> void:
		captured_names.append(text)
	)

	panel.apply_selection(
		_make_worker_snapshot(WorkerTaskModel.State.IDLE),
		"",
		[]
	)
	name_edit.text = "  琥珀  "
	name_button.pressed.emit()
	_expect_int(captured_names.size(), 1, "the name button emits one request")
	_expect_string(captured_names[0], "琥珀", "button submission trims surrounding whitespace")

	name_edit.text_submitted.emit("  月牙  ")
	_expect_int(captured_names.size(), 2, "LineEdit submission emits one request")
	_expect_string(captured_names[1], "月牙", "LineEdit submission uses normalized text")

	name_edit.text = "   "
	name_button.pressed.emit()
	_expect_int(captured_names.size(), 3, "an empty name still emits a clear request")
	_expect_string(captured_names[2], "", "whitespace-only input requests name clearing")

	panel.reset_panel()
	name_button.pressed.emit()
	_expect_int(
		captured_names.size(),
		3,
		"an empty panel cannot emit another name request"
	)

	_destroy_panel(panel)


func _create_panel() -> WorkerObservationPanel:
	var panel: WorkerObservationPanel = WorkerObservationPanel.new()
	panel.name = "WorkerObservationPanel"

	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "Layout"
	panel.add_child(layout)
	layout.owner = panel

	var prompt: Label = Label.new()
	_add_unique_child(layout, prompt, "WorkerPromptLabel", panel)

	var content: VBoxContainer = VBoxContainer.new()
	_add_unique_child(layout, content, "SelectedWorkerContent", panel)

	var display_name: Label = Label.new()
	_add_unique_child(
		content,
		display_name,
		"WorkerDisplayNameLabel",
		panel
	)

	var current_behavior: Label = Label.new()
	_add_unique_child(
		content,
		current_behavior,
		"WorkerCurrentBehaviorLabel",
		panel
	)

	var name_edit: LineEdit = LineEdit.new()
	_add_unique_child(content, name_edit, "WorkerNameEdit", panel)

	var name_button: Button = Button.new()
	_add_unique_child(content, name_button, "WorkerNameButton", panel)

	var history: Label = Label.new()
	_add_unique_child(content, history, "WorkerHistoryLabel", panel)

	_scene_root.add_child(panel)
	return panel


func _add_unique_child(
	parent: Node,
	child: Node,
	child_name: String,
	panel: WorkerObservationPanel
) -> void:
	child.name = child_name
	child.unique_name_in_owner = true
	parent.add_child(child)
	child.owner = panel


func _destroy_panel(panel: WorkerObservationPanel) -> void:
	_scene_root.remove_child(panel)
	panel.free()


func _make_worker_snapshot(task_state: int) -> AntSnapshot:
	return AntSnapshot.new(
		WORKER_ID,
		AntModel.LifeStage.WORKER,
		0,
		0,
		0,
		&"left_chamber",
		0,
		-1,
		-1,
		task_state,
		&"left_chamber",
		20,
		&"right_chamber"
	)


func _make_event(
	event_id: int,
	tick: int,
	event_type: ObservationEvent.Type
) -> ObservationEvent:
	return ObservationEvent.new(
		event_id,
		tick,
		event_type,
		WORKER_ID,
		20,
		&"left_chamber",
		&"right_chamber"
	)


func _expect_int(actual: int, expected: int, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _expect_int_array(
	actual: Array[int],
	expected: Array[int],
	message: String
) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, str(expected), str(actual))


func _expect_string(actual: String, expected: String, message: String) -> void:
	_assertion_count += 1
	if actual == expected:
		return
	_record_failure(message, expected, actual)


func _expect_true(actual: bool, message: String) -> void:
	_assertion_count += 1
	if actual:
		return
	_record_failure(message, "true", "false")


func _record_failure(message: String, expected: String, actual: String) -> void:
	_failure_count += 1
	printerr("  %s - expected %s, got %s" % [message, expected, actual])
