extends Node

# Procedural Sound Manager for Balloon Room
# High-fidelity 16-bit acoustic audio synthesis with punchy, crisp, warm bubble pop sounds.

var audio_players: Array[AudioStreamPlayer] = []
var max_channels: int = 32
var current_channel: int = 0

# Warm, pleasant acoustic frequencies (180Hz - 380Hz)
var warm_notes: Array[float] = [185.0, 207.6, 233.0, 261.6, 293.6, 329.6, 370.0, 415.3]

var cached_pops: Array[AudioStreamWAV] = []
var cached_zap: AudioStreamWAV
var cached_spike: AudioStreamWAV
var cached_gold: AudioStreamWAV
var cached_bomb: AudioStreamWAV
var cached_ice: AudioStreamWAV
var cached_plasma: AudioStreamWAV
var cached_crunch: AudioStreamWAV
var cached_vent: AudioStreamWAV
var cached_power_trip: AudioStreamWAV
var cached_quest_fanfare: AudioStreamWAV
var cached_victory_fanfare: AudioStreamWAV
var cached_button_click: AudioStreamWAV
var cached_door_slide: AudioStreamWAV
var cached_pipe_burst: AudioStreamWAV
var cached_pipe_repair: AudioStreamWAV
var cached_minigun_shot: AudioStreamWAV
var cached_dart_shot: AudioStreamWAV
var cached_shotgun_shot: AudioStreamWAV
var cached_notification: AudioStreamWAV
var cached_jackpot: AudioStreamWAV
var last_minigun_time: int = 0
var last_notification_time: int = 0
var last_jackpot_time: int = 0

# Warm, smooth acoustic pentatonic frequencies for coin pickups (A4 to A5, non-fatiguing)
var coin_notes: Array[float] = [440.0, 493.88, 554.37, 659.25, 739.99, 880.0]
var cached_coin_pickups: Array[AudioStreamWAV] = []
var coin_streak_idx: int = 0
var last_coin_pickup_time: int = 0

func _ready() -> void:
	for i in range(max_channels):
		var player = AudioStreamPlayer.new()
		player.volume_db = -6.5
		add_child(player)
		audio_players.append(player)
		
	# Pre-bake audio streams on startup (Zero CPU calculation during mass pops)
	for freq in warm_notes:
		cached_pops.append(generate_pop_stream(freq))
	for freq in coin_notes:
		cached_coin_pickups.append(generate_coin_stream(freq))
	cached_zap = generate_zap_stream()
	cached_spike = generate_spike_stream()
	cached_gold = generate_gold_stream()
	cached_bomb = generate_bomb_stream()
	cached_ice = generate_ice_stream()
	cached_plasma = generate_plasma_stream()
	cached_crunch = generate_crunch_stream()
	cached_vent = generate_vent_stream()
	cached_power_trip = generate_power_trip_stream()
	cached_quest_fanfare = generate_quest_fanfare_stream()
	cached_victory_fanfare = generate_victory_fanfare_stream()
	cached_jackpot = generate_jackpot_stream()
	cached_button_click = generate_button_click_stream()
	cached_door_slide = generate_door_slide_stream()
	cached_pipe_burst = generate_pipe_burst_stream()
	cached_pipe_repair = generate_pipe_repair_stream()
	cached_minigun_shot = generate_minigun_stream()
	cached_dart_shot = generate_dart_stream()
	cached_shotgun_shot = generate_shotgun_stream()
	cached_notification = generate_notification_stream()
	interaction_streams = {"door": cached_door_slide, "button": cached_button_click,
		"repair": cached_pipe_repair, "place": cached_crunch, "pickup": cached_button_click,
		"unpack": cached_pipe_repair, "confirm": _control_tone(false), "denied": _control_tone(true),
		"portal": cached_notification, "switch": cached_power_trip}

func _get_next_player() -> AudioStreamPlayer:
	if audio_players.is_empty():
		return null
	var p = audio_players[current_channel]
	current_channel = (current_channel + 1) % max_channels
	return p

