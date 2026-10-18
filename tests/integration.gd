extends SceneTree
## Exercises the actual CharacterBody3D, Area3D and Timer, including denial paths.

const SCENE = preload("res://main.tscn")
var results: Array[Dictionary] = []
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func ticks(count: int) -> void:
	for index in range(count):
		await physics_frame

func check(label: String, passed: bool) -> void:
	results.append({"name": label, "passed": passed})
	print("PASS " if passed else "FAIL ", label)
	if not passed:
		failures += 1

func _run() -> void:
	var yard = SCENE.instantiate()
	root.add_child(yard)
	yard.player.controlled_by_test = true
	await ticks(45)
	check("gravity settles courier on the real floor", yard.player.is_on_floor() and absf(yard.player.position.y) < 0.1)
	yard.player.request_jump()
	await ticks(12)
	check("jump leaves the floor", yard.player.position.y > 0.5 and not yard.player.is_on_floor())
	await ticks(70)
	check("jump returns to a stable landing", yard.player.is_on_floor() and absf(yard.player.position.y) < 0.1)
	yard.player.position = Vector3(8, 0.1, 4)
	yard.player.test_direction = Vector3.RIGHT
	await ticks(45)
	check("solid perimeter stops sustained horizontal motion", yard.player.position.x < 8.9 and yard.player.is_on_wall())
	yard.player.test_direction = Vector3.ZERO
	yard.player.velocity = Vector3.ZERO
	yard.player.position = yard.exit_area.position + Vector3(0, 0.1, 0)
	await ticks(6)
	check("exit before both pickups does not complete route", not yard.completed)
	var outsider := Node3D.new()
	root.add_child(outsider)
	yard.relays[0]._on_body_entered(outsider)
	check("unrelated body cannot claim a pickup", not yard.relays[0].claimed and yard.collected.is_empty())
	outsider.queue_free()
	yard.player.position = yard.relays[0].position + Vector3(0, 0.1, 0)
	await ticks(6)
	check("physical pickup signal updates count and starts timer", yard.collected.size() == 1 and not yard.delivery_timer.is_stopped())
	yard.relays[0]._on_body_entered(yard.player)
	check("duplicate overlap cannot double-count a pickup", yard.collected.size() == 1)
	yard.player.position = yard.relays[1].position + Vector3(0, 0.1, 0)
	await ticks(6)
	yard.player.position = yard.exit_area.position + Vector3(0, 0.1, 0)
	await ticks(6)
	check("both physical pickups plus exit complete and stop timer", yard.collected.size() == 2 and yard.completed and yard.delivery_timer.is_stopped())
	yard.queue_free()
	await process_frame
	var timed_yard = SCENE.instantiate()
	root.add_child(timed_yard)
	timed_yard.player.controlled_by_test = true
	timed_yard.delivery_timer.start(0.03)
	await ticks(8)
	timed_yard._on_collect("A")
	timed_yard._on_collect("B")
	timed_yard._on_exit_entered(timed_yard.player)
	check("real Timer timeout prevents late completion", timed_yard.expired and not timed_yard.completed and timed_yard.collected.is_empty())
	var report := {"engine": Engine.get_version_info().string, "platform": OS.get_name(), "run_at_utc": Time.get_datetime_string_from_system(true), "passed": results.size() - failures, "failed": failures, "checks": results, "scope": "Engine integration with real physics and timers; synthetic input. No client or browser testing claimed."}
	var file := FileAccess.open("res://evidence/integration-results.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	timed_yard.queue_free()
	quit(0 if failures == 0 else 1)
