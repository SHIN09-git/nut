extends SceneTree

const SAMPLE_RATE: int = 44100
const OUTPUT_ROOT: String = "res://assets/production/audio"
const TAU_F: float = PI * 2.0


func _initialize() -> void:
	var absolute_root: String = ProjectSettings.globalize_path(
		OUTPUT_ROOT
	)
	if DirAccess.make_dir_recursive_absolute(absolute_root) != OK:
		printerr("Could not create audio output directory")
		quit(1)
		return
	var outputs: Dictionary[String, PackedFloat32Array] = {
		"ambient_glass_observation.wav": _make_ambient_loop(),
		"ui_soft_confirm.wav": _make_ui_confirm(),
		"glass_tap.wav": _make_glass_tap(),
		"water_drop.wav": _make_water_drop(),
		"facility_place.wav": _make_facility_place(),
		"gate_toggle.wav": _make_gate_toggle(),
		"journal_open.wav": _make_journal_open(),
		"chapter_complete.wav": _make_chapter_complete(),
		"report_reveal.wav": _make_report_reveal(),
	}
	for file_name: String in outputs:
		var path: String = OUTPUT_ROOT.path_join(file_name)
		if not _write_pcm16_wav(path, outputs[file_name]):
			printerr("Could not write %s" % path)
			quit(1)
			return
		print(
			"%s %s"
			% [path, FileAccess.get_sha256(path)]
		)
	quit(0)


