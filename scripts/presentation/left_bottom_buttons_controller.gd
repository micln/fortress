class_name LeftBottomButtonsController
extends HBoxContainer

signal pause_requested
signal restart_requested
signal home_requested

@onready var pause_button: Button = $PauseButton
@onready var restart_button: Button = $RestartButton
@onready var home_button: Button = $HomeButton


func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	home_button.pressed.connect(_on_home_pressed)


func set_game_active(game_started: bool, game_over: bool) -> void:
	pause_button.disabled = game_over or not game_started


func _on_pause_pressed() -> void:
	pause_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_home_pressed() -> void:
	home_requested.emit()
