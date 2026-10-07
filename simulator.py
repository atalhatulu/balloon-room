#!/usr/bin/env python3
"""
Balloon Room Economy & Progression Simulator
Matematiksel ve metin tabanlı oyun ilerleme simülatörü.
Fizik/grafik yükü olmadan saniyeler içinde binlerce saniyelik oyunu simüle eder.
"""

import sys
import math

# Oda Yapılandırması (shop_manager.gd ile birebir uyumlu)
ROOMS = {
    "small_room": {
        "name": "Küçük Oda",
        "unlock_pops": 0,
        "capacity": 600,
        "max_pipes": 2,
        "max_devices": 4,
        "flow_mult": 1.0,
        "coin_multiplier": 1.0,
        "cost_multiplier": 1.0,
        "avg_balloon_tier": 0.94 * 1 + 0.06 * 5 # 1.24
    },
    "medium_room": {
        "name": "Üretim Tesisi",
        "unlock_pops": 5000,
        "capacity": 2500,
        "max_pipes": 4,
        "max_devices": 8,
        "flow_mult": 1.25,
        "coin_multiplier": 1.3,
        "cost_multiplier": 1.5,
        "avg_balloon_tier": 0.75 * 1 + 0.18 * 5 + 0.06 * 10 + 0.01 * 50 # 2.75
    },
    "hangar": {
        "name": "Mega Hangar",
        "unlock_pops": 60000,
        "capacity": 8000,
        "max_pipes": 6,
        "max_devices": 16,
        "flow_mult": 1.65,
        "coin_multiplier": 1.8,
        "cost_multiplier": 1.9,
        "avg_balloon_tier": 0.55 * 1 + 0.28 * 5 + 0.14 * 10 + 0.03 * 50 # 4.85
    },
}

# Otomasyon Cihazları (Spike Shredder & EMP Grid)
DEVICES = {
    "spike_wall": {
        "name": "Zemin Kırıcısı (Tuzak)",
        "unlock_pops": 5000,
        "unit_costs": [400, 1500, 6000, 22000, 70000, 180000],
        "unit_req_pops": [5000, 14000, 60000, 120000, 350000, 600000],
        "pps_per_unit": 28.0
    },
    "electric_wall": {
        "name": "EMP Izgarası (Şimşek)",
        "unlock_pops": 30000,
        "unit_costs": [1200, 4500, 18000, 60000, 150000, 350000],
        "unit_req_pops": [30000, 50000, 140000, 300000, 580000, 780000],
        "pps_per_unit": 65.0
    }
}

