class_name OverlayController
extends CanvasLayer

## Overlay Controller - Manages overlay panel content.
## This script should be attached to a CanvasLayer node with this structure:
##   CanvasLayer
##   ├── Shade (ColorRect)
##   └── OverlayPanel (PanelContainer)
##       └── OverlayMargin (MarginContainer)
##           └── OverlayColumn (VBoxContainer)
##               ├── OverlayScroll (ScrollContainer)
##               │   └── OverlayContent (VBoxContainer)
##               │       ├── OverlayTitleLabel (Label)
##               │       ├── OverlayBodyLabel (Label)
##               │       ├── RuleLabel (Label)
##               │       ├── RuleLabel2 (Label)
##               │       ├── RuleLabel3 (Label)
##               │       └── SettingsGrid (GridContainer)
##               │           ├── AiCountOption (OptionButton)
##               │           ├── DifficultyOption (OptionButton)
##               │           └── StyleOption (OptionButton)
##               └── OverlayActionButton (Button)

signal action_button_pressed
signal ai_config_changed(player_count: int, difficulty: String, style: String)

var _mode: String = "start"
var _winner: int = 0

const PLAYER_COUNT_ITEMS: Array = [
	{"id": 2, "name": "2 方"},
	{"id": 3, "name": "3 方"},
	{"id": 4, "name": "4 方"},
	{"id": 5, "name": "5 方"}
]

const AI_DIFFICULTY_ITEMS: Array = [
	{"id": "easy", "name": "简单"},
	{"id": "normal", "name": "普通"},
	{"id": "hard", "name": "困难"}
]

const AI_STYLE_ITEMS: Array = [
	{"id": "aggressive", "name": "进攻型"},
	{"id": "defensive", "name": "防御型"}
]

var _ai_difficulty: String = "easy"
var _ai_style: String = "defensive"
var _player_count: int = 5


func _ready() -> void:
	visible = false


func show_start_panel() -> void:
	_mode = "start"
	visible = true


func show_pause_panel() -> void:
	_mode = "pause"
	visible = true


func show_game_over_panel(winner: int) -> void:
	_mode = "game_over"
	_winner = winner
	visible = true


func hide() -> void:
	visible = false


func set_ai_options(player_count: int, difficulty: String, style: String) -> void:
	_player_count = player_count
	_ai_difficulty = difficulty
	_ai_style = style


func get_mode() -> String:
	return _mode


func get_winner() -> int:
	return _winner


func get_ai_config() -> Dictionary:
	return {
		"player_count": _player_count,
		"difficulty": _ai_difficulty,
		"style": _ai_style
	}
