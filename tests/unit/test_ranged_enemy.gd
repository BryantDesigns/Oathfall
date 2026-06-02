extends GutTest

func _make_ranged() -> RangedEnemy:
	var ranged := RangedEnemy.new()
	ranged.preferred_distance = 180.0
	ranged.distance_buffer = 30.0
	return ranged

func test_intent_approach_when_far() -> void:
	assert_eq(_make_ranged().movement_intent(250.0), 1)

func test_intent_kite_when_close() -> void:
	assert_eq(_make_ranged().movement_intent(100.0), -1)

func test_intent_hold_within_buffer() -> void:
	assert_eq(_make_ranged().movement_intent(180.0), 0)
