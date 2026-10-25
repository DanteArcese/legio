extends SceneTree
## Bakes a recoloured copy of a palette texture, so the game swaps textures
## instead of recolouring pixels at runtime.
## Usage: godot --headless --path game --script res://tools/bake_palette.gd -- \
##   <in.png> <out.png> <hue_from> <hue_to> <new_hue> [min_saturation] [value_scale]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var image := Image.load_from_file(ProjectSettings.globalize_path(args[0]))
	var low := float(args[2])
	var high := float(args[3])
	var new_hue := float(args[4])
	var min_saturation := float(args[5]) if args.size() > 5 else 0.12
	var value_scale := float(args[6]) if args.size() > 6 else 0.9
	var changed := 0
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.s > min_saturation and c.h >= low and c.h <= high:
				image.set_pixel(x, y, Color.from_hsv(new_hue, minf(c.s * 1.1, 1.0), c.v * value_scale, c.a))
				changed += 1
	image.save_png(ProjectSettings.globalize_path(args[1]))
	print("recoloured %d pixels -> %s" % [changed, args[1]])
	quit()
