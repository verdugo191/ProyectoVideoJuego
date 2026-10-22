extends CharacterBody2D

@export var interaction_distance: float = 72.0
@export var exit_door_position: Vector2 = Vector2(570, 590)
@export var escape_speed: float = 90.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

const DIALOGUE_LINES: PackedStringArray = [
	"Wait! Please don't eat me!",
	"I have a deal for you.",
	"I can help you get out of here.",
	"If you bring me some cheese, I'll be waiting outside with the door open."
]
const EXIT_WAYPOINTS: PackedVector2Array = [
	Vector2(600, 180), Vector2(570, 360), Vector2(570, 500), Vector2(570, 590)
]
const BACK_DOOR_WAYPOINTS: PackedVector2Array = [
	Vector2(580, 75), Vector2(580, 20), Vector2(580, -80)
]

enum MovementMode { IDLE, TO_EXIT, FLEEING, ENDING }

var player: Node2D
var already_interacted: bool = false
var mission_accepted: bool = false
var dialogue_canvas: DialogueCanvas
var movement_mode: MovementMode = MovementMode.IDLE
var exit_waypoint_index: int = 0
var back_door_waypoint_index: int = 0
var at_exit: bool = false


# Preparar a Mr. Cheese
func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	animated_sprite.play("rat_CalmDown")
	_find_player()
	_find_dialogue_canvas()


# Actualizar su movimiento
func _physics_process(delta: float) -> void:
	match movement_mode:
		MovementMode.TO_EXIT:
			_move_toward_exit(delta)
		MovementMode.FLEEING:
			_escape_through_back_door(delta)
		_:
			velocity = Vector2.ZERO


# Interactuar con E
func _unhandled_input(event: InputEvent) -> void:
	if movement_mode != MovementMode.IDLE or not (event is InputEventKey):
		return
	_find_dialogue_canvas()
	if dialogue_canvas == null or dialogue_canvas.is_open:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or (key_event.keycode != KEY_E and key_event.physical_keycode != KEY_E):
		return
	if player == null or not is_instance_valid(player):
		_find_player()
	if player == null or global_position.distance_to(player.global_position) > interaction_distance:
		return

	get_viewport().set_input_as_handled()
	if already_interacted:
		if not mission_accepted:
			return
		if QuestManager.cheese_delivered:
			if at_exit:
				_show_final_dialogue()
		else:
			_check_cheese_delivery()
		return

	already_interacted = true
	var opening_lines: Array[String] = []
	for line in DIALOGUE_LINES:
		opening_lines.append(line)
	opening_lines.append("Do you accept?")
	if not dialogue_canvas.choice_selected.is_connected(_on_initial_choice):
		dialogue_canvas.choice_selected.connect(_on_initial_choice)
	dialogue_canvas.show_choice_dialogue("Mr. Cheese", opening_lines, ["Yes", "No"], _get_portrait())


# Buscar la interfaz de diálogo
func _find_dialogue_canvas() -> void:
	if dialogue_canvas == null or not is_instance_valid(dialogue_canvas):
		dialogue_canvas = get_tree().get_first_node_in_group("dialogo") as DialogueCanvas


# Procesar la respuesta a la misión
func _on_initial_choice(choice: String) -> void:
	if dialogue_canvas.choice_selected.is_connected(_on_initial_choice):
		dialogue_canvas.choice_selected.disconnect(_on_initial_choice)
	if choice == "Yes":
		_accept_deal()
	else:
		_reject_deal()


# Aceptar la misión
func _accept_deal() -> void:
	QuestManager.unlock_cheese()
	mission_accepted = true
	get_tree().call_group("level_2", "show_level_message", "Collect all three cheeses and return to Mr. Cheese.", 4.0)


# Rechazar y hacer huir al NPC
func _reject_deal() -> void:
	get_tree().call_group("level_2", "show_level_message", "Mr. Cheese ran away.", 3.0)
	movement_mode = MovementMode.FLEEING
	back_door_waypoint_index = 0
	animated_sprite.play("rat_goAway")


# Revisar la entrega del queso
func _check_cheese_delivery() -> void:
	var line := "Thanks, but I still need more. I need all three cheeses."
	if QuestManager.cheese_count >= QuestManager.required_cheese:
		line = "Thank you so much for the cheese! Let's go. I'll be waiting for you at the door."
	_show_delivery_dialogue([line])


