extends GutTest

func _curve() -> DifficultyCurve:
	var curve := DifficultyCurve.new()
	curve.hp_growth_per_wave = 0.25
	curve.speed_growth_per_wave = 0.05
	return curve

func test_wave_zero_is_baseline() -> void:
	var curve := _curve()
	assert_almost_eq(curve.hp_multiplier(0), 1.0, 0.001)
	assert_almost_eq(curve.speed_multiplier(0), 1.0, 0.001)

func test_wave_two_scales() -> void:
	var curve := _curve()
	assert_almost_eq(curve.hp_multiplier(2), 1.5, 0.001)
	assert_almost_eq(curve.speed_multiplier(2), 1.1, 0.001)
