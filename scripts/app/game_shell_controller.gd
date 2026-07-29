class_name GameShellController
extends Control

signal application_exit_requested

const LEGACY_GAME_SCENE: PackedScene = preload(
	"res://scenes/main/combined_observation.tscn"
)
const ACT1_GAME_SCENE: PackedScene = preload(
	"res://scenes/main/act1_test_tube.tscn"
)
const ACT1_SCENARIO_ID: StringName = &"act1_test_tube"

enum ConfirmAction {
	NONE,
	NEW_PROFILE,
	DELETE_PROFILE,
	RESTORE_BACKUP,
}

var profile_path_override: String = ""
var settings_path_override: String = ""
var exit_application_on_request: bool = true

var _profile_store: ProfileStore
var _settings_store: SettingsStore
var _settings: DemoSettingsState
var _game_controller: Node
var _active_page: Control
var _confirm_action: ConfirmAction = ConfirmAction.NONE
var _ui_scale_theme: Theme
var _pending_binding_action: StringName = &""

@onready var _game_host: Control = %GameHost
@onready var _audio_director: AudioDirector = %AudioDirector
@onready var _shell_overlay: Control = %ShellOverlay
@onready var _title_page: Control = %TitlePage
@onready var _profiles_page: Control = %ProfilesPage
@onready var _settings_page: Control = %SettingsPage
@onready var _controls_page: Control = %ControlsPage
@onready var _credits_page: Control = %CreditsPage
@onready var _confirm_panel: Control = %ConfirmPanel
@onready var _title_heading: Label = %TitleHeading
@onready var _title_subtitle: Label = %TitleSubtitle
@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _profiles_button: Button = %ProfilesButton
@onready var _settings_button: Button = %SettingsButton
@onready var _credits_button: Button = %CreditsButton
@onready var _exit_button: Button = %ShellExitButton
@onready var _profile_heading: Label = %ProfileHeading
@onready var _profile_summary: Label = %ProfileSummary
@onready var _profile_continue_button: Button = %ProfileContinueButton
@onready var _restore_backup_button: Button = %RestoreBackupButton
@onready var _delete_profile_button: Button = %DeleteProfileButton
@onready var _profile_back_button: Button = %ProfileBackButton
@onready var _settings_heading: Label = %SettingsHeading
@onready var _master_volume_label: Label = %ShellMasterVolumeLabel
@onready var _master_volume_slider: HSlider = %ShellMasterVolumeSlider
@onready var _ambient_volume_label: Label = %ShellAmbientVolumeLabel
@onready var _ambient_volume_slider: HSlider = %ShellAmbientVolumeSlider
@onready var _effects_volume_label: Label = %ShellEffectsVolumeLabel
@onready var _effects_volume_slider: HSlider = %ShellEffectsVolumeSlider
@onready var _resolution_label: Label = %ShellResolutionLabel
@onready var _resolution_option: OptionButton = %ShellResolutionOption
@onready var _fullscreen_check: CheckButton = %ShellFullscreenCheck
@onready var _ui_scale_label: Label = %ShellUIScaleLabel
@onready var _ui_scale_option: OptionButton = %ShellUIScaleOption
@onready var _language_label: Label = %ShellLanguageLabel
@onready var _language_option: OptionButton = %ShellLanguageOption
@onready var _reduced_motion_check: CheckButton = %ShellReducedMotionCheck
@onready var _controls_button: Button = %ControlsButton
@onready var _settings_back_button: Button = %SettingsBackButton
@onready var _controls_heading: Label = %ControlsHeading
@onready var _controls_description: Label = %ControlsDescription
@onready var _help_binding_label: Label = %HelpBindingLabel
@onready var _help_binding_button: Button = %HelpBindingButton
@onready var _journal_binding_label: Label = %JournalBindingLabel
@onready var _journal_binding_button: Button = %JournalBindingButton
@onready var _layout_binding_label: Label = %LayoutBindingLabel
@onready var _layout_binding_button: Button = %LayoutBindingButton
@onready var _controls_reset_button: Button = %ControlsResetButton
@onready var _controls_back_button: Button = %ControlsBackButton
@onready var _credits_heading: Label = %CreditsHeading
@onready var _project_credits_label: RichTextLabel = %ProjectCreditsLabel
@onready var _engine_credits_label: RichTextLabel = %EngineCreditsLabel
@onready var _privacy_heading: Label = %PrivacyHeading
@onready var _privacy_body_label: RichTextLabel = %PrivacyBodyLabel
@onready var _notices_label: RichTextLabel = %NoticesLabel
@onready var _credits_back_button: Button = %CreditsBackButton
@onready var _confirm_heading: Label = %ConfirmHeading
@onready var _confirm_description: Label = %ConfirmDescription
@onready var _confirm_accept_button: Button = %ConfirmAcceptButton
@onready var _confirm_cancel_button: Button = %ConfirmCancelButton
@onready var _status_label: Label = %ShellStatusLabel


