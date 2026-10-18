extends Node3D
## Small original prototype; not the buyer's checkpoint/respawn assessment.

const COURIER = preload("res://player.tscn")
const RELAY = preload("res://scripts/relay_pad.gd")
var player: CharacterBody3D
var relays: Array[Area3D] = []
var collected: Dictionary = {}
var delivery_timer: Timer
var completed := false
var expired := false
var exit_area: Area3D
var counter: Label
var clock_label: Label
var state_label: Label
var capture_ticks := 0

func material(color: Color, glow := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.75
	if glow:
		result.emission_enabled = true
		result.emission = color * 0.45
	return result

func box(center: Vector3, size: Vector3, color: Color, solid := true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.position = center
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material(color)
	body.add_child(visual)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	add_child(body)
	return body

func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("111d30")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("a1b6d8")
	world.environment.ambient_light_energy = 0.6
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58, -30, 0)
	light.light_color = Color("fff3da")
	light.light_energy = 1.3
	light.shadow_enabled = true
	add_child(light)
	box(Vector3(0, -0.45, 0), Vector3(19, 0.9, 14), Color("c0c8ce"))
	# Low perimeter walls keep this small scene bounded.
	box(Vector3(-9.2, 0.45, 0), Vector3(0.4, 0.9, 14), Color("34465e"))
	box(Vector3(9.2, 0.45, 0), Vector3(0.4, 0.9, 14), Color("34465e"))
	box(Vector3(0, 0.45, -6.8), Vector3(18, 0.9, 0.4), Color("34465e"))
	box(Vector3(0, 0.45, 6.8), Vector3(18, 0.9, 0.4), Color("34465e"))
	# Walk/jump obstacles are independent of the client's assessment repository.
	box(Vector3(-0.8, 0.25, 1.0), Vector3(1.4, 0.5, 3.0), Color("8497aa"))
	box(Vector3(2.2, 0.5, -0.8), Vector3(1.7, 1.0, 1.8), Color("657e99"))
	for z in [-4.5, -2.5, -0.5, 1.5, 3.5, 5.5]:
		box(Vector3(-6.2, 0.015, z), Vector3(0.08, 0.03, 0.8), Color("e9eff2"), false)
	for index in range(2):
		var point := Vector3(-4.0, 0, -2.5) if index == 0 else Vector3(5.0, 0, 2.0)
		box(point + Vector3(0, 0.04, 0), Vector3(1.7, 0.08, 1.7), Color("e99745"), false)
		var relay := Area3D.new()
		relay.set_script(RELAY)
		relay.relay_key = "A" if index == 0 else "B"
		relay.position = point
		relay.collected.connect(_on_collect)
		add_child(relay)
		relays.append(relay)
		var number := Label3D.new()
		number.text = "0%d" % (index + 1)
		number.position = point + Vector3(0, 2.1, 0)
		number.font_size = 70
		number.pixel_size = 0.008
		number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		number.modulate = Color("fff2d7")
		add_child(number)
	exit_area = Area3D.new()
	exit_area.position = Vector3(0, 0, -5.1)
	exit_area.collision_layer = 0
	exit_area.collision_mask = 2
	var exit_shape := CollisionShape3D.new()
	var exit_box := BoxShape3D.new()
	exit_box.size = Vector3(2.2, 2, 1.5)
	exit_shape.shape = exit_box
	exit_shape.position.y = 0.8
	exit_area.add_child(exit_shape)
	exit_area.body_entered.connect(_on_exit_entered)
	add_child(exit_area)
	box(Vector3(0, 0.04, -5.1), Vector3(2.2, 0.08, 1.5), Color("49bbb0"), false)
	var exit_text := Label3D.new()
	exit_text.text = "DELIVERY"
	exit_text.position = Vector3(0, 1.9, -5.1)
	exit_text.font_size = 56
	exit_text.pixel_size = 0.008
	exit_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	exit_text.modulate = Color("85eee2")
	add_child(exit_text)
	var camera := Camera3D.new()
	camera.position = Vector3(13, 16, 19)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 23
	add_child(camera)
	camera.look_at(Vector3(0, 0, 0))
	camera.current = true
	player = COURIER.instantiate()
	player.position = Vector3(-5, 0.15, 4)
	player.camera = camera
	add_child(player)
	delivery_timer = Timer.new()
	delivery_timer.one_shot = true
	delivery_timer.wait_time = 30
	delivery_timer.timeout.connect(_on_timeout)
	add_child(delivery_timer)
	_build_hud()
	_refresh_hud()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var top := VBoxContainer.new()
	top.position = Vector2(44, 32)
	top.add_theme_constant_override("separation", 7)
	layer.add_child(top)
	var eyebrow := Label.new()
	eyebrow.text = "GODOT 4  /  ORIGINAL PLAYABLE PROTOTYPE"
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.modulate = Color("a8bfd8")
	top.add_child(eyebrow)
	var title := Label.new()
	title.text = "SIGNAL YARD"
	title.add_theme_font_size_override("font_size", 42)
	top.add_child(title)
	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 18)
	top.add_child(state_label)
	counter = Label.new()
	counter.position = Vector2(1024, 42)
	counter.add_theme_font_size_override("font_size", 26)
	counter.modulate = Color("ffcb83")
	layer.add_child(counter)
	clock_label = Label.new()
	clock_label.position = Vector2(1024, 78)
	clock_label.add_theme_font_size_override("font_size", 17)
	layer.add_child(clock_label)
	var footer := Label.new()
	footer.text = "W A S D   Move       SPACE   Jump       R   Restart       |       Collect both amber signals, then reach DELIVERY."
	footer.position = Vector2(44, 746)
	footer.add_theme_font_size_override("font_size", 16)
	footer.modulate = Color("c0d0df")
	layer.add_child(footer)

func _on_collect(key: String) -> void:
	if completed or expired or collected.has(key):
		return
	collected[key] = true
	if collected.size() == 1:
		delivery_timer.start()
	_refresh_hud()

func _on_exit_entered(body: Node3D) -> void:
	if body != player or collected.size() != 2 or expired:
		return
	completed = true
	delivery_timer.stop()
	_refresh_hud()

func _on_timeout() -> void:
	if not completed:
		expired = true
	_refresh_hud()

func _refresh_hud() -> void:
	if not counter:
		return
	counter.text = "%02d / 02 SIGNALS" % collected.size()
	if completed:
		state_label.text = "Delivery complete. Press R to run again."
	elif expired:
		state_label.text = "Delivery window closed. Press R to try again."
	elif collected.is_empty():
		state_label.text = "Find the two amber signals. The clock starts at your first pickup."
	else:
		state_label.text = "Both signals to the green delivery pad — before the clock runs out."

func _process(_delta: float) -> void:
	if clock_label:
		clock_label.text = "%02d SECONDS" % ceili(delivery_timer.time_left) if not delivery_timer.is_stopped() else "READY" if not completed and not expired else "COMPLETE" if completed else "TIME OUT"
	if Input.is_physical_key_pressed(KEY_R):
		get_tree().reload_current_scene()
	if "--capture" in OS.get_cmdline_user_args():
		capture_ticks += 1
		if capture_ticks == 45:
			_capture.call_deferred()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png("res://evidence/preview.png")
	print("CAPTURE_RESULT=", result)
	get_tree().quit(0 if result == OK else 1)
