extends Node

signal coins_changed(total_coins: int)
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal room_unlocked(room_id: String)
signal room_switched(room_id: String)
signal room_transfer_requested(room_id: String)
signal device_purchased(device_id: String, new_level: int)
signal device_unit_purchased(device_id: String, new_count: int, level: int)
signal purchase_failed(reason: String)
signal prestige_performed(new_prestige_level: int, helium_earned: int)

var coins: int = 0
var current_room: String = "small_room"
var pending_room: String = ""
var unlocked_rooms: Array = ["small_room"]
var prestige_level: int = 0
var helium_atoms: int = 0

# Devices & Automation Equipment Catalog (3 Distinct Placeable Archetypes + 1 Wall Terminal)
var devices: Dictionary = {
	"spike_wall": {
		"id": "spike_wall",
		"name": "Endüstriyel Zemin Kırıcısı (Floor Shredder)",
		"category": "devices",
		"unlock_pops": 2000,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 2,
		"desc": "Zemine serilen sivri çelik kırıcı tuzak. Üstündeki balonları vakumlayarak aşağı çeker ve devasa grupları seri öğütür.",
		"widths": ["3.6m Alan | 0.55s (20 Balon)", "4.6m Alan | 0.42s (45 Balon)", "5.8m Alan | 0.32s (90 Balon)", "7.2m Alan | 0.24s (160 Balon)", "8.8m Alan | 0.18s (260 Balon)", "10.8m Alan | 0.12s (400 Balon)"],
		"unit_costs": [500, 1200, 8000, 25000, 80000, 200000],
		"unit_req_pops": [2000, 10000, 40000, 120000, 300000, 600000],
		"costs": [1000, 3000, 10000, 35000, 120000, 300000],
		"req_pops": [4000, 15000, 50000, 150000, 350000, 700000]
	},
	"fan": {
		"id": "fan", "name": "Yönlendirme Vantilatörü", "category": "devices",
		"unlock_pops": 3500, "level": 0, "max_level": 6, "count": 0, "max_count": 3,
		"requires_device": "spike_wall",
		"desc": "Zemine yerleştirilen yönlendirici pervane. Önündeki balonları kuvvetli rüzgarla lazer çitine veya kuyuya fırlatır. [R] ile döndürülür.",
		"unit_costs": [800, 2500, 8000, 28000, 85000, 200000],
		"unit_req_pops": [3500, 14000, 50000, 140000, 320000, 600000],
		"costs": [1000, 3000, 10000, 35000, 120000, 300000],
		"req_pops": [6000, 20000, 60000, 180000, 400000, 750000]
	},
	"magnet_pylon": {
		"id": "magnet_pylon",
		"name": "Manyetik Çekim Kulesi (Magnet Pylon)",
		"category": "devices",
		"unlock_pops": 6000,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 2,
		"requires_device": "fan",
		"desc": "Dikey elektromanyetik kule. Çevredeki tüm düşen balonları kendi merkezine ve altındaki tuzaklara çeker.",
		"widths": ["3.8m Çekim (1.6 Güç)", "5.0m Çekim (2.6 Güç)", "6.5m Çekim (4.0 Güç)", "8.5m Çekim (6.0 Güç)", "11.0m Çekim (8.8 Güç)", "14.0m Çekim (12.5 Güç)"],
		"unit_costs": [1200, 3500, 14000, 50000, 140000, 300000],
		"unit_req_pops": [6000, 20000, 60000, 160000, 350000, 650000],
		"costs": [1800, 5000, 18000, 60000, 160000, 380000],
		"req_pops": [9000, 28000, 80000, 200000, 450000, 800000]
	},
	"electric_wall": {
		"id": "electric_wall",
		"name": "Elektrikli Izgara Bariyeri",
		"category": "devices",
		"unlock_pops": 35000,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 2,
		"requires_device": "fan",
		"desc": "Zemine sabitlenen dikey yüksek voltaj ızgarası. Vantilatör akışına dik yerleştirildiğinde içinden geçen balonları havada patlatır.",
		"widths": ["5.0m Genişlik (25 Balon)", "7.0m Genişlik (50 Balon)", "9.5m Genişlik (90 Balon)", "12.0m Genişlik (150 Balon)", "15.0m Genişlik (240 Balon)", "18.0m Genişlik (380 Balon)"],
		"unit_costs": [1500, 5000, 20000, 70000, 180000, 400000],
		"unit_req_pops": [35000, 60000, 150000, 320000, 600000, 800000],
		"costs": [2200, 7000, 25000, 85000, 220000, 480000],
		"req_pops": [40000, 80000, 180000, 420000, 700000, 900000]
	},
	"gravity_regulator": {
		"id": "gravity_regulator",
		"name": "Yerçekimi & Gaz Regülatörü (Gravity Regulator)",
		"category": "devices",
		"unlock_pops": 1000,
		"level": 0,
		"max_level": 4,
		"count": 1,
		"max_count": 1,
		"desc": "Odadaki balonların düşme hızını ve yerçekimini kontrol eder. Tablet → Tesis ekranından açılan yerçekimi modu seçilir.",
		"modes": ["0.25 G (Standart)", "0.75 G (Yoğun Akış)", "1.60 G (Hızlı Şelale)", "3.20 G (Ağır Çöküş)", "6.00 G (Hiper Yerçekimi)"],
		"costs": [1200, 15000, 90000, 280000],
		"req_pops": [2500, 30000, 180000, 550000]
	}
}