func _make_ambient_loop() -> PackedFloat32Array:
	var duration: float = 16.0
	var sample_count: int = roundi(duration * SAMPLE_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(sample_count)
	for index: int in sample_count:
		var phase: float = TAU_F * float(index) / float(sample_count)
		var breath: float = 0.62 + 0.38 * sin(phase * 2.0 - 0.7)
		var air: float = (
			sin(phase * 37.0 + 0.8) * 0.014
			+ sin(phase * 61.0 + 2.1) * 0.010
			+ sin(phase * 89.0 + 4.7) * 0.006
			+ sin(phase * 131.0 + 1.3) * 0.004
		) * breath
		var room: float = (
			sin(phase * 3.0 + 0.2) * 0.018
			+ sin(phase * 5.0 + 1.7) * 0.011
			+ sin(phase * 8.0 + 3.4) * 0.007
		)
		var glass: float = 0.0
		for pulse: float in [0.18, 0.53, 0.81]:
			var progress: float = float(index) / float(sample_count)
			var distance: float = absf(progress - pulse)
			distance = minf(distance, 1.0 - distance)
			var envelope: float = exp(-distance * 46.0)
			glass += envelope * (
				sin(phase * 223.0 + pulse * 7.0) * 0.010
				+ sin(phase * 347.0 + pulse * 11.0) * 0.006
			)
		samples[index] = air + room + glass
	return _normalize(samples, 0.32)


func _make_ui_confirm() -> PackedFloat32Array:
	return _make_tonal_effect(
		0.18,
		[
			{"frequency": 520.0, "gain": 0.58, "decay": 24.0},
			{"frequency": 780.0, "gain": 0.28, "decay": 30.0},
		],
		0.70
	)


func _make_glass_tap() -> PackedFloat32Array:
	return _make_tonal_effect(
		0.42,
		[
			{"frequency": 1620.0, "gain": 0.52, "decay": 13.0},
			{"frequency": 2470.0, "gain": 0.33, "decay": 18.0},
			{"frequency": 3110.0, "gain": 0.15, "decay": 25.0},
		],
		0.72
	)


func _make_water_drop() -> PackedFloat32Array:
	var duration: float = 0.62
	var samples: PackedFloat32Array = _empty_samples(duration)
	for index: int in samples.size():
		var time: float = float(index) / float(SAMPLE_RATE)
		var normalized: float = time / duration
		var frequency: float = lerpf(980.0, 240.0, sqrt(normalized))
		var phase: float = TAU_F * (
			980.0 * time - 0.5 * 740.0 * time * normalized
		)
		var droplet: float = sin(phase) * exp(-time * 8.5) * 0.62
		var body: float = (
			sin(TAU_F * 132.0 * time)
			* exp(-time * 13.0)
			* 0.30
		)
		var ripple: float = (
			sin(TAU_F * frequency * time + 0.4)
			* exp(-time * 5.4)
			* 0.14
		)
		samples[index] = droplet + body + ripple
	return _normalize(samples, 0.74)


func _make_facility_place() -> PackedFloat32Array:
	var duration: float = 0.48
	var samples: PackedFloat32Array = _empty_samples(duration)
	for index: int in samples.size():
		var time: float = float(index) / float(SAMPLE_RATE)
		var thump: float = (
			sin(TAU_F * (92.0 - time * 38.0) * time)
			* exp(-time * 12.0)
			* 0.62
		)
		var latch: float = (
			sin(TAU_F * 680.0 * maxf(0.0, time - 0.055))
			* exp(-maxf(0.0, time - 0.055) * 24.0)
			* (0.25 if time >= 0.055 else 0.0)
		)
		samples[index] = thump + latch
	return _normalize(samples, 0.76)


func _make_gate_toggle() -> PackedFloat32Array:
	var duration: float = 0.38
	var samples: PackedFloat32Array = _empty_samples(duration)
	for index: int in samples.size():
		var time: float = float(index) / float(SAMPLE_RATE)
		var sample: float = 0.0
		for onset: float in [0.015, 0.16]:
			if time < onset:
				continue
			var local_time: float = time - onset
			sample += (
				sin(TAU_F * 940.0 * local_time)
				* exp(-local_time * 31.0)
				* 0.48
				+ sin(TAU_F * 390.0 * local_time)
				* exp(-local_time * 24.0)
				* 0.26
			)
		samples[index] = sample
	return _normalize(samples, 0.72)


func _make_journal_open() -> PackedFloat32Array:
	var duration: float = 0.52
	var samples: PackedFloat32Array = _empty_samples(duration)
	for index: int in samples.size():
		var time: float = float(index) / float(SAMPLE_RATE)
		var envelope: float = sin(clampf(time / duration, 0.0, 1.0) * PI)
		var paper: float = (
			sin(TAU_F * 1180.0 * time + sin(time * 73.0) * 2.0)
			+ sin(TAU_F * 1730.0 * time + 1.2)
			+ sin(TAU_F * 2310.0 * time + 2.4)
		) * 0.10 * envelope
		var settle: float = (
			sin(TAU_F * 220.0 * time)
			* exp(-time * 9.0)
			* 0.20
		)
		samples[index] = paper + settle
	return _normalize(samples, 0.60)


func _make_chapter_complete() -> PackedFloat32Array:
	return _make_staggered_chime(
		1.25,
		[
			{"onset": 0.0, "frequency": 392.0, "gain": 0.42},
			{"onset": 0.18, "frequency": 523.25, "gain": 0.36},
			{"onset": 0.36, "frequency": 659.25, "gain": 0.32},
		],
		0.70
	)


func _make_report_reveal() -> PackedFloat32Array:
	return _make_staggered_chime(
		1.85,
		[
			{"onset": 0.0, "frequency": 196.0, "gain": 0.35},
			{"onset": 0.16, "frequency": 293.66, "gain": 0.32},
			{"onset": 0.34, "frequency": 392.0, "gain": 0.30},
			{"onset": 0.58, "frequency": 783.99, "gain": 0.20},
		],
		0.72
	)


func _make_tonal_effect(
	duration: float,
	partials: Array,
	target_peak: float
) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _empty_samples(duration)
	for index: int in samples.size():
		var time: float = float(index) / float(SAMPLE_RATE)
		var sample: float = 0.0
		for partial: Dictionary in partials:
			sample += (
				sin(TAU_F * float(partial["frequency"]) * time)
				* exp(-time * float(partial["decay"]))
				* float(partial["gain"])
			)
		samples[index] = sample
	return _normalize(samples, target_peak)


func _make_staggered_chime(
	duration: float,
	notes: Array,
	target_peak: float
) -> PackedFloat32Array:
	var samples: PackedFloat32Array = _empty_samples(duration)
	for index: int in samples.size():
		var time: float = float(index) / float(SAMPLE_RATE)
		var sample: float = 0.0
		for note: Dictionary in notes:
			var onset: float = float(note["onset"])
			if time < onset:
				continue
			var local_time: float = time - onset
			var frequency: float = float(note["frequency"])
			var gain: float = float(note["gain"])
			sample += (
				sin(TAU_F * frequency * local_time)
				+ sin(TAU_F * frequency * 2.01 * local_time) * 0.28
				+ sin(TAU_F * frequency * 3.97 * local_time) * 0.12
			) * exp(-local_time * 3.7) * gain
		samples[index] = sample
	return _normalize(samples, target_peak)


func _empty_samples(duration: float) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(roundi(duration * SAMPLE_RATE))
	return samples


func _normalize(
	samples: PackedFloat32Array,
	target_peak: float
) -> PackedFloat32Array:
	var peak: float = 0.0
	for sample: float in samples:
		peak = maxf(peak, absf(sample))
	if peak <= 0.000001:
		return samples
	var scale_factor: float = target_peak / peak
	for index: int in samples.size():
		samples[index] *= scale_factor
	return samples


func _write_pcm16_wav(
	resource_path: String,
	samples: PackedFloat32Array
) -> bool:
	var absolute_path: String = ProjectSettings.globalize_path(
		resource_path
	)
	var file: FileAccess = FileAccess.open(
		absolute_path,
		FileAccess.WRITE
	)
	if file == null:
		return false
	var data_size: int = samples.size() * 2
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + data_size)
	file.store_buffer("WAVE".to_ascii_buffer())
	file.store_buffer("fmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)
	file.store_16(1)
	file.store_32(SAMPLE_RATE)
	file.store_32(SAMPLE_RATE * 2)
	file.store_16(2)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data_size)
	var buffer: PackedByteArray = PackedByteArray()
	buffer.resize(data_size)
	for index: int in samples.size():
		var signed_value: int = clampi(
			roundi(samples[index] * 32767.0),
			-32768,
			32767
		)
		var value: int = signed_value if signed_value >= 0 else signed_value + 65536
		buffer[index * 2] = value & 0xFF
		buffer[index * 2 + 1] = (value >> 8) & 0xFF
	file.store_buffer(buffer)
	file.flush()
	file.close()
	return FileAccess.file_exists(absolute_path)