var last_pop_time: int = 0
var last_zap_time: int = 0
var last_spike_time: int = 0
var last_gold_time: int = 0
var last_bomb_time: int = 0
var last_ice_time: int = 0
var last_plasma_time: int = 0
var last_crunch_time: int = 0
var last_vent_time: int = 0

func play_coin_pickup(val: int = 1) -> void:
	var now = Time.get_ticks_msec()
	# Prevent acoustic stacking when multiple coins arrive on the same physics tick
	if (now - last_coin_pickup_time) < 28:
		return
		
	# Ascending musical arpeggio streak if collected in quick succession (< 450ms)
	if (now - last_coin_pickup_time) < 450:
		coin_streak_idx = mini(coin_streak_idx + 1, maxi(0, cached_coin_pickups.size() - 1))
	else:
		coin_streak_idx = 0
		
	last_coin_pickup_time = now
	
	var player = _get_next_player()
	if not player or cached_coin_pickups.is_empty(): return
	
	# Balanced, smooth volume that sits pleasantly in the mix without piercing the ear
	var vol = -15.0
	if val >= 50:
		vol = -12.5
	elif val >= 10:
		vol = -13.5
	elif val >= 5:
		vol = -14.2
		
	player.volume_db = vol + randf_range(-0.3, 0.3)
	player.pitch_scale = randf_range(0.99, 1.01)
	player.stream = cached_coin_pickups[coin_streak_idx]
	player.play()

func play_vent_spawn() -> void:
	var now = Time.get_ticks_msec()
	if (now - last_vent_time) < 40:
		return
	last_vent_time = now
	
	var player = _get_next_player()
	if not player or not cached_vent: return
	player.volume_db = -12.0 + randf_range(-0.5, 0.5)
	player.pitch_scale = randf_range(0.94, 1.06)
	player.stream = cached_vent
	player.play()

func play_pop(combo_level: int = 0) -> void:
	var now = Time.get_ticks_msec()
	if (now - last_pop_time) < 14:
		return
	last_pop_time = now
	
	var player = _get_next_player()
	if not player or cached_pops.is_empty(): return
	var note_idx = combo_level % cached_pops.size()
	player.volume_db = -6.5 + randf_range(-0.4, 0.4)
	# Gentle, musical pitch ascent with combo depth (clamped between 0.95 and 1.30)
	var combo_bonus = clamp(float(combo_level) * 0.02, 0.0, 0.28)
	player.pitch_scale = randf_range(0.98, 1.02) + combo_bonus
	player.stream = cached_pops[note_idx]
	player.play()

func play_zap() -> void:
	var now = Time.get_ticks_msec()
	if (now - last_zap_time) < 30:
		return
	last_zap_time = now
	
	var player = _get_next_player()
	if not player or not cached_zap: return
	player.volume_db = -7.5
	player.pitch_scale = randf_range(0.96, 1.04)
	player.stream = cached_zap
	player.play()

func play_spike_pop() -> void:
	var now = Time.get_ticks_msec()
	if (now - last_spike_time) < 25:
		return
	last_spike_time = now
	
	var player = _get_next_player()
	if not player or not cached_spike: return
	player.volume_db = -7.0
	player.pitch_scale = randf_range(0.96, 1.04)
	player.stream = cached_spike
	player.play()

func play_gold_pop() -> void:
	var now = Time.get_ticks_msec()
	if (now - last_gold_time) < 30:
		return
	last_gold_time = now
	
	var player = _get_next_player()
	if not player or not cached_gold: return
	player.volume_db = -5.0
	player.pitch_scale = randf_range(0.98, 1.02)
	player.stream = cached_gold
	player.play()

var last_air_time: int = 0

func play_air_blast() -> void:
	var now = Time.get_ticks_msec()
	if (now - last_air_time) < 30:
		return
	last_air_time = now
	
	var player = _get_next_player()
	if not player or not cached_bomb: return
	player.volume_db = -5.0
	player.pitch_scale = randf_range(1.15, 1.35)
	player.stream = cached_bomb
	player.play()