# Room Expansion Catalog (3 Ana Aşama: 0-15k Workshop, 15k-250k Facility, 250k-1M Hangar)
var rooms: Dictionary = {
	"small_room": {
		"id": "small_room",
		"name": "Başlangıç Atölyesi (Workshop)",
		"desc": "18x18m alan, 6.5m tavan. 1.0x Coin Çarpanı, 1.000 Balon Kapasitesi. (0 - 15.000 Pop aşaması).",
		"cost": 0,
		"unlock_pops": 0,
		"floor_size": Vector2(18, 18),
		"ceiling_height": 6.5,
		"capacity": 1000,
		"max_balloon_tier": 1,
		"max_devices": 4,
		"max_pipes": 2,
		"flow_mult": 1.0,
		"coin_multiplier": 1.0,
		"tier_weights": {1: 1.0, 5: 0.0, 10: 0.0, 50: 0.0}
	},
	"medium_room": {
		"id": "medium_room",
		"name": "Üretim Tesisi (Facility)",
		"desc": "26x26m alan, 7.5m tavan. 1.4x Coin Çarpanı, 4.000 Balon Kapasitesi. Otomasyon ve Pompalı aktif (15.000 - 250.000 Pop aşaması).",
		"cost": 0,
		"requires_room": "small_room",
		"unlock_pops": 15000,
		"floor_size": Vector2(26, 26),
		"ceiling_height": 7.5,
		"capacity": 4000,
		"max_balloon_tier": 5,
		"max_devices": 8,
		"max_pipes": 4,
		"flow_mult": 1.50,
		"coin_multiplier": 1.4,
		"tier_weights": {1: 0.75, 5: 0.25, 10: 0.0, 50: 0.0}
	},
	"hangar": {
		"id": "hangar",
		"name": "Mega Hangar (Hangar)",
		"desc": "42x42m dev alan, 10.5m tavan. 2.0x Coin Çarpanı, 650 fiziksel balon / 15.000 yük birimi. Büyük balon ağırlıklı üretim.",
		"cost": 0,
		"requires_room": "medium_room",
		"unlock_pops": 250000,
		"floor_size": Vector2(42, 42),
		"ceiling_height": 10.5,
		"capacity": 15000,
		"physics_budget": 650,
		"max_balloon_tier": 50,
		"max_devices": 16,
		"max_pipes": 9,
		# More tier-50 balloons reduce physical clutter. Keep weighted production
		# near its prior pace by scaling down the number spawned per second.
		"flow_mult": 0.33,
		"coin_multiplier": 2.0,
		"tier_weights": {1: 0.05, 5: 0.10, 10: 0.40, 50: 0.45}
	},
}

