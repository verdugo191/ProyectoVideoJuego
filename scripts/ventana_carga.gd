extends Window

@onready var saves_list: ItemList = $Control/ItemList
@onready var close_button: TextureButton = $Control/TextureButton
@onready var load_button: Button = $Control/LoadButton
@onready var delete_button: Button = $Control/DeleteButton

var delete_confirmation: ConfirmationDialog
var selected_delete_slot: int = -1


func _ready() -> void:
	transient = true
	borderless = true
	transparent = true
	transparent_bg = true
	close_requested.connect(hide)
	close_button.pressed.connect(hide)
	load_button.pressed.connect(_load_selected_save)
	delete_button.pressed.connect(_confirm_delete_selected_save)
	saves_list.item_selected.connect(_on_save_selected)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_set_button_style(load_button)
	_set_button_style(delete_button)
	_set_list_style()
	_create_delete_confirmation()


# Mostrar la ventana y refrescar las ranuras disponibles.
func open_saves() -> void:
	_refresh_saves_list()
	popup_centered()


# Dar estilo a los botones de acción.
func _set_button_style(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("#fff1c8"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffe08a"))
	button.add_theme_color_override("font_outline_color", Color("#351508"))
	button.add_theme_constant_override("outline_size", 3)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#7a3512")
	normal.border_color = Color("#f2a72d")
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(9)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	button.add_theme_stylebox_override("normal", normal)

	var hovered := normal.duplicate() as StyleBoxFlat
	hovered.bg_color = Color("#a64e17")
	button.add_theme_stylebox_override("hover", hovered)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#54230e")
	button.add_theme_stylebox_override("pressed", pressed)


# Mantener la lista integrada visualmente con el panel.
func _set_list_style() -> void:
	saves_list.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	saves_list.add_theme_font_size_override("font_size", 18)
	saves_list.add_theme_color_override("font_color", Color("#fff0cf"))
	saves_list.add_theme_color_override("font_hovered_color", Color("#ffffff"))
	saves_list.add_theme_color_override("font_selected_color", Color("#ffffff"))

	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color(0.78, 0.38, 0.08, 0.68)
	selected_style.set_corner_radius_all(6)
	saves_list.add_theme_stylebox_override("selected", selected_style)


# Configurar el diálogo para confirmar eliminaciones.
func _create_delete_confirmation() -> void:
	delete_confirmation = ConfirmationDialog.new()
	delete_confirmation.title = "Borrar partida"
	delete_confirmation.dialog_text = "¿Quieres borrar esta partida guardada?"
	delete_confirmation.confirmed.connect(_delete_selected_save)
	add_child(delete_confirmation)


# Cargar las partidas guardadas en la lista.
func _refresh_saves_list() -> void:
	saves_list.clear()
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		push_warning("No se encontró el autoload SaveManager.")
		_set_action_buttons_enabled(false)
		return

	var saves: Array = save_manager.call("get_saved_games")
	for index in range(saves.size() - 1, -1, -1):
		var data: Dictionary = saves[index]
		var slot_id := int(data.get("slot_id", 0))
		var level_path := str(data.get("level_path", ""))
		var level_name := "Nivel 2" if level_path.contains("level_2") else "Nivel 1"
		var dog_state: Dictionary = data.get("dog", {})
		var dog_health := int(dog_state.get("health", -1))
		var details := "Corazones del perro: %d" % dog_health if dog_health >= 0 else "Progreso guardado"
		var saved_at := str(data.get("saved_at", ""))
		var label := "Partida %d — %s — %s" % [slot_id, level_name, details]
		if not saved_at.is_empty():
			label += " — " + saved_at
		var item_index := saves_list.add_item(label)
		saves_list.set_item_metadata(item_index, slot_id)

	if saves_list.item_count == 0:
		saves_list.add_item("No hay partidas guardadas todavía.")
		saves_list.set_item_selectable(0, false)
		_set_action_buttons_enabled(false)
		return

	saves_list.select(0)
	_on_save_selected(0)


# Activar los botones cuando hay una partida seleccionada.
func _on_save_selected(index: int) -> void:
	_set_action_buttons_enabled(index >= 0 and index < saves_list.item_count and saves_list.is_item_selectable(index))


func _set_action_buttons_enabled(enabled: bool) -> void:
	load_button.disabled = not enabled
	delete_button.disabled = not enabled


# Cargar la partida seleccionada.
func _load_selected_save() -> void:
	var selected := saves_list.get_selected_items()
	if selected.is_empty():
		return
	var slot_id := int(saves_list.get_item_metadata(selected[0]))
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null or not bool(save_manager.call("load_game", slot_id)):
		_show_notice("No se pudo cargar la partida.")
		return
	hide()


# Pedir confirmación antes de borrar una partida.
func _confirm_delete_selected_save() -> void:
	var selected := saves_list.get_selected_items()
	if selected.is_empty():
		return
	selected_delete_slot = int(saves_list.get_item_metadata(selected[0]))
	delete_confirmation.popup_centered()


# Borrar la partida confirmada y actualizar la lista.
func _delete_selected_save() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if selected_delete_slot > 0 and (save_manager == null or not bool(save_manager.call("delete_save", selected_delete_slot))):
		_show_notice("No se pudo borrar la partida.")
	selected_delete_slot = -1
	_refresh_saves_list()


# Mostrar un aviso breve dentro de la ventana.
func _show_notice(message: String) -> void:
	var notice := AcceptDialog.new()
	notice.dialog_text = message
	add_child(notice)
	notice.confirmed.connect(notice.queue_free)
	notice.canceled.connect(notice.queue_free)
	notice.popup_centered()