func play_bomb_pop() -> void:
	var now = Time.get_ticks_msec()
	if (now - last_bomb_time) < 40:
		return
	last_bomb_time = now
	
	var player = _get_next_player()
	if not player or not cached_bomb: return
	player.volume_db = -4.5
	player.pitch_scale = randf_range(0.85, 0.98)
	player.stream = cached_bomb
	player.play()

func play_ice_pop() -> void:
	var now = Time.get_ticks_msec()
	if (now - last_ice_time) < 35:
		return
	last_ice_time = now
	
	var player = _get_next_player()
	if not player or not cached_ice: return
	player.volume_db = -5.5
	player.pitch_scale = randf_range(0.95, 1.05)
	player.stream = cached_ice
	player.play()

func play_plasma_pop() -> void:
	var now = Time.get_ticks_msec()
	if (now - last_plasma_time) < 35:
		return
	last_plasma_time = now
	
	var player = _get_next_player()
	if not player or not cached_plasma: return
	player.volume_db = -5.0
	player.pitch_scale = randf_range(0.96, 1.04)
	player.stream = cached_plasma
	player.play()

func play_crunch() -> void:
	var now = Time.get_ticks_msec()
	if (now - last_crunch_time) < 35:
		return
	last_crunch_time = now
	
	var player = _get_next_player()
	if not player or not cached_crunch: return
	player.volume_db = -5.5
	player.pitch_scale = randf_range(0.92, 1.08)
	player.stream = cached_crunch
	player.play()

func play_power_trip() -> void:
	var player = _get_next_player()
	if not player or not cached_power_trip: return
	player.volume_db = -4.0
	player.pitch_scale = randf_range(0.97, 1.03)
	player.stream = cached_power_trip
	player.play()

func play_quest_complete() -> void:
	var player = _get_next_player()
	if not player or not cached_quest_fanfare: return
	player.volume_db = -4.5
	player.pitch_scale = 1.0
	player.stream = cached_quest_fanfare
	player.play()

func play_victory_fanfare() -> void:
	var player = _get_next_player()
	if not player or not cached_victory_fanfare: return
	player.volume_db = -3.0
	player.pitch_scale = 1.0
	player.stream = cached_victory_fanfare
	player.play()

func play_jackpot_fanfare() -> void:
	var now = Time.get_ticks_msec()
	if (now - last_jackpot_time) < 400:
		return
	last_jackpot_time = now
	
	var player = _get_next_player()
	if not player or not cached_jackpot: return
	player.volume_db = -2.5
	player.pitch_scale = randf_range(0.98, 1.02)
	player.stream = cached_jackpot
	player.play()

func play_button_click() -> void:
	var player = _get_next_player()
	if not player or not cached_button_click: return
	player.volume_db = -6.0
	player.pitch_scale = randf_range(0.96, 1.04)
	player.stream = cached_button_click
	player.play()

func play_door_slide() -> void:
	var player = _get_next_player()
	if not player or not cached_door_slide: return
	player.volume_db = -7.0
	player.pitch_scale = randf_range(0.97, 1.03)
	player.stream = cached_door_slide
	player.play()

