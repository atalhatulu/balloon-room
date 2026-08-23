extends Node

signal coins_changed(total_coins: int)
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal room_unlocked(room_id: String)
signal room_switched(room_id: String)
signal device_purchased(device_id: String, new_level: int)
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
		"desc": "Zemine serilen sivri çelik iğneler. Balonlar üzerine yığılır ve periyodik vuruşla topluca delinir.",
		"widths": ["2.8s Bekleme (8 Balon)", "2.4s Bekleme (16 Balon)", "2.0s Bekleme (28 Balon)", "1.6s Bekleme (45 Balon)", "1.2s Bekleme (75 Balon)", "0.8s Bekleme (120 Balon)"],
		"costs": [600, 2500, 12000, 60000, 220000, 650000]
	},
	"electric_wall": {
		"id": "electric_wall",
		"name": "Elektrikli Zemin Izgarası (Electric Floor Grid)",
		"category": "devices",
		"unlock_pops": 3000,
		"level": 0,
		"max_level": 6,
		"desc": "Tabana yüksek voltajlı neon ark ızgarası serer. Şarj dolduğunda biriken balonları devasa bir yıldırımla yakar.",
		"widths": ["3.5s Şarj (12 Balon)", "3.0s Şarj (22 Balon)", "2.4s Şarj (40 Balon)", "1.8s Şarj (70 Balon)", "1.2s Şarj (110 Balon)", "0.7s Şarj (180 Balon)"],
		"costs": [1500, 6000, 28000, 110000, 380000, 950000]
	},
	"magnet_pylon": {
		"id": "magnet_pylon",
		"name": "Manyetik Çekim Kulesi (Magnet Pylon)",
		"category": "devices",
		"unlock_pops": 1800,
		"level": 0,
		"max_level": 6,
		"desc": "Dikilen dikey elektromanyetik kule. Balonları çevreden kendi merkezine ve altındaki tuzaklara çeker.",
		"widths": ["6.0m Çekim", "10.0m Çekim", "16.0m Çekim", "24.0m Çekim", "35.0m Çekim", "50.0m Çekim"],
		"costs": [1000, 4500, 18000, 75000, 280000, 750000]
	},
	"gravity_regulator": {
		"id": "gravity_regulator",
		"name": "Yerçekimi & Gaz Regülatörü (Gravity Regulator)",
		"category": "devices",
		"unlock_pops": 800,
		"level": 0,
		"max_level": 4,
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
		"desc": "Zemine konulan çift silindirli döner çelik öğütücü. Balonları içine çekip parti halinde kıyma yapar ve soğumaya geçer.",
		"widths": ["2.8s Soğuma (5 Balon)", "2.2s Soğuma (12 Balon)", "1.7s Soğuma (24 Balon)", "1.2s Soğuma (45 Balon)", "0.8s Soğuma (80 Balon)", "0.5s Soğuma (150 Balon)"],
		"costs": [2000, 8000, 35000, 140000, 450000, 1200000]
	},
	"sentry_drone": {
		"id": "sentry_drone",
		"name": "Uçan Lazer Dronu (Sentry Drone)",
		"category": "devices",
		"unlock_pops": 8000,
		"level": 0,
		"max_level": 6,
		"desc": "Oyuncunun yanında süzülen güvenlik dronu. Lazer atışları arasında şarj olur.",
		"widths": ["2.4s Bekleme (Tek Hedef)", "1.8s Bekleme (Çift Hedef)", "1.2s Bekleme (3x Hedef)", "0.8s Bekleme (4x Hedef)", "0.5s Bekleme (6x Hedef)", "0.25s Bekleme (10x Hedef)"],
		"costs": [3500, 14000, 55000, 200000, 650000, 1800000]
	}
}

