class_name AimProvider
extends RefCounted
## Returns a continuous aim vector. Concrete impls per input device.
## MouseAimProvider for desktop; VirtualStickAimProvider added in M3 for mobile.

## Returns the world-space point the player is aiming at, relative to the
## supplied origin. The hero passes its global_position as origin.
func aim_world_point(_origin: Vector2) -> Vector2:
    push_error("AimProvider.aim_world_point() must be overridden")
    return Vector2.ZERO

## Convenience: unit vector from origin toward aim point. Returns RIGHT
## as a safe default if origin == aim point.
func aim_direction(origin: Vector2) -> Vector2:
    var aim_target := aim_world_point(origin)
    var offset := aim_target - origin
    if offset.length_squared() < 0.001:
        return Vector2.RIGHT
    return offset.normalized()
