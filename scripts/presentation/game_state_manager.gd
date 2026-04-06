class_name GameStateManager
extends RefCounted

signal game_started
signal game_over(winner: int)
signal paused
signal resumed
signal overlay_mode_changed(mode: String)
signal state_changed()

var _is_game_over: bool = false
var _game_started: bool = false
var _manual_paused: bool = false
var _overlay_mode: String = "start"  # "start", "play", "pause", "game_over"
var last_winner: int = 0

var _on_game_started: Callable
var _on_game_over: Callable
var _on_game_paused: Callable
var _on_game_resumed: Callable


func setup(on_started: Callable, on_over: Callable, on_paused: Callable, on_resumed: Callable) -> void:
	_on_game_started = on_started
	_on_game_over = on_over
	_on_game_paused = on_paused
	_on_game_resumed = on_resumed


func is_gameplay_active() -> bool:
	return _game_started and not _is_game_over and not _manual_paused and _overlay_mode == "play"


func is_gameplay_paused() -> bool:
	return _manual_paused or _overlay_mode != "play"


func start_game() -> void:
	_game_started = true
	_is_game_over = false
	_manual_paused = false
	_overlay_mode = "play"
	state_changed.emit()
	game_started.emit()
	if _on_game_started:
		_on_game_started.call()


func start_new_match() -> void:
	_is_game_over = false
	_game_started = false
	_manual_paused = false
	_overlay_mode = "start"
	last_winner = 0


func pause_game() -> void:
	if _is_game_over or not _game_started:
		return
	_manual_paused = true
	_overlay_mode = "pause"
	state_changed.emit()
	paused.emit()
	if _on_game_paused:
		_on_game_paused.call()


func resume_game() -> void:
	_manual_paused = false
	_overlay_mode = "play"
	state_changed.emit()
	resumed.emit()
	if _on_game_resumed:
		_on_game_resumed.call()


func set_overlay_mode(mode: String) -> void:
	_overlay_mode = mode
	overlay_mode_changed.emit(mode)
	state_changed.emit()


func trigger_game_over(winner: int) -> void:
	_is_game_over = true
	last_winner = winner
	_overlay_mode = "game_over"
	state_changed.emit()
	game_over.emit(winner)
	if _on_game_over:
		_on_game_over.call(winner)


func get_current_state() -> Dictionary:
	return {
		"game_started": _game_started,
		"game_over": _is_game_over,
		"manual_paused": _manual_paused,
		"overlay_mode": _overlay_mode,
		"last_winner": last_winner,
		"is_active": is_gameplay_active(),
		"is_paused": is_gameplay_paused()
	}


func get_game_over() -> bool:
	return _is_game_over


func get_game_started() -> bool:
	return _game_started


func get_manual_paused() -> bool:
	return _manual_paused


func get_overlay_mode() -> String:
	return _overlay_mode


func set_last_winner(winner: int) -> void:
	last_winner = winner
