extends Control

var options_dialog: Window
var saves_window: Window
var selected_delete_slot: int = -1


func _ready() -> void:
	_connect_menu_buttons()


# Conectar los botones visibles de la escena.
func _connect_menu_buttons() -> void:
	_connect_menu_button("VBoxContainer/TextureButton", _on_play_pressed)
	_connect_menu_button("VBoxContainer/TextureButton2", _on_cargar_pressed)
	_connect_menu_button("VBoxContainer/TextureButton3", _on_salir_pressed)
	_connect_menu_button("TextureButton", _on_opcion_pressed, false)


# Enlazar una señal pressed sin duplicar conexiones.
func _connect_menu_button(node_path: NodePath, callback: Callable, scale_on_hover: bool = true) -> void:
	var button := get_node_or_null(node_path) as BaseButton
	if button == null:
		push_warning("No se encontró el botón del menú: %s" % node_path)
		return
	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)
	if not button.mouse_entered.is_connected(_set_menu_button_hover.bind(button, true, scale_on_hover)):
		button.mouse_entered.connect(_set_menu_button_hover.bind(button, true, scale_on_hover))
	if not button.mouse_exited.is_connected(_set_menu_button_hover.bind(button, false, scale_on_hover)):
		button.mouse_exited.connect(_set_menu_button_hover.bind(button, false, scale_on_hover))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


# Resaltar un botón al pasar el cursor.
func _set_menu_button_hover(button: BaseButton, hovered: bool, scale_on_hover: bool) -> void:
	if not is_instance_valid(button):
		return
	var tween := create_tween().set_parallel(true)
	if scale_on_hover:
		button.pivot_offset = button.size * 0.5
		var target_scale := Vector2(1.045, 1.045) if hovered else Vector2.ONE
		tween.tween_property(button, "scale", target_scale, 0.14)
	var target_color := Color(1.15, 1.08, 0.78, 1.0) if hovered else Color.WHITE
	tween.tween_property(button, "self_modulate", target_color, 0.14)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://MenuInicio/tutorial.tscn")


func _on_opcion_pressed() -> void:
	if not is_instance_valid(options_dialog):
		var packed_scene := load("res://MenuInicio/Ventana_opciones.tscn") as PackedScene
		if packed_scene == null:
			push_error("No se pudo cargar la escena de opciones.")
			return
		options_dialog = packed_scene.instantiate() as Window
		if options_dialog == null:
			push_error("La escena de opciones debe tener Window como raíz.")
			return
		add_child(options_dialog)
	options_dialog.call("open_options")


func _on_cargar_pressed() -> void:
	_open_saves_window()

func _on_salir_pressed() -> void:
	get_tree().quit()



# Mostrar y actualizar la lista de partidas guardadas.
func _open_saves_window() -> void:
	if not is_instance_valid(saves_window):
		var packed_scene := load("res://MenuInicio/Ventana_carga.tscn") as PackedScene
		if packed_scene == null:
			push_error("No se pudo cargar la escena de partidas guardadas.")
			return
		saves_window = packed_scene.instantiate() as Window
		if saves_window == null:
			push_error("La escena de partidas guardadas no tiene una raíz Window.")
			return
		add_child(saves_window)
	saves_window.call("open_saves")

func _show_notice(message: String) -> void:
	var notice := AcceptDialog.new()
	notice.dialog_text = message
	add_child(notice)
	notice.confirmed.connect(notice.queue_free)
	notice.canceled.connect(notice.queue_free)
	notice.popup_centered()