# Core Standard Upgrades
var upgrades: Dictionary = {
	"dart_gun": {
		"category": "upgrades", "unlock_pops": 800, "level": 0, "max_level": 5,
		"requires_upgrade": "splash_pop",
		"title": "Dart Tabancası [2]",
		"desc": "[1] İğne / [2] Dart. Uzak mesafeden balonları deler; ilk isabet yakındaki birkaç balona sekebilir. Duvarlarda durur.",
		"costs": [750, 2400, 8000, 30000, 90000], "req_pops": [800, 2500, 10000, 35000, 80000],
		"intervals": [0.24, 0.20, 0.16, 0.12, 0.08], "pierce": [2, 3, 5, 8, 12],
		"magazine_sizes": [10, 12, 14, 16, 18], "reload_seconds": [1.40, 1.30, 1.20, 1.10, 1.00],
		"ricochet_targets": [2, 3, 5, 8, 12], "ricochet_radius": [2.2, 2.6, 3.0, 3.5, 4.0], "range": 28.0
	},
	"shotgun_dart": {
		"category": "upgrades", "unlock_pops": 10000, "level": 0, "max_level": 5,
		"requires_upgrade": "dart_gun",
		"title": "Pompalı Dart [3]",
		"desc": "[3] Ağır Pompalı Dart. Tek atışta 18–36 saçma ile yakın mesafedeki devasa balon kümelerini geniş açıyla süpürür; çoklu delme gücüne sahiptir. Oda 2 ile açılır.",
		"costs": [5000, 15000, 45000, 120000, 300000], "req_pops": [10000, 20000, 40000, 75000, 150000],
		"intervals": [0.45, 0.38, 0.32, 0.26, 0.22], "pierce": [3, 4, 6, 8, 10],
		"magazine_sizes": [8, 10, 12, 16, 20], "reload_seconds": [1.40, 1.25, 1.10, 0.95, 0.80],
		"pellets": [18, 22, 26, 30, 36], "range": 14.0
	},
	"minigun_weapon": {
		"category": "upgrades", "unlock_pops": 100000, "level": 0, "max_level": 5,
		"requires_upgrade": "shotgun_dart",
		"title": "Ağır Minigun [4]",
		"desc": "[4] Kalıcı Ağır Minigun. Saniyede 26 delip geçen mermi sıkar. Oda 3 (Hangar) ile açılır.",
		"costs": [50000, 150000, 400000, 1000000, 2500000], "req_pops": [100000, 200000, 380000, 600000, 900000],
		"intervals": [0.045, 0.040, 0.035, 0.030, 0.025], "overheat_times": [2.2, 2.0, 1.8, 1.5, 1.2]
	},
	# 1. BALON AKIŞI & BORU HATTI
	"pipe_count": {
		"category": "upgrades",
		"unlock_pops": 500,
		"requires_upgrade": "vent_rate",
		"level": 0,
		"max_level": 8,
		"title": "Tavan Menfez Sayısı (Boru Hattı)",
		"desc": "Tavana ek boru hattı çeker. Her boru üretimi katlar. Oda sınırları: 2 / 4 / 9 boru.",
		"pipes": ["1 Boru (1x Akış)", "2 Boru (2x Akış)", "3 Boru (3x Akış)", "4 Boru (4x Akış)", "5 Boru (5x Akış)", "6 Boru (6x Akış)", "7 Boru (7x Akış)", "8 Boru (8x Akış)", "9 Boru (9x Matrix)"],
		"costs": [500, 2000, 8000, 25000, 80000, 250000, 800000, 2500000],
		"req_pops": [500, 4000, 25000, 350000, 500000, 650000, 800000, 950000]
	},
	"vent_rate": {
		"category": "upgrades",
		"unlock_pops": 0,
		"level": 0,
		"max_level": 12,
		"title": "Balon Dökülme Hızı",
		"desc": "Tavandan saniyede dökülen balon sayısını artırır.",
		"rates": [1.5, 2.5, 4.0, 6.0, 9.0, 14.0, 22.0, 35.0, 55.0, 85.0, 130.0, 190.0, 280.0],
		"costs": [50, 150, 400, 1200, 3500, 10000, 30000, 90000, 250000, 700000, 1800000, 4500000],
		"req_pops": [0, 50, 200, 700, 2500, 20000, 300000, 450000, 600000, 750000, 900000, 1000000]
	},

	# 2. İĞNE / OTOMASYON YETENEKLERİ
	"auto_pop": {
		"category": "upgrades",
		"unlock_pops": 50,
		"requires_upgrade": "athlete_training",
		"level": 0,
		"max_level": 8,
		"title": "Auto-Pop & Makro İğne",
		"desc": "Sol tıka basılı tutarak veya [Z] tuşuyla elinizi değmeden otomatik iğne makrosunu açar ve hızlandırır. Seviye arttıkça enerji tüketimi sıfıra iner!",
		"speeds": ["Kapalı", "5.0/sn", "8.3/sn", "13.3/sn", "22.2/sn", "35.7/sn", "55.5/sn", "83.3/sn", "125.0/sn"],
		"costs": [180, 800, 2800, 11000, 48000, 190000, 600000, 1800000],
		"req_pops": [50, 400, 2000, 7000, 28000, 95000, 280000, 750000]
	},
	"splash_pop": {
		"category": "upgrades",
		"unlock_pops": 200,
		"requires_upgrade": "auto_pop",
		"level": 0,
		"max_level": 7,
		"title": "İğne: Alan Patlatma (Splash)",
		"desc": "İğneye özeldir (Dart etkilenmez). Vurulan balonun etrafındaki aynı renkteki komşu balonları zincirleme patlatır.",
		"targets": ["Kapalı", "2 Balon (1.8m)", "3 Balon (2.4m)", "5 Balon (3.0m)", "8 Balon (3.8m)", "12 Balon (4.6m)", "18 Balon (5.5m)", "25 Balon (6.8m)"],
		"costs": [500, 1600, 5500, 24000, 95000, 360000, 1200000],
		"req_pops": [200, 1000, 3500, 13000, 48000, 160000, 500000]
	},

	# 3. KARAKTER KONDİSYONU & ÇEVİKLİK
	"athlete_training": {
		"category": "upgrades",
		"unlock_pops": 25,
		"level": 0,
		"max_level": 8,
		"title": "Kondisyon & Çeviklik",
		"desc": "Maksimum dayanıklılığı, enerji dolum hızını ve yürüme/koşma çevikliğini artırır.",
		"costs": [250, 650, 1400, 4000, 14000, 52000, 180000, 550000],
		"req_pops": [25, 100, 400, 1500, 5200, 20000, 80000, 250000]
	},

	# 4. SİKKE MIKNATISI
	"coin_magnet": {
		"category": "upgrades",
		"unlock_pops": 100,
		"requires_upgrade": "athlete_training",
		"level": 0,
		"max_level": 8,
		"title": "Coin Mıknatısı (Vakum Menfezi)",
		"desc": "Yerdeki altın, gümüş ve kristalleri oyuncunun etrafında otomatik olarak çeker.",
		"costs": [300, 750, 1800, 7000, 28000, 110000, 400000, 1200000],
		"req_pops": [100, 400, 1500, 5200, 20000, 80000, 250000, 650000]
	},

	# 5. OYUNCU YOLDAŞI: NÖBETÇİ AVCI DRON
	"companion_drone": {
		"category": "upgrades",
		"unlock_pops": 15000,
		"requires_upgrade": "auto_pop",
		"level": 0,
		"max_level": 6,
		"title": "Nöbetçi İğne Dronu (Companion Drone)",
		"desc": "Karakterin yanında uçar. Mekanik iğne koluyla en öncelikli (Bomba, Altın, Kroma vb.) balonları seri ve tek tek hedef alıp patlatır.",
		"costs": [1500, 5000, 20000, 75000, 220000, 600000],
		"req_pops": [15000, 35000, 90000, 220000, 480000, 850000]
	}
}

