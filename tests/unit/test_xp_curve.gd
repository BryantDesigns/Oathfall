extends GutTest

func test_threshold_for_level_1_is_10() -> void:
    var curve := XpCurve.new()
    assert_eq(curve.threshold_to_reach(2), 10)

func test_threshold_for_level_3_is_30() -> void:
    var curve := XpCurve.new()
    assert_eq(curve.threshold_to_reach(3), 30)

func test_threshold_for_level_5_is_100() -> void:
    var curve := XpCurve.new()
    # 10 * 4 * 5 / 2 = 100
    assert_eq(curve.threshold_to_reach(5), 100)

func test_level_at_total_xp() -> void:
    var curve := XpCurve.new()
    assert_eq(curve.level_at_total_xp(0), 1)
    assert_eq(curve.level_at_total_xp(9), 1)
    assert_eq(curve.level_at_total_xp(10), 2)
    assert_eq(curve.level_at_total_xp(29), 2)
    assert_eq(curve.level_at_total_xp(30), 3)
