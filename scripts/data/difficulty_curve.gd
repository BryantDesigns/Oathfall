class_name DifficultyCurve
extends Resource
## Per-wave stat multipliers. Closed-form so no per-wave arrays are needed.
## wave_index is 0-based; wave 0 returns the baseline (1.0).

@export var hp_growth_per_wave: float = 0.25    ## +25% enemy HP per wave index
@export var speed_growth_per_wave: float = 0.05 ## +5% enemy move speed per wave index

func hp_multiplier(wave_index: int) -> float:
	return 1.0 + hp_growth_per_wave * float(wave_index)

func speed_multiplier(wave_index: int) -> float:
	return 1.0 + speed_growth_per_wave * float(wave_index)