# Room Expansion Catalog (1M Balanced Scale)
var rooms: Dictionary = {
	"small_room": {
		"id": "small_room",
		"name": "Küçük Salon (Small Room)",
		"desc": "Başlangıç odası. 1.0x Coin çarpanı, standart %8 Altın / %6 Bomba balon şansı.",
		"cost": 0,
		"unlock_pops": 0,
		"floor_size": Vector2(16, 16),
		"ceiling_height": 6.0,
		"cap_bonus": 10,
		"flow_mult": 1.0,
		"coin_multiplier": 1.0,
		"gold_chance": 0.08,
		"bomb_chance": 0.06
	},
	"medium_room": {
		"id": "medium_room",
		"name": "Geniş Salon (Medium Room)",
		"desc": "26x26m alan, 7.5m tavan. 1.5x Coin Çarpanı, %10 Altın / %8 Bomba balon şansı.",
		"cost": 1500,
		"unlock_pops": 1000,
		"floor_size": Vector2(26, 26),
		"ceiling_height": 7.5,
		"cap_bonus": 40,
		"flow_mult": 1.25,
		"coin_multiplier": 1.5,
		"gold_chance": 0.10,
		"bomb_chance": 0.08
	},
	"large_room": {
		"id": "large_room",
		"name": "Büyük Kompleks (Large Room)",
		"desc": "38x38m alan, 9m tavan. 2.2x Coin Çarpanı, %14 Altın / %10 Bomba balon şansı.",
		"cost": 25000,
		"unlock_pops": 10000,
		"floor_size": Vector2(38, 38),
		"ceiling_height": 9.0,
		"cap_bonus": 90,
		"flow_mult": 1.6,
		"coin_multiplier": 2.2,
		"gold_chance": 0.14,
		"bomb_chance": 0.10
	},
	"warehouse": {
		"id": "warehouse",
		"name": "Sanayi Deposu (Warehouse)",
		"desc": "54x54m alan, 11m tavan. 3.5x Mega Coin Çarpanı, %18 Altın / %14 Bomba balon yağmuru.",
		"cost": 150000,
		"unlock_pops": 50000,
		"floor_size": Vector2(54, 54),
		"ceiling_height": 11.0,
		"cap_bonus": 180,
		"flow_mult": 2.2,
		"coin_multiplier": 3.5,
		"gold_chance": 0.18,
		"bomb_chance": 0.14
	},
	"hangar": {
		"id": "hangar",
		"name": "Mega Hangar (Hangar)",
		"desc": "75x75m alan, 14m tavan. 5.0x Hiper Coin Çarpanı, %24 Altın / %18 Bomba balon sağanağı!",
		"cost": 750000,
		"unlock_pops": 200000,
		"floor_size": Vector2(75, 75),
		"ceiling_height": 14.0,
		"cap_bonus": 350,
		"flow_mult": 3.0,
		"coin_multiplier": 5.0,
		"gold_chance": 0.24,
		"bomb_chance": 0.18
	},
	"hyper_lab": {
		"id": "hyper_lab",
		"name": "Hyper Lab (Absürt Boyut)",
		"desc": "95x95m sibernetik mega tesis, 18m tavan. 8.0x Kozmik Coin Çarpanı, %30 Altın / %24 Bomba balon kaosu!",
		"cost": 3000000,
		"unlock_pops": 500000,
		"floor_size": Vector2(95, 95),
		"ceiling_height": 18.0,
		"cap_bonus": 700,
		"flow_mult": 4.5,
		"coin_multiplier": 8.0,
		"gold_chance": 0.30,
		"bomb_chance": 0.24
	}
}

# Core Standard Upgrades
var upgrades: Dictionary = {
	# 1. BALON AKIŞI
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
	"room_capacity": {
		"category": "upgrades",
		"unlock_pops": 0,
		"level": 0,
		"max_level": 10,
		"title": "Oda Kapasitesi",
		"desc": "Odada aynı anda bulunabilecek maksimum balon limitini artırır.",
		"caps": [30, 50, 80, 130, 200, 320, 500, 750, 1100, 1600, 2400],
		"costs": [15, 40, 100, 260, 650, 1600, 4000, 10000, 25000, 60000]
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
	"nudge": {
		"category": "upgrades",
		"unlock_pops": 50,
		"level": 0,
		"max_level": 8,
		"title": "Nudge / Hava Körüğü",
		"desc": "Sağ tıkla balonları daha geniş ve kuvvetli süpürür.",
		"costs": [25, 75, 200, 550, 1500, 4200, 12000, 32000]
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
		"title": "Splash / Alan Patlatma",
		"desc": "İğneyle vurulan balonun çevresinde şok dalgası oluşturup birden fazla balonu aynı anda patlatır.",
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

func buy_device(device_id: String, total_pops: int = 999999) -> bool:
	if not devices.has(device_id):
		purchase_failed.emit("Bilinmeyen cihaz")
		return false
		
	var d_data = devices[device_id]
	if total_pops < d_data["unlock_pops"]:
		purchase_failed.emit("Kilitli! " + str(d_data["unlock_pops"]) + " patlatma gerekiyor.")
		return false
		
	if d_data["level"] >= d_data["max_level"]:
		purchase_failed.emit("Cihaz maksimum seviyeye ulaştı!")
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