func add_coins(amount: int = 1) -> void:
	var mult = 1.0 + (prestige_level * 1.0)
	coins += int(amount * mult)
	coins_changed.emit(coins)

func get_test_coin_multiplier() -> int:
	var gm = get_node_or_null("../GameManager")
	return maxi(1, int(gm.turbo_coin_multiplier)) if gm and gm.turbo_mode_enabled else 1

func get_spendable_coin_balance() -> int:
	return coins * get_test_coin_multiplier()

func can_afford(cost: int) -> bool:
	return get_spendable_coin_balance() >= cost

func spend_coins(cost: int) -> bool:
	if not can_afford(cost): return false
	var multiplier := get_test_coin_multiplier()
	coins -= ceili(float(cost) / float(multiplier))
	coins_changed.emit(coins)
	return true

func is_unlocked(upgrade_id: String, total_pops: int) -> bool:
	if not upgrades.has(upgrade_id):
		return false
	return total_pops >= upgrades[upgrade_id]["unlock_pops"]

func _market_item_name(kind: String, item_id: String) -> String:
	match kind:
		"upgrade":
			return str(upgrades.get(item_id, {}).get("title", item_id))
		"device":
			return str(devices.get(item_id, {}).get("name", item_id))
		"room":
			return str(rooms.get(item_id, {}).get("name", item_id))
	return item_id

func get_upgrade_prerequisite_message(upgrade_id: String) -> String:
	if not upgrades.has(upgrade_id): return ""
	var data: Dictionary = upgrades[upgrade_id]
	if int(data.get("level", 0)) > 0: return ""
	var required_id := str(data.get("requires_upgrade", ""))
	if required_id == "" or int(upgrades.get(required_id, {}).get("level", 0)) > 0: return ""
	return "Önce %s satın al" % _market_item_name("upgrade", required_id)

