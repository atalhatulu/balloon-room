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
	"spike_wall": {
		"id": "spike_wall",
		"name": "Dikenli Zemin Tuzağı (Floor Spikes)",
		"category": "devices",
		"unlock_pops": 1200,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 3,
		"desc": "Zemine serilen sivri çelik iğneler. Balonlar üzerine düştükçe sürekli seri darbelerle deler.",
		"widths": ["0.60s Bekleme (12 Balon)", "0.48s Bekleme (22 Balon)", "0.38s Bekleme (36 Balon)", "0.30s Bekleme (55 Balon)", "0.22s Bekleme (80 Balon)", "0.16s Bekleme (120 Balon)"],
		"unit_costs": [400, 1500, 6000],
		"costs": [800, 2500, 9000, 32000, 110000, 350000]
	},
	"electric_wall": {
		"id": "electric_wall",
		"name": "Elektrikli Zemin Izgarası (Electric Floor Grid)",
		"category": "devices",
		"unlock_pops": 3000,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 3,
		"desc": "Yüksek voltajlı kondansatör ızgarası. Şarj olduğunda havadaki ve yerdeki balonlara devasa yıldırım EMP patlaması yapar.",
		"widths": ["2.5s Şarj (16 Balon)", "2.0s Şarj (28 Balon)", "1.6s Şarj (45 Balon)", "1.25s Şarj (70 Balon)", "0.95s Şarj (105 Balon)", "0.70s Şarj (150 Balon)"],
		"unit_costs": [1000, 4500, 18000],
		"costs": [2000, 6500, 22000, 80000, 280000, 850000]
	},
	"magnet_pylon": {
		"id": "magnet_pylon",
		"name": "Manyetik Çekim Kulesi (Magnet Pylon)",
		"category": "devices",
		"unlock_pops": 1800,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 3,
		"desc": "Dikey elektromanyetik kule. Çevredeki düşen balonları kendi merkezine ve altındaki tuzaklara çeker.",
		"widths": ["3.5m Çekim", "4.5m Çekim", "5.8m Çekim", "7.2m Çekim", "8.8m Çekim", "10.5m Çekim"],
		"unit_costs": [800, 3000, 12000],
		"costs": [1500, 4500, 15000, 55000, 190000, 550000]
	},
	"gravity_regulator": {
		"id": "gravity_regulator",
		"name": "Yerçekimi & Gaz Regülatörü (Gravity Regulator)",
		"category": "devices",
		"unlock_pops": 250,
		"level": 0,
		"max_level": 4,
		"count": 1,
		"max_count": 1,
		"desc": "Odadaki balonların düşme hızını ve yerçekimini kontrol eder. Duvardaki [E] butonundan veya [G] tuşundan kontrol edilir.",
		"modes": ["0.25 G (Standart)", "0.80 G (Ağır Döküm)", "1.80 G (Hızlı Şelale)", "3.50 G (Ağır Çöküş)", "6.00 G (Hiper Yerçekimi)"],
		"costs": [400, 1800, 8500, 35000]
	},
	"conveyor_crusher": {
		"id": "conveyor_crusher",
		"name": "Makaralı Balon Öğütücü (Conveyor Crusher)",
		"category": "devices",
		"unlock_pops": 5000,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 3,
		"desc": "Zemine konulan çift silindirli döner çelik öğütücü. Yakındaki balonları vakumlayıp silindirlerde kıyma yapar.",
		"widths": ["1.4s Soğuma (12 Balon)", "1.1s Soğuma (20 Balon)", "0.85s Soğuma (32 Balon)", "0.65s Soğuma (50 Balon)", "0.48s Soğuma (75 Balon)", "0.35s Soğuma (110 Balon)"],
		"unit_costs": [1500, 6000, 25000],
		"costs": [3000, 9500, 32000, 110000, 380000, 1100000]
	},
	"sentry_drone": {
		"id": "sentry_drone",
		"name": "Uçan Lazer Dronu (Sentry Drone)",
		"category": "devices",
		"unlock_pops": 8000,
		"level": 0,
		"max_level": 6,
		"count": 0,
		"max_count": 3,
		"desc": "Oyuncunun yanında süzülen güvenlik dronu. Havadaki balonları lazerle otomatik vurur.",
		"widths": ["1.4s (1x Hedef)", "1.1s (2x Hedef)", "0.85s (3x Hedef)", "0.65s (4x Hedef)", "0.50s (6x Hedef)", "0.38s (8x Hedef)"],
		"unit_costs": [2500, 9000, 35000],
		"costs": [5000, 16000, 55000, 190000, 600000, 1600000]
	}
}

