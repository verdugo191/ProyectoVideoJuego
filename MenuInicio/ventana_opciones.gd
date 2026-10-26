extends Window

@onready var volume_slider: HSlider = $Control/HSlider
@onready var fullscreen_toggle: CheckButton = $Control/CheckButton
@onready var close_button: TextureButton = $Control/TextureButton
@onready var ok_button: TextureButton = $Control/TextureButton2


func _ready() -> void:
	transient = true
	borderless = true
	transparent = true
	transparent_bg = true
	unresizable = true
	close_requested.connect(hide)
	close_button.pressed.connect(hide)
	ok_button.pressed.connect(_on_ok_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ok_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_configure_volume_bar()
	_load_options()


# Abrir la ventana centrada sobre el menú.
func open_options() -> void:
	popup_centered()


# Aplicar y guardar el volumen.
func _on_volume_changed(value: float) -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(value, 0.001)))
	_save_options()


# Cambiar y guardar pantalla completa.
func _on_fullscreen_toggled(enabled: bool) -> void:
	var display_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(display_mode)
	_save_options()


# Cargar y aplicar las opciones guardadas.
func _load_options() -> void:
	var config := ConfigFile.new()
	var volume := 0.8
	var fullscreen := false
	if config.load("user://options.cfg") == OK:
		volume = float(config.get_value("audio", "volume", volume))
		fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	volume_slider.set_value_no_signal(clampf(volume, 0.0, 1.0))
	fullscreen_toggle.set_pressed_no_signal(fullscreen)
	_apply_volume(volume_slider.value)
	var display_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(display_mode)


# El relleno verde sigue el valor hasta la bolita.
func _configure_volume_bar() -> void:
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color("#59432D")
	track_style.set_corner_radius_all(6)
	track_style.content_margin_top = 4.0
	track_style.content_margin_bottom = 4.0
	volume_slider.add_theme_stylebox_override("slider", track_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("#00E645")
	fill_style.set_corner_radius_all(6)
	fill_style.content_margin_top = 4.0
	fill_style.content_margin_bottom = 4.0
	volume_slider.add_theme_stylebox_override("grabber_area", fill_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color("#58F077")
	hover_style.set_corner_radius_all(6)
	hover_style.content_margin_top = 4.0
	hover_style.content_margin_bottom = 4.0
	volume_slider.add_theme_stylebox_override("grabber_area_highlight", hover_style)


# Aplicar volumen sin modificar el archivo.
func _apply_volume(value: float) -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(value, 0.001)))


# Guardar las opciones actuales.
func _save_options() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "volume", volume_slider.value)
	config.set_value("display", "fullscreen", fullscreen_toggle.button_pressed)
	config.save("user://options.cfg")


# Confirmar y cerrar.
func _on_ok_pressed() -> void:
	_save_options()
	hide()