func generate_power_trip_stream() -> AudioStreamWAV:
	var sample_rate = 44100
	var duration = 0.35
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 5.0) * clamp(t / 0.003, 0.0, 1.0)
		var f = 160.0 * (1.0 - progress * 0.75)
		var buzz = sin(t * f * TAU) * 0.6 + sin(t * f * 2.0 * TAU) * 0.25 + (randf() * 2.0 - 1.0) * 0.15 * (1.0 - progress)
		var sample_val = clamp(buzz * env * 0.95, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_gold_stream() -> AudioStreamWAV:
	var sample_rate = 44100
	var duration = 0.18
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 5.0) * clamp(t / 0.003, 0.0, 1.0)
		var bell = sin(t * 880.0 * TAU) * 0.5 + sin(t * 1760.0 * TAU) * 0.35 + sin(t * 2640.0 * TAU) * 0.15
		var sample_val = clamp(bell * env * 0.9, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_bomb_stream() -> AudioStreamWAV:
	var sample_rate = 44100
	var duration = 0.22
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 4.5) * clamp(t / 0.005, 0.0, 1.0)
		var freq = 120.0 * (1.0 - progress * 0.7)
		var sub = sin(t * freq * TAU) * 0.75 + (randf() * 2.0 - 1.0) * 0.25 * (1.0 - progress)
		var sample_val = clamp(sub * env * 0.95, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_pop_stream(freq: float) -> AudioStreamWAV:
	var sample_rate = 44100
	var duration = 0.055
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	
	var pitch_start = clamp(freq, 180.0, 420.0)
	
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		
		# Downward pitch drop giving the round "plop/pop" feeling
		var cur_freq = pitch_start * (1.0 - progress * 0.58)
		
		# Snappy attack (2.0ms) with clean exponential decay
		var attack = clamp(t / 0.002, 0.0, 1.0)
		var envelope = attack * exp(-progress * 6.5)
		
		# Rich fundamentals
		var body = sin(t * cur_freq * TAU) * 0.85 + sin(t * cur_freq * 2.0 * TAU) * 0.15
		
		# Crisp, rounded transient click
		var snap = 0.0
		if progress < 0.10:
			var snap_fade = 1.0 - (progress / 0.10)
			snap = sin(t * cur_freq * 3.2 * TAU) * 0.22 * snap_fade
			
		var sample_val = (body + snap) * envelope
		sample_val = clamp(sample_val * 0.92, -0.98, 0.98)
		
		var sample_s16 = int(sample_val * 32767.0)
		byte_data.encode_s16(i * 2, sample_s16)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_zap_stream() -> AudioStreamWAV:
	var sample_rate = 44100
	var duration = 0.070
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var envelope = exp(-progress * 7.5) * clamp(t / 0.002, 0.0, 1.0)
		
		var hum = sin(t * 220.0 * TAU) * 0.55
		var spark = sin(t * (650.0 + sin(t * 360.0) * 220.0) * TAU) * 0.35
		var soft_noise = randf_range(-0.15, 0.15) * (1.0 - progress)
		
		var sample_val = (hum + spark + soft_noise) * envelope * 0.88
		sample_val = clamp(sample_val, -0.98, 0.98)
		
		var sample_s16 = int(sample_val * 32767.0)
		byte_data.encode_s16(i * 2, sample_s16)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_spike_stream() -> AudioStreamWAV:
	var sample_rate = 44100
	var duration = 0.060
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var cur_freq = 280.0 * (1.0 - progress * 0.55)
		var envelope = exp(-progress * 7.0) * clamp(t / 0.002, 0.0, 1.0)
		
		var body = sin(t * cur_freq * TAU) * 0.75 + sin(t * cur_freq * 2.0 * TAU) * 0.25
		var sample_val = body * envelope * 0.90
		sample_val = clamp(sample_val, -0.98, 0.98)
		
		var sample_s16 = int(sample_val * 32767.0)
		byte_data.encode_s16(i * 2, sample_s16)
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_ice_stream() -> AudioStreamWAV:
	var sample_rate = 44100
	var duration = 0.12
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 6.0) * clamp(t / 0.002, 0.0, 1.0)
		var glass = sin(t * 1200.0 * TAU) * 0.4 + sin(t * 2400.0 * TAU) * 0.35 + (randf() * 2.0 - 1.0) * 0.25
		var sample_val = clamp(glass * env * 0.85, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_plasma_stream() -> AudioStreamWAV:
	var sample_rate = 44100
	var duration = 0.14
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 5.5) * clamp(t / 0.001, 0.0, 1.0)
		var buzz = sin(t * 450.0 * TAU + sin(t * 1800.0 * TAU) * 2.0) * 0.6 + (randf() * 2.0 - 1.0) * 0.4
		var sample_val = clamp(buzz * env * 0.9, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_crunch_stream() -> AudioStreamWAV:
	var sample_rate = 44100
	var duration = 0.09
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 8.0) * clamp(t / 0.002, 0.0, 1.0)
		var grind = sin(t * 140.0 * TAU) * 0.5 + (randf() * 2.0 - 1.0) * 0.5
		var sample_val = clamp(grind * env * 0.95, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_vent_stream() -> AudioStreamWAV:
	var sample_rate = 44100
	var duration = 0.10
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		# Fast initial puff attack, smooth exponential decay
		var env = exp(-progress * 7.0) * clamp(t / 0.005, 0.0, 1.0)
		# Low frequency pneumatic pressure release (175Hz descending to 80Hz)
		var freq = 175.0 * (1.0 - progress * 0.55)
		var sub = sin(t * freq * TAU) * 0.60
		# Soft pressurized air hiss
		var hiss = (randf() * 2.0 - 1.0) * 0.30 * exp(-progress * 9.0)
		var sample_val = clamp((sub + hiss) * env * 0.85, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_coin_stream(freq: float) -> AudioStreamWAV:
	var sample_rate = 44100
	var duration = 0.11
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	
	var note2_start = 0.024
	var f1 = freq
	var f2 = freq * 1.50 # Warm, pure perfect 5th interval
	
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var sample_val = 0.0
		
		# Smooth acoustic attack ramp (4ms) eliminates any harsh digital click
		var attack = clamp(t / 0.004, 0.0, 1.0)
		
		# Tone 1: Round, warm fundamental body (like a soft mallet on metal/wood)
		if t < 0.065:
			var env1 = exp(-t * 32.0) * attack
			var s1 = sin(t * f1 * TAU) * 0.72 + sin(t * f1 * 2.0 * TAU) * 0.08
			sample_val += s1 * env1
			
		# Tone 2: Soft harmonic fifth that blooms gently without piercing harmonics
		if t >= note2_start:
			var t2 = t - note2_start
			var attack2 = clamp(t2 / 0.004, 0.0, 1.0)
			var env2 = exp(-t2 * 20.0) * attack2
			var s2 = sin(t2 * f2 * TAU) * 0.55 + sin(t2 * f2 * 0.5 * TAU) * 0.15
			sample_val += s2 * env2
			
		sample_val = clamp(sample_val * 0.72, -0.95, 0.95)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_quest_fanfare_stream() -> AudioStreamWAV:
	# A warm, uplifting acoustic 3-chord triumphant fanfare (C5 -> E5 -> G5 -> C6 shimmer)
	var sample_rate = 44100
	var duration = 0.55
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	
	# Arpeggio notes: C5 (523.25), E5 (659.25), G5 (783.99), C6 (1046.50)
	var notes = [
		{"start": 0.00, "end": 0.35, "freq": 523.25, "vol": 0.45},
		{"start": 0.10, "end": 0.42, "freq": 659.25, "vol": 0.50},
		{"start": 0.20, "end": 0.55, "freq": 783.99, "vol": 0.60},
		{"start": 0.30, "end": 0.55, "freq": 1046.50, "vol": 0.70}
	]
	
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var sample_val = 0.0
		for n in notes:
			if t >= n["start"] and t < n["end"]:
				var dt = t - n["start"]
				var note_len = n["end"] - n["start"]
				var attack = clamp(dt / 0.008, 0.0, 1.0)
				var decay = exp(-dt * 6.5)
				var env = attack * decay
				var s = sin(dt * n["freq"] * TAU) + 0.25 * sin(dt * n["freq"] * 2.0 * TAU)
				sample_val += s * env * n["vol"]
		sample_val = clamp(sample_val * 0.75, -0.96, 0.96)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_victory_fanfare_stream() -> AudioStreamWAV:
	# Epic orchestral chordal finale (F4 -> A4 -> C5 -> F5 grand major chord with shimmering brass sustain)
	var sample_rate = 44100
	var duration = 1.35
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	
	var chord_notes = [
		{"start": 0.00, "end": 1.25, "freq": 349.23, "vol": 0.50}, # F4
		{"start": 0.14, "end": 1.30, "freq": 440.00, "vol": 0.55}, # A4
		{"start": 0.28, "end": 1.35, "freq": 523.25, "vol": 0.60}, # C5
		{"start": 0.42, "end": 1.35, "freq": 698.46, "vol": 0.70}, # F5
		{"start": 0.42, "end": 1.35, "freq": 1046.50, "vol": 0.35} # C6 shimmer
	]
	
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var sample_val = 0.0
		for n in chord_notes:
			if t >= n["start"] and t < n["end"]:
				var dt = t - n["start"]
				var attack = clamp(dt / 0.015, 0.0, 1.0)
				var decay = exp(-dt * 2.8)
				var env = attack * decay
				# Rich harmonic warmth (fundamental + 2nd + 3rd harmonic)
				var s = sin(dt * n["freq"] * TAU) * 0.70 + sin(dt * n["freq"] * 2.0 * TAU) * 0.20 + sin(dt * n["freq"] * 3.0 * TAU) * 0.10
				sample_val += s * env * n["vol"]
		sample_val = clamp(sample_val * 0.65, -0.96, 0.96)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_jackpot_stream() -> AudioStreamWAV:
	# Shimmering golden coin rain cascade (rapid 7-note ascending bright crystal arpeggio + bell resonance)
	var sample_rate = 44100
	var duration = 0.95
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	
	# Pentatonic golden sparkle notes: E5, G5, A5, C6, D6, E6, G6 (1567Hz)
	var notes = [
		{"start": 0.00, "end": 0.40, "freq": 659.25, "vol": 0.35},
		{"start": 0.07, "end": 0.48, "freq": 783.99, "vol": 0.40},
		{"start": 0.14, "end": 0.56, "freq": 880.00, "vol": 0.45},
		{"start": 0.21, "end": 0.65, "freq": 1046.50, "vol": 0.55},
		{"start": 0.28, "end": 0.74, "freq": 1174.66, "vol": 0.60},
		{"start": 0.35, "end": 0.88, "freq": 1318.51, "vol": 0.65},
		{"start": 0.42, "end": 0.95, "freq": 1567.98, "vol": 0.75}
	]
	
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var sample_val = 0.0
		for n in notes:
			if t >= n["start"] and t < n["end"]:
				var dt = t - n["start"]
				var attack = clamp(dt / 0.005, 0.0, 1.0)
				var decay = exp(-dt * 6.0)
				var env = attack * decay
				# Bell/crystal chime formula: fundamental + bell partial (2.76x)
				var s = sin(dt * n["freq"] * TAU) * 0.75 + sin(dt * n["freq"] * 2.76 * TAU) * 0.25
				sample_val += s * env * n["vol"]
		sample_val = clamp(sample_val * 0.68, -0.96, 0.96)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_button_click_stream() -> AudioStreamWAV:
	# Heavy industrial push button click (crisp mechanical latch + metallic resonance)
	var sample_rate = 44100
	var duration = 0.08
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 24.0) * clamp(t / 0.002, 0.0, 1.0)
		# Dual frequency transient: punchy 420Hz + 860Hz metallic click
		var click = sin(t * 420.0 * TAU) * 0.65 + sin(t * 860.0 * TAU) * 0.35
		var noise = (randf() * 2.0 - 1.0) * 0.20 * exp(-progress * 45.0)
		var sample_val = clamp((click + noise) * env * 0.95, -0.96, 0.96)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_door_slide_stream() -> AudioStreamWAV:
	# Industrial pneumatic motorized sliding door rumble and hiss
	var sample_rate = 44100
	var duration = 0.42
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		# Smooth trapezoidal envelope with soft fade out
		var attack = clamp(t / 0.03, 0.0, 1.0)
		var decay = clamp((duration - t) / 0.06, 0.0, 1.0)
		var env = attack * decay
		# Heavy 95Hz motor hum + pressurized air friction
		var motor = sin(t * 95.0 * TAU) * 0.50 + sin(t * 190.0 * TAU) * 0.20
		var friction = (randf() * 2.0 - 1.0) * 0.28
		var sample_val = clamp((motor + friction) * env * 0.88, -0.96, 0.96)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func play_pipe_burst() -> void:
	var player = _get_next_player()
	if not player or not cached_pipe_burst: return
	player.volume_db = -3.0
	player.pitch_scale = randf_range(0.92, 1.05)
	player.stream = cached_pipe_burst
	player.play()

func play_pipe_repair() -> void:
	var player = _get_next_player()
	if not player or not cached_pipe_repair: return
	player.volume_db = -4.5
	player.pitch_scale = randf_range(0.96, 1.04)
	player.stream = cached_pipe_repair
	player.play()

func generate_pipe_burst_stream() -> AudioStreamWAV:
	# Dramatic explosive pipe rupture followed by sustained pressurized steam hiss
	var sample_rate = 44100
	var duration = 0.85
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		# Rupture thump (70Hz boom) + steam burst hiss
		var boom_env = exp(-progress * 14.0)
		var boom = sin(t * 70.0 * TAU) * boom_env * 0.75
		var hiss_env = clamp(t / 0.02, 0.0, 1.0) * exp(-progress * 2.8)
		var hiss = (randf() * 2.0 - 1.0) * hiss_env * 0.45
		var sample_val = clamp((boom + hiss) * 0.95, -0.96, 0.96)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func generate_pipe_repair_stream() -> AudioStreamWAV:
	# Heavy metallic wrench ratchet clank and pressure sealing thud
	var sample_rate = 44100
	var duration = 0.38
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var clank_env = exp(-progress * 18.0)
		var clank = (sin(t * 310.0 * TAU) * 0.6 + sin(t * 740.0 * TAU) * 0.4) * clank_env
		var seal = (randf() * 2.0 - 1.0) * exp(-progress * 28.0) * 0.25
		var sample_val = clamp((clank + seal) * 0.92, -0.96, 0.96)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func play_minigun_shot() -> void:
	var now = Time.get_ticks_msec()
	if (now - last_minigun_time) < 18:
		return
	last_minigun_time = now
	var player = _get_next_player()
	if not player or not cached_minigun_shot: return
	player.volume_db = -8.5 + randf_range(-0.5, 0.5)
	player.pitch_scale = randf_range(0.92, 1.08)
	player.stream = cached_minigun_shot
	player.play()

func generate_minigun_stream() -> AudioStreamWAV:
	# Rapid, punchy mechanical ballistic crack
	var sample_rate = 44100
	var duration = 0.09
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var progress = t / duration
		var env = exp(-progress * 9.0) * clamp(t / 0.0008, 0.0, 1.0)
		var pop = sin(TAU * (155.0 * t - 340.0 * t * t)) * 0.55 + (randf() * 2.0 - 1.0) * 0.32 + sin(t * 920.0 * TAU) * 0.13
		var sample_val = clamp(pop * env * 0.95, -0.98, 0.98)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

func play_dart_shot() -> void:
	var voice = _get_next_player()
	if not voice or not cached_dart_shot: return
	voice.stream = cached_dart_shot
	voice.volume_db = -10.0
	voice.pitch_scale = randf_range(0.97, 1.03)
	voice.play()

func generate_dart_stream() -> AudioStreamWAV:
	# Pneumatic snap, spring resonance and a short return latch.
	var rate := 44100
	var frames := int(rate * 0.12)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / rate
		var attack := minf(1.0, t / 0.001)
		var hiss := randf_range(-1, 1) * exp(-t * 110.0) * 0.5
		var spring := sin(TAU * (1150.0 * t - 2400.0 * t * t)) * exp(-t * 65.0) * 0.26
		var body := sin(t * 230.0 * TAU) * exp(-t * 75.0) * 0.24
		var latch := sin((t - 0.055) * 1900.0 * TAU) * exp(-maxf(0.0, t - 0.055) * 180.0) * 0.12 if t > 0.055 else 0.0
		bytes.encode_s16(i * 2, int(clampf((hiss + spring + body) * attack + latch, -0.95, 0.95) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream

func play_shotgun_shot() -> void:
	var voice = _get_next_player()
	if not voice or not cached_shotgun_shot: return
	voice.stream = cached_shotgun_shot
	voice.volume_db = -4.0
	voice.pitch_scale = randf_range(0.92, 1.04)
	voice.play()

func generate_shotgun_stream() -> AudioStreamWAV:
	# Heavy pneumatic blast with deep sub-bass resonance, gunshot crack and pump rack
	var rate := 44100
	var frames := int(rate * 0.28)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / rate
		var attack := minf(1.0, t / 0.0008)
		var blast := randf_range(-1, 1) * exp(-t * 35.0) * 0.85
		var crack := sin(TAU * (360.0 * t - 720.0 * t * t)) * exp(-t * 40.0) * 0.6
		var bass := sin(t * 70.0 * TAU) * exp(-t * 16.0) * 0.55
		var pump := sin((t - 0.14) * 1100.0 * TAU) * exp(-maxf(0.0, t - 0.14) * 50.0) * 0.25 if t > 0.14 else 0.0
		bytes.encode_s16(i * 2, int(clampf((blast + crack + bass) * attack + pump, -0.98, 0.98) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream

func play_notification() -> void:
	var now = Time.get_ticks_msec()
	if (now - last_notification_time) < 1500:
		return
	last_notification_time = now
	
	var player = _get_next_player()
	if not player or not cached_notification: return
	player.volume_db = -5.0
	player.pitch_scale = 1.0
	player.stream = cached_notification
	player.play()

func generate_notification_stream() -> AudioStreamWAV:
	# Subtle, premium modern tablet / smartphone chime (Two soft harmonic tones: E5 659.25Hz -> G#5 830.61Hz)
	var sample_rate = 44100
	var duration = 0.38
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames * 2)
	
	var chime_notes = [
		{"start": 0.00, "end": 0.22, "freq": 659.25, "vol": 0.45}, # E5
		{"start": 0.08, "end": 0.38, "freq": 830.61, "vol": 0.55}, # G#5
		{"start": 0.08, "end": 0.38, "freq": 1661.22, "vol": 0.12} # Harmonic shimmer
	]
	
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var sample_val = 0.0
		for n in chime_notes:
			if t >= n["start"] and t < n["end"]:
				var dt = t - n["start"]
				var attack = clamp(dt / 0.005, 0.0, 1.0)
				var decay = exp(-dt * 9.5)
				var env = attack * decay
				var s = sin(dt * n["freq"] * TAU)
				sample_val += s * env * n["vol"]
		sample_val = clamp(sample_val * 0.75, -0.95, 0.95)
		byte_data.encode_s16(i * 2, int(sample_val * 32767.0))
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	return stream

# Separate spatial voices keep machinery feedback audible without stealing pop voices.
var interaction_voices: Array[AudioStreamPlayer3D] = []
var interaction_streams: Dictionary = {}
var interaction_times: Dictionary = {}
var interaction_voice := 0

func play_interaction(kind: String, origin: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - int(interaction_times.get(kind, -1000)) < 90: return
	interaction_times[kind] = now
	if interaction_voices.is_empty():
		for i in range(12):
			var voice := AudioStreamPlayer3D.new()
			voice.max_distance = 28.0
			voice.unit_size = 5.0
			voice.volume_db = -10.0
			add_child(voice)
			interaction_voices.append(voice)
	var voice := interaction_voices[interaction_voice]
	interaction_voice = (interaction_voice + 1) % interaction_voices.size()
	voice.stop()
	voice.global_position = origin
	voice.stream = interaction_streams.get(kind, cached_button_click)
	voice.pitch_scale = 0.85 if kind == "place" else 1.0
	voice.play()

func _control_tone(denied: bool) -> AudioStreamWAV:
	var rate := 22050
	var duration := 0.26
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var time := float(i) / rate
		var segment := fmod(time, 0.13)
		var envelope := sin(clampf(segment / 0.12, 0.0, 1.0) * PI)
		var frequency := (310.0 if time < 0.13 else 230.0) if denied else (620.0 if time < 0.13 else 830.0)
		var sample := sin(time * TAU * frequency) * envelope * 0.22
		bytes.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