# Room Expansion Catalog (Fixed Room Dimensions & Natural Capacities)
var rooms: Dictionary = {
	"small_room": {
		"id": "small_room",
		"name": "Küçük Salon (Small Room)",
		"desc": "16x16m alan, 6m tavan. 1.0x Coin Çarpanı, 500 Balon Kapasitesi.",
		"cost": 0,
		"unlock_pops": 0,
		"floor_size": Vector2(16, 16),
		"ceiling_height": 6.0,
		"capacity": 500,
		"flow_mult": 1.0,
		"coin_multiplier": 1.0
	},
	"medium_room": {
		"id": "medium_room",
		"name": "Geniş Salon (Medium Room)",
		"desc": "26x26m alan, 7.5m tavan. 1.5x Coin Çarpanı, 1.500 Balon Kapasitesi.",
		"cost": 1500,
		"unlock_pops": 1000,
		"floor_size": Vector2(26, 26),
		"ceiling_height": 7.5,
		"capacity": 1500,
		"flow_mult": 1.25,
		"coin_multiplier": 1.5
	},
	"large_room": {
		"id": "large_room",
		"name": "Büyük Kompleks (Large Room)",
		"desc": "38x38m alan, 9m tavan. 2.2x Coin Çarpanı, 4.000 Balon Kapasitesi.",
		"cost": 25000,
		"unlock_pops": 10000,
		"floor_size": Vector2(38, 38),
		"ceiling_height": 9.0,
		"capacity": 4000,
		"flow_mult": 1.6,
		"coin_multiplier": 2.2
	},
	"warehouse": {
		"id": "warehouse",
		"name": "Sanayi Deposu (Warehouse)",
		"desc": "54x54m alan, 11m tavan. 3.5x Mega Coin Çarpanı, 10.000 Balon Kapasitesi.",
		"cost": 150000,
		"unlock_pops": 50000,
		"floor_size": Vector2(54, 54),
		"ceiling_height": 11.0,
		"capacity": 10000,
		"flow_mult": 2.2,
		"coin_multiplier": 3.5
	},
	"hangar": {
		"id": "hangar",
		"name": "Mega Hangar (Hangar)",
		"desc": "72x72m dev alan, 14m tavan. 5.0x Mega Çarpan, 25.000 Balon Kapasitesi.",
		"cost": 750000,
		"unlock_pops": 200000,
		"floor_size": Vector2(72, 72),
		"ceiling_height": 14.0,
		"capacity": 25000,
		"flow_mult": 3.0,
		"coin_multiplier": 5.0
	},
	"hyper_lab": {
		"id": "hyper_lab",
		"name": "Hyper Lab (Absürt Aşama)",
		"desc": "95x95m siber tesis, 18m tavan. 8.0x Nihai Çarpan, 60.000 Balon Kapasitesi.",
		"cost": 3000000,
		"unlock_pops": 500000,
		"floor_size": Vector2(95, 95),
		"ceiling_height": 18.0,
		"capacity": 60000,
		"flow_mult": 4.5,
		"coin_multiplier": 8.0
	}
}

