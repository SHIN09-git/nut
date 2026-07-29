extends SceneTree

const SHELL_SCENE: PackedScene = preload(
	"res://scenes/app/game_shell.tscn"
)
const TEST_PROFILE_PATH: String = "user://r15_runtime/profile.json"
const TEST_SETTINGS_PATH: String = "user://r15_runtime/settings.json"


func _initialize() -> void:
	call_deferred("_run_check")


func _run_check() -> void:
	var shell: GameShellController = SHELL_SCENE.instantiate()
	shell.profile_path_override = TEST_PROFILE_PATH
	shell.settings_path_override = TEST_SETTINGS_PATH
	shell.exit_application_on_request = false
	root.add_child(shell)
	await process_frame
	var director: AudioDirector = shell.get_node(
		"%AudioDirector"
	) as AudioDirector
	if director == null or not director.is_ambient_playing():
		printerr("R15 runtime check: ambience did not start")
		_cleanup(shell)
		quit(1)
		return
	if (
		not director.play_cue(&"glass_tap")
		or not director.is_effect_playing()
	):
		printerr("R15 runtime check: effects playback did not start")
		_cleanup(shell)
		quit(1)
		return
	print("PASS: R15 ambient and effects playback active")
	_cleanup(shell)
	quit(0)


func _cleanup(shell: GameShellController) -> void:
	root.remove_child(shell)
	shell.free()
	ProfileStore.new(TEST_PROFILE_PATH).delete_profile()
	SettingsStore.new(TEST_SETTINGS_PATH).delete_for_tests()
