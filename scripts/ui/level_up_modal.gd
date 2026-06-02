class_name LevelUpModal
extends CanvasLayer
## Pause-modal upgrade chooser. Three Buttons; clicking one applies the
## chosen Upgrade to the hero and resumes the game.

signal upgrade_chosen(upgrade: Upgrade)

const POOL: Array[String] = [
	"res://resources/upgrades/upgrade_hp.tres",
	"res://resources/upgrades/upgrade_damage.tres",
	"res://resources/upgrades/upgrade_speed.tres",
]

@onready var _title: Label = $Panel/VBox/Title
@onready var _buttons: Array[Button] = [
	$Panel/VBox/Option1,
	$Panel/VBox/Option2,
	$Panel/VBox/Option3,
]

var _options: Array[Upgrade] = []

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for button_index in _buttons.size():
		var captured_index := button_index
		_buttons[button_index].pressed.connect(func(): _choose(captured_index))

func open() -> void:
	_title.text = tr("LEVELUP_TITLE")
	_options = _roll_options()
	for button_index in _buttons.size():
		_buttons[button_index].text = _options[button_index].description
	show()
	get_tree().paused = true

func _close() -> void:
	get_tree().paused = false
	hide()

func _roll_options() -> Array[Upgrade]:
	var pool := POOL.duplicate()
	var picked_upgrades: Array[Upgrade] = []
	var pick_count: int = min(3, pool.size())
	for _i in pick_count:
		var random_index := RNG.randi_range(0, pool.size() - 1)
		picked_upgrades.append(load(pool[random_index]) as Upgrade)
		pool.remove_at(random_index)
	return picked_upgrades

func _choose(option_index: int) -> void:
	var chosen_upgrade := _options[option_index]
	upgrade_chosen.emit(chosen_upgrade)
	_close()