func _ready() -> void:
	_profile_store = ProfileStore.new(
		profile_path_override
		if not profile_path_override.is_empty()
		else ProfileStore.DEFAULT_PROFILE_PATH
	)
	_settings_store = SettingsStore.new(
		settings_path_override
		if not settings_path_override.is_empty()
		else SettingsStore.DEFAULT_PATH
	)
	var settings_result: Dictionary = _settings_store.load_or_default()
	_settings = settings_result["settings"]
	_connect_controls()
	_populate_setting_controls()
	_apply_settings(false)
	_show_title_page()
	if not settings_result.get("ok", false):
		_show_status(
			tr("SHELL_SETTINGS_DEFAULTED"),
			true
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_copy()


func _unhandled_input(event: InputEvent) -> void:
	if not _shell_overlay.visible:
		return
	var key_event: InputEventKey = event as InputEventKey
	if (
		key_event == null
		or not key_event.pressed
		or key_event.echo
	):
		return
	if not _pending_binding_action.is_empty():
		if key_event.keycode == KEY_ESCAPE:
			var cancelled_button: Button = _binding_button_for_action(
				_pending_binding_action
			)
			_pending_binding_action = &""
			_refresh_binding_buttons()
			_show_status(tr("R13_BINDING_CANCELLED"), false)
			cancelled_button.grab_focus()
		elif _settings.set_key_binding(
			_pending_binding_action,
			key_event.keycode
		):
			var changed_button: Button = _binding_button_for_action(
				_pending_binding_action
			)
			_pending_binding_action = &""
			_apply_settings(true)
			_show_status(tr("R13_BINDING_SAVED"), false)
			changed_button.grab_focus()
		else:
			_show_status(tr("R13_BINDING_INVALID"), true)
		get_viewport().set_input_as_handled()
		return
	if key_event.keycode != KEY_ESCAPE:
		return
	if _confirm_panel.visible:
		_close_confirmation()
	elif _active_page == _controls_page:
		_show_settings_page()
	elif _active_page != _title_page:
		_show_title_page()
	get_viewport().set_input_as_handled()


func _connect_controls() -> void:
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_profiles_button.pressed.connect(_show_profiles_page)
	_settings_button.pressed.connect(_show_settings_page)
	_credits_button.pressed.connect(_show_credits_page)
	_exit_button.pressed.connect(_on_exit_pressed)
	_profile_continue_button.pressed.connect(_on_continue_pressed)
	_restore_backup_button.pressed.connect(
		_request_confirmation.bind(ConfirmAction.RESTORE_BACKUP)
	)
	_delete_profile_button.pressed.connect(
		_request_confirmation.bind(ConfirmAction.DELETE_PROFILE)
	)
	_profile_back_button.pressed.connect(_show_title_page)
	_settings_back_button.pressed.connect(_show_title_page)
	_controls_button.pressed.connect(_show_controls_page)
	_controls_back_button.pressed.connect(_show_settings_page)
	_credits_back_button.pressed.connect(_show_title_page)
	_controls_reset_button.pressed.connect(_reset_key_bindings)
	_help_binding_button.pressed.connect(
		_begin_binding_capture.bind(DemoSettingsState.ACTION_HELP)
	)
	_journal_binding_button.pressed.connect(
		_begin_binding_capture.bind(DemoSettingsState.ACTION_JOURNAL)
	)
	_layout_binding_button.pressed.connect(
		_begin_binding_capture.bind(DemoSettingsState.ACTION_LAYOUT)
	)
	_confirm_accept_button.pressed.connect(_on_confirmation_accepted)
	_confirm_cancel_button.pressed.connect(_close_confirmation)
	_master_volume_slider.value_changed.connect(_on_master_volume_changed)
	_ambient_volume_slider.value_changed.connect(
		_on_ambient_volume_changed
	)
	_effects_volume_slider.value_changed.connect(
		_on_effects_volume_changed
	)
	_resolution_option.item_selected.connect(_on_resolution_selected)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_ui_scale_option.item_selected.connect(_on_ui_scale_selected)
	_language_option.item_selected.connect(_on_language_selected)
	_reduced_motion_check.toggled.connect(_on_reduced_motion_toggled)
	for node: Node in _shell_overlay.find_children(
		"*",
		"BaseButton",
		true,
		false
	):
		var button: BaseButton = node as BaseButton
		if (
			button != null
			and not button.pressed.is_connected(_play_ui_confirm)
		):
			button.pressed.connect(_play_ui_confirm)


func _populate_setting_controls() -> void:
	_resolution_option.clear()
	for resolution: Vector2i in DemoSettingsState.WINDOWED_RESOLUTIONS:
		_resolution_option.add_item("%d × %d" % [resolution.x, resolution.y])
	_resolution_option.select(_settings.get_resolution_index())
	_ui_scale_option.clear()
	for scale_factor: float in DemoSettingsState.UI_SCALE_FACTORS:
		_ui_scale_option.add_item("%d%%" % int(scale_factor * 100.0))
	_ui_scale_option.select(_settings.get_ui_scale_index())
	_language_option.clear()
	_language_option.add_item(tr("UI_LANGUAGE_ZH"))
	_language_option.add_item(tr("UI_LANGUAGE_EN"))
	_language_option.select(_settings.get_locale_index())
	_fullscreen_check.set_pressed_no_signal(
		_settings.is_fullscreen_requested()
	)
	_reduced_motion_check.set_pressed_no_signal(
		_settings.is_reduced_motion()
	)
	_master_volume_slider.set_value_no_signal(
		_settings.get_master_volume()
	)
	_ambient_volume_slider.set_value_no_signal(
		_settings.get_ambient_volume()
	)
	_effects_volume_slider.set_value_no_signal(
		_settings.get_effects_volume()
	)
	_refresh_binding_buttons()


func _refresh_copy() -> void:
	_title_heading.text = tr("SHELL_TITLE")
	_title_subtitle.text = tr("SHELL_SUBTITLE")
	_new_game_button.text = tr("SHELL_NEW_GAME")
	_continue_button.text = tr("SHELL_CONTINUE")
	_profiles_button.text = tr("SHELL_PROFILES")
	_settings_button.text = tr("SHELL_SETTINGS")
	_credits_button.text = tr("R16_CREDITS_OPEN")
	_exit_button.text = tr("UI_EXIT")
	_profile_heading.text = tr("SHELL_PROFILE_HEADING")
	_profile_continue_button.text = tr("SHELL_PROFILE_CONTINUE")
	_restore_backup_button.text = tr("SHELL_RESTORE_BACKUP")
	_delete_profile_button.text = tr("SHELL_DELETE_PROFILE")
	_profile_back_button.text = tr("SHELL_BACK")
	_settings_heading.text = tr("SHELL_SETTINGS")
	_master_volume_label.text = tr("UI_MASTER_VOLUME")
	_ambient_volume_label.text = tr("R15_AMBIENT_VOLUME")
	_effects_volume_label.text = tr("R15_EFFECTS_VOLUME")
	_resolution_label.text = tr("UI_RESOLUTION")
	_fullscreen_check.text = tr("UI_FULLSCREEN")
	_ui_scale_label.text = tr("UI_SCALE")
	_language_label.text = tr("UI_LANGUAGE")
	_reduced_motion_check.text = tr("UI_REDUCED_MOTION")
	_controls_button.text = tr("R13_CONTROLS_OPEN")
	_settings_back_button.text = tr("SHELL_SAVE_BACK")
	_controls_heading.text = tr("R13_CONTROLS_HEADING")
	_controls_description.text = tr("R13_CONTROLS_DESCRIPTION")
	_help_binding_label.text = tr("R13_BINDING_HELP")
	_journal_binding_label.text = tr("R13_BINDING_JOURNAL")
	_layout_binding_label.text = tr("R13_BINDING_LAYOUT")
	_controls_reset_button.text = tr("R13_BINDING_RESET")
	_controls_back_button.text = tr("SHELL_BACK")
	_credits_heading.text = tr("R16_CREDITS_HEADING")
	_project_credits_label.text = tr("R16_PROJECT_CREDITS")
	_engine_credits_label.text = tr("R16_ENGINE_CREDITS")
	_privacy_heading.text = tr("R16_PRIVACY_HEADING")
	_privacy_body_label.text = tr("R16_PRIVACY_BODY")
	_notices_label.text = tr("R16_NOTICES")
	_credits_back_button.text = tr("SHELL_BACK")
	_refresh_binding_buttons()
	_confirm_accept_button.text = tr("SHELL_CONFIRM")
	_confirm_cancel_button.text = tr("SHELL_CANCEL")
	if _language_option.item_count >= 2:
		_language_option.set_item_text(0, tr("UI_LANGUAGE_ZH"))
		_language_option.set_item_text(1, tr("UI_LANGUAGE_EN"))
		var locale_index: int = _settings.get_locale_index()
		_language_option.select(locale_index)
		_language_option.text = _language_option.get_item_text(locale_index)
	_refresh_profile_summary()


func _show_title_page() -> void:
	_show_shell_page(_title_page)
	_refresh_profile_summary()
	_new_game_button.grab_focus()


func _show_profiles_page() -> void:
	_show_shell_page(_profiles_page)
	_refresh_profile_summary()
	(
		_profile_continue_button
		if not _profile_continue_button.disabled
		else _profile_back_button
	).grab_focus()


func _show_settings_page() -> void:
	_pending_binding_action = &""
	_populate_setting_controls()
	_show_shell_page(_settings_page)
	_master_volume_slider.grab_focus()


func _show_controls_page() -> void:
	_pending_binding_action = &""
	_refresh_binding_buttons()
	_show_shell_page(_controls_page)
	_help_binding_button.grab_focus()


func _show_credits_page() -> void:
	_show_shell_page(_credits_page)
	_credits_back_button.grab_focus()


func _show_shell_page(page: Control) -> void:
	_shell_overlay.visible = true
	_title_page.visible = page == _title_page
	_profiles_page.visible = page == _profiles_page
	_settings_page.visible = page == _settings_page
	_controls_page.visible = page == _controls_page
	_credits_page.visible = page == _credits_page
	_confirm_panel.visible = false
	_confirm_action = ConfirmAction.NONE
	_active_page = page


func _refresh_profile_summary() -> void:
	if _profile_store == null:
		return
	var summary: Dictionary = _profile_store.get_summary()
	var available: bool = bool(summary.get("available", false))
	_continue_button.disabled = not available
	_profile_continue_button.disabled = not available
	_delete_profile_button.disabled = not _profile_store.has_any_candidate()
	_restore_backup_button.disabled = not bool(
		summary.get("backup_exists", false)
	)
	if not available:
		_profile_summary.text = tr("SHELL_NO_PROFILE")
		return
	var source_note: String = ""
	if String(summary.get("recovered_from", "primary")) != "primary":
		source_note = tr("SHELL_RECOVERY_NOTE")
	_profile_summary.text = tr("SHELL_PROFILE_SUMMARY") % [
		_campaign_chapter_name(
			int(summary.get("campaign_chapter", -1)),
			bool(summary.get("campaign_completed", false))
		),
		_format_duration(float(summary.get("simulation_seconds", 0.0))),
		_observation_name(String(summary.get("recent_observation_id", ""))),
		String(summary.get("saved_at_utc", "—")),
		source_note,
	]


func _on_new_game_pressed() -> void:
	if _profile_store.has_any_candidate():
		_request_confirmation(ConfirmAction.NEW_PROFILE)
		return
	_begin_new_profile()


func _begin_new_profile() -> void:
	var delete_result: Dictionary = _profile_store.delete_profile()
	if not delete_result.get("ok", false):
		_show_status(
			tr("SHELL_CLEAR_PROFILE_FAILED"),
			true
		)
		return
	_create_game_controller(ACT1_SCENARIO_ID)
	_shell_overlay.visible = false


func _on_continue_pressed() -> void:
	var load_result: Dictionary = _profile_store.load_best()
	if not load_result.get("ok", false):
		_show_status(
			tr("SHELL_LOAD_FAILED"),
			true
		)
		_refresh_profile_summary()
		return
	var restored_simulation: ColonySimulation = load_result["simulation"]
	_create_game_controller(
		restored_simulation.create_snapshot().scenario_id
	)
	if not bool(_game_controller.call(
		&"restore_loaded_session",
		restored_simulation,
		load_result["clock"]
	)):
		_destroy_game_controller()
		_show_status(
			tr("SHELL_RESTORE_SESSION_FAILED"),
			true
		)
		return
	_shell_overlay.visible = false
	if String(load_result.get("recovered_from", "primary")) != "primary":
		_show_status(
			tr("SHELL_BACKUP_LOADED"),
			false
		)


func _create_game_controller(scenario_id: StringName) -> void:
	_destroy_game_controller()
	var scene: PackedScene = (
		ACT1_GAME_SCENE
		if scenario_id == ACT1_SCENARIO_ID
		else LEGACY_GAME_SCENE
	)
	_game_controller = scene.instantiate()
	_game_controller.set(&"provided_settings_state", _settings)
	_game_controller.set(&"shell_managed", true)
	_game_controller.set(&"exit_application_on_request", false)
	_game_controller.connect(
		&"save_profile_requested",
		_save_active_profile
	)
	_game_controller.connect(
		&"return_to_title_requested",
		_on_return_to_title_requested
	)
	_game_controller.connect(
		&"settings_changed",
		_on_game_settings_changed
	)
	_game_controller.connect(
		&"application_exit_requested",
		_on_exit_pressed
	)
	if _game_controller.has_signal(&"presentation_audio_cue_requested"):
		_game_controller.connect(
			&"presentation_audio_cue_requested",
			_audio_director.play_cue
		)
	_game_host.add_child(_game_controller)


func _destroy_game_controller() -> void:
	if _game_controller == null:
		return
	var old_controller: Node = _game_controller
	_game_controller = null
	old_controller.visible = false
	old_controller.process_mode = Node.PROCESS_MODE_DISABLED
	if old_controller.is_inside_tree():
		old_controller.queue_free()
	else:
		old_controller.free()


func _save_active_profile() -> bool:
	if _game_controller == null:
		return false
	var envelope: Dictionary = _game_controller.call(
		&"create_profile_envelope"
	)
	if envelope.is_empty():
		_game_controller.call(&"report_profile_save_result", false)
		return false
	var result: Dictionary = _profile_store.save_envelope(envelope)
	var success: bool = bool(result.get("ok", false))
	_game_controller.call(&"report_profile_save_result", success)
	_refresh_profile_summary()
	return success


func _on_return_to_title_requested() -> void:
	if not _save_active_profile():
		return
	_destroy_game_controller()
	_show_title_page()
	_show_status(tr("SHELL_PROGRESS_SAVED"), false)


func _request_confirmation(action: ConfirmAction) -> void:
	_confirm_action = action
	match action:
		ConfirmAction.NEW_PROFILE:
			_confirm_heading.text = tr("SHELL_CONFIRM_NEW_HEADING")
			_confirm_description.text = tr("SHELL_CONFIRM_NEW_BODY")
		ConfirmAction.DELETE_PROFILE:
			_confirm_heading.text = tr("SHELL_CONFIRM_DELETE_HEADING")
			_confirm_description.text = tr("SHELL_CONFIRM_DELETE_BODY")
		ConfirmAction.RESTORE_BACKUP:
			_confirm_heading.text = tr("SHELL_CONFIRM_RESTORE_HEADING")
			_confirm_description.text = tr("SHELL_CONFIRM_RESTORE_BODY")
		_:
			return
	_confirm_panel.visible = true
	_confirm_accept_button.grab_focus()


func _close_confirmation() -> void:
	_confirm_panel.visible = false
	_confirm_action = ConfirmAction.NONE
	if _active_page == _profiles_page:
		_profile_back_button.grab_focus()
	else:
		_new_game_button.grab_focus()


func _on_confirmation_accepted() -> void:
	var action: ConfirmAction = _confirm_action
	_close_confirmation()
	match action:
		ConfirmAction.NEW_PROFILE:
			_begin_new_profile()
		ConfirmAction.DELETE_PROFILE:
			var result: Dictionary = _profile_store.delete_profile()
			_refresh_profile_summary()
			_show_status(
				tr("SHELL_DELETE_SUCCESS")
				if result.get("ok", false)
				else tr("SHELL_DELETE_FAILED"),
				not result.get("ok", false)
			)
		ConfirmAction.RESTORE_BACKUP:
			var result: Dictionary = _profile_store.restore_backup()
			_refresh_profile_summary()
			_show_status(
				tr("SHELL_BACKUP_RESTORE_SUCCESS")
				if result.get("ok", false)
				else tr("SHELL_BACKUP_RESTORE_FAILED"),
				not result.get("ok", false)
			)


func _on_exit_pressed() -> void:
	application_exit_requested.emit()
	if exit_application_on_request:
		get_tree().quit()


func _on_master_volume_changed(value: float) -> void:
	if _settings.set_master_volume(value):
		_apply_settings(true)


func _on_ambient_volume_changed(value: float) -> void:
	if _settings.set_ambient_volume(value):
		_apply_settings(true)


func _on_effects_volume_changed(value: float) -> void:
	if _settings.set_effects_volume(value):
		_apply_settings(true)


func _play_ui_confirm() -> void:
	_audio_director.play_cue(&"ui_confirm")


func _on_resolution_selected(index: int) -> void:
	if _settings.select_resolution(index):
		_apply_settings(true)


func _on_fullscreen_toggled(enabled: bool) -> void:
	_settings.set_fullscreen_requested(enabled)
	_apply_settings(true)


func _on_ui_scale_selected(index: int) -> void:
	if _settings.select_ui_scale(index):
		_apply_settings(true)


func _on_language_selected(index: int) -> void:
	if _settings.select_locale(index):
		_apply_settings(true)


func _on_reduced_motion_toggled(enabled: bool) -> void:
	_settings.set_reduced_motion(enabled)
	_apply_settings(true)


func _begin_binding_capture(action_id: StringName) -> void:
	if not DemoSettingsState.BINDABLE_ACTIONS.has(action_id):
		return
	_pending_binding_action = action_id
	_refresh_binding_buttons()
	var button: Button = _binding_button_for_action(action_id)
	button.text = tr("R13_BINDING_PRESS_KEY")
	button.grab_focus()
	_show_status(tr("R13_BINDING_WAITING"), false)


func _reset_key_bindings() -> void:
	_pending_binding_action = &""
	_settings.reset_key_bindings()
	_apply_settings(true)
	_show_status(tr("R13_BINDING_RESET_DONE"), false)
	_controls_reset_button.grab_focus()


func _refresh_binding_buttons() -> void:
	if _settings == null:
		return
	_help_binding_button.text = _settings.get_key_binding_label(
		DemoSettingsState.ACTION_HELP
	)
	_journal_binding_button.text = _settings.get_key_binding_label(
		DemoSettingsState.ACTION_JOURNAL
	)
	_layout_binding_button.text = _settings.get_key_binding_label(
		DemoSettingsState.ACTION_LAYOUT
	)


func _binding_button_for_action(action_id: StringName) -> Button:
	match action_id:
		DemoSettingsState.ACTION_HELP:
			return _help_binding_button
		DemoSettingsState.ACTION_JOURNAL:
			return _journal_binding_button
		_:
			return _layout_binding_button


func _on_game_settings_changed(settings: DemoSettingsState) -> void:
	_settings = settings
	_settings_store.save(_settings)
	_apply_settings(false)


func _apply_settings(persist: bool) -> void:
	TranslationServer.set_locale(_settings.get_locale_code())
	var window: Window = get_window()
	if window != null:
		window.content_scale_factor = 1.0
	var scale_factor: float = _settings.get_ui_scale_factor()
	if _ui_scale_theme == null:
		_ui_scale_theme = (
			theme.duplicate(true) as Theme
			if theme != null else Theme.new()
		)
		theme = _ui_scale_theme
	_ui_scale_theme.default_base_scale = scale_factor
	_ui_scale_theme.default_font_size = int(round(16.0 * scale_factor))
	_apply_explicit_font_scale(self, scale_factor)
	if DisplayServer.get_name().to_lower() != "headless":
		if _settings.is_fullscreen_requested():
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_size(_settings.get_windowed_resolution())
	_audio_director.apply_settings(_settings)
	if _game_controller != null:
		_game_controller.call(&"apply_external_settings", _settings)
	if persist:
		var result: Dictionary = _settings_store.save(_settings)
		if not result.get("ok", false):
			_show_status(
				tr("SHELL_SETTINGS_SAVE_FAILED"),
				true
			)
	_populate_setting_controls()
	_refresh_copy()


func _apply_explicit_font_scale(node: Node, scale_factor: float) -> void:
	if node is Control:
		var control: Control = node as Control
		if control.has_theme_font_size_override(&"font_size"):
			if not control.has_meta(&"ui_scale_base_font_size"):
				control.set_meta(
					&"ui_scale_base_font_size",
					control.get_theme_font_size(&"font_size")
				)
			control.add_theme_font_size_override(
				&"font_size",
				int(round(
					float(control.get_meta(&"ui_scale_base_font_size"))
					* scale_factor
				))
			)
	for child: Node in node.get_children():
		_apply_explicit_font_scale(child, scale_factor)


func _phase_name(phase: int) -> String:
	var phase_keys: PackedStringArray = [
		"SHELL_PHASE_FOUNDING",
		"SHELL_PHASE_IDENTITY",
		"SHELL_PHASE_HUMIDITY",
		"SHELL_PHASE_SUGAR",
		"SHELL_PHASE_SUMMARY",
	]
	if phase < 0 or phase >= phase_keys.size():
		return tr("SHELL_PHASE_NOT_STARTED")
	return tr(phase_keys[phase])


func _campaign_chapter_name(chapter: int, completed: bool) -> String:
	if completed:
		return tr("SHELL_CAMPAIGN_COMPLETE")
	match chapter:
		CampaignState.Chapter.FOUNDING_OBSERVATION:
			return tr("CAMPAIGN_CHAPTER_FOUNDING")
		CampaignState.Chapter.ENVIRONMENTAL_CARE:
			return tr("CAMPAIGN_CHAPTER_ENVIRONMENT")
		CampaignState.Chapter.ACT1_FOUNDING:
			return tr("ACT1_CHAPTER_FOUNDING")
		CampaignState.Chapter.ACT1_FIRST_WORKERS:
			return tr("ACT1_CHAPTER_FIRST_WORKERS")
		CampaignState.Chapter.ACT1_FORAGING_EXPANSION:
			return tr("R10_CHAPTER_FORAGING")
		CampaignState.Chapter.ACT1_ENVIRONMENT_MANAGEMENT:
			return tr("R10_CHAPTER_ENVIRONMENT")
		CampaignState.Chapter.ACT1_MODULAR_MIGRATION:
			return tr("R11_CHAPTER_MIGRATION")
		CampaignState.Chapter.ACT1_STABLE_COLONY_SUMMARY:
			return tr("R12_CHAPTER_FINALE")
		_:
			return _phase_name(-1)


func _observation_name(observation_id: String) -> String:
	match observation_id:
		"first_worker_emerged":
			return tr("SHELL_OBSERVATION_FIRST_WORKER")
		"brood_humidity_relocation":
			return tr("SHELL_OBSERVATION_HUMIDITY")
		"sugar_foraging_complete":
			return tr("SHELL_OBSERVATION_SUGAR")
		"queen_brood_care":
			return tr("ACT1_EVIDENCE_QUEEN_CARE")
		"first_pupa_stable":
			return tr("ACT1_EVIDENCE_FIRST_PUPA")
		"first_worker_brood_care":
			return tr("ACT1_EVIDENCE_WORKER_CARE")
		"first_nutrient_exchange":
			return tr("ACT1_EVIDENCE_NUTRIENT")
		"glass_observation_report":
			return tr("R12_OBSERVATION_REPORT")
		"":
			return tr("SHELL_OBSERVATION_NONE")
		_:
			return tr("SHELL_OBSERVATION_NEW")


func _format_duration(seconds: float) -> String:
	var total_seconds: int = maxi(0, int(floor(seconds)))
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _show_status(message: String, is_error: bool) -> void:
	_status_label.text = "%s %s" % [
		"!" if is_error else "✓",
		message,
	]
	_status_label.modulate = (
		Color(1.0, 0.62, 0.52)
		if is_error
		else Color(0.68, 0.9, 0.72)
	)
	_status_label.visible = not message.is_empty()


func get_active_page_name() -> StringName:
	return _active_page.name if _active_page != null else &""


func get_game_controller() -> Node:
	return _game_controller


func get_settings_state() -> DemoSettingsState:
	return _settings
