extends GutTest

func _make_health(max_hp: int = 100) -> HealthComponent:
    var health := HealthComponent.new()
    health.max_hp = max_hp
    health.current_hp = max_hp
    return health

func test_starts_full() -> void:
    var health := _make_health(50)
    assert_eq(health.current_hp, 50)
    assert_false(health.is_dead())

func test_take_damage_reduces_hp() -> void:
    var health := _make_health(100)
    health.take_damage(30)
    assert_eq(health.current_hp, 70)

func test_take_damage_clamps_at_zero() -> void:
    var health := _make_health(10)
    health.take_damage(999)
    assert_eq(health.current_hp, 0)
    assert_true(health.is_dead())

func test_heal_does_not_exceed_max() -> void:
    var health := _make_health(100)
    health.current_hp = 50
    health.heal(999)
    assert_eq(health.current_hp, 100)

func test_died_signal_fires_once() -> void:
    var health := _make_health(10)
    watch_signals(health)
    health.take_damage(5)
    assert_signal_emit_count(health, "died", 0)
    health.take_damage(10)
    assert_signal_emit_count(health, "died", 1)
    health.take_damage(10)
    assert_signal_emit_count(health, "died", 1, "died fires only on transition")

func test_health_changed_signal_fires() -> void:
    var health := _make_health(100)
    watch_signals(health)
    health.take_damage(10)
    assert_signal_emitted_with_parameters(health, "health_changed", [90, 100])
