extends SceneTree
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		push_error(text)
	else: print("PASS: ", text)
func _init() -> void: run.call_deferred()
func run() -> void:
	var bench := Node.new()
	bench.name = "BalanceBench"
	root.add_child(bench)
	var shop = load("res://src/core/shop_manager.gd").new()
	shop.name = "ShopManager"
	bench.add_child(shop)
	var container := Node3D.new()
	container.name = "BalloonContainer"
	bench.add_child(container)
	var gm = load("res://src/core/game_manager.gd").new()
	gm.name = "GameManager"
	bench.add_child(gm)
	gm.set_process(false)
	gm.spawn_requested.connect(func(count):
		# Isolate the real scheduler with an ideal consumer; this is NOT a physics benchmark.
		for i in range(count): gm.on_balloon_spawned(1)
		gm.active_balloons = 0
	)
	var exits := [15000, 250000, 1000000]
	var index := 0
	for room_id in shop.rooms:
		shop.current_room = room_id
		var threshold: int = exits[index]
		var pipe_level := 0
		for i in range(shop.upgrades.pipe_count.req_pops.size()):
			if int(shop.upgrades.pipe_count.req_pops[i]) < threshold: pipe_level = i + 1
		shop.upgrades.pipe_count.level = pipe_level
		var vent_level := 0
		for i in range(shop.upgrades.vent_rate.req_pops.size()):
			if int(shop.upgrades.vent_rate.req_pops[i]) < threshold: vent_level = i + 1
		shop.upgrades.vent_rate.level = vent_level
		gm.current_vent_level = vent_level
		gm.recalculate_effective_stats()
		print("ROOM CAPACITY ", room_id, " pipes=", shop.get_active_pipe_count(), " vent_level=", vent_level, " nominal_balloons_per_second=", gm.balloons_per_second)
		for fps in [30, 60, 144]:
			gm.spawn_accumulator = 0.0
			gm.actual_spawn_total = 0
			gm.active_balloons = 0
			gm.session_elapsed_time = 0
			gm.spawn_samples.clear()
			for frame in range(fps * 10): gm._process(1.0 / fps)
			var expected := int(round(float(gm.balloons_per_second) * 10.0))
			check(absi(gm.actual_spawn_total - expected) <= 1, "%s scheduler at %d FPS: %d/%d balloons" % [room_id, fps, gm.actual_spawn_total, expected])
		index += 1
	var entry := 0
	index = 0
	for room_id in shop.rooms:
		var progress := float(entry)
		var seconds := 0.0
		shop.current_room = room_id
		while progress < exits[index]:
			var pipes := 1
			var vent := 0
			for i in range(shop.upgrades.pipe_count.req_pops.size()):
				if progress >= int(shop.upgrades.pipe_count.req_pops[i]): pipes = i + 2
			for i in range(shop.upgrades.vent_rate.req_pops.size()):
				if progress >= int(shop.upgrades.vent_rate.req_pops[i]): vent = i + 1
			var rate := float(shop.upgrades.vent_rate.rates[vent]) * mini(pipes, shop.get_pipe_limit()) * float(shop.rooms[room_id].flow_mult)
			progress += rate * 0.1
			seconds += 0.1
		print("IDEAL PRODUCTION LOWER BOUND ", room_id, " seconds=", snappedf(seconds, 0.1), " (unlimited coins, immediate upgrades, all production popped)")
		entry = exits[index]
		index += 1
	shop.current_room = "small_room"
	shop.coins = 9999999
	check(not shop.buy_device_unit("spike_wall", 1000000), "Automation blocked in room one")
	shop.current_room = "medium_room"
	check(shop.buy_device_unit("spike_wall", 5000), "First crusher available on entering facility")
	check(not shop.buy_device_unit("fan", 6999) and not shop.buy_device_unit("magnet_pylon", 9000), "Fan and magnet remain locked before completing the automation tiers")
	check(shop.buy_device_unit("fan", 7000), "Crusher purchase unlocks fan at 7000")
	check(not shop.buy_device_unit("magnet_pylon", 8999) and shop.buy_device_unit("magnet_pylon", 9000), "Fan purchase unlocks magnet at its pop milestone")
	check(shop.get_device_tech_cost("spike_wall", 1) == 1200, "Level 1 to 2 uses first price with room multiplier")
	check(shop.get_device_tech_req_pops("spike_wall", 1) == 9000, "Level 1 to 2 uses matching first threshold")
	check(not shop.buy_device_upgrade("spike_wall", 8999) and shop.buy_device_upgrade("spike_wall", 9000), "Technology upgrade obeys matching threshold")
	check(shop.buy_device_upgrade("spike_wall", 24000) and not shop.buy_device_upgrade("spike_wall", 999999), "Facility tech stops at level three")
	check(shop.buy_device_unit("fan", 18000) and not shop.buy_device_unit("fan", 999999), "Facility limits each device type to two")
	shop.current_room = "small_room"
	shop.coins = 9999999
	check(not shop.buy_room("hangar", 250000), "Hangar cannot skip the facility tier")
	check(shop.buy_room("medium_room", 15000), "Facility opens at its progression milestone")
	shop.pending_room = ""
	check(shop.buy_room("hangar", 250000), "Owning the facility unlocks the final hangar tier")
	shop.pending_room = ""
	check(shop.rooms.size() == 3, "Exactly three rooms remain")
	for kind in ["spike_wall", "electric_wall", "magnet_pylon", "fan"]:
		for level in [1, 3, 6]: print("DEVICE ", kind, " L", level, " ", shop.device_output_preview(kind, level))
	check(shop.rooms.medium_room.unlock_pops == 15000 and shop.rooms.hangar.unlock_pops == 250000, "Room milestones match progression plan")
	check(shop.rooms.medium_room.cost == 0 and shop.rooms.hangar.cost == 0, "Room progression is free")
	bench.queue_free()
	await process_frame
	print("BALANCE AUDIT: ", failures, " failures")
	quit(1 if failures else 0)
