extends Node

signal coins_changed(total_coins: int)
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal room_unlocked(room_id: String)
signal room_switched(room_id: String)
signal device_purchased(device_id: String, new_level: int)
signal device_unit_purchased(device_id: String, new_count: int, level: int)
signal purchase_failed(reason: String)
signal prestige_performed(new_prestige_level: int, helium_earned: int)

var coins: int = 0
var current_room: String = "small_room"
var unlocked_rooms: Array = ["small_room"]
var prestige_level: int = 0
var helium_atoms: int = 0

# Devices & Automation Equipment Catalog
var devices: Dictionary = {
	"fan": {
		"id": "fan",
		"name": "Endüstriyel Hava Türbini (Industrial Turbine)",
		"category": "devices",
		"unlock_pops": 18000,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 6,
		"desc": "Duvara monte dev hava türbini. Geniş tesislerde balonları karşıdaki tuzaklara ve pylonlara doğru savurur.",
		"widths": ["12.0m Menzil (5.5 Güç)", "16.0m Menzil (7.5 Güç)", "22.0m Menzil (10.0 Güç)", "28.0m Menzil (13.5 Güç)", "36.0m Menzil (18.0 Güç)", "45.0m Menzil (24.0 Güç)"],
		"unit_costs": [1500, 5000, 18000, 60000, 150000, 350000],
		"unit_req_pops": [18000, 45000, 120000, 280000, 550000, 750000],
		"costs": [2500, 7500, 25000, 85000, 200000, 450000],
		"req_pops": [22000, 55000, 150000, 350000, 600000, 800000]
	},
	"spike_wall": {
		"id": "spike_wall",
		"name": "Dikenli Zemin Tuzağı (Floor Spikes)",
		"category": "devices",
		"unlock_pops": 300,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 6,
		"desc": "Zemine serilen sivri çelik iğneler. Seviye atladıkça fiziksel alanı büyür ve daha seri darbeler vurur.",
		"widths": ["2.4m Alan | 0.90s (5 Balon)", "3.0m Alan | 0.70s (10 Balon)", "3.8m Alan | 0.55s (18 Balon)", "4.6m Alan | 0.42s (30 Balon)", "5.6m Alan | 0.32s (50 Balon)", "6.8m Alan | 0.22s (85 Balon)"],
		"unit_costs": [400, 1500, 6000, 22000, 70000, 180000],
		"unit_req_pops": [300, 1500, 7000, 30000, 100000, 300000],
		"costs": [800, 2500, 9000, 32000, 110000, 300000],
		"req_pops": [450, 2000, 8500, 35000, 120000, 350000]
	},
	"electric_wall": {
		"id": "electric_wall",
		"name": "Elektrikli Zemin Izgarası (Electric Floor Grid)",
		"category": "devices",
		"unlock_pops": 20000,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 6,
		"desc": "Yüksek voltajlı kondansatör ızgarası. Şarj olduğunda havadaki ve yerdeki balonlara devasa yıldırım EMP patlaması yapar.",
		"widths": ["2.5s Şarj (16 Balon)", "2.0s Şarj (28 Balon)", "1.6s Şarj (45 Balon)", "1.25s Şarj (70 Balon)", "0.95s Şarj (105 Balon)", "0.70s Şarj (150 Balon)"],
		"unit_costs": [1200, 4500, 18000, 60000, 150000, 350000],
		"unit_req_pops": [20000, 45000, 120000, 280000, 550000, 750000],
		"costs": [2000, 6500, 22000, 80000, 200000, 450000],
		"req_pops": [25000, 60000, 160000, 400000, 650000, 850000]
	},
	"magnet_pylon": {
		"id": "magnet_pylon",
		"name": "Manyetik Çekim Kulesi (Magnet Pylon)",
		"category": "devices",
		"unlock_pops": 15000,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 6,
		"desc": "Dikey elektromanyetik kule. Çevredeki düşen balonları kendi merkezine ve altındaki tuzaklara çeker.",
		"widths": ["3.5m Çekim", "4.5m Çekim", "5.8m Çekim", "7.2m Çekim", "8.8m Çekim", "10.5m Çekim"],
		"unit_costs": [1000, 3000, 12000, 45000, 120000, 280000],
		"unit_req_pops": [15000, 35000, 90000, 220000, 500000, 750000],
		"costs": [1500, 4500, 15000, 55000, 150000, 350000],
		"req_pops": [20000, 50000, 140000, 350000, 600000, 800000]
	},
	"gravity_regulator": {
		"id": "gravity_regulator",
		"name": "Yerçekimi & Gaz Regülatörü (Gravity Regulator)",
		"category": "devices",
		"unlock_pops": 500,
		"level": 0,
		"max_level": 4,
		"count": 1,
		"max_count": 1,
		"desc": "Odadaki balonların düşme hızını ve yerçekimini kontrol eder. Duvardaki [E] butonundan veya [G] tuşundan kontrol edilir.",
		"modes": ["0.25 G (Standart)", "0.80 G (Ağır Döküm)", "1.80 G (Hızlı Şelale)", "3.50 G (Ağır Çöküş)", "6.00 G (Hiper Yerçekimi)"],
		"costs": [400, 1800, 8500, 35000],
		"req_pops": [500, 4000, 25000, 150000]
	},
	"conveyor_crusher": {
		"id": "conveyor_crusher",
		"name": "Makaralı Balon Öğütücü (Conveyor Crusher)",
		"category": "devices",
		"unlock_pops": 25000,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 6,
		"desc": "Zemine konulan çift silindirli döner çelik öğütücü. Yakındaki balonları vakumlayıp silindirlerde kıyma yapar.",
		"widths": ["1.4s Soğuma (12 Balon)", "1.1s Soğuma (20 Balon)", "0.85s Soğuma (32 Balon)", "0.65s Soğuma (50 Balon)", "0.48s Soğuma (75 Balon)", "0.35s Soğuma (110 Balon)"],
		"unit_costs": [1500, 6000, 25000, 75000, 180000, 400000],
		"unit_req_pops": [25000, 60000, 150000, 350000, 600000, 800000],
		"costs": [3000, 9500, 32000, 110000, 250000, 500000],
		"req_pops": [30000, 80000, 200000, 450000, 700000, 850000]
	},
	"sentry_drone": {
		"id": "sentry_drone",
		"name": "Uçan Lazer Dronu (Sentry Drone)",
		"category": "devices",
		"unlock_pops": 120000,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 6,
		"desc": "Oyuncunun yanında süzülen güvenlik dronu. Havadaki balonları lazerle otomatik vurur.",
		"widths": ["1.4s (1x Hedef)", "1.1s (2x Hedef)", "0.85s (3x Hedef)", "0.65s (4x Hedef)", "0.50s (6x Hedef)", "0.38s (8x Hedef)"],
		"unit_costs": [25000, 45000, 80000, 150000, 220000, 350000],
		"unit_req_pops": [120000, 180000, 280000, 500000, 650000, 800000],
		"costs": [5000, 16000, 45000, 100000, 200000, 400000],
		"req_pops": [150000, 250000, 400000, 600000, 750000, 880000]
	}
}

