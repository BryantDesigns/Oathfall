extends GutTest

func before_each() -> void:
    GameState.reset()

func test_reset_clears_run_state() -> void:
    GameState.hero_id = "dreadhunter"
    GameState.current_seed = 999
    GameState.reset()
    assert_eq(GameState.hero_id, "")
    assert_eq(GameState.current_seed, 0)
    assert_false(GameState.run_in_progress)

func test_start_run_sets_state() -> void:
    GameState.start_run("dreadhunter", 12345)
    assert_eq(GameState.hero_id, "dreadhunter")
    assert_eq(GameState.current_seed, 12345)
    assert_true(GameState.run_in_progress)

func test_start_run_seeds_rng() -> void:
    GameState.start_run("dreadhunter", 777)
    assert_eq(RNG.current_seed, 777)

func test_end_run_clears_in_progress() -> void:
    GameState.start_run("dreadhunter", 1)
    GameState.end_run(true)
    assert_false(GameState.run_in_progress)