func get_device_prerequisite_message(device_id: String) -> String:
	if not devices.has(device_id): return ""
	var data: Dictionary = devices[device_id]
	if int(data.get("count", 0)) > 0: return ""
	var required_id := str(data.get("requires_device", ""))
	if required_id == "" or int(devices.get(required_id, {}).get("count", 0)) > 0: return ""
	return "Önce %s cihazını satın al" % _market_item_name("device", required_id)

func get_room_prerequisite_message(room_id: String) -> String:
	if not rooms.has(room_id) or is_room_unlocked(room_id): return ""
	var required_id := str(rooms[room_id].get("requires_room", ""))
	if required_id == "" or is_room_unlocked(required_id): return ""
	return "Önce %s odasını aç" % _market_item_name("room", required_id)

func get_upgrade_req_pops(upgrade_id: String, target_lvl: int) -> int:
	if not upgrades.has(upgrade_id): return 0
	var up = upgrades[upgrade_id]
	if up.has("req_pops"):
		var arr = up["req_pops"]
		return arr[clamp(target_lvl, 0, arr.size() - 1)]
	return up.get("unlock_pops", 0)

func get_device_unit_req_pops(device_id: String, target_count: int) -> int:
	if not devices.has(device_id): return 0
	var d = devices[device_id]
	if d.has("unit_req_pops"):
		var arr = d["unit_req_pops"]
		return arr[clamp(target_count, 0, arr.size() - 1)]
	return d.get("unlock_pops", 0)

func get_device_tech_req_pops(device_id: String, target_lvl: int) -> int:
	if not devices.has(device_id): return 0
	var d = devices[device_id]
	if d.has("req_pops"):
		var arr = d["req_pops"]
		return arr[clamp(target_lvl if device_id == "gravity_regulator" else target_lvl - 1, 0, arr.size() - 1)]
	return d.get("unlock_pops", 0)

func get_pipe_limit() -> int:
	return int(get_current_room_data().get("max_pipes", 2))

func get_upgrade_room_cap(upgrade_id: String, room_id: String = "") -> int:
	var target_room := room_id if room_id != "" else current_room
	if upgrade_id == "pipe_count":
		# pipe_count level 0 means 1 pipe, level 1 means 2 pipes, so max level = max_pipes - 1
		var r_data = rooms.get(target_room, rooms["small_room"])
		return maxi(0, int(r_data.get("max_pipes", 2)) - 1)
		
	var caps = {
		"small_room": {
			"athlete_training": 4,
			"auto_pop": 3,
			"splash_pop": 3,
			"dart_gun": 2,
			"shotgun_dart": 0,
			"minigun_weapon": 0,
			"coin_magnet": 3,
			"vent_rate": 5,
			"companion_drone": 0
		},
		"medium_room": {
			"athlete_training": 6,
			"auto_pop": 5,
			"splash_pop": 5,
			"dart_gun": 4,
			"shotgun_dart": 3,
			"minigun_weapon": 0,
			"coin_magnet": 5,
			"vent_rate": 6,
			"companion_drone": 2
		},
		"hangar": {
			"athlete_training": 8,
			"auto_pop": 7,
			"splash_pop": 7,
			"dart_gun": 5,
			"shotgun_dart": 5,
			"minigun_weapon": 3,
			"coin_magnet": 7,
			"vent_rate": 8,
			"companion_drone": 4
		},
	}
	var room_dict: Dictionary = caps.get(target_room, {})
	var default_max = upgrades.get(upgrade_id, {}).get("max_level", 99)
	return int(room_dict.get(upgrade_id, default_max))

func get_active_pipe_count() -> int:
	return clampi(1 + int(upgrades.pipe_count.level), 1, get_pipe_limit())

func get_room_purchase_cost_multiplier(room_id: String = "") -> float:
	var target_room := room_id if room_id != "" else current_room
	return {"small_room": 1.0, "medium_room": 1.5, "hangar": 1.9}.get(target_room, 1.0)

func get_scaled_purchase_cost(base_cost: int, room_id: String = "") -> int:
	return maxi(base_cost, int(round(float(base_cost) * get_room_purchase_cost_multiplier(room_id))))

func get_upgrade_cost(upgrade_id: String, level: int = -1) -> int:
	if not upgrades.has(upgrade_id): return 0
	var data: Dictionary = upgrades[upgrade_id]
	var cost_level := int(data.level) if level < 0 else level
	var costs: Array = data.get("costs", [])
	if cost_level < 0 or cost_level >= costs.size(): return 0
	return get_scaled_purchase_cost(int(costs[cost_level]))

