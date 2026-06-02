extends GutTest

func test_hitbox_default_damage() -> void:
    var hitbox := HitboxComponent.new()
    assert_eq(hitbox.damage, 1)
    hitbox.free()

func test_hitbox_carries_source() -> void:
    var hitbox := HitboxComponent.new()
    var fake_source := Node.new()
    hitbox.source = fake_source
    assert_same(hitbox.source, fake_source)
    hitbox.free()
    fake_source.free()

func test_hurtbox_routes_damage_to_sibling_health() -> void:
    var owner_node := Node.new()
    add_child_autofree(owner_node)

    var health := HealthComponent.new()
    health.max_hp = 50
    owner_node.add_child(health)

    var hurtbox := HurtboxComponent.new()
    owner_node.add_child(hurtbox)
    hurtbox.health_path = health.get_path()

    var hitbox := HitboxComponent.new()
    hitbox.damage = 7

    # Simulate the area_entered signal directly
    hurtbox._on_area_entered(hitbox)

    assert_eq(health.current_hp, 43)

    hitbox.free()

func test_hurtbox_ignores_damage_when_disabled() -> void:
    var owner_node := Node.new()
    add_child_autofree(owner_node)

    var health := HealthComponent.new()
    health.max_hp = 50
    owner_node.add_child(health)

    var hurtbox := HurtboxComponent.new()
    hurtbox.invulnerable = true
    owner_node.add_child(hurtbox)
    hurtbox.health_path = health.get_path()

    var hitbox := HitboxComponent.new()
    hitbox.damage = 7
    hurtbox._on_area_entered(hitbox)

    assert_eq(health.current_hp, 50)
    hitbox.free()
