class_name DialogueCanvas
extends CanvasLayer

signal finished
signal choice_selected(choice: String)

@export var margen_inferior: float = 40.0

var panel: PanelContainer
var portrait_rect: TextureRect
var name_label: Label
var dialogue_label: Label
var continue_button: Button
var choice_row: HBoxContainer
var current_choices: Array[String] = []

var current_dialogues: Array[String] = []
var dialogue_index: int = 0
var is_open: bool = false


# Inicializar la interfaz
func _ready() -> void:
	add_to_group("dialogo")
	crear_interfaz()
	panel.hide()


# Crear el panel de diálogo
func crear_interfaz() -> void:
	panel = PanelContainer.new()
	panel.custom_minimum_size.x = 560
	panel.add_theme_stylebox_override("panel", crear_estilo())
	add_child(panel)

	var margen := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 8)
	panel.add_child(margen)

	var contenido := HBoxContainer.new()
	contenido.add_theme_constant_override("separation", 14)
	margen.add_child(contenido)

	portrait_rect = TextureRect.new()
	portrait_rect.custom_minimum_size = Vector2(104, 104)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	contenido.add_child(portrait_rect)

	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	contenido.add_child(caja)

	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 20)
	caja.add_child(name_label)

	dialogue_label = Label.new()
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size.x = 380
	dialogue_label.add_theme_font_size_override("font_size", 18)
	caja.add_child(dialogue_label)

	continue_button = Button.new()
	continue_button.pressed.connect(next_dialogue)
	caja.add_child(continue_button)

	choice_row = HBoxContainer.new()
	choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_row.add_theme_constant_override("separation", 12)
	caja.add_child(choice_row)
	choice_row.hide()

	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -margen_inferior


# Definir el estilo del panel
func crear_estilo() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.12, 0.12, 0.14, 0.92)
	estilo.border_color = Color(0.85, 0.85, 0.85, 0.6)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	return estilo


# Mostrar diálogo normal
func show_dialogue(character_name: String, dialogues: Array[String], portrait: Texture2D = null) -> void:
	if dialogues.is_empty() or is_open:
		return

	current_choices.clear()
	_show_dialogue(character_name, dialogues, portrait)


# Mostrar diálogo con opciones
func show_choice_dialogue(character_name: String, dialogues: Array[String], choices: Array[String], portrait: Texture2D = null) -> void:
	if dialogues.is_empty() or choices.is_empty() or is_open:
		return

	current_choices.assign(choices)
	for child in choice_row.get_children():
		child.queue_free()
	for choice in current_choices:
		var button := Button.new()
		button.text = choice
		button.pressed.connect(_select_choice.bind(choice))
		choice_row.add_child(button)
	_show_dialogue(character_name, dialogues, portrait)


# Preparar los datos del diálogo
func _show_dialogue(character_name: String, dialogues: Array[String], portrait: Texture2D) -> void:
	current_dialogues.assign(dialogues)
	dialogue_index = 0
	is_open = true

	portrait_rect.texture = portrait
	portrait_rect.visible = portrait != null
	name_label.text = character_name
	panel.show()
	_show_line()


# Actualizar la línea visible
func _show_line() -> void:
	dialogue_label.text = current_dialogues[dialogue_index]

	var is_last := dialogue_index == current_dialogues.size() - 1
	var show_choices := is_last and not current_choices.is_empty()
	continue_button.visible = not show_choices
	choice_row.visible = show_choices
	continue_button.text = "Close" if is_last else "Continue"
	if show_choices:
		if choice_row.get_child_count() > 0:
			(choice_row.get_child(0) as Control).grab_focus()
	else:
		continue_button.grab_focus()


# Procesar la opción seleccionada
func _select_choice(choice: String) -> void:
	if not is_open:
		return
	choice_selected.emit(choice)
	close_dialogue()


# Avanzar el diálogo
func next_dialogue() -> void:
	if not is_open:
		return

	dialogue_index += 1

	if dialogue_index >= current_dialogues.size():
		close_dialogue()
		return

	_show_line()


# Cerrar el panel
func close_dialogue() -> void:
	if not is_open:
		return

	panel.hide()
	current_dialogues.clear()
	current_choices.clear()
	choice_row.hide()
	dialogue_index = 0
	is_open = false
	finished.emit()