func get_device_unit_cost(device_id: String, count: int = -1) -> int:
	if not devices.has(device_id): return 0
	var data: Dictionary = devices[device_id]
	var unit_count := int(data.get("count", 0)) if count < 0 else count
	var costs: Array = data.get("unit_costs", data.get("costs", []))
	if unit_count < 0 or unit_count >= costs.size(): return 0
	return get_scaled_purchase_cost(int(costs[unit_count]))

func get_device_tech_cost(device_id: String, level: int = -1) -> int:
	if not devices.has(device_id): return 0
	var data: Dictionary = devices[device_id]
	var current_level := int(data.get("level", 0)) if level < 0 else level
	var tech_level := current_level if device_id == "gravity_regulator" else maxi(0, current_level - 1)
	var costs: Array = data.get("costs", [])
	if tech_level < 0 or tech_level >= costs.size(): return 0
	return get_scaled_purchase_cost(int(costs[tech_level]))

func buy_upgrade(upgrade_id: String, total_pops: int = 999999) -> bool:
	if not upgrades.has(upgrade_id):
		purchase_failed.emit("Bilinmeyen yükseltme")
		return false
		
	var up = upgrades[upgrade_id]
	var prerequisite := get_upgrade_prerequisite_message(upgrade_id)
	if prerequisite != "":
		purchase_failed.emit(prerequisite)
		return false
	var room_cap := get_upgrade_room_cap(upgrade_id)
	if int(up["level"]) >= room_cap:
		purchase_failed.emit("Maksimum seviyeye ulaşıldı (Sv. %d)." % room_cap if current_room == "hangar" else "Bu odada bu seviyeye ulaşılamaz (Oda sınırı: Sv. %d). Sonraki odaya geç." % room_cap)
		return false

	var needed_pops = get_upgrade_req_pops(upgrade_id, up["level"])
	if total_pops < needed_pops:
		purchase_failed.emit("Kilitli! " + str(needed_pops) + " balon patlatılması gerekiyor.")
		return false
		
	if up["level"] >= up["max_level"]:
		purchase_failed.emit("Maksimum seviyeye ulaşıldı")
		return false
		
	var cost = get_upgrade_cost(upgrade_id, int(up["level"]))
	if not can_afford(cost):
		purchase_failed.emit("Yetersiz Coin!")
		return false
	spend_coins(cost)
	up["level"] += 1
	upgrade_purchased.emit(upgrade_id, up["level"])
	
	var gm = get_node_or_null("../GameManager")
	if gm and gm.has_method("log_timeline_event"):
		gm.log_timeline_event("upgrade", upgrade_id, up.get("title", upgrade_id), up["level"], cost)
		
	return true

func is_room_unlocked(room_id: String) -> bool:
	return unlocked_rooms.has(room_id)

func buy_room(room_id: String, total_pops: int = 999999) -> bool:
	if not rooms.has(room_id):
		purchase_failed.emit("Bilinmeyen oda")
		return false
		
	if room_id == current_room: return true
	if pending_room != "":
		if pending_room == room_id: return true
		purchase_failed.emit("Önce ortadaki portaldan bekleyen odaya geç.")
		return false
	var r_data = rooms[room_id]
	var prerequisite := get_room_prerequisite_message(room_id)
	if prerequisite != "":
		purchase_failed.emit(prerequisite)
		return false
	if is_room_unlocked(room_id):
		pending_room = room_id
		room_transfer_requested.emit(room_id)
		return true
		
	var required_pops := int(r_data.get("unlock_pops", 0))
	if total_pops < required_pops:
		purchase_failed.emit("Kilitli! " + str(required_pops) + " balon patlatılması gerekiyor.")
		return false
	return _unlock_room_for_progress(room_id)

func check_room_progression(total_pops: int) -> void:
	if pending_room != "": return
	var room_order: Array[String] = ["small_room", "medium_room", "hangar"]
	var current_index := room_order.find(current_room)
	if current_index < 0 or current_index + 1 >= room_order.size(): return
	var next_room := room_order[current_index + 1]
	if total_pops < int(rooms[next_room].get("unlock_pops", 0)): return
	_unlock_room_for_progress(next_room)

func _unlock_room_for_progress(room_id: String) -> bool:
	if not rooms.has(room_id) or pending_room != "": return false
	if room_id == current_room: return true
	if not unlocked_rooms.has(room_id):
		unlocked_rooms.append(room_id)
	pending_room = room_id
	room_unlocked.emit(room_id)
	room_transfer_requested.emit(room_id)
	var gm = get_node_or_null("../GameManager")
	if gm and gm.has_method("log_timeline_event"):
		gm.log_timeline_event("room", room_id, rooms[room_id].get("name", room_id), 1, 0)
	return true

