class_name EconomySimulator
extends RefCounted

# Matematiksel ve Metin Tabanlı İlerleme Simülatörü
# Godot içinden ve F1 panelinden 0.1 saniyede çalışır.

const ROOMS = {
	"small_room": {
		"name": "Küçük Oda",
		"unlock_pops": 0,
		"capacity": 1000,
		"max_pipes": 2,
		"max_devices": 4,
		"flow_mult": 1.0,
		"coin_multiplier": 1.0,
		"cost_multiplier": 1.0,
		"avg_balloon_tier": 1.0
	},
	"medium_room": {
		"name": "Üretim Tesisi",
		"unlock_pops": 15000,
		"capacity": 4000,
		"max_pipes": 4,
		"max_devices": 8,
		"flow_mult": 1.50,
		"coin_multiplier": 1.4,
		"cost_multiplier": 1.5,
		"avg_balloon_tier": 2.4
	},
	"hangar": {
		"name": "Mega Hangar",
		"unlock_pops": 250000,
		"capacity": 15000,
		"physics_budget": 650,
		"max_pipes": 9,
		"max_devices": 16,
		"flow_mult": 0.33,
		"coin_multiplier": 2.0,
		"cost_multiplier": 1.9,
		"avg_balloon_tier": 27.05
	},
}

const ROOM_UPGRADE_CAPS := {
	"small_room": {"vent_rate": 5, "pipe_count": 1, "dart_gun": 2, "auto_pop": 3, "splash_pop": 3},
	"medium_room": {"vent_rate": 6, "pipe_count": 3, "dart_gun": 4, "auto_pop": 5, "splash_pop": 5},
	"hangar": {"vent_rate": 8, "pipe_count": 8, "dart_gun": 5, "auto_pop": 7, "splash_pop": 7},
}

const UPGRADES = {
	"vent_rate": {
		"name": "Dökülme Hızı",
		"costs": [50, 150, 400, 1200, 3500, 10000, 30000, 90000, 250000, 700000, 1800000, 4500000],
		"req_pops": [0, 50, 200, 700, 2500, 20000, 300000, 450000, 600000, 750000, 900000, 1000000],
		"values": [1.5, 2.5, 4.0, 6.0, 9.0, 14.0, 22.0, 35.0, 55.0, 85.0, 130.0, 190.0, 280.0]
	},
	"pipe_count": {
		"name": "Boru Sayısı",
		"costs": [250, 1500, 9500, 42000, 180000, 750000, 2400000, 7000000],
		"req_pops": [300, 3000, 25000, 350000, 500000, 650000, 800000, 950000],
		"values": [1, 2, 3, 4, 5, 6, 7, 8, 9]
	},
	"dart_gun": {
		"name": "Dart Silahı",
		"costs": [600, 2400, 11000, 45000, 180000],
		"req_pops": [650, 2500, 8500, 28000, 95000],
		"intervals": [0.24, 0.20, 0.16, 0.12, 0.08],
		"pierce": [2, 3, 5, 8, 12]
	},
	"auto_pop": {
		"name": "Auto-Pop Makro",
		"costs": [150, 600, 2500, 11000, 48000, 190000, 600000, 1800000],
		"req_pops": [50, 400, 2000, 7000, 28000, 95000, 280000, 750000],
		"values": [0.0, 5.0, 8.3, 13.3, 22.2, 35.7, 55.5, 83.3, 125.0]
	},
	"splash_pop": {
		"name": "İğne Splash",
		"costs": [300, 1200, 5500, 24000, 95000, 360000, 1200000],
		"req_pops": [200, 1000, 3500, 13000, 48000, 160000, 500000],
		"targets": [1, 2, 3, 5, 8, 12, 18, 25]
	}
}

# Otomasyon Cihazları (Spike Shredder & EMP Grid)
const DEVICES = {
	"spike_wall": {
		"name": "Zemin Kırıcısı (Tuzak)",
		"unlock_pops": 5000,
		"unit_costs": [400, 1500, 6000, 22000, 70000, 180000],
		"unit_req_pops": [5000, 14000, 60000, 120000, 350000, 600000],
		# Her bir kırıcının saniye başına ortalama balon öğütme kapasitesi (PPS)
		"pps_per_unit": 28.0
	},
	"electric_wall": {
		"name": "EMP Izgarası (Şimşek)",
		"unlock_pops": 30000,
		"unit_costs": [1200, 4500, 18000, 60000, 150000, 350000],
		"unit_req_pops": [30000, 50000, 140000, 300000, 580000, 780000],
		# EMP deşarjı tavana doğru devasa sütun patlatır (PPS)
		"pps_per_unit": 65.0
	}
}