# Room Expansion Catalog (4 Distinct, Impactful Progression Stages)
var rooms: Dictionary = {
	"small_room": {
		"id": "small_room",
		"name": "Başlangıç Atölyesi (Workshop)",
		"desc": "18x18m alan, 6.5m tavan. 1.0x Coin Çarpanı, 600 Balon Kapasitesi.",
		"cost": 0,
		"unlock_pops": 0,
		"floor_size": Vector2(18, 18),
		"ceiling_height": 6.5,
		"capacity": 600,
		"flow_mult": 1.0,
		"coin_multiplier": 1.0,
		"tier_weights": {1: 0.90, 5: 0.10, 10: 0.0, 50: 0.0}
	},
	"medium_room": {
		"id": "medium_room",
		"name": "Üretim Tesisi (Facility)",
		"desc": "38x38m alan, 8.5m tavan. 1.5x Coin Çarpanı, 2.500 Balon Kapasitesi.",
		"cost": 12000,
		"unlock_pops": 15000,
		"floor_size": Vector2(38, 38),
		"ceiling_height": 8.5,
		"capacity": 2500,
		"flow_mult": 1.4,
		"coin_multiplier": 1.5,
		"tier_weights": {1: 0.55, 5: 0.30, 10: 0.12, 50: 0.03}
	},
	"hangar": {
		"id": "hangar",
		"name": "Mega Hangar (Hangar)",
		"desc": "65x65m dev alan, 13m tavan. 2.5x Coin Çarpanı, 9.000 Balon Kapasitesi.",
		"cost": 150000,
		"unlock_pops": 120000,
		"floor_size": Vector2(65, 65),
		"ceiling_height": 13.0,
		"capacity": 9000,
		"flow_mult": 2.2,
		"coin_multiplier": 2.5,
		"tier_weights": {1: 0.30, 5: 0.35, 10: 0.25, 50: 0.10}
	},
	"hyper_lab": {
		"id": "hyper_lab",
		"name": "Siber Laboratuvar (Hyper Lab)",
		"desc": "95x95m siber tesis, 18m tavan. 4.5x Hiper Çarpan, 35.000 Balon Kapasitesi.",
		"cost": 550000,
		"unlock_pops": 450000,
		"floor_size": Vector2(95, 95),
		"ceiling_height": 18.0,
		"capacity": 35000,
		"flow_mult": 3.5,
		"coin_multiplier": 4.5,
		"tier_weights": {1: 0.10, 5: 0.30, 10: 0.35, 50: 0.25}
	}
}