func switch_to_room(room_id: String) -> bool:
	if not rooms.has(room_id) or not is_room_unlocked(room_id):
		return false
	current_room = room_id
	room_switched.emit(room_id)
	return true

func get_current_room_data() -> Dictionary:
	return rooms.get(current_room, rooms["small_room"])

func get_total_placed_devices() -> int:
	var total = 0
	for d_id in devices:
		if d_id != "gravity_regulator":
			total += devices[d_id].get("count", 0)
	return total

func get_current_room_max_devices() -> int:
	var r = rooms.get(current_room, rooms["small_room"])
	return r.get("max_devices", 4)

func automation_available() -> bool:
	return true

func device_count_limit() -> int:
	return {"small_room": 2, "medium_room": 4, "hangar": 8}.get(current_room, 2)

func device_level_limit() -> int:
	return {"small_room": 2, "medium_room": 4, "hangar": 6}.get(current_room, 2)

func buy_device_unit(device_id: String, total_pops: int = 999999) -> bool:
	if device_id != "gravity_regulator" and not automation_available():
		purchase_failed.emit("Otomasyon Üretim Tesisi'nde açılır.")
		return false
	if not devices.has(device_id):
		purchase_failed.emit("Bilinmeyen cihaz")
		return false
		
	var d_data = devices[device_id]
	var cur_count = d_data.get("count", 0)
	var prerequisite := get_device_prerequisite_message(device_id)
	if prerequisite != "":
		purchase_failed.emit(prerequisite)
		return false
	var max_count = mini(int(d_data.get("max_count", 6)), device_count_limit())
	if cur_count >= max_count:
		purchase_failed.emit("Maksimum cihaz adedine (" + str(max_count) + "/" + str(max_count) + ") ulaşıldı!")
		return false
		
	if device_id != "gravity_regulator":
		var total_placed = get_total_placed_devices()
		var max_room_devs = get_current_room_max_devices()
		if total_placed >= max_room_devs:
			purchase_failed.emit("Oda cihaz kapasitesi dolu (" + str(total_placed) + "/" + str(max_room_devs) + ")! Daha büyük bir odaya geçin.")
			return false
		
	var needed_pops = get_device_unit_req_pops(device_id, cur_count)
	if total_pops < needed_pops:
		purchase_failed.emit("Kilitli! " + str(needed_pops) + " balon patlatılması gerekiyor.")
		return false
		
	var cost = get_device_unit_cost(device_id, cur_count)
	if not can_afford(cost):
		purchase_failed.emit("Yetersiz Coin! (" + str(cost) + " Coin gerekli)")
		return false
	spend_coins(cost)
	d_data["count"] = cur_count + 1
	if d_data["level"] == 0:
		d_data["level"] = 1
	device_unit_purchased.emit(device_id, d_data["count"], 1)
	
	var gm = get_node_or_null("../GameManager")
	if gm and gm.has_method("log_timeline_event"):
		gm.log_timeline_event("device_unit", device_id, d_data.get("name", device_id), d_data["count"], cost)
		
	return true

func buy_device_upgrade(device_id: String, total_pops: int = 999999) -> bool:
	if not devices.has(device_id):
		purchase_failed.emit("Bilinmeyen cihaz")
		return false
		
	if device_id != "gravity_regulator":
		purchase_failed.emit("Her cihaz ayrı yükseltilir. Kurulu cihaza bakıp [F] tuşuna bas.")
		return false
	var d_data = devices[device_id]
	if device_id != "gravity_regulator" and (not automation_available() or int(d_data.level) < 1 or int(d_data.level) >= device_level_limit()):
		purchase_failed.emit("Önce cihazı satın al veya sonraki odaya geç.")
		return false
	if d_data["level"] >= d_data["max_level"]:
		purchase_failed.emit("Cihaz teknolojisi maksimum seviyeye ulaştı!")
		return false
		
	var needed_pops = get_device_tech_req_pops(device_id, d_data["level"])
	if total_pops < needed_pops:
		purchase_failed.emit("Kilitli! " + str(needed_pops) + " balon patlatılması gerekiyor.")
		return false
		
	var cost = get_device_tech_cost(device_id, int(d_data["level"]))
	if not can_afford(cost):
		purchase_failed.emit("Yetersiz Coin! (" + str(cost) + " Coin gerekli)")
		return false
	spend_coins(cost)
	d_data["level"] += 1
	device_purchased.emit(device_id, d_data["level"])
	
	var gm = get_node_or_null("../GameManager")
	if gm and gm.has_method("log_timeline_event"):
		gm.log_timeline_event("device_tech", device_id, d_data.get("name", device_id), d_data["level"], cost)
		
	return true