static func run_simulation(target_pops: int = 1000000, max_seconds: float = 72000.0) -> Dictionary:
	var time: float = 0.0
	var total_pops: int = 0
	var coins: int = 0
	var pop_accumulator: float = 0.0
	var coin_accumulator: float = 0.0
	var active_balloons: float = 0.0
	var current_room: String = "small_room"
	
	var levels = {
		"vent_rate": 0,
		"pipe_count": 0,
		"dart_gun": 0,
		"auto_pop": 0,
		"splash_pop": 0
	}
	
	var devices_owned = {
		"spike_wall": 0,
		"electric_wall": 0
	}
	
	var events: Array[String] = []
	var minute_stats: Array[Dictionary] = []
	var dt: float = 0.5
	var last_minute: int = 0
	
	while total_pops < target_pops and time < max_seconds:
		time += dt
		var room = ROOMS[current_room]
		
		# 1. Üretim
		var vent_val: float = UPGRADES["vent_rate"]["values"][levels["vent_rate"]]
		var active_pipes: int = mini(1 + levels["pipe_count"], room["max_pipes"])
		var spawn_rate: float = vent_val * float(active_pipes) * room["flow_mult"]
		
		var spawn_amt: float = spawn_rate * dt
		if active_balloons + spawn_amt <= float(room["capacity"]):
			active_balloons += spawn_amt
		else:
			active_balloons = float(room["capacity"])
			
		# 2. Oda Basıncı ve Dinamik Patlatma Simülasyonu
		# Basınç oranı: odadaki balon / oda kapasitesi
		var room_cap: float = float(room["capacity"])
		var pressure_ratio: float = active_balloons / room_cap
		
		# Oyuncu davranış modeli:
		# - Basınç %25-50 aralığında oyuncu dengeli patlatır (üretime ayak uydurur).
		# - Basınç %50'yi aşıp %80'e yaklaştığında oyuncu telaşla maksimum hızda (tüm makro ve dart gücüyle) saldırır.
		# - Basınç %15'in altına düştüğünde patlatma yavaşlar çünkü odada balon seyrekleşir.
		var player_effort: float = 1.0
		if pressure_ratio > 0.50:
			# %50'den %80'e doğru acil durum patlatması (1.0x -> 2.5x güç)
			player_effort = 1.0 + ((pressure_ratio - 0.50) / 0.30) * 1.5
		elif pressure_ratio < 0.25:
			# %25'in altında balon aramak gerektiği için çaba düşer
			player_effort = maxf(0.35, pressure_ratio / 0.25)
		else:
			# %25 - %50 arası dengeli tempo
			player_effort = 1.0
			
		var needle_base_pps: float = 4.0
		var auto_pps: float = UPGRADES["auto_pop"]["values"][levels["auto_pop"]]
		var splash_mult: int = UPGRADES["splash_pop"]["targets"][levels["splash_pop"]]
		var effective_needle_pps: float = (needle_base_pps + auto_pps) * (1.0 + float(splash_mult - 1) * 0.4)
		
		var dart_pps: float = 0.0
		if levels["dart_gun"] > 0:
			var d_lvl = levels["dart_gun"] - 1
			var fire_interval: float = UPGRADES["dart_gun"]["intervals"][d_lvl]
			var pierce: int = UPGRADES["dart_gun"]["pierce"][d_lvl]
			var density: float = clampf(pressure_ratio * 1.8, 0.2, 1.0)
			var eff_pierce: float = maxf(1.0, float(pierce) * density)
			dart_pps = (1.0 / fire_interval) * eff_pierce
			
		# Cihazların pasif otomasyon patlatma gücü (Zemin Kırıcısı + EMP Izgarası)
		var device_pps: float = 0.0
		for d_id in devices_owned.keys():
			var count: int = devices_owned[d_id]
			if count > 0:
				device_pps += float(count) * DEVICES[d_id]["pps_per_unit"]
		
		var player_total_pps: float = (effective_needle_pps + dart_pps) * player_effort
		var total_pps: float = player_total_pps + device_pps
		# Ayrıca oyuncu ve cihazlar en azından gelen üretimi süpürebilecek kadar aktiftir (basıncı %25-50 tutar)
		var target_desired_pops: float = spawn_rate * player_effort
		var final_pps: float = maxf(total_pps, target_desired_pops)
		
		var pot_pops: float = final_pps * dt
		var act_pops: float = minf(active_balloons, pot_pops)
		
		active_balloons -= act_pops
		pop_accumulator += act_pops
		while pop_accumulator >= 1.0:
			pop_accumulator -= 1.0
			total_pops += 1
		
		# 3. Altın Kazanımı
		var gained_coins_float: float = act_pops * float(room["avg_balloon_tier"]) * float(room["coin_multiplier"]) * 1.2
		coin_accumulator += gained_coins_float
		while coin_accumulator >= 1.0:
			coin_accumulator -= 1.0
			coins += 1
		
		# 4. Oda İlerlemesi
		for r_id in ["hangar", "medium_room"]:
			if total_pops >= ROOMS[r_id]["unlock_pops"] and current_room != r_id:
				var order = ["small_room", "medium_room", "hangar"]
				if order.find(r_id) > order.find(current_room):
					current_room = r_id
					var m_e = int(time / 60.0)
					var s_e = int(fmod(time, 60.0))
					events.append("[%02d:%02d] 🏠 ODA GEÇİŞİ: %s açıldı! (Balon: %d)" % [m_e, s_e, ROOMS[r_id]["name"], total_pops])
					break
					
		# 5. Satın Alımlar (Geliştirmeler ve Cihazlar)
		var candidates: Array[Dictionary] = []
		for up_id in UPGRADES.keys():
			var u_data = UPGRADES[up_id]
			var lvl: int = levels[up_id]
			var room_caps: Dictionary = ROOM_UPGRADE_CAPS.get(current_room, {})
			var max_lvl: int = mini(u_data["costs"].size(), int(room_caps.get(up_id, u_data["costs"].size())))
			if lvl < max_lvl:
				var base_cost: int = u_data["costs"][lvl]
				var cost: int = maxi(base_cost, int(round(float(base_cost) * ROOMS[current_room]["cost_multiplier"])))
				var req: int = u_data["req_pops"][lvl]
				if coins >= cost and total_pops >= req:
					candidates.append({"type": "upgrade", "id": up_id, "name": u_data["name"], "lvl": lvl + 1, "cost": cost})
					
		# Cihaz satın alma kontrolü
		var total_devices_owned: int = devices_owned["spike_wall"] + devices_owned["electric_wall"]
		var room_device_limit: int = room["max_devices"]
		if total_devices_owned < room_device_limit:
			for d_id in DEVICES.keys():
				var d_data = DEVICES[d_id]
				var cur_cnt: int = devices_owned[d_id]
				var max_units: int = d_data["unit_costs"].size()
				if cur_cnt < max_units and total_pops >= d_data["unlock_pops"]:
					var base_cost: int = d_data["unit_costs"][cur_cnt]
					var cost: int = maxi(base_cost, int(round(float(base_cost) * ROOMS[current_room]["cost_multiplier"])))
					var req: int = d_data["unit_req_pops"][cur_cnt]
					if coins >= cost and total_pops >= req:
						candidates.append({"type": "device", "id": d_id, "name": d_data["name"], "lvl": cur_cnt + 1, "cost": cost})

		if not candidates.is_empty():
			candidates.sort_custom(func(a, b): return a["cost"] < b["cost"])
			var best = candidates[0]
			coins -= best["cost"]
			var m_p = int(time / 60.0)
			var s_p = int(fmod(time, 60.0))
			if best["type"] == "upgrade":
				levels[best["id"]] += 1
				events.append("[%02d:%02d] 🛒 Geliştirme: %s -> Seviye %d (Maliyet: %d, Kalan Coin: %d)" % [m_p, s_p, best["name"], best["lvl"], best["cost"], coins])
			else:
				devices_owned[best["id"]] += 1
				events.append("[%02d:%02d] ⚙️ Cihaz Kuruldu: %s #%d (Maliyet: %d, Kalan Coin: %d)" % [m_p, s_p, best["name"], best["lvl"], best["cost"], coins])
			
		# Dakika İstatistiği
		var cur_min: int = int(time / 60.0)
		if cur_min > last_minute:
			last_minute = cur_min
			minute_stats.append({
				"min": cur_min,
				"room": ROOMS[current_room]["name"],
				"pops": total_pops,
				"coins": coins,
				"active_b": int(active_balloons),
				"pps": round(total_pps * 10.0) / 10.0,
				"devices": devices_owned.duplicate()
			})

	return {
		"target_pops": target_pops,
		"time_seconds": time,
		"total_pops": total_pops,
		"coins": coins,
		"room": ROOMS[current_room]["name"],
		"levels": levels,
		"devices_owned": devices_owned,
		"minute_stats": minute_stats,
		"events": events
	}
