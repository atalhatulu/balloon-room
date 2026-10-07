extends SceneTree

# Economy/production planning model, not a physics or human-play simulation.
# effective_output is the fraction of nominal production actually popped.
# 1.5 collected coin/pop is an assumed scenario, not measured tier-one income.
func _init() -> void:
	for efficiency in [1.0, 0.9, 0.85, 0.75]:
		model(float(efficiency))
	quit()

func model(efficiency: float) -> void:
	var shop = load("res://src/core/shop_manager.gd").new()
	var pops := 0.0
	var purse := 0.0
	var elapsed := 0.0
	var purchases: Array[Dictionary] = []
	var production := 0.0
	var order := ["auto_pop", "splash_pop", "dart_gun", "vent_rate", "pipe_count", "coin_magnet", "athlete_training"]
	while pops < 5000 and elapsed < 3600:
		for id in order:
			var data: Dictionary = shop.upgrades[id]
			var level: int = data.level
			if level >= int(data.max_level): continue
			if id == "pipe_count" and level >= 1: continue
			if pops < int(data.req_pops[level]): continue
			var cost := float(data.costs[level])
			if purse < cost: continue
			purse -= cost
			data.level += 1
			purchases.append({"seconds": snappedf(elapsed, 0.1), "pops": int(pops), "id": id, "level": int(data.level), "cost": cost})
			# Budget two seconds per purchase for interacting with the tablet.
			elapsed += 2.0
		production = float(shop.upgrades.vent_rate.rates[int(shop.upgrades.vent_rate.level)]) * float(1 + int(shop.upgrades.pipe_count.level))
		var physical_pops := production * efficiency * 0.1
		pops += physical_pops
		purse += physical_pops * 1.5
		elapsed += 0.1
	print(JSON.stringify({"effective_output": efficiency, "seconds_to_room_two": snappedf(elapsed, 0.1), "final_production_per_second": production, "coins": int(purse), "purchases": purchases}))
	shop.free()
