extends GutTest

func test_same_seed_produces_same_sequence() -> void:
    RNG.seed(12345)
    var seq_a := []
    for i in 5:
        seq_a.append(RNG.randi())

    RNG.seed(12345)
    var seq_b := []
    for i in 5:
        seq_b.append(RNG.randi())

    assert_eq(seq_a, seq_b, "Same seed must produce identical sequences")

func test_different_seeds_diverge() -> void:
    RNG.seed(1)
    var a := RNG.randi()
    RNG.seed(2)
    var b := RNG.randi()
    assert_ne(a, b, "Different seeds should produce different first values")

func test_randi_range_inclusive() -> void:
    RNG.seed(42)
    for i in 100:
        var v := RNG.randi_range(5, 10)
        assert_true(v >= 5 and v <= 10, "randi_range must be inclusive on both ends")

func test_randf_unit_interval() -> void:
    RNG.seed(42)
    for i in 100:
        var v := RNG.randf()
        assert_true(v >= 0.0 and v < 1.0, "randf must be in [0.0, 1.0)")

func test_current_seed_readable() -> void:
    RNG.seed(99)
    assert_eq(RNG.current_seed, 99)
