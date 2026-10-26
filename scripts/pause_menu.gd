extends CanvasLayer

const SAVE_WINDOW_PATH := "res://MenuInicio/Ventana_carga.tscn"
const MAIN_MENU_PATH := "res://MenuInicio/control.tscn"

const HOVER_RISE := 3.0
const HOVER_SCALE := 1.035
const HOVER_DURATION := 0.13

@onready var pause_interface: Control = $Interfaz
@onready var dimmer: ColorRect = $Interfaz/Oscurecer
@onready var continue_button: TextureButton = $Interfaz/Centro/Proporcion/Diseño/Botones/Continuar
@onready var save_button: TextureButton = $Interfaz/Centro/Proporcion/Diseño/Botones/Guardar
@onready var load_button: TextureButton = $Interfaz/Centro/Proporcion/Diseño/Botones/Cargar
@onready var menu_button: TextureButton = $Interfaz/Centro/Proporcion/Diseño/Botones/Menu

var saves_window: Window
var button_base_offsets: Dictionary = {}
var button_base_scales: Dictionary = {}
var button_tweens: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	pause_interface.hide()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.45)

	_connect_pause_button(continue_button, _on_continue_pressed)
	_connect_pause_button(save_button, _on_save_pressed)
	_connect_pause_button(load_button, _on_load_pressed)
	_connect_pause_button(menu_button, _on_menu_pressed)
	get_tree().scene_changed.connect(_on_scene_changed)


# Preparar clic, cursor y animación de cada botón.
func _connect_pause_button(button: TextureButton, callback: Callable) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.offset_transform_enabled = true
	button_base_offsets[button] = button.offset_transform_position
	button_base_scales[button] = button.scale

	if button.texture_normal != null:
		button.texture_hover = button.texture_normal
		button.texture_pressed = button.texture_normal

	button.pressed.connect(callback)
	button.mouse_entered.connect(_set_button_hover.bind(button, true))
	button.mouse_exited.connect(_set_button_hover.bind(button, false))


# Elevar un poco el botón al pasar el cursor.
func _set_button_hover(button: TextureButton, hovered: bool) -> void:
	if not is_instance_valid(button):
		return

	if button_tweens.has(button):
		var previous_tween: Tween = button_tweens[button]
		if previous_tween != null and previous_tween.is_running():
			previous_tween.kill()

	button.pivot_offset = button.size * 0.5
	var base_offset: Vector2 = button_base_offsets.get(button, button.offset_transform_position)
	var base_scale: Vector2 = button_base_scales.get(button, button.scale)
	var lift := -HOVER_RISE if hovered else 0.0
	var target_offset := base_offset + Vector2(0.0, lift)
	var target_scale := base_scale * HOVER_SCALE if hovered else base_scale

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "offset_transform_position", target_offset, HOVER_DURATION)
	tween.tween_property(button, "scale", target_scale, HOVER_DURATION)
	button_tweens[button] = tween


# Abrir o cerrar la pausa únicamente con Escape.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_ESCAPE and key_event.physical_keycode != KEY_ESCAPE:
		return

	if is_instance_valid(saves_window) and saves_window.visible:
		saves_window.hide()
		get_viewport().set_input_as_handled()
		return

	if get_tree().get_first_node_in_group("player") == null:
		return

	if get_tree().paused:
		_resume_game()
	else:
		_open_pause()
	get_viewport().set_input_as_handled()


# Mostrar el cartel y detener el árbol del juego.
func _open_pause() -> void:
	pause_interface.show()
	get_tree().paused = true


# Ocultar el cartel y reanudar el juego.
func _resume_game() -> void:
	pause_interface.hide()
	get_tree().paused = false


# Continuar la partida.
func _on_continue_pressed() -> void:
	_resume_game()


# Guardar un punto nuevo con el sistema de guardado existente.
func _on_save_pressed() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		push_warning("No se encontró el autoload SaveManager.")
		return
	if not bool(save_manager.call("quick_save")):
		push_warning("No se pudo guardar la partida actual.")


# Abrir la ventana de carga existente sobre la pausa.
func _on_load_pressed() -> void:
	if not is_instance_valid(saves_window):
		var packed_scene := load(SAVE_WINDOW_PATH) as PackedScene
		if packed_scene == null:
			push_error("No se pudo cargar la ventana de partidas guardadas.")
			return

		saves_window = packed_scene.instantiate() as Window
		if saves_window == null:
			push_error("La ventana de carga debe tener un nodo Window como raíz.")
			return
		saves_window.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(saves_window)

	saves_window.call_deferred("open_saves")


# Volver al menú principal.
func _on_menu_pressed() -> void:
	_resume_game()
	get_tree().call_deferred("change_scene_to_file", MAIN_MENU_PATH)


# Cerrar la pausa después de cargar o cambiar de escena.
func _on_scene_changed(_scene: Node) -> void:
	pause_interface.hide()
	if get_tree().paused:
		get_tree().paused = false
	if is_instance_valid(saves_window) and saves_window.visible:
		saves_window.hide()