# Mostrar el diálogo de entrega
func _show_delivery_dialogue(lines: Array[String]) -> void:
	dialogue_canvas.show_dialogue("Mr. Cheese", lines, _get_portrait())
	await dialogue_canvas.finished
	if not is_instance_valid(self):
		return
	if QuestManager.cheese_count >= QuestManager.required_cheese and QuestManager.deliver_cheese():
		get_tree().call_group("level_2", "show_level_message", "Mr. Cheese is heading to the door.", 4.0)
		_start_exit_walk()


# Empezar el camino a la puerta
func _start_exit_walk() -> void:
	movement_mode = MovementMode.TO_EXIT
	exit_waypoint_index = 0
	animated_sprite.play("rat_goAway")


# Avanzar hacia la salida
func _move_toward_exit(delta: float) -> void:
	if exit_waypoint_index >= EXIT_WAYPOINTS.size():
		_arrive_at_exit()
		return
	var target := exit_door_position if exit_waypoint_index == EXIT_WAYPOINTS.size() - 1 else EXIT_WAYPOINTS[exit_waypoint_index]
	if global_position.distance_to(target) <= 10.0:
		exit_waypoint_index += 1
		if exit_waypoint_index >= EXIT_WAYPOINTS.size():
			_arrive_at_exit()
			return
		target = exit_door_position if exit_waypoint_index == EXIT_WAYPOINTS.size() - 1 else EXIT_WAYPOINTS[exit_waypoint_index]
	_move_with_collisions(global_position.direction_to(target), delta)


# Esperar junto a la puerta
func _arrive_at_exit() -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	movement_mode = MovementMode.IDLE
	at_exit = true
	animated_sprite.play("rat_CalmDown")


# Mostrar el diálogo final
func _show_final_dialogue() -> void:
	movement_mode = MovementMode.ENDING
	dialogue_canvas.show_dialogue("Mr. Cheese", ["Thank you again for the cheese."], _get_portrait())
	await dialogue_canvas.finished
	if is_instance_valid(self):
		get_tree().call_group("level_2", "finish_game")


# Obtener el retrato del NPC
func _get_portrait() -> Texture2D:
	var portrait_area := get_node_or_null("Area2D") as Area2D
	if portrait_area != null and portrait_area.has_method("get_dialogue_portrait"):
		return portrait_area.call("get_dialogue_portrait") as Texture2D
	return animated_sprite.sprite_frames.get_frame_texture("rat_CalmDown", 0)


# Salir del mapa por la puerta trasera
func _escape_through_back_door(delta: float) -> void:
	if back_door_waypoint_index >= BACK_DOOR_WAYPOINTS.size():
		_finish_back_door_escape()
		return
	var target := BACK_DOOR_WAYPOINTS[back_door_waypoint_index]
	if global_position.distance_to(target) <= 10.0:
		back_door_waypoint_index += 1
		if back_door_waypoint_index >= BACK_DOOR_WAYPOINTS.size():
			_finish_back_door_escape()
			return
		target = BACK_DOOR_WAYPOINTS[back_door_waypoint_index]
	_move_with_collisions(global_position.direction_to(target), delta)


# Avisar cuando ya salió del mapa
func _finish_back_door_escape() -> void:
	velocity = Vector2.ZERO
	get_tree().call_group("level_2", "on_mr_cheese_escaped")
	queue_free()


# Moverse respetando colisiones
func _move_with_collisions(desired_direction: Vector2, delta: float) -> void:
	if desired_direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := _find_open_direction(desired_direction, delta)
	velocity = direction * escape_speed
	animated_sprite.flip_h = direction.x < -0.1
	if animated_sprite.animation != "rat_goAway":
		animated_sprite.play("rat_goAway")
	move_and_slide()


# Buscar una dirección libre
func _find_open_direction(desired_direction: Vector2, delta: float) -> Vector2:
	var directions: Array[Vector2] = [
		desired_direction, desired_direction.rotated(PI / 4.0), desired_direction.rotated(-PI / 4.0),
		desired_direction.rotated(PI / 2.0), desired_direction.rotated(-PI / 2.0),
		desired_direction.rotated(3.0 * PI / 4.0), desired_direction.rotated(-3.0 * PI / 4.0),
		desired_direction.rotated(PI)
	]
	var best_direction := Vector2.ZERO
	var best_score := -INF
	for candidate in directions:
		var motion := candidate.normalized() * escape_speed * delta
		if test_move(global_transform, motion):
			continue
		var score := candidate.normalized().dot(desired_direction.normalized())
		if score > best_score:
			best_score = score
			best_direction = candidate.normalized()
	return best_direction


# Buscar al jugador
func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
