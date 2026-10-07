extends Node3D

var main: Node
var destination := ""
var ring: MeshInstance3D
var transitioning := false
var armed := false
var opening := 0.0

func setup(owner_node: Node, room_id: String) -> void:
	main = owner_node
	destination = room_id
	preload("res://src/environment/interaction_feedback.gd").sound(self, "portal")
	position = Vector3(0, 1.7, 0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("40dfed")
	material.emission_enabled = true
	material.emission = Color("39bcff")
	material.emission_energy_multiplier = 3.0
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.25
	torus.outer_radius = 1.42
	ring.mesh = torus
	ring.material_override = material
	ring.rotation.x = PI / 2
	add_child(ring)
	var surface := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 1.25
	disk.bottom_radius = 1.25
	disk.height = 0.025
	surface.mesh = disk
	surface.rotation.x = PI / 2
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	vec2 p = UV - vec2(0.5);
	float wave = 0.5 + 0.5 * sin(length(p) * 65.0 - TIME * 5.0 + atan(p.y, p.x) * 4.0);
	ALBEDO = mix(vec3(0.04, 0.08, 0.3), vec3(0.12, 0.85, 1.0), wave);
	EMISSION = ALBEDO * 1.5;
}
"""
	var swirl := ShaderMaterial.new()
	swirl.shader = shader
	surface.material_override = swirl
	add_child(surface)
	var light := OmniLight3D.new()
	light.light_color = Color("56bfff")
	light.light_energy = 2.0
	light.omni_range = 6.0
	add_child(light)
	var title := Label3D.new()
	title.text = str(main.shop_manager.rooms[room_id].name).split(" (")[0] + "\nGEÇMEK İÇİN PORTALA GİR"
	title.position.y = 1.9
	title.font_size = 40
	title.pixel_size = 0.004
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(title)
	scale = Vector3.ONE * 0.02
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if not main or transitioning: return
	opening += delta
	ring.rotate_y(delta * 0.4)
	if main.is_loading_save or not main.game_manager.is_game_started or main.player.is_ui_open: return
	var offset: Vector3 = main.player.global_position - global_position
	var distance := Vector2(offset.x, offset.z).length()
	# A portal created around the player must not transport them accidentally.
	if distance > 1.8: armed = true
	if armed and opening >= 0.8 and distance < 1.05 and absf(offset.y) < 2.0:
		enter()

func enter() -> void:
	if transitioning or main.shop_manager.pending_room != destination: return
	preload("res://src/environment/interaction_feedback.gd").sound(self, "confirm")
	transitioning = true
	main.player.set_ui_open(true)
	main.player.velocity = Vector3.ZERO
	var canvas := CanvasLayer.new()
	canvas.layer = 120
	add_child(canvas)
	var fade := ColorRect.new()
	fade.color = Color(0.02, 0.04, 0.08, 0)
	canvas.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.35)
	await tween.finished
	main.factory.complete_room_transfer(destination)
	tween = create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.45)
	await tween.finished
	main.player.set_ui_open(false)
	main.hud_controller.show_prompt("Yeni oda hazır. Kapı yanındaki BAŞLAT düğmesine bas.", 5.0)
	queue_free()