# Geliştirme Ağacı
UPGRADES = {
    "vent_rate": {
        "name": "Dökülme Hızı",
        "costs": [25, 100, 350, 1200, 4500, 18000, 65000, 220000, 600000, 1500000, 3200000, 7500000],
        "req_pops": [10, 40, 150, 500, 2000, 6500, 24000, 75000, 200000, 500000, 1000000, 2200000],
        "values": [1.2, 2.0, 3.0, 4.5, 6.5, 9.0, 15.0, 22.0, 32.0, 48.0, 70.0, 105.0, 150.0]
    },
    "pipe_count": {
        "name": "Boru Sayısı",
        "costs": [250, 1500, 9500, 42000, 180000, 750000, 2400000, 7000000],
        "req_pops": [300, 3000, 12000, 48000, 140000, 380000, 700000, 1300000],
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

class Simulation:
    def __init__(self, target_pops=1000000, max_seconds=72000):
        self.target_pops = target_pops
        self.max_seconds = max_seconds
        
        self.time = 0.0
        self.total_pops = 0
        self.coins = 0
        self.pop_acc = 0.0
        self.coin_acc = 0.0
        self.active_balloons = 0
        
        self.current_room = "small_room"
        self.levels = {
            "vent_rate": 0,
            "pipe_count": 0,
            "dart_gun": 0,
            "auto_pop": 0,
            "splash_pop": 0
        }
        self.devices_owned = {
            "spike_wall": 0,
            "electric_wall": 0
        }
        
        self.events = []
        self.minute_stats = []

    def get_room(self):
        return ROOMS[self.current_room]
        
    def check_room_progression(self):
        for r_id in ["hangar", "medium_room"]:
            if self.total_pops >= ROOMS[r_id]["unlock_pops"] and self.current_room != r_id:
                # Sadece daha üst odaya geç
                order = ["small_room", "medium_room", "hangar"]
                if order.index(r_id) > order.index(self.current_room):
                    self.current_room = r_id
                    self.log_event(f"🏠 ODA GEÇİŞİ: {ROOMS[r_id]['name']} açıldı!")
                    break

    def get_scaled_cost(self, base_cost):
        return max(base_cost, int(round(base_cost * self.get_room()["cost_multiplier"])))

    def log_event(self, text):
        m = int(self.time // 60)
        s = int(self.time % 60)
        self.events.append(f"[{m:02d}:{s:02d}] {text} (Balon: {self.total_pops:,} | Coin: {self.coins:,})")

    def run(self):
        dt = 0.5 # 0.5 saniyelik adımlarla simüle et
        last_minute = 0
        
        while self.total_pops < self.target_pops and self.time < self.max_seconds:
            self.time += dt
            room = self.get_room()
            
            # 1. Üretim (Spawn Rate)
            vent_val = UPGRADES["vent_rate"]["values"][self.levels["vent_rate"]]
            active_pipes = min(1 + self.levels["pipe_count"], room["max_pipes"])
            spawn_rate = vent_val * active_pipes * room["flow_mult"]
            
            # Odadaki balon kapasite kontrolü
            spawn_amount = spawn_rate * dt
            if self.active_balloons + spawn_amount <= room["capacity"]:
                self.active_balloons += spawn_amount
            else:
                self.active_balloons = room["capacity"]

            # 2. Oda Basıncı ve Dinamik Patlatma (25-50% hedef, 80% tavan salvosu)
            room_cap = float(room["capacity"])
            pressure_ratio = self.active_balloons / room_cap
            
            # Basınç %25-50 arasında dengeli, %80'e yaklaşınca acil durum salvosu
            if pressure_ratio > 0.50:
                player_effort = 1.0 + ((pressure_ratio - 0.50) / 0.30) * 1.5
            elif pressure_ratio < 0.25:
                player_effort = max(0.35, pressure_ratio / 0.25)
            else:
                player_effort = 1.0
                
            needle_base_pps = 4.0
            auto_pps = UPGRADES["auto_pop"]["values"][self.levels["auto_pop"]]
            splash_mult = UPGRADES["splash_pop"]["targets"][self.levels["splash_pop"]]
            effective_needle_pps = (needle_base_pps + auto_pps) * (1.0 + (splash_mult - 1) * 0.4)

            # Dart silahı katkısı
            dart_pps = 0.0
            if self.levels["dart_gun"] > 0:
                dart_lvl = self.levels["dart_gun"] - 1
                fire_interval = UPGRADES["dart_gun"]["intervals"][dart_lvl]
                pierce = UPGRADES["dart_gun"]["pierce"][dart_lvl]
                density = min(1.0, max(0.2, pressure_ratio * 1.8))
                effective_pierce = max(1.0, pierce * density)
                dart_pps = (1.0 / fire_interval) * effective_pierce

            # Cihazların pasif otomasyon katkısı
            device_pps = 0.0
            for d_id, count in self.devices_owned.items():
                if count > 0:
                    device_pps += count * DEVICES[d_id]["pps_per_unit"]

            total_pps_capacity = ((effective_needle_pps + dart_pps) * player_effort) + device_pps
            # Basıncı %25-50 bandında tutacak dinamik oyuncu tepkisi
            desired_sweep_pps = spawn_rate * player_effort
            final_pps = max(total_pps_capacity, desired_sweep_pps)
            
            # Gerçekte patlatılan balon sayısı
            potential_pops = final_pps * dt
            actual_pops = min(self.active_balloons, potential_pops)
            
            self.active_balloons -= actual_pops
            self.pop_acc += actual_pops
            while self.pop_acc >= 1.0:
                self.pop_acc -= 1.0
                self.total_pops += 1
            
            # 3. Altın Kazanımı
            coin_gain = actual_pops * room["avg_balloon_tier"] * room["coin_multiplier"] * 1.2
            self.coin_acc += coin_gain
            while self.coin_acc >= 1.0:
                self.coin_acc -= 1.0
                self.coins += 1

            # 4. Oda Kontrolü
            self.check_room_progression()

            # 5. Otomatik Satın Alma Kararı (Akıllı Oyuncu Mantığı)
            self.attempt_purchases()

            # Dakikalık İstatistik
            current_min = int(self.time // 60)
            if current_min > last_minute:
                last_minute = current_min
                self.minute_stats.append({
                    "min": current_min,
                    "pops": self.total_pops,
                    "coins": self.coins,
                    "room": room["name"],
                    "active_b": int(self.active_balloons),
                    "pps": round(total_pps_capacity, 1),
                    "devices": dict(self.devices_owned)
                })

        return self.generate_report()

    def attempt_purchases(self):
        affordable_candidates = []
        for up_id, up_data in UPGRADES.items():
            lvl = self.levels[up_id]
            max_lvl = len(up_data["costs"])
            if lvl < max_lvl:
                base_cost = up_data["costs"][lvl]
                cost = self.get_scaled_cost(base_cost)
                req = up_data["req_pops"][lvl]
                
                can_afford = (self.coins >= cost)
                unlocked = (self.total_pops >= req)
                
                if can_afford and unlocked:
                    affordable_candidates.append({
                        "type": "upgrade",
                        "id": up_id,
                        "name": up_data["name"],
                        "lvl": lvl + 1,
                        "cost": cost
                    })
        
        # Cihaz satın alma kontrolü
        room = self.get_room()
        total_dev_owned = sum(self.devices_owned.values())
        if total_dev_owned < room["max_devices"]:
            for d_id, d_data in DEVICES.items():
                cur_cnt = self.devices_owned[d_id]
                if cur_cnt < len(d_data["unit_costs"]) and self.total_pops >= d_data["unlock_pops"]:
                    base_cost = d_data["unit_costs"][cur_cnt]
                    cost = self.get_scaled_cost(base_cost)
                    req = d_data["unit_req_pops"][cur_cnt]
                    if self.coins >= cost and self.total_pops >= req:
                        affordable_candidates.append({
                            "type": "device",
                            "id": d_id,
                            "name": d_data["name"],
                            "lvl": cur_cnt + 1,
                            "cost": cost
                        })

        if affordable_candidates:
            affordable_candidates.sort(key=lambda x: x["cost"])
            best = affordable_candidates[0]
            self.coins -= best["cost"]
            if best["type"] == "upgrade":
                self.levels[best["id"]] += 1
                self.log_event(f"🛒 SATIN ALINDI: {best['name']} -> Seviye {best['lvl']} (Maliyet: {best['cost']:,})")
            else:
                self.devices_owned[best["id"]] += 1
                self.log_event(f"⚙️ CİHAZ KURULDU: {best['name']} #{best['lvl']} (Maliyet: {best['cost']:,})")

    def generate_report(self):
        m = int(self.time // 60)
        s = int(self.time % 60)
        
        out = []
        out.append("=" * 70)
        out.append(f"   BALLOON ROOM İLERLEME & EKONOMİ SİMÜLASYONU RAPORU")
        out.append("=" * 70)
        out.append(f"Hedef: {self.target_pops:,} Balon")
        out.append(f"Tamamlanma Süresi: {m} dakika {s} saniye ({self.time:.1f} saniye)")
        out.append(f"Nihai Oda: {self.get_room()['name']}")
        out.append(f"Kalan Altın: {self.coins:,}")
        out.append(f"Kurulan Otomasyon Cihazları: {self.devices_owned}")
        out.append(f"Nihai Geliştirme Seviyeleri:")
        for up_id, lvl in self.levels.items():
            max_lvl = len(UPGRADES[up_id]["costs"])
            out.append(f"  - {UPGRADES[up_id]['name']}: Seviye {lvl}/{max_lvl}")
        
        out.append("\n--- DAKİKA DAKİKA GELİŞİM TABLOSU ---")
        out.append(f"{'Dk':<4} | {'Oda':<16} | {'Toplam Balon':<14} | {'Mevcut Coin':<12} | {'Odadaki Balon':<13} | {'Kapasite (PPS)':<14}")
        out.append("-" * 80)
        for stat in self.minute_stats:
            out.append(f"{stat['min']:<4} | {stat['room']:<16} | {stat['pops']:<14,}"
                       f" | {stat['coins']:<12,} | {stat['active_b']:<13} | {stat['pps']:<14}")

        out.append("\n--- ÖNEMLİ OLAY GÜNLÜĞÜ (İLK 25 İŞLEM) ---")
        for ev in self.events[:25]:
            out.append(" " + ev)
        if len(self.events) > 25:
            out.append(f" ... ve {len(self.events) - 25} satın alım daha.")
            
        out.append("=" * 70)
        return "\n".join(out)

if __name__ == "__main__":
    target = 1000000
    if len(sys.argv) > 1:
        target = int(sys.argv[1])
    sim = Simulation(target_pops=target)
    rep = sim.run()
    with open("simulation_report.txt", "w", encoding="utf-8") as f:
        f.write(rep)
    print(rep)
