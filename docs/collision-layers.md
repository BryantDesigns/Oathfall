# Collision Layers

These map directly to Godot's `collision_layer` and `collision_mask` bitfields.
Keep this doc in sync with all `.tscn` collision_layer / collision_mask values.

| Bit | Layer | Used by |
|---|---|---|
| 1 | 1 | World / walls (StaticBody2D in arena) |
| 2 | 2 | Hero body (CharacterBody2D) |
| 3 | 4 | Enemy body (CharacterBody2D) |
| 4 | 8 | Hero hitbox (Hex-Bolt, Tetherhook) |
| 5 | 16 | Enemy hurtbox |
| 6 | 32 | Enemy hitbox (contact damage) |
| 7 | 64 | Hero hurtbox |
| 8 | 128 | Pickups (XP gems) |

## Common mask combinations

- **Hero body** mask = 1 (collides with walls)
- **Enemy body** mask = 1 (collides with walls)
- **Hero hitbox** mask = 16 (sees enemy hurtboxes)
- **Enemy hitbox** mask = 64 (sees hero hurtbox)
- **XP gem** mask = 2 (sees hero body)
- **Tetherhook** mask = 17 (walls + enemy hurtbox)

Adding a new entity? Pick the right body layer, then set the mask to whatever the body should physically collide with. Hitboxes/Hurtboxes live on their own layers and are masked separately from body collision.
