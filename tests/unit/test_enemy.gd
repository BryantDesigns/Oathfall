extends GutTest

func _make_enemy(max_hp: int = 4) -> Enemy:
	var enemy := Enemy.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_hp = max_hp
	enemy.add_child(health)
	enemy.health_path = NodePath("HealthComponent")
	add_child_autofree(enemy)
	return enemy

func test_velocity_toward_points_at_target() -> void:
	var v := Enemy.velocity_toward(Vector2.ZERO, Vector2(100, 0), 70.0)
	assert_almost_eq(v.x, 70.0, 0.001)
	assert_almost_eq(v.y, 0.0, 0.001)

func test_velocity_toward_zero_when_coincident() -> void:
	var v := Enemy.velocity_toward(Vector2(5, 5), Vector2(5, 5), 70.0)
	assert_eq(v, Vector2.ZERO)

func test_apply_difficulty_scales_hp_and_speed() -> void:
	var enemy := _make_enemy(4)
	enemy.move_speed = 70.0
	enemy.apply_difficulty(2.0, 1.5)
	assert_eq(enemy.health.max_hp, 8)
	assert_eq(enemy.health.current_hp, 8)
	assert_almost_eq(enemy.move_speed, 105.0, 0.001)
