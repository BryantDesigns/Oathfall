extends GutTest

var received_args: Array = []

func _on_enemy_died(xp: int) -> void:
	received_args.append(xp)

func before_each() -> void:
	received_args.clear()

func test_enemy_died_signal_is_defined() -> void:
	assert_true(EventBus.has_signal("enemy_died"), "enemy_died signal must exist")

func test_enemy_died_signal_carries_xp_arg() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.enemy_died.emit(42)
	assert_eq(received_args, [42])
	EventBus.enemy_died.disconnect(_on_enemy_died)

func test_level_up_signal_is_defined() -> void:
	assert_true(EventBus.has_signal("level_up"), "level_up signal must exist")

func test_run_ended_signal_is_defined() -> void:
	assert_true(EventBus.has_signal("run_ended"), "run_ended signal must exist")
