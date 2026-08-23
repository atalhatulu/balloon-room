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

func _ready() -> void:
	for i in range(max_channels):
		var player = AudioStreamPlayer.new()
		player.volume_db = -6.5
		add_child(player)
		audio_players.append(player)
		
	# Pre-bake audio streams on startup (Zero CPU calculation during mass pops)
	for freq in warm_notes:
		cached_pops.append(generate_pop_stream(freq))
	cached_zap = generate_zap_stream()
	cached_spike = generate_spike_stream()
	cached_gold = generate_gold_stream()
	cached_bomb = generate_bomb_stream()
	cached_ice = generate_ice_stream()
	cached_plasma = generate_plasma_stream()
	cached_crunch = generate_crunch_stream()

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

func play_pop(combo_level: int = 0) -> void:
	var now = Time.get_ticks_msec()
	if (now - last_pop_time) < 14:
		return
	last_pop_time = now
	
	var player = _get_next_player()
	if not player or cached_pops.is_empty(): return
	var note_idx = combo_level % cached_pops.size()
	player.volume_db = -6.5 + randf_range(-0.5, 0.5)
	player.pitch_scale = randf_range(0.98, 1.02)
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

func play_bomb_pop() -> void:
	var now = Time.get_ticks_msec()
	if (now - last_bomb_time) < 40:
		return
	last_bomb_time = now
	
	var player = _get_next_player()
	if not player or not cached_bomb: return
	player.volume_db = -4.5
	player.pitch_scale = randf_range(0.95, 1.05)
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
