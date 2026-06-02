extends Node
## Global signal hub. Systems emit and listen here to avoid hard coupling.
##
## Convention: signals are past-tense (something happened) or imperative
## verbs for requests. Always document each signal's payload.

## Emitted when an enemy dies. xp is the amount granted to the player.
signal enemy_died(xp: int)

## Emitted when the player levels up. new_level is the level just reached.
signal level_up(new_level: int)

## Emitted when a run ends, win or loss. won is true on victory.
signal run_ended(won: bool)
