extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://player/player2.tscn")
const DIALOGUE_SCENE: PackedScene = preload("res://scenes/canvas_layer.tscn")

@export var spawn_position: Vector2 = Vector2(580, 105)
@export_range(0.5, 3.0, 0.05) var camera_zoom: float = 2.0
@export var camera_bounds: Rect2i = Rect2i(0, 0, 1152, 648)
@export var back_door_position: Vector2 = Vector2(580, 20)
@export var back_door_radius: float = 48.0

var player: CharacterBody2D
var background: Sprite2D
var furniture_occluders: Array[Dictionary] = []
var cheese_counter_label: Label
var npc_message_label: Label
var health_hearts_label: Label
var message_version: int = 0
var game_finished: bool = false
var mr_cheese_escaped: bool = false
var player_trying_to_leave: bool = false


# Preparar el segundo nivel
func _ready() -> void:
	add_to_group("level_2")
	add_to_group("vida_ui")
	QuestManager.start_cheese_level()
	_create_cheese_hud()
	var dialogue := DIALOGUE_SCENE.instantiate() as DialogueCanvas
	dialogue.name = "DialogueCanvas"
	dialogue.layer = 10
	add_child(dialogue)

	background = get_node_or_null("Sprite2D") as Sprite2D
	if background == null or background.texture == null:
		push_error("El nivel 2 necesita el Sprite2D del diseño como fondo.")
		return

	# Permite dejar un jugador colocado manualmente en la escena si se desea.
	player = get_node_or_null("Player2") as CharacterBody2D
	if player == null:
		player = PLAYER_SCENE.instantiate() as CharacterBody2D
		player.name = "Player2"
		player.position = spawn_position
		_configure_player_camera(player)
		add_child(player)
	else:
		_configure_player_camera(player)

	player.z_index = 1
	# En este nivel el perro no es un objetivo de combate: ocultamos sus corazones
	# sin cambiar la interfaz de vida que se usa en el nivel 1.
	var dog_health_label := get_node_or_null("Enemigos/HealthLabel") as Label
	if dog_health_label != null:
		dog_health_label.hide()

	_create_furniture_occluders()
	_update_furniture_occlusion()
	update_cheese_count(QuestManager.cheese_count)
	show_level_message("Talk to Mr. Cheese", 4.0)


# Actualizar la oclusión de muebles
func _process(_delta: float) -> void:
	_update_furniture_occlusion()
	if mr_cheese_escaped and is_instance_valid(player):
		if player.global_position.distance_to(back_door_position) <= back_door_radius:
			player_trying_to_leave = true


# Crear la interfaz del nivel
func _create_cheese_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "CheeseHUD"
	add_child(hud)

	cheese_counter_label = Label.new()
	cheese_counter_label.name = "CheeseCounter"
	cheese_counter_label.position = Vector2(24, 18)
	cheese_counter_label.add_theme_font_size_override("font_size", 24)
	cheese_counter_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	cheese_counter_label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
	cheese_counter_label.add_theme_constant_override("outline_size", 5)
	hud.add_child(cheese_counter_label)

	npc_message_label = Label.new()
	npc_message_label.name = "NPC2Message"
	npc_message_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	npc_message_label.offset_top = 54
	npc_message_label.offset_bottom = 94
	npc_message_label.add_theme_font_size_override("font_size", 22)
	npc_message_label.add_theme_color_override("font_color", Color.WHITE)
	npc_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	npc_message_label.add_theme_constant_override("outline_size", 5)
	npc_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	npc_message_label.hide()
	hud.add_child(npc_message_label)

	health_hearts_label = Label.new()
	health_hearts_label.name = "PlayerHearts"
	health_hearts_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	health_hearts_label.offset_left = -180.0
	health_hearts_label.offset_top = 18.0
	health_hearts_label.offset_right = -24.0
	health_hearts_label.offset_bottom = 54.0
	health_hearts_label.add_theme_font_size_override("font_size", 25)
	health_hearts_label.add_theme_color_override("font_color", Color(1.0, 0.28, 0.38))
	health_hearts_label.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.04))
	health_hearts_label.add_theme_constant_override("outline_size", 5)
	health_hearts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(health_hearts_label)

	update_cheese_count(QuestManager.cheese_count)
	actualizar(4)


# Actualizar el contador de queso
func update_cheese_count(count: int) -> void:
	if is_instance_valid(cheese_counter_label):
		cheese_counter_label.text = "Cheese %d" % count


