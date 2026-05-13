extends GutTest

func _make_xp_component() -> XpComponent:
	var xp_component := XpComponent.new()
	xp_component.curve = XpCurve.new()
	return xp_component

func test_starts_level_1_zero_xp() -> void:
	var xp_component := _make_xp_component()
	assert_eq(xp_component.level, 1)
	assert_eq(xp_component.total_xp, 0)

func test_gain_xp_under_threshold_no_levelup() -> void:
	var xp_component := _make_xp_component()
	watch_signals(xp_component)
	xp_component.gain_xp(5)
	assert_eq(xp_component.total_xp, 5)
	assert_eq(xp_component.level, 1)
	assert_signal_emit_count(xp_component, "leveled_up", 0)

func test_gain_xp_crosses_threshold_levels_up() -> void:
	var xp_component := _make_xp_component()
	watch_signals(xp_component)
	xp_component.gain_xp(10)
	assert_eq(xp_component.level, 2)
	assert_signal_emit_count(xp_component, "leveled_up", 1)
	assert_signal_emitted_with_parameters(xp_component, "leveled_up", [2])

func test_gain_xp_can_skip_multiple_levels() -> void:
	var xp_component := _make_xp_component()
	watch_signals(xp_component)
	xp_component.gain_xp(35)  # crosses level 2 (10) and level 3 (30)
	assert_eq(xp_component.level, 3)
	assert_signal_emit_count(xp_component, "leveled_up", 2)
