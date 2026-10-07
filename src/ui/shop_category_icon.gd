extends Control
var item_id := ""
var category := "upgrades"
func _draw() -> void:
	var c := Color("73dcc8")
	var p := size * 0.5
	if item_id == "dart_gun":
		draw_rect(Rect2(p + Vector2(-16, -9), Vector2(28, 10)), c, false, 2)
		draw_line(p + Vector2(12, -4), p + Vector2(19, -4), c, 3)
		draw_line(p + Vector2(-8, 1), p + Vector2(-12, 14), c, 6)
	elif item_id in ["auto_pop", "splash_pop"]:
		draw_line(p + Vector2(-12, 14), p + Vector2(12, -14), c, 3)
		if item_id == "splash_pop": draw_arc(p, 16, 0, TAU, 24, c, 1.5, true)
	elif item_id == "coin_magnet" or item_id == "magnet_pylon":
		draw_arc(p, 12, 0, PI, 20, c, 5, true)
		for x in [-12, 12]: draw_line(p + Vector2(x, 0), p + Vector2(x, -12), c, 5)
	elif item_id in ["vent_rate", "pipe_count"]:
		draw_rect(Rect2(p - Vector2(14, 12), Vector2(28, 24)), c, false, 2)
		for y in [-6, 0, 6]: draw_line(p + Vector2(-10, y), p + Vector2(10, y), c, 2)
	elif item_id == "fan":
		draw_circle(p, 3, c)
		for i in range(3):
			var d := Vector2.from_angle(i * TAU / 3)
			draw_line(p + d * 4, p + d * 15, c, 7, true)
		draw_arc(p, 18, 0, TAU, 32, c, 1, true)
	elif item_id in ["spike_wall", "conveyor_crusher"]:
		for x in [-9, 9]:
			draw_rect(Rect2(p + Vector2(x - 5, -13), Vector2(10, 26)), c, false, 2)
			for y in [-7, 0, 7]: draw_line(p + Vector2(x - 4, y), p + Vector2(x + 4, y), c, 2)
	elif item_id == "electric_wall":
		draw_polyline(PackedVector2Array([p + Vector2(6, -17), p + Vector2(-9, 1), p + Vector2(6, 1), p + Vector2(-6, 17)]), c, 4, true)
	elif item_id == "athlete_training":
		draw_circle(p + Vector2(0, -12), 4, c)
		draw_polyline(PackedVector2Array([p + Vector2(-12, -1), p + Vector2(0, -5), p + Vector2(8, 4), p + Vector2(15, 4)]), c, 3, true)
		draw_polyline(PackedVector2Array([p + Vector2(0, -5), p + Vector2(-4, 7), p + Vector2(-13, 15)]), c, 3, true)
		draw_line(p + Vector2(-4, 7), p + Vector2(8, 15), c, 3, true)
	elif category == "rooms":
		draw_rect(Rect2(p - Vector2(14, 11), Vector2(28, 24)), c, false, 2.0)
		draw_line(p + Vector2(-14, -11), p + Vector2(0, -19), c, 2, true)
		draw_line(p + Vector2(0, -19), p + Vector2(14, -11), c, 2, true)
		draw_rect(Rect2(p + Vector2(-4, 2), Vector2(8, 11)), c, false, 2)
	elif category == "devices":
		draw_arc(p, 11, 0, TAU, 32, c, 2, true)
		draw_circle(p, 4, c)
		for i in range(8):
			var d := Vector2.from_angle(i * TAU / 8)
			draw_line(p + d * 12, p + d * 17, c, 3, true)
	else:
		for i in range(3):
			draw_rect(Rect2(p + Vector2(-14 + i * 10, 7 - i * 7), Vector2(6, 8 + i * 7)), c)
		draw_line(p + Vector2(-14, -8), p + Vector2(12, -18), c, 2, true)
		draw_line(p + Vector2(12, -18), p + Vector2(5, -19), c, 2, true)
