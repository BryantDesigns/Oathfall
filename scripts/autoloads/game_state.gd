extends Node
## In-flight run state: which hero, seed, run-scoped counters.
## Persists no data — that's SaveManager's job.

var hero_id: String = ""
var current_seed: int = 0
var run_in_progress: bool = false
var current_level: int = 1
var current_xp: int = 0

func reset() -> void:
    hero_id = ""
    current_seed = 0
    run_in_progress = false
    current_level = 1
    current_xp = 0

func start_run(hero: String, seed: int) -> void:
    reset()
    hero_id = hero
    current_seed = seed
    run_in_progress = true
    RNG.seed(seed)

func end_run(won: bool) -> void:
    run_in_progress = false
    EventBus.run_ended.emit(won)