# Core Standard Upgrades
var upgrades: Dictionary = {
	# 1. BALON AKIŞI & BORU HATTI
	"pipe_count": {
		"category": "upgrades",
		"unlock_pops": 50,
		"level": 0,
		"max_level": 8,
		"title": "Tavan Menfez Sayısı (Boru Hattı)",
		"desc": "Tavana ek boru hattı çeker. Her yeni boru toplam dökülme akışını katlar (1x ➔ 9x)!",
		"pipes": ["1 Boru (1x Akış)", "2 Boru (2x Akış)", "3 Boru (3x Akış)", "4 Boru (4x Akış)", "5 Boru (5x Akış)", "6 Boru (6x Akış)", "7 Boru (7x Akış)", "8 Boru (8x Akış)", "9 Boru (9x Matrix)"],
		"costs": [120, 600, 3500, 18000, 75000, 250000, 650000, 1250000],
		"req_pops": [50, 1500, 15000, 50000, 120000, 300000, 550000, 800000]
	},
	"vent_rate": {
		"category": "upgrades",
		"unlock_pops": 0,
		"level": 0,
		"max_level": 12,
		"title": "Balon Dökülme Hızı",
		"desc": "Tavandan saniyede dökülen balon sayısını artırır.",
		"rates": [1, 2, 3.5, 6, 10, 16, 26, 42, 70, 110, 180, 280, 450],
		"costs": [10, 25, 60, 150, 400, 1200, 3500, 10000, 30000, 80000, 150000, 300000],
		"req_pops": [0, 20, 100, 350, 1200, 4000, 12000, 35000, 100000, 250000, 500000, 750000]
	},

	# 2. İĞNE / OTOMASYON YETENEKLERİ
	"auto_pop": {
		"category": "upgrades",
		"unlock_pops": 50,
		"level": 0,
		"max_level": 8,
		"title": "Auto-Pop & Makro İğne",
		"desc": "Sol tıka basılı tutarak veya [Z] tuşuyla elinizi değmeden otomatik iğne makrosunu açar ve hızlandırır. Seviye arttıkça enerji tüketimi sıfıra iner!",
		"speeds": ["Kapalı", "5.0/sn", "8.3/sn", "13.3/sn", "22.2/sn", "35.7/sn", "55.5/sn", "83.3/sn", "125.0/sn"],
		"costs": [50, 180, 600, 2200, 8000, 25000, 80000, 220000],
		"req_pops": [50, 300, 1500, 6000, 25000, 100000, 300000, 700000]
	},
	"splash_pop": {
		"category": "upgrades",
		"unlock_pops": 200,
		"level": 0,
		"max_level": 7,
		"title": "Splash / Alan Patlatma",
		"desc": "İğneyle vurulan balonun çevresinde AYNI RENKTEKİ komşu balonları zincirleme patlatır.",
		"targets": ["Kapalı", "2 Balon (1.8m)", "3 Balon (2.4m)", "5 Balon (3.0m)", "8 Balon (3.8m)", "12 Balon (4.6m)", "18 Balon (5.5m)", "25 Balon (6.8m)"],
		"costs": [100, 350, 1200, 4500, 16000, 60000, 180000],
		"req_pops": [200, 1000, 5000, 25000, 120000, 400000, 750000]
	},

	# 3. KARAKTER KONDİSYONU & ÇEVİKLİK
	"athlete_training": {
		"category": "upgrades",
		"unlock_pops": 25,
		"level": 0,
		"max_level": 8,
		"title": "Kondisyon & Çeviklik",
		"desc": "Maksimum dayanıklılığı, enerji dolum hızını ve yürüme/koşma çevikliğini artırır.",
		"costs": [30, 90, 260, 800, 2500, 8000, 25000, 75000],
		"req_pops": [25, 120, 500, 2000, 8000, 30000, 100000, 300000]
	},

	# 4. SİKKE MIKNATISI
	"coin_magnet": {
		"category": "upgrades",
		"unlock_pops": 100,
		"level": 0,
		"max_level": 8,
		"title": "Coin Mıknatısı (Vakum Menfezi)",
		"desc": "Yerdeki altın, gümüş ve kristalleri oyuncunun etrafında otomatik olarak çeker.",
		"costs": [80, 250, 800, 2500, 8000, 25000, 80000, 220000],
		"req_pops": [100, 500, 2000, 8000, 30000, 120000, 400000, 750000]
	}
}

