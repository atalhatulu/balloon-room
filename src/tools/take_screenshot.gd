extends SceneTree

func _init():
	print("Starting screenshot script...")
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		print("ERROR: Could not load res://scenes/main.tscn")
		quit()
		return
		
	var root_node = main_scene.instantiate()
	root.add_child(root_node)
	
	await create_timer(1.5).timeout
	
	var vp = root.get_viewport()
	if vp:
		var img = vp.get_texture().get_image()
		if img:
			var path = "/home/teha/Desktop/game_screenshot.png"
			img.save_png(path)
			print("SUCCESS_SAVED:", path)
	quit()
