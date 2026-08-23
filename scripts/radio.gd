extends Node

# Procedural Cozy Radio / Background Music Synthesizer
# Plays relaxing Lo-Fi / Ambient chord progressions without external audio assets

signal track_changed(track_name: String, is_playing: bool)

var current_station: int = 1 # 0: Off, 1: Cozy Lo-Fi, 2: Ambient Chill, 3: Synthwave Pop
var is_playing: bool = true

var music_player: AudioStreamPlayer
var sample_rate: int = 22050
var playback_timer: float = 0.0
var step_index: int = 0
var tempo_interval: float = 0.42 # Beats tempo

# Chord Progressions (Frequencies in Hz)
# Progression A (Lo-Fi Dream): Cmaj7 -> Am7 -> Dm7 -> G7
var lofi_chords: Array = [
	[261.63, 329.63, 392.00, 493.88], # Cmaj7
	[220.00, 261.63, 329.63, 392.00], # Am7
	[146.83, 220.00, 261.63, 349.23], # Dm7
	[196.00, 246.94, 293.66, 349.23]  # G7
]

# Basslines
var lofi_bass: Array = [130.81, 110.00, 73.42, 98.00]

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -12.0
	add_child(music_player)
	emit_station_info()

func _process(delta: float) -> void:
	if not is_playing or current_station == 0:
		return
		
	playback_timer += delta
	if playback_timer >= tempo_interval:
		playback_timer = 0.0
		play_next_step()

func next_station() -> void:
	current_station = (current_station + 1) % 4
	is_playing = current_station != 0
	emit_station_info()

func toggle_play() -> void:
	if current_station == 0:
		current_station = 1
		is_playing = true
	else:
		is_playing = not is_playing
	emit_station_info()

func set_station(station_idx: int) -> void:
	current_station = clamp(station_idx, 0, 3)
	is_playing = current_station != 0
	emit_station_info()

func emit_station_info() -> void:
	var names = ["KAPALI", "Radyo 1: Cozy Lo-Fi", "Radyo 2: Gece Ambiyansı", "Radyo 3: Arcade Synth"]
	var station_name = names[current_station] if is_playing else "DURAKLATILDI"
	track_changed.emit(station_name, is_playing and current_station != 0)

func play_next_step() -> void:
	var chord_idx = (step_index / 4) % lofi_chords.size()
	var chord_notes = lofi_chords[chord_idx]
	var bass_note = lofi_bass[chord_idx]
	var beat = step_index % 4
	
	step_index = (step_index + 1) % 16
	
	# Generate a soft composite chord buffer
	var duration = tempo_interval * 0.92
	var total_frames = int(sample_rate * duration)
	var byte_data = PackedByteArray()
	byte_data.resize(total_frames)
	
	var is_bass_beat = (beat == 0 or beat == 2)
	
	for i in range(total_frames):
		var t = float(i) / float(sample_rate)
		var envelope = exp(-t * 3.2) # Soft pad/piano decay
		
		# Mix chords with soft warm sines
		var sample_val = 0.0
		for note in chord_notes:
			sample_val += sin(t * note * TAU) * 0.16
			
		# Add soft bassline
		if is_bass_beat:
			var bass_env = exp(-t * 5.0)
			sample_val += sin(t * bass_note * TAU) * 0.35 * bass_env
			
		# Add gentle vinyl crackle / texture
		if current_station == 1 and randf() < 0.008:
			sample_val += randf_range(-0.15, 0.15)
			
		sample_val = clamp(sample_val * envelope, -1.0, 1.0)
		var byte_val = int((sample_val + 1.0) * 0.5 * 255.0)
		byte_data[i] = byte_val
		
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = byte_data
	
	music_player.stream = stream
	music_player.play()