# Actualizar los corazones del jugador
func actualizar(vida: int) -> void:
	if not is_instance_valid(health_hearts_label):
		return
	var hearts := ""
	for index in range(4):
		hearts += "♥ " if index < clampi(vida, 0, 4) else "♡ "
	health_hearts_label.text = hearts.strip_edges()


# Mostrar un mensaje temporal
func show_level_message(message: String, duration: float = 3.0) -> void:
	if not is_instance_valid(npc_message_label):
		return
	message_version += 1
	var current_version := message_version
	npc_message_label.text = message
	npc_message_label.show()
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(npc_message_label) and current_version == message_version:
		npc_message_label.hide()


# Mostrar la pantalla final
func finish_game() -> void:
	_show_ending("You won.\nCongratulations, you won.\nGame over.")


# Habilitar la salida alternativa cuando Mr. Cheese se marcha
func on_mr_cheese_escaped() -> void:
	mr_cheese_escaped = true


# Mostrar el final alternativo cuando la niña atrapa al gato
func on_girl_caught_player() -> void:
	if mr_cheese_escaped:
		_show_ending("YOU LOST\nYou have been\ndomesticated.")


# Mostrar la pantalla final
func _show_ending(message: String) -> void:
	if game_finished:
		return
	game_finished = true
	if is_instance_valid(player):
		player.velocity = Vector2.ZERO
		player.set_physics_process(false)
		player.set_process_input(false)

	var ending_layer := CanvasLayer.new()
	ending_layer.name = "EndingScreen"
	ending_layer.layer = 30
	ending_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ending_layer)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_layer.add_child(shade)

	var ending_text := Label.new()
	ending_text.text = message
	ending_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ending_text.offset_left = -240.0
	ending_text.offset_top = -85.0
	ending_text.offset_right = 240.0
	ending_text.offset_bottom = 85.0
	ending_text.add_theme_font_size_override("font_size", 38)
	ending_text.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	ending_text.add_theme_color_override("font_outline_color", Color.BLACK)
	ending_text.add_theme_constant_override("outline_size", 6)
	ending_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ending_layer.add_child(ending_text)
	get_tree().paused = true

# Configurar la cámara
func _configure_player_camera(target_player: CharacterBody2D) -> void:
	# El mapa ya está dibujado en level_2.tscn; aquí solo configuramos al gato
	# y su cámara para recorrer el diseño existente.
	target_player.set("camera_zoom", camera_zoom)
	var camera := target_player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		push_warning("Player2 necesita un nodo Camera2D para el nivel 2.")
		return

	camera.limit_left = camera_bounds.position.x
	camera.limit_top = camera_bounds.position.y
	camera.limit_right = camera_bounds.end.x
	camera.limit_bottom = camera_bounds.end.y