# Core Standard Upgrades
var upgrades: Dictionary = {
	# 1. BALON AKIŞI & BORU HATTI
	"pipe_count": {
		"category": "upgrades",
		"unlock_pops": 80,
		"level": 0,
		"max_level": 8,
		"title": "Tavan Menfez Sayısı (Boru Hattı)",
		"desc": "Tavana ek boru hattı çeker. Her yeni boru toplam dökülme akışını katlar (1x ➔ 9x)!",
		"pipes": ["1 Boru (1x Akış)", "2 Boru (2x Akış)", "3 Boru (3x Akış)", "4 Boru (4x Akış)", "5 Boru (5x Akış)", "6 Boru (6x Akış)", "7 Boru (7x Akış)", "8 Boru (8x Akış)", "9 Boru (9x Matrix)"],
		"costs": [120, 600, 2500, 9000, 32000, 110000, 350000, 1200000]
	},
	"vent_rate": {
		"category": "upgrades",
		"unlock_pops": 0,
		"level": 0,
		"max_level": 12,
		"title": "Balon Dökülme Hızı",
		"desc": "Tavandan saniyede dökülen balon sayısını artırır.",
		"rates": [1, 2, 3.5, 6, 10, 16, 26, 42, 70, 110, 180, 280, 450],
		"costs": [10, 25, 60, 150, 350, 800, 1800, 4000, 8000, 15000, 30000, 60000]
	},

	# 2. İĞNE / OYUNCU ARAÇLARI
	"reach": {
		"category": "upgrades",
		"unlock_pops": 10,
		"level": 0,
		"max_level": 8,
		"title": "Reach / Uzun İğne",
		"desc": "İğnenin vuruş ve tıklama menzilini uzatır.",
		"costs": [12, 35, 90, 250, 700, 2000, 6000, 18000]
	},

	"auto_pop": {
		"category": "upgrades",
		"unlock_pops": 50,
		"level": 0,
		"max_level": 8,
		"title": "Auto-Pop",
		"desc": "Sol tıka basılı tutulduğunda aralıksız seri iğne batırma özelliğini açar ve hızlandırır.",
		"speeds": ["Kapalı", "3.0/sn", "5.0/sn", "8.0/sn", "12.0/sn", "18.0/sn", "26.0/sn", "38.0/sn", "55.0/sn"],
		"costs": [50, 150, 450, 1400, 4200, 12000, 35000, 95000]
	},
	"splash_pop": {
		"category": "upgrades",
		"unlock_pops": 250,
		"level": 0,
		"max_level": 7,
		"title": "Splash / Renk Eşleşmeli Alan Patlatma",
		"desc": "İğneyle vurulan balonun çevresinde şok dalgası oluşturup AYNI RENKTEKİ komşu balonları zincirleme patlatır.",
		"radii": ["Kapalı", "2.5m (~8 Balon)", "3.8m (~18 Balon)", "5.5m (~32 Balon)", "7.5m (~55 Balon)", "10.0m (~90 Balon)", "14.0m (~150 Balon)", "20.0m (Dev Kozmik Şok)"],
		"costs": [100, 300, 900, 2800, 8500, 26000, 75000]
	},

	# 3. ENERJİ / KARAKTER
	"energy_cap": {
		"category": "upgrades",
		"unlock_pops": 0,
		"level": 0,
		"max_level": 8,
		"title": "Energy Capacity",
		"desc": "Maksimum enerji havuzunu +25 birim artırır.",
		"costs": [10, 30, 80, 220, 600, 1600, 4500, 12000]
	},
	"energy_regen": {
		"category": "upgrades",
		"unlock_pops": 0,
		"level": 0,
		"max_level": 8,
		"title": "Energy Regen",
		"desc": "Dinlenirken enerjinin saniyede dolum hızını artırır.",
		"costs": [10, 30, 80, 220, 600, 1600, 4500, 12000]
	},
	"speed": {
		"category": "upgrades",
		"unlock_pops": 0,
		"level": 0,
		"max_level": 8,
		"title": "Speed",
		"desc": "Yürüme ve koşma hızını artırır.",
		"costs": [20, 60, 160, 420, 1100, 3000, 8000, 22000]
	},
	"sprint_efficiency": {
		"category": "upgrades",
		"unlock_pops": 40,
		"level": 0,
		"max_level": 8,
		"title": "Sprint Efficiency",
		"desc": "Basılı tutarak patlatma ve süpürme enerji harcamasını azaltır.",
		"costs": [15, 45, 120, 320, 850, 2300, 6200, 16000]
	},
	"coin_magnet": {
		"category": "upgrades",
		"unlock_pops": 25,
		"level": 0,
		"max_level": 8,
		"title": "Manyetik Para Çekimi (Coin Magnet)",
		"desc": "Yerdeki altın madeni paraları çok daha uzak mesafelerden otomatik olarak kendine çeker.",
		"ranges": ["3.5m Menzil", "5.5m Menzil", "8.0m Menzil", "12.0m Menzil", "17.0m Menzil", "24.0m Menzil", "32.0m Menzil", "45.0m (Oda Çapında Manyetik Çekim)"],
		"costs": [25, 75, 220, 650, 1900, 5500, 16000, 48000]
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

func buy_upgrade(upgrade_id: String, total_pops: int = 999999) -> bool:
	if not upgrades.has(upgrade_id):
		purchase_failed.emit("Bilinmeyen yükseltme")
		return false
		
	var up = upgrades[upgrade_id]
	if total_pops < up["unlock_pops"]:
		purchase_failed.emit("Kilitli! " + str(up["unlock_pops"]) + " patlatma gerekiyor.")
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
	if total_pops < d_data["unlock_pops"]:
		purchase_failed.emit("Kilitli! " + str(d_data["unlock_pops"]) + " patlatma gerekiyor.")
		return false
		
	var cur_count = d_data.get("count", 0)
	var max_count = d_data.get("max_count", 6)
	if cur_count >= max_count:
		purchase_failed.emit("Maksimum cihaz adedine (" + str(max_count) + "/" + str(max_count) + ") ulaşıldı!")
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
	return true

func buy_device_upgrade(device_id: String, total_pops: int = 999999) -> bool:
	if not devices.has(device_id):
		purchase_failed.emit("Bilinmeyen cihaz")
		return false
		
	var d_data = devices[device_id]
	if total_pops < d_data["unlock_pops"]:
		purchase_failed.emit("Kilitli! " + str(d_data["unlock_pops"]) + " patlatma gerekiyor.")
		return false
		
	if d_data["level"] >= d_data["max_level"]:
		purchase_failed.emit("Cihaz teknolojisi maksimum seviyeye ulaştı!")
		return false
		
	var cost = d_data["costs"][d_data["level"]]
	if coins < cost:
		purchase_failed.emit("Yetersiz Coin! (" + str(cost) + " Coin gerekli)")
		return false
		
	coins -= cost
	d_data["level"] += 1
	coins_changed.emit(coins)
	device_purchased.emit(device_id, d_data["level"])
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
