extends CanvasLayer

const NEXT_LEVEL_SCENE := "res://scenes/level_2.tscn"
const MAIN_MENU_SCENE := "res://MenuInicio/control.tscn"
const HOVER_RISE := 3.0
const HOVER_DURATION := 0.12

@onready var interface: Control = $Control
@onready var stars_bar: TextureProgressBar = $Control/CenterContainer/AspectRatioContainer/Control/ProgressBar
@onready var next_level_button: TextureButton = $Control/CenterContainer/AspectRatioContainer/Control/Control/TextureButton
@onready var menu_button: TextureButton = $Control/CenterContainer/AspectRatioContainer/Control/Control/TextureButton2
@onready var restart_button: TextureButton = $Control/CenterContainer/AspectRatioContainer/Control/Control/TextureButton3

var button_base_positions: Dictionary = {}
var button_tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	add_to_group("you_win_screen")
	interface.hide()
	_setup_button(next_level_button, _on_next_level_pressed)
	_setup_button(restart_button, _on_restart_pressed)
	_setup_button(menu_button, _on_main_menu_pressed)


# Conectar clics y el efecto hover.
func _setup_button(button: TextureButton, callback: Callable) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if button.texture_normal != null:
		button.texture_hover = button.texture_normal
		button.texture_pressed = button.texture_normal
	button_base_positions[button] = button.position
	button.pressed.connect(callback)
	button.mouse_entered.connect(_set_button_hover.bind(button, true))
	button.mouse_exited.connect(_set_button_hover.bind(button, false))


# Elevar un poco el botón al pasar el cursor.
func _set_button_hover(button: TextureButton, hovered: bool) -> void:
	if not is_instance_valid(button):
		return
	if button_tweens.has(button):
		var previous_tween: Tween = button_tweens[button] as Tween
		if previous_tween != null and previous_tween.is_running():
			previous_tween.kill()
	var base_position: Vector2 = button_base_positions.get(button, button.position)
	var lift := -HOVER_RISE if hovered else 0.0
	var target_position := base_position + Vector2(0.0, lift)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "position", target_position, HOVER_DURATION)
	button_tweens[button] = tween


# Mostrar la victoria usando la vida que conserva el jugador.
func show_victory(hearts_remaining: int, is_final_level: bool = false) -> void:
	if interface.visible or hearts_remaining <= 0:
		return
	next_level_button.visible = not is_final_level
	stars_bar.call("set_stars", hearts_remaining)
	interface.show()
	get_tree().paused = true


# Avanzar al segundo nivel.
func _on_next_level_pressed() -> void:
	_change_scene(NEXT_LEVEL_SCENE)


# Reiniciar el nivel actual.
func _on_restart_pressed() -> void:
	interface.hide()
	var tree := get_tree()
	tree.paused = false
	var error_code: int = tree.reload_current_scene()
	if error_code != OK:
		push_error("No se pudo reiniciar el nivel: %s" % error_string(error_code))


# Volver al menú principal.
func _on_main_menu_pressed() -> void:
	_change_scene(MAIN_MENU_SCENE)


# Cambiar de escena y reanudar el árbol.
func _change_scene(scene_path: String) -> void:
	interface.hide()
	var tree := get_tree()
	tree.paused = false
	var error_code: int = tree.change_scene_to_file(scene_path)
	if error_code != OK:
		push_error("No se pudo cargar %s: %s" % [scene_path, error_string(error_code)])