# Crear capas de oclusión
func _create_furniture_occluders() -> void:
	# El diseño está pintado en una sola imagen. Estos polígonos vuelven a dibujar
	# los muebles encima del gato solo mientras este camina por detrás de ellos.
	_add_furniture_occluder("Sofa", PackedVector2Array([
		Vector2(744, 360), Vector2(777, 340), Vector2(985, 340), Vector2(1007, 360),
		Vector2(1012, 456), Vector2(998, 485), Vector2(982, 498), Vector2(765, 498),
		Vector2(742, 479), Vector2(736, 401)
	]))
	_add_furniture_occluder("Sillon", PackedVector2Array([
		Vector2(643, 409), Vector2(683, 389), Vector2(718, 404), Vector2(751, 437),
		Vector2(752, 475), Vector2(727, 511), Vector2(698, 520), Vector2(663, 501),
		Vector2(638, 470), Vector2(631, 438)
	]))
	_add_furniture_occluder("MesaSala", PackedVector2Array([
		Vector2(772, 500), Vector2(941, 500), Vector2(951, 552), Vector2(932, 575),
		Vector2(781, 575), Vector2(767, 552)
	]))
	_add_furniture_occluder("Cama", PackedVector2Array([
		Vector2(126, 218), Vector2(257, 218), Vector2(260, 452), Vector2(128, 454)
	]))
	_add_furniture_occluder("Armario", PackedVector2Array([
		Vector2(423, 190), Vector2(512, 190), Vector2(514, 341), Vector2(424, 341)
	]))
	_add_furniture_occluder("MesaComedor", PackedVector2Array([
		Vector2(219, 794), Vector2(435, 794), Vector2(438, 952), Vector2(218, 952)
	]))
	_add_furniture_occluder("Bañera", PackedVector2Array([
		Vector2(1115, 664), Vector2(1209, 664), Vector2(1211, 841), Vector2(1114, 841)
	]))
	_add_furniture_occluder("LavaboYSanitario", PackedVector2Array([
		Vector2(965, 750), Vector2(1053, 750), Vector2(1054, 938), Vector2(965, 938)
	]))
	_add_furniture_occluder("Chimenea", PackedVector2Array([
		Vector2(1010, 128), Vector2(1154, 128), Vector2(1154, 326), Vector2(1010, 326)
	]))
	_add_furniture_occluder("Librero", PackedVector2Array([
		Vector2(610, 190), Vector2(697, 190), Vector2(697, 280), Vector2(610, 280)
	]))
	# Las plantas se ordenan individualmente: pueden tapar al gato sin hacer que
	# toda la fila de cocina se dibuje por encima de él.
	_add_furniture_occluder("PlantaMesaSala", PackedVector2Array([
		Vector2(844, 456), Vector2(858, 446), Vector2(879, 449), Vector2(893, 463),
		Vector2(902, 481), Vector2(891, 493), Vector2(891, 514), Vector2(883, 526),
		Vector2(855, 526), Vector2(848, 513), Vector2(850, 489), Vector2(837, 479)
	]))
	_add_furniture_occluder("PlantaSalaLateral", PackedVector2Array([
		Vector2(1017, 393), Vector2(1034, 383), Vector2(1050, 394), Vector2(1062, 416),
		Vector2(1053, 432), Vector2(1054, 462), Vector2(1045, 476), Vector2(1022, 476),
		Vector2(1015, 461), Vector2(1018, 433), Vector2(1007, 420)
	]))
	_add_furniture_occluder("PlantaDormitorio", PackedVector2Array([
		Vector2(130, 197), Vector2(145, 187), Vector2(163, 194), Vector2(177, 212),
		Vector2(169, 228), Vector2(171, 246), Vector2(162, 257), Vector2(139, 257),
		Vector2(131, 246), Vector2(134, 229), Vector2(124, 218)
	]))
	_add_furniture_occluder("PlantaCocina", PackedVector2Array([
		Vector2(124, 676), Vector2(139, 665), Vector2(157, 675), Vector2(173, 699),
		Vector2(164, 714), Vector2(166, 731), Vector2(157, 742), Vector2(134, 742),
		Vector2(125, 728), Vector2(128, 711), Vector2(117, 697)
	]))
	_add_furniture_occluder("PlantaComedor", PackedVector2Array([
		Vector2(286, 807), Vector2(301, 796), Vector2(320, 805), Vector2(337, 827),
		Vector2(328, 844), Vector2(330, 864), Vector2(321, 875), Vector2(296, 875),
		Vector2(287, 861), Vector2(290, 844), Vector2(279, 830)
	]))
	_add_furniture_occluder("PlantaBano", PackedVector2Array([
		Vector2(969, 679), Vector2(985, 668), Vector2(1005, 677), Vector2(1019, 696),
		Vector2(1011, 713), Vector2(1014, 734), Vector2(1004, 746), Vector2(981, 746),
		Vector2(973, 733), Vector2(975, 714), Vector2(963, 700)
	]))


# Añadir una forma de oclusión
func _add_furniture_occluder(occluder_name: String, source_points: PackedVector2Array) -> void:
	var image_size := background.texture.get_size()
	var polygon := Polygon2D.new()
	polygon.name = "Oclusion_%s" % occluder_name
	polygon.texture = background.texture
	polygon.uv = source_points
	polygon.z_index = 2

	var local_points := PackedVector2Array()
	var source_bottom := 0.0
	for source_point in source_points:
		var point_in_background := source_point - image_size / 2.0
		local_points.append(to_local(background.to_global(point_in_background)))
		source_bottom = maxf(source_bottom, source_point.y)
	polygon.polygon = local_points
	add_child(polygon)

	var bottom_in_background := Vector2(0.0, source_bottom - image_size.y / 2.0)
	var depth_y := background.to_global(bottom_in_background).y
	furniture_occluders.append({"node": polygon, "depth_y": depth_y})


# Actualizar qué muebles tapan al jugador
func _update_furniture_occlusion() -> void:
	if not is_instance_valid(player):
		return
	for occluder_data in furniture_occluders:
		var polygon := occluder_data["node"] as Polygon2D
		polygon.visible = player.global_position.y < float(occluder_data["depth_y"])
