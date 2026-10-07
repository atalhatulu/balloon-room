extends SceneTree

# Planning model: purchases use the live ShopManager catalog. The efficiency
# parameter represents all aiming, device coverage, idle time, and physics loss.
# It must be calibrated from F1 telemetry; it is not an observed game result.
const ROOM_IDS := ["small_room", "medium_room", "hangar"]
const MILESTONES := [15000, 250000, 1000000]
const EFFICIENCIES := [0.50, 0.70, 0.90]
const COIN_PICKUP_FRACTION := 0.70
const PRODUCTION_BUDGET_SHARE := 0.70
const MAX_SECONDS := 72000

func _init() -> void:
	run.call_deferred()

func run() -> void:
	for efficiency in EFFICIENCIES:
		var report := simulate(efficiency)
		var costly: Array[Dictionary] = []
		for purchase in report.purchases:
			if int(purchase.unlock_wait_seconds) >= 120:
				costly.append({"room": purchase.room, "item": purchase.id, "level": purchase.level, "wait_minutes": snappedf(float(purchase.unlock_wait_seconds) / 60.0, 0.1), "late_pops": purchase.after_unlock_pops})
		print(JSON.stringify({"pop_fraction": efficiency, "finish_minutes": report.finish_minutes, "milestones": report.milestones, "purchase_delays": costly}))
		if int(report.get("pops", 0)) < 1000000:
			push_error("Scenario did not reach one million balloons: %.0f%%" % (efficiency * 100.0))
			quit(1)
			return
	quit(0)

func simulate(efficiency: float) -> Dictionary:
	var shop = load("res://src/core/shop_manager.gd").new()
	var pops := 0.0
	var spendable_coins := 0.0
	var reserved_coins := 0.0
	var elapsed := 0
	var milestones: Array[Dictionary] = []
	var purchases: Array[Dictionary] = []
	var waiting_for_coins: Dictionary = {}
	var next_milestone := 0
	while pops < 1000000 and elapsed < MAX_SECONDS:
		var room_id: String = ROOM_IDS[next_milestone]
		shop.current_room = room_id
		var candidate := best_production_upgrade(shop, int(pops), spendable_coins)
		if not candidate.is_empty():
			var cost: int = candidate.cost
			spendable_coins -= cost
			var req: int = shop.get_upgrade_req_pops(candidate.id, int(shop.upgrades[candidate.id].level))
			shop.upgrades[candidate.id].level += 1
			purchases.append({"seconds": elapsed, "pops": int(pops), "room": room_id, "id": candidate.id, "level": int(shop.upgrades[candidate.id].level), "cost": cost, "after_unlock_pops": int(pops) - req, "unlock_wait_seconds": elapsed - int(waiting_for_coins.get(candidate.id, elapsed))})
			waiting_for_coins.erase(candidate.id)
		for id in ["vent_rate", "pipe_count"]:
			var data: Dictionary = shop.upgrades[id]
			var level: int = data.level
			if level >= int(data.max_level) or (id == "pipe_count" and shop.get_active_pipe_count() >= shop.get_pipe_limit()): continue
			if pops >= shop.get_upgrade_req_pops(id, level) and spendable_coins < shop.get_upgrade_cost(id, level) and not waiting_for_coins.has(id):
				waiting_for_coins[id] = elapsed
		var vent_level: int = shop.upgrades.vent_rate.level
		var rate: float = float(shop.upgrades.vent_rate.rates[vent_level]) * shop.get_active_pipe_count() * float(shop.rooms[room_id].flow_mult)
		var actual_pops := rate * efficiency
		pops += actual_pops
		var expected_reward := expected_coin_reward(shop.rooms[room_id])
		spendable_coins += actual_pops * expected_reward * COIN_PICKUP_FRACTION * PRODUCTION_BUDGET_SHARE
		reserved_coins += actual_pops * expected_reward * COIN_PICKUP_FRACTION * (1.0 - PRODUCTION_BUDGET_SHARE)
		elapsed += 1
		if pops >= MILESTONES[next_milestone]:
			milestones.append({"room": room_id, "threshold": MILESTONES[next_milestone], "seconds": elapsed, "minutes": snappedf(float(elapsed) / 60.0, 0.1), "nominal_rate": snappedf(rate, 0.1), "production_coins": int(spendable_coins), "other_spending_pool": int(reserved_coins)})
			next_milestone += 1
			if next_milestone == MILESTONES.size(): break
	var result := {"assumed_pop_fraction": efficiency, "coin_pickup_fraction": COIN_PICKUP_FRACTION, "production_budget_share": PRODUCTION_BUDGET_SHARE, "finish_minutes": snappedf(float(elapsed) / 60.0, 0.1), "pops": int(pops), "milestones": milestones, "purchases": purchases}
	shop.free()
	return result

func best_production_upgrade(shop: Node, pops: int, coins: float) -> Dictionary:
	var best: Dictionary = {}
	var best_value := -1.0
	var room: Dictionary = shop.get_current_room_data()
	var flow_mult: float = room.flow_mult
	var pipes: int = shop.get_active_pipe_count()
	var vent_level: int = shop.upgrades.vent_rate.level
	var current_vent: float = shop.upgrades.vent_rate.rates[vent_level]
	for id in ["vent_rate", "pipe_count"]:
		var data: Dictionary = shop.upgrades[id]
		var level: int = data.level
		if level >= int(data.max_level): continue
		if id == "pipe_count" and pipes >= shop.get_pipe_limit(): continue
		if pops < shop.get_upgrade_req_pops(id, level): continue
		var cost: int = shop.get_upgrade_cost(id, level)
		if coins < cost: continue
		var extra_rate: float = (float(data.rates[level + 1]) - current_vent) * pipes * flow_mult if id == "vent_rate" else current_vent * flow_mult
		var value := extra_rate / maxf(1.0, float(cost))
		if value > best_value:
			best_value = value
			best = {"id": id, "cost": cost}
	return best

func expected_coin_reward(room: Dictionary) -> float:
	var reward := 0.0
	for tier in room.tier_weights:
		var value: int = maxi(int(tier), int(float(tier) * float(room.coin_multiplier)))
		reward += float(room.tier_weights[tier]) * value
	return reward
