extends Area3D
## One-shot pickup: collision events, rather than proximity checks, drive scoring.

signal collected(key: String)
@export var relay_key := "A"
var claimed := false
var orb: MeshInstance3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.8
	cylinder.height = 1.6
	shape.shape = cylinder
	shape.position.y = 0.7
	add_child(shape)
	orb = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.23
	mesh.height = 0.46
	orb.mesh = mesh
	orb.position.y = 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffbd69")
	material.emission_enabled = true
	material.emission = Color("f59a3e")
	material.emission_energy_multiplier = 1.2
	orb.material_override = material
	add_child(orb)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if orb and not claimed:
		orb.rotate_y(delta)

func _on_body_entered(body: Node3D) -> void:
	if claimed or not body.is_in_group("courier"):
		return
	claimed = true
	orb.hide()
	set_deferred("monitoring", false)
	collected.emit(relay_key)
