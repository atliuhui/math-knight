extends SceneTree


func _init() -> void:
	var options := _parse_options()
	var source := String(options.get("source", ""))
	var target := String(options.get("target", ""))
	var scale := int(options.get("scale", "4"))
	if source.is_empty() or target.is_empty():
		printerr("Usage: -- source=<pxo-path> target=<png-path> scale=<integer>")
		quit(1)
		return
	var zip := ZIPReader.new()
	var err := zip.open(source)
	if err != OK:
		printerr("Failed to open pxo: ", source, " err=", err)
		quit(1)
		return
	var json_text := zip.read_file("data.json").get_string_from_utf8()
	var parsed := JSON.new()
	err = parsed.parse(json_text)
	if err != OK:
		printerr("Failed to parse data.json in ", source, " err=", err)
		zip.close()
		quit(1)
		return
	var data: Dictionary = parsed.get_data()
	var width := int(data["size_x"])
	var height := int(data["size_y"])
	var format := int(data.get("color_mode", Image.FORMAT_RGBA8))
	var image_data := zip.read_file("image_data/frames/1/layer_1")
	zip.close()
	var image := Image.create_from_data(width, height, false, format, image_data)
	if scale != 1:
		image.resize(width * scale, height * scale, Image.INTERPOLATE_NEAREST)
	err = image.save_png(target)
	if err != OK:
		printerr("Failed to save png: ", target, " err=", err)
		quit(1)
		return
	print("Exported ", target)
	quit()


func _parse_options() -> Dictionary:
	var options := {}
	for arg in OS.get_cmdline_user_args():
		var separator: int = arg.find("=")
		if separator > 0:
			options[arg.substr(0, separator)] = arg.substr(separator + 1)
	return options
