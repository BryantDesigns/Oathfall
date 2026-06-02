class_name HUD
extends CanvasLayer
## Wires HP and XP bars to the hero's components. Bind via bind_to().

@onready var _hp_bar: ProgressBar = $Margin/VBox/HPBar
@onready var _xp_bar: ProgressBar = $Margin/VBox/XPBar
@onready var _level_label: Label = $Margin/VBox/LevelLabel

var _xp_component: XpComponent

func bind_to(hero: Hero, xp_component: XpComponent) -> void:
	hero.health.health_changed.connect(_on_health_changed)
	_on_health_changed(hero.health.current_hp, hero.health.max_hp)
	_xp_component = xp_component
	xp_component.xp_changed.connect(_on_xp_changed)
	xp_component.leveled_up.connect(_on_leveled_up)
	_on_xp_changed(xp_component.total_xp, xp_component.level)
	_on_leveled_up(xp_component.level)

func _on_health_changed(current: int, maximum: int) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current

func _on_xp_changed(total_xp: int, level: int) -> void:
	if _xp_component == null:
		return
	var level_floor_xp := _xp_component.curve.threshold_to_reach(level)
	var next_level_xp := _xp_component.curve.threshold_to_reach(level + 1)
	_xp_bar.min_value = level_floor_xp
	_xp_bar.max_value = next_level_xp
	_xp_bar.value = total_xp

func _on_leveled_up(level: int) -> void:
	_level_label.text = "%s %d" % [tr("HUD_LEVEL"), level]
