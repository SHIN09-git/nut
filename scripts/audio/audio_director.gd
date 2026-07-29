class_name AudioDirector
extends Node

const AMBIENT_STREAM: AudioStreamWAV = preload(
	"res://assets/production/audio/ambient_glass_observation.wav"
)
const CUE_STREAMS: Dictionary[StringName, AudioStreamWAV] = {
	&"ui_confirm": preload(
		"res://assets/production/audio/ui_soft_confirm.wav"
	),
	&"glass_tap": preload(
		"res://assets/production/audio/glass_tap.wav"
	),
	&"water_drop": preload(
		"res://assets/production/audio/water_drop.wav"
	),
	&"facility_place": preload(
		"res://assets/production/audio/facility_place.wav"
	),
	&"gate_toggle": preload(
		"res://assets/production/audio/gate_toggle.wav"
	),
	&"journal_open": preload(
		"res://assets/production/audio/journal_open.wav"
	),
	&"chapter_complete": preload(
		"res://assets/production/audio/chapter_complete.wav"
	),
	&"report_reveal": preload(
		"res://assets/production/audio/report_reveal.wav"
	),
}

@onready var _ambient_player: AudioStreamPlayer = %AmbientPlayer
@onready var _effects_player: AudioStreamPlayer = %EffectsPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var loop_stream: AudioStreamWAV = (
		AMBIENT_STREAM.duplicate(true) as AudioStreamWAV
	)
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop_stream.loop_begin = 0
	loop_stream.loop_end = loop_stream.data.size() / 2
	_ambient_player.stream = loop_stream
	start_ambient()


func _exit_tree() -> void:
	_ambient_player.stop()
	_effects_player.stop()
	_ambient_player.stream = null
	_effects_player.stream = null


func apply_settings(settings: DemoSettingsState) -> void:
	if settings == null:
		return
	_apply_bus_volume(&"Master", settings.get_master_volume())
	_apply_bus_volume(&"Ambient", settings.get_ambient_volume())
	_apply_bus_volume(&"SFX", settings.get_effects_volume())


func start_ambient() -> void:
	if (
		DisplayServer.get_name().to_lower() != "headless"
		and _ambient_player.stream != null
		and not _ambient_player.playing
	):
		_ambient_player.play()


func stop_ambient() -> void:
	_ambient_player.stop()


func play_cue(cue_id: StringName) -> bool:
	if not CUE_STREAMS.has(cue_id):
		return false
	_effects_player.stream = CUE_STREAMS[cue_id]
	if DisplayServer.get_name().to_lower() != "headless":
		_effects_player.play()
	return true


func get_supported_cue_ids() -> Array[StringName]:
	var cue_ids: Array[StringName] = []
	for cue_id: StringName in CUE_STREAMS:
		cue_ids.append(cue_id)
	cue_ids.sort()
	return cue_ids


func get_ambient_stream() -> AudioStreamWAV:
	return _ambient_player.stream as AudioStreamWAV


func is_ambient_playing() -> bool:
	return _ambient_player.playing


func is_effect_playing() -> bool:
	return _effects_player.playing


func _apply_bus_volume(bus_name: StringName, volume: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var safe_volume: float = clampf(volume, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, safe_volume <= 0.0001)
	if safe_volume > 0.0001:
		AudioServer.set_bus_volume_db(
			bus_index,
			linear_to_db(safe_volume)
		)
