class_name BalanceDiagnostics
extends RefCounted

const TARGETS := {"small_room": 15000, "medium_room": 250000, "hangar": 1000000}

static func analyze(data: Dictionary) -> Dictionary:
	var room_id: String = data.get("room", "small_room")
	var target: int = TARGETS.get(room_id, 1000000)
	var pops: int = data.get("pops", 0)
	var now: float = data.get("seconds", 0.0)
	var result := {"target": target, "remaining": maxi(0, target - pops), "has_window": false, "eta_minutes": -1.0, "pop_rate": 0.0, "coin_per_pop": -1.0, "diagnosis": "En az 1 dakika normal oynanış verisi gerekli.", "needle_pops": 0, "dart_pops": 0, "device_pops": 0, "needle_pps": -1.0, "dart_pps": -1.0, "dart_hit_ratio": -1.0, "window_seconds": 0.0}
	if pops >= target:
		result.diagnosis = "Oda hedefi tamamlandı."
		result.eta_minutes = 0.0
	var snaps: Array = data.get("minute_snapshots", [])
	var oldest: Dictionary = {}
	for i in range(snaps.size() - 1, -1, -1):
		var snap: Dictionary = snaps[i]
		var age := now - float(snap.get("minute", 0)) * 60.0
		if snap.get("room", "") != room_id or age > 360.0: break
		if age >= 60.0: oldest = snap
	if oldest.is_empty(): return result
	var duration := now - float(oldest.get("minute", 0)) * 60.0
	if duration < 60.0: return result
	var gained := maxi(0, pops - int(oldest.get("pops", pops)))
	var rate := float(gained) / duration
	result.has_window = true
	result.window_seconds = duration
	result.pop_rate = rate
	if rate >= 0.5 and result.remaining > 0:
		result.eta_minutes = float(result.remaining) / rate / 60.0
	var costs := 0
	for event in data.get("timeline_events", []):
		var event_time := float(event.get("minute", 0)) * 60.0
		if event_time > float(oldest.get("minute", 0)) * 60.0 and event_time <= now:
			costs += int(event.get("cost", 0))
	if gained > 0:
		result.coin_per_pop = maxf(0.0, float(int(data.get("coins", 0)) - int(oldest.get("coins", 0)) + costs) / gained)
	var current_sources: Dictionary = data.get("pop_sources", {})
	var old_sources: Dictionary = oldest.get("pop_sources", {})
	result.needle_pops = maxi(0, int(current_sources.get("needle", 0)) + int(current_sources.get("splash", 0)) - int(old_sources.get("needle", 0)) - int(old_sources.get("splash", 0)))
	result.dart_pops = maxi(0, int(current_sources.get("dart", 0)) - int(old_sources.get("dart", 0)))
	for source in ["spike_floor", "electric_grid", "conveyor_crusher", "sentry_drone"]:
		result.device_pops += maxi(0, int(current_sources.get(source, 0)) - int(old_sources.get(source, 0)))
	var current_use: Dictionary = data.get("weapon_active_seconds", {})
	var old_use: Dictionary = oldest.get("weapon_active_seconds", {})
	var needle_seconds := float(current_use.get("needle", 0.0)) - float(old_use.get("needle", 0.0))
	var dart_seconds := float(current_use.get("dart", 0.0)) - float(old_use.get("dart", 0.0))
	if needle_seconds >= 10.0: result.needle_pps = float(result.needle_pops) / needle_seconds
	if dart_seconds >= 10.0: result.dart_pps = float(result.dart_pops) / dart_seconds
	var shot_count := int(data.get("dart_shots", 0)) - int(oldest.get("dart_shots", 0))
	var hit_count := int(data.get("dart_hit_shots", 0)) - int(oldest.get("dart_hit_shots", 0))
	if shot_count >= 10: result.dart_hit_ratio = clampf(float(hit_count) / float(shot_count), 0.0, 1.0)
	var actual: float = data.get("actual_spawn_rate", 0.0)
	var nominal: float = data.get("nominal_spawn_rate", 0.0)
	var physical: int = data.get("physical_balloons", 0)
	var budget: int = maxi(1, int(data.get("physics_budget", 1)))
	var limited: float = float(data.get("physics_limited_seconds", 0.0)) - float(oldest.get("physics_limited_seconds", 0.0))
	if not data.get("production_enabled", true):
		result.diagnosis = "Üretim kapalı; süre tahmini duraklatıldı."
		result.eta_minutes = -1.0
	elif limited > duration * 0.2 or physical >= budget * 0.8:
		result.diagnosis = "Oda basıncı yüksek; üretim kısılıyor. Patlatma veya cihaz temizleme hızını artır."
	elif nominal > 0.0 and actual < nominal * 0.75:
		result.diagnosis = "Gerçek üretim nominal hızın altında; doluluk ve boruları kontrol et."
	elif actual > 1.0 and rate < actual * 0.7:
		result.diagnosis = "Patlatma üretime yetişmiyor; silah ve cihaz yerleşimini incele."
	elif rate < 0.5:
		result.diagnosis = "Bu pencerede yeterli patlatma yok; ETA hesaplanamadı."
	else:
		result.diagnosis = "Akış dengeli; bir sonraki boru ve dökülme yükseltmesini incele."
	return result
