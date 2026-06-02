extends GutTest

# Inner class for mocking hero properties
class FakeHero extends Node:
    var move_speed: float = 100.0
    var salvo_damage: int = 1
    var health: HealthComponent

func _make_hero():
    var hero := FakeHero.new()
    var health := HealthComponent.new()
    health.max_hp = 100
    hero.add_child(health)
    hero.health = health
    add_child_autofree(hero)
    return hero

func test_hp_upgrade_increases_max_hp() -> void:
    var upgrade = load("res://resources/upgrades/upgrade_hp.tres")
    var hero = _make_hero()
    upgrade.apply(hero)
    assert_eq(hero.health.max_hp, 120)

func test_damage_upgrade_increases_salvo_damage() -> void:
    var upgrade = load("res://resources/upgrades/upgrade_damage.tres")
    var hero = _make_hero()
    upgrade.apply(hero)
    assert_eq(hero.salvo_damage, 2)

func test_speed_upgrade_increases_move_speed() -> void:
    var upgrade = load("res://resources/upgrades/upgrade_speed.tres")
    var hero = _make_hero()
    upgrade.apply(hero)
    assert_almost_eq(hero.move_speed, 115.0, 0.01)

func test_unapply_reverses_apply() -> void:
    var upgrade = load("res://resources/upgrades/upgrade_hp.tres")
    var hero = _make_hero()
    upgrade.apply(hero)
    upgrade.unapply(hero)
    assert_eq(hero.health.max_hp, 100)