func buy_device(device_id: String, total_pops: int = 999999) -> bool:
	# Placeable purchases always order a new level-one unit.
	if not devices.has(device_id):
		return false
	var d_data = devices[device_id]
	if device_id != "gravity_regulator" or d_data.get("count", 0) == 0:
		return buy_device_unit(device_id, total_pops)
	else:
		return buy_device_upgrade(device_id, total_pops)

func perform_prestige(total_pops: int) -> int:
	var helium_earned = max(1, int(total_pops / 100000))
	helium_atoms += helium_earned
	prestige_level += 1
	
	# Reset progress for new rebirth
	coins = 0
	current_room = "small_room"
	unlocked_rooms = ["small_room"]
	
	for u_id in upgrades.keys():
		upgrades[u_id]["level"] = 0
		upgrade_purchased.emit(u_id, 0)
		
	for d_id in devices.keys():
		devices[d_id]["level"] = 0
		device_purchased.emit(d_id, 0)
		
	coins_changed.emit(coins)
	room_switched.emit("small_room")
	prestige_performed.emit(prestige_level, helium_earned)
	return helium_earned

func upgrade_value(id: String, level: int) -> String:
	match id:
		"vent_rate":
			var multiplier: float = get_active_pipe_count() * float(get_current_room_data().get("flow_mult", 1.0)) * (1 + prestige_level * 0.5)
			return "%.2f balon/sn" % (float(upgrades.vent_rate.rates[level]) * multiplier)
		"pipe_count": return "%d / %d boru" % [mini(level + 1, get_pipe_limit()), get_pipe_limit()]
		"dart_gun":
			if level == 0: return "Kilitli • [2] ile kuşan"
			return "%.1f atış/sn • %d delme + %d sekme (Sonsuz Cephane)" % [1.0 / float(upgrades.dart_gun.intervals[level - 1]), upgrades.dart_gun.pierce[level - 1], upgrades.dart_gun.ricochet_targets[level - 1]]
		"auto_pop": return upgrades.auto_pop.speeds[level]
		"splash_pop": return upgrades.splash_pop.targets[level]
		"athlete_training": return "%d enerji / %.1f m/sn" % [100 + level * 25, 5.2 + level * 0.35]
		"coin_magnet": return "Kapalı" if level == 0 else "%.1f m çekim" % [3.5, 5.5, 8.0, 12.0, 17.0, 24.0, 32.0, 45.0][level - 1]
		"gravity_regulator": return "%.2f G" % [0.25, 0.75, 1.6, 3.2, 6.0][level]
	return ""

func upgrade_preview(id: String) -> String:
	var data: Dictionary = devices[id] if devices.has(id) else upgrades.get(id, {})
	if data.is_empty(): return ""
	var level: int = data.level
	var current := upgrade_value(id, level)
	return current if level >= int(data.max_level) or (id == "pipe_count" and level + 1 >= get_pipe_limit()) else current + "\n→ " + upgrade_value(id, level + 1)

var _device_preview_cache: Dictionary = {}

func device_output_preview(device_id: String, level: int) -> String:
	var key := "%s:%d" % [device_id, level]
	if _device_preview_cache.has(key): return _device_preview_cache[key]
	var script_path := "res://src/devices/%s.gd" % device_id
	if not ResourceLoader.exists(script_path): return ""
	var device = load(script_path).new()
	var idx := clampi(level, 1, 6)
	var result := ""
	if "batch_capacities" in device:
		result = "%d balon / %.2f sn • teorik %.1f/sn" % [device.batch_capacities[idx], device.cooldown_intervals[idx], float(device.batch_capacities[idx]) / device.cooldown_intervals[idx]]
	elif "max_burst_caps" in device:
		result = "%d balon / %.2f sn • teorik %.1f/sn" % [device.max_burst_caps[idx], device.cooldown_intervals[idx], float(device.max_burst_caps[idx]) / device.cooldown_intervals[idx]]
	elif "wind_range" in device: result = "%.1f m ileri üfleme • patlatmaz" % device.ranges[idx]
	elif "pull_ranges" in device: result = "%.1f m çekim • patlatmaz" % device.pull_ranges[idx]
	device.free()
	_device_preview_cache[key] = result
	return result
