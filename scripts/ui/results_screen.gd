class_name ResultsScreen
extends CanvasLayer
## Shown after run_ended. One button: restart.

@onready var _title: Label = $Panel/VBox/Title
@onready var _play_again_button: Button = $Panel/VBox/PlayAgain

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().paused = true
    _title.text = tr("RESULTS_DEFEAT")
    _play_again_button.text = tr("RESULTS_PLAY_AGAIN")
    _play_again_button.pressed.connect(_restart)

func _restart() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()