func add_coins(amount: int = 1) -> void:
	var mult = 1.0 + (prestige_level * 1.0)
	coins += int(amount * mult)
	coins_changed.emit(coins)

func is_unlocked(upgrade_id: String, total_pops: int) -> bool:
	if not upgrades.has(upgrade_id):
		return false
	return total_pops >= upgrades[upgrade_id]["unlock_pops"]

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
		return arr[clamp(target_lvl, 0, arr.size() - 1)]
	return d.get("unlock_pops", 0)

func buy_upgrade(upgrade_id: String, total_pops: int = 999999) -> bool:
	if not upgrades.has(upgrade_id):
		purchase_failed.emit("Bilinmeyen yükseltme")
		return false
		
	var up = upgrades[upgrade_id]
	var needed_pops = get_upgrade_req_pops(upgrade_id, up["level"])
	if total_pops < needed_pops:
		purchase_failed.emit("Kilitli! " + str(needed_pops) + " patlatma gerekiyor.")
		return false
		
	if up["level"] >= up["max_level"]:
		purchase_failed.emit("Maksimum seviyeye ulaşıldı")
		return false
		
	var cost = up["costs"][up["level"]]
	if coins < cost:
		purchase_failed.emit("Yetersiz Coin!")
		return false
		
	coins -= cost
	up["level"] += 1
	coins_changed.emit(coins)
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
		
	var r_data = rooms[room_id]
	if is_room_unlocked(room_id):
		switch_to_room(room_id)
		return true
		
	if total_pops < r_data["unlock_pops"]:
		purchase_failed.emit("Kilitli! " + str(r_data["unlock_pops"]) + " patlatma gerekiyor.")
		return false
		
	var cost = r_data["cost"]
	if coins < cost:
		purchase_failed.emit("Yetersiz Coin! (" + str(cost) + " Coin gerekli)")
		return false
		
	coins -= cost
	unlocked_rooms.append(room_id)
	current_room = room_id
	coins_changed.emit(coins)
	room_unlocked.emit(room_id)
	room_switched.emit(room_id)
	
	var gm = get_node_or_null("../GameManager")
	if gm and gm.has_method("log_timeline_event"):
		gm.log_timeline_event("room", room_id, r_data.get("name", room_id), 1, cost)
		
	return true

