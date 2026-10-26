extends CanvasLayer

const MAIN_MENU_SCENE := "res://MenuInicio/control.tscn"
const HOVER_RISE := 3.0
const HOVER_DURATION := 0.12

@onready var interface: Control = $Interfaz
@onready var restart_button: TextureButton = $Interfaz/Centro/Propocion/Contenido/Reiniciar
@onready var menu_button: TextureButton = $Interfaz/Centro/Propocion/Contenido/Menu

var button_base_positions: Dictionary = {}
var button_tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	interface.hide()
	_setup_button(restart_button, _restart_level)
	_setup_button(menu_button, _return_to_menu)


# Conectar el clic y el efecto hover.
func _setup_button(button: TextureButton, callback: Callable) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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


# Mostrar la ventana solo cuando el jugador muere.
func show_game_over() -> void:
	if interface.visible:
		return
	interface.show()
	get_tree().paused = true


# Reiniciar la escena actual.
func _restart_level() -> void:
	interface.hide()
	var tree := get_tree()
	var active_scene := tree.current_scene
	if active_scene != null and active_scene.scene_file_path.ends_with("level01.tscn"):
		QuestManager.reset_rock_quest()
	tree.paused = false
	var error_code: int = tree.reload_current_scene()
	if error_code != OK:
		push_error("No se pudo reiniciar la escena actual: %s" % error_string(error_code))


# Volver al menú principal.
func _return_to_menu() -> void:
	interface.hide()
	var tree := get_tree()
	tree.paused = false
	var error_code: int = tree.change_scene_to_file(MAIN_MENU_SCENE)
	if error_code != OK:
		push_error("No se pudo abrir el menú principal: %s" % error_string(error_code))
