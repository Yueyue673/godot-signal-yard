extends CharacterBody3D
## Shared controller used by the playable scene and real physics integration tests.

@export var speed := 6.0
@export var acceleration := 25.0
@export var jump_speed := 8.0
@export var gravity := 22.0
var camera: Camera3D
var controlled_by_test := false
var test_direction := Vector3.ZERO
var jump_queued := false

func request_jump() -> void:
	jump_queued = true

func _physics_process(delta: float) -> void:
	var direction := test_direction
	if not controlled_by_test:
		var axis := Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		if camera:
			direction = camera.global_basis.x * axis.x + camera.global_basis.z * axis.y
		else:
			direction = Vector3(axis.x, 0, axis.y)
		direction.y = 0
		direction = direction.limit_length()
		if Input.is_physical_key_pressed(KEY_SPACE):
			request_jump()
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump_queued:
		velocity.y = jump_speed
	jump_queued = false
	move_and_slide()