func switch_to_room(room_id: String) -> bool:
	if not rooms.has(room_id) or not is_room_unlocked(room_id):
		return false
	current_room = room_id
	room_switched.emit(room_id)
	return true

func get_current_room_data() -> Dictionary:
	return rooms.get(current_room, rooms["small_room"])

func buy_device_unit(device_id: String, total_pops: int = 999999) -> bool:
	if not devices.has(device_id):
		purchase_failed.emit("Bilinmeyen cihaz")
		return false
		
	var d_data = devices[device_id]
	var cur_count = d_data.get("count", 0)
	var max_count = d_data.get("max_count", 6)
	if cur_count >= max_count:
		purchase_failed.emit("Maksimum cihaz adedine (" + str(max_count) + "/" + str(max_count) + ") ulaşıldı!")
		return false
		
	var needed_pops = get_device_unit_req_pops(device_id, cur_count)
	if total_pops < needed_pops:
		purchase_failed.emit("Kilitli! " + str(needed_pops) + " patlatma gerekiyor.")
		return false
		
	var u_costs = d_data.get("unit_costs", d_data.get("costs", [500]))
	var cost = u_costs[clamp(cur_count, 0, u_costs.size() - 1)]
	if coins < cost:
		purchase_failed.emit("Yetersiz Coin! (" + str(cost) + " Coin gerekli)")
		return false
		
	coins -= cost
	d_data["count"] = cur_count + 1
	if d_data["level"] == 0:
		d_data["level"] = 1
	coins_changed.emit(coins)
	device_unit_purchased.emit(device_id, d_data["count"], d_data["level"])
	
	var gm = get_node_or_null("../GameManager")
	if gm and gm.has_method("log_timeline_event"):
		gm.log_timeline_event("device_unit", device_id, d_data.get("name", device_id), d_data["count"], cost)
		
	return true

func buy_device_upgrade(device_id: String, total_pops: int = 999999) -> bool:
	if not devices.has(device_id):
		purchase_failed.emit("Bilinmeyen cihaz")
		return false
		
	var d_data = devices[device_id]
	if d_data["level"] >= d_data["max_level"]:
		purchase_failed.emit("Cihaz teknolojisi maksimum seviyeye ulaştı!")
		return false
		
	var needed_pops = get_device_tech_req_pops(device_id, d_data["level"])
	if total_pops < needed_pops:
		purchase_failed.emit("Kilitli! " + str(needed_pops) + " patlatma gerekiyor.")
		return false
		
	var cost = d_data["costs"][d_data["level"]]
	if coins < cost:
		purchase_failed.emit("Yetersiz Coin! (" + str(cost) + " Coin gerekli)")
		return false
		
	coins -= cost
	d_data["level"] += 1
	coins_changed.emit(coins)
	device_purchased.emit(device_id, d_data["level"])
	
	var gm = get_node_or_null("../GameManager")
	if gm and gm.has_method("log_timeline_event"):
		gm.log_timeline_event("device_tech", device_id, d_data.get("name", device_id), d_data["level"], cost)
		
	return true

func buy_device(device_id: String, total_pops: int = 999999) -> bool:
	# Fallback router: If not owned yet, buy 1st unit; if owned, upgrade tech
	if not devices.has(device_id):
		return false
	var d_data = devices[device_id]
	if d_data.get("count", 0) == 0:
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
