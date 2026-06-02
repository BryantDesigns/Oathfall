extends Node
## Single source of randomness. Gameplay code MUST use this and never
## call randi() / randf() directly, so runs are reproducible from a seed.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var current_seed: int = 0

func _ready() -> void:
    seed(Time.get_ticks_usec())

func seed(value: int) -> void:
    current_seed = value
    _rng.seed = value

func randi() -> int:
    return _rng.randi()

func randf() -> float:
    return _rng.randf()

func randi_range(min_value: int, max_value: int) -> int:
    return _rng.randi_range(min_value, max_value)

func randf_range(min_value: float, max_value: float) -> float:
    return _rng.randf_range(min_value, max_value)

func pick(arr: Array) -> Variant:
    if arr.is_empty():
        return null
    return arr[_rng.randi_range(0, arr.size() - 1)]
