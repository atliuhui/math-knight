extends SceneTree


func _init() -> void:
	var options := _parse_options()
	var source_root := String(options.get("source-root", ""))
	var output_root := String(options.get("output-root", ""))
	var size := int(options.get("size", "32"))
	if source_root.is_empty() or output_root.is_empty():
		printerr("Usage: -- source-root=<path> output-root=<path> size=<pixels>")
		quit(1)
		return
	var dir := DirAccess.open(source_root)
	if dir == null:
		printerr("Failed to open SVG source directory: ", source_root)
		quit(1)
		return
	for file_name in dir.get_files():
		if file_name.get_extension().to_lower() != "svg":
			continue
		var source_path: String = source_root.path_join(file_name)
		var output_path: String = output_root.path_join(file_name.get_basename() + ".png")
		var svg_file := FileAccess.open(source_path, FileAccess.READ)
		if svg_file == null:
			printerr("Failed to open SVG file: ", source_path)
			quit(1)
			return
		var svg_text := _normalize_svg_fill(svg_file.get_as_text())
		var image := Image.new()
		var err := image.load_svg_from_buffer(svg_text.to_utf8_buffer(), float(size) / 24.0)
		if err != OK:
			printerr("Failed to load SVG: ", source_path, " err=", err)
			quit(1)
			return
		if image.get_width() != size or image.get_height() != size:
			image.resize(size, size, Image.INTERPOLATE_LANCZOS)
		err = image.save_png(output_path)
		if err != OK:
			printerr("Failed to save PNG: ", output_path, " err=", err)
			quit(1)
			return
		print("Exported ", output_path)
	quit()


func _normalize_svg_fill(svg_text: String) -> String:
	var normalized := svg_text.replace("currentColor", "#ffffff")
	var hex_fill := RegEx.new()
	var err := hex_fill.compile("fill=\"#[0-9a-fA-F]{6}\"")
	if err != OK:
		printerr("Failed to compile SVG fill normalization regex: ", err)
		quit(1)
		return normalized
	return hex_fill.sub(normalized, "fill=\"#ffffff\"", true)


func _parse_options() -> Dictionary:
	var options := {}
	for arg in OS.get_cmdline_user_args():
		var separator: int = arg.find("=")
		if separator > 0:
			options[arg.substr(0, separator)] = arg.substr(separator + 1)
	return options
