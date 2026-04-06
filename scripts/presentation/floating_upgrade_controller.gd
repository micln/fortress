class_name FloatingUpgradeController
extends PanelContainer

signal upgrade_requested(city_id: int, upgrade_type: String)

const NARROW_OVERLAY_BREAKPOINT: float = 520.0

var _city_id: int = -1
var _camera_controller = null

@onready var upgrade_level_button: Button = $FloatingUpgradeRow/LevelButton
@onready var upgrade_defense_button: Button = $FloatingUpgradeRow/DefenseButton
@onready var upgrade_production_button: Button = $FloatingUpgradeRow/ProductionButton


func _ready() -> void:
	upgrade_level_button.pressed.connect(_on_level_pressed)
	upgrade_defense_button.pressed.connect(_on_defense_pressed)
	upgrade_production_button.pressed.connect(_on_production_pressed)
	get_window().size_changed.connect(_on_window_size_changed)


func setup(city_id: int, camera) -> void:
	_city_id = city_id
	_camera_controller = camera


func show_for_city(city, camera, selected: bool, game_over: bool, game_started: bool, order_dialog_visible: bool, manual_paused: bool) -> void:
	if not selected or game_over or not game_started or order_dialog_visible or manual_paused:
		visible = false
		upgrade_level_button.disabled = true
		upgrade_defense_button.disabled = true
		upgrade_production_button.disabled = true
		upgrade_level_button.text = "升级"
		upgrade_defense_button.text = "升防"
		upgrade_production_button.text = "升产"
		return

	if city.owner != 1:  # Not player
		visible = false
		return

	var options: Dictionary = _get_upgrade_options(city)
	_apply_upgrade_button_state(upgrade_level_button, city, options.get("level", {}), "升级")
	_apply_upgrade_button_state(upgrade_defense_button, city, options.get("defense", {}), "升防")
	_apply_upgrade_button_state(upgrade_production_button, city, options.get("production", {}), "升产")
	_position_panel(camera.world_to_screen(city.position))
	visible = true


func _get_upgrade_options(city) -> Dictionary:
	# This will be connected to the battle service from the main controller
	# For now, return a basic structure
	return {}


func _apply_upgrade_button_state(button: Button, city, option: Dictionary, fallback_label: String) -> void:
	var available: bool = option.get("available", false)
	var cost: int = option.get("cost", 0)
	button.text = "%s-%d" % [fallback_label, cost] if available else "%s已满" % fallback_label
	button.disabled = not available or city.soldiers < cost


func _position_panel(city_position: Vector2) -> void:
	var panel_size: Vector2 = size
	if panel_size == Vector2.ZERO:
		panel_size = Vector2(180.0, 42.0)
	var viewport_size: Vector2 = get_viewport_rect().size
	var visible_rect := Rect2(Vector2.ZERO, viewport_size)
	if not visible_rect.grow(60.0).has_point(city_position):
		visible = false
		return
	var desired_position := city_position + Vector2(45.0, -22.0)
	var clamped_x: float = clamp(desired_position.x, 10.0, viewport_size.x - panel_size.x - 10.0)
	var clamped_y: float = clamp(desired_position.y, 80.0, viewport_size.y - panel_size.y - 50.0)
	position = Vector2(clamped_x, clamped_y)


func _on_window_size_changed() -> void:
	_apply_layout()


func _apply_layout() -> void:
	# Layout adjustments for narrow viewports
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size.x <= NARROW_OVERLAY_BREAKPOINT:
		# Mobile adjustments if needed
		pass


func _on_level_pressed() -> void:
	if _city_id >= 0:
		upgrade_requested.emit(_city_id, "level")


func _on_defense_pressed() -> void:
	if _city_id >= 0:
		upgrade_requested.emit(_city_id, "defense")


func _on_production_pressed() -> void:
	if _city_id >= 0:
		upgrade_requested.emit(_city_id, "production")
