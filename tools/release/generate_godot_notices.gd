extends SceneTree

const OUTPUT_PATH: String = "res://docs/production/GODOT_COPYRIGHT.txt"


func _initialize() -> void:
	var version: Dictionary = Engine.get_version_info()
	var lines: PackedStringArray = PackedStringArray([
		"GODOT ENGINE AND BUNDLED THIRD-PARTY NOTICES",
		"",
		"Generated from the exact engine binary through "
			+ "Engine.get_license_text(), Engine.get_copyright_info(), "
			+ "and Engine.get_license_info().",
		"Engine version: %s" % String(version.get("string", "unknown")),
		"Upstream: https://godotengine.org/",
		"",
		"================================================================",
		"GODOT ENGINE LICENSE",
		"================================================================",
		"",
		Engine.get_license_text().strip_edges(),
		"",
		"================================================================",
		"COMPONENT COPYRIGHT INFORMATION",
		"================================================================",
	])
	for component: Dictionary in Engine.get_copyright_info():
		lines.append("")
		lines.append("Component: %s" % String(component.get("name", "")))
		for part_value: Variant in component.get("parts", []):
			var part: Dictionary = part_value
			lines.append(
				"Files: %s" % ", ".join(
					_to_string_array(part.get("files", []))
				)
			)
			lines.append(
				"Copyright: %s" % "; ".join(
					_to_string_array(part.get("copyright", []))
				)
			)
			lines.append("License: %s" % String(part.get("license", "")))
	var license_info: Dictionary = Engine.get_license_info()
	var license_names: Array[String] = []
	for license_name: Variant in license_info:
		license_names.append(String(license_name))
	license_names.sort()
	lines.append("")
	lines.append(
		"================================================================"
	)
	lines.append("FULL LICENSE TEXTS")
	lines.append(
		"================================================================"
	)
	for license_name: String in license_names:
		lines.append("")
		lines.append(
			"----------------------------------------------------------------"
		)
		lines.append(license_name)
		lines.append(
			"----------------------------------------------------------------"
		)
		lines.append(String(license_info[license_name]).strip_edges())
	lines.append("")
	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr(
			"Unable to write Godot notices: %s"
			% error_string(FileAccess.get_open_error())
		)
		quit(1)
		return
	file.store_string("\n".join(lines))
	file.close()
	print("Generated %s" % OUTPUT_PATH)
	quit(0)


func _to_string_array(values: Variant) -> PackedStringArray:
	var result: PackedStringArray = []
	for value: Variant in values:
		result.append(String(value))
	return result
