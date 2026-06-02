extends GutTest

func test_returns_three_waves() -> void:
	assert_eq(WaveLibrary.default_waves().size(), 3)

func test_wave_totals_escalate() -> void:
	var waves := WaveLibrary.default_waves()
	assert_eq(waves[0].total_enemy_count(), 8)
	assert_eq(waves[1].total_enemy_count(), 28)
	assert_eq(waves[2].total_enemy_count(), 26)

func test_first_wave_is_rushers_only() -> void:
	var waves := WaveLibrary.default_waves()
	assert_eq(waves[0].entries.size(), 1)

func test_third_wave_has_three_entry_types() -> void:
	var waves := WaveLibrary.default_waves()
	assert_eq(waves[2].entries.size(), 3)
