extends CharacterBody2D

enum State {
	PATROL,
	CHASE,
	GO_TO_DOOR,
	WAIT_FOR_DOOR
}

const SPEED: float = 100.0
const CHASE_SPEED: float = 160.0
const CHANGE_DIRECTION_TIME: float = 2.0
const PATH_UPDATE_TIME: float = 0.2

@export var damage: int = 1
@export var attack_range: float = 60.0
@export var attack_delay: float = 0.3
@export var attack_cooldown: float = 0.5
@export var max_health: int = 4

@onready var campo_vision: Area2D = $Area2D
@onready var area_ataque: Area2D = $Area2D2
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var health_label: Label = $HealthLabel

var current_state: State = State.PATROL
var gato: Node2D = null
var puerta: Node2D = null
var health: int = 4
var derrotado: bool = false

var direccion: Vector2 = Vector2.ZERO
var tiempo_cambio: float = 0.0

var esperando_ataque: bool = false
var atacando: bool = false
var tiempo_espera: float = 0.0
var tiempo_recarga: float = 0.0
var tiempo_ataque: float = 0.0
var duracion_ataque: float = 0.0

var tiempo_ruta: float = 0.0


# Preparar al perro y sus señales
func _ready() -> void:
	add_to_group("dog")
	health = max_health
	gato = get_tree().get_first_node_in_group("player") as Node2D
	_update_health_label()

	nav_agent.path_desired_distance = 8.0
	nav_agent.target_desired_distance = 8.0

	cambiar_direccion()
	animated_sprite.stop()


# Actualizar estados y movimiento
func _physics_process(delta: float) -> void:
	# En el nivel 2 el jugador se instancia desde el nodo padre después de que
	# este enemigo haya recibido _ready(); volver a buscarlo evita una referencia nula.
	if gato == null or not is_instance_valid(gato):
		gato = get_tree().get_first_node_in_group("player") as Node2D

	if current_state == State.GO_TO_DOOR:
		ir_a_la_puerta(delta)
		move_and_slide()
		actualizar_animacion()
		return
	if current_state == State.WAIT_FOR_DOOR:
		velocity = Vector2.ZERO
		animated_sprite.stop()
		move_and_slide()
		return

	if gato == null:
		velocity = Vector2.ZERO
		patrol(delta)
		move_and_slide()
		actualizar_animacion()
		return

	if gato.get("is_dead") == true or gato.get("health") <= 0:
		velocity = Vector2.ZERO
		esperando_ataque = false
		atacando = false
		animated_sprite.stop()
		move_and_slide()
		return
	if tiempo_recarga > 0.0:
		tiempo_recarga = maxf(tiempo_recarga - delta, 0.0)

	# Si está atacando, no interrumpir la animación.
	if atacando:
		velocity = Vector2.ZERO
		tiempo_ataque += delta

		if tiempo_ataque >= duracion_ataque:
			atacando = false
			animated_sprite.stop()
			comprobar_gato()

		move_and_slide()
		return

	comprobar_gato()

	# Comprobar si el gato está dentro del área de ataque.
	var gato_cerca: bool = false

	if gato != null and is_instance_valid(gato):
		gato_cerca = (
			gato in area_ataque.get_overlapping_bodies()
			or global_position.distance_to(gato.global_position) <= attack_range
		)

	if gato_cerca:
		velocity = Vector2.ZERO

		if not esperando_ataque and tiempo_recarga <= 0.0:
			esperando_ataque = true
			tiempo_espera = attack_delay

		if esperando_ataque:
			tiempo_espera -= delta

			if tiempo_espera <= 0.0:
				iniciar_ataque()

		move_and_slide()
		return

	# Si el gato se aleja, cancelar la espera.
	esperando_ataque = false
	tiempo_espera = 0.0

	match current_state:
		State.PATROL:
			patrol(delta)
		State.CHASE:
			chase(delta)

	move_and_slide()
	actualizar_animacion()


# Recibir un impacto de roca
func take_rock_hit() -> void:
	if derrotado:
		return

	health = maxi(health - 1, 0)
	_update_health_label()
	print("Vida del perro: ", health, "/", max_health)

	if health == 0:
		derrotado = true
		esperando_ataque = false
		atacando = false
		campo_vision.set_deferred("monitoring", false)
		area_ataque.set_deferred("monitoring", false)
		puerta = get_tree().get_first_node_in_group("door") as Node2D
		if puerta == null:
			push_warning("No se encontró la puerta para el perro.")
			return

		if not puerta.is_connected("opening_finished", _on_door_opening_finished):
			puerta.connect("opening_finished", _on_door_opening_finished)
		get_tree().call_group("goal_message", "show_message", "Head to the door.")
		current_state = State.GO_TO_DOOR
		tiempo_ruta = 0.0


# Esperar a que la puerta se abra
func on_door_touched() -> void:
	if not derrotado:
		return

	current_state = State.WAIT_FOR_DOOR
	velocity = Vector2.ZERO
	animated_sprite.stop()


# Desaparecer tras abrirse la puerta
func _on_door_opening_finished() -> void:
	if derrotado and is_instance_valid(self):
		queue_free()


# Actualizar los corazones del perro
func _update_health_label() -> void:
	if health <= 0:
		health_label.hide()
		return

	var hearts := ""
	for index in range(max_health):
		hearts += "♥ " if index < health else "♡ "
	health_label.text = hearts.strip_edges()
	health_label.show()


# Dirigirse hacia la puerta
func ir_a_la_puerta(delta: float) -> void:
	if not is_instance_valid(puerta):
		velocity = Vector2.ZERO
		return

	tiempo_ruta -= delta
	if tiempo_ruta <= 0.0:
		nav_agent.target_position = _get_door_target_position()
		tiempo_ruta = PATH_UPDATE_TIME

	var target_position := _get_door_target_position()
	var destino := target_position
	if nav_agent.get_current_navigation_path().size() > 1:
		destino = nav_agent.get_next_path_position()

	if global_position.distance_to(target_position) <= 28.0:
		velocity = Vector2.ZERO
	else:
		velocity = global_position.direction_to(destino) * CHASE_SPEED


# Obtener la posición de la puerta
func _get_door_target_position() -> Vector2:
	var sensor_shape := puerta.get_node_or_null("Area2D/CollisionShape2D") as Node2D
	if sensor_shape != null:
		return sensor_shape.global_position
	return puerta.global_position


# Comprobar si el gato está cerca
func comprobar_gato() -> void:
	if gato == null or not is_instance_valid(gato):
		current_state = State.PATROL
		return

	var cuerpos: Array[Node2D] = campo_vision.get_overlapping_bodies()

	if gato in cuerpos:
		current_state = State.CHASE
	else:
		current_state = State.PATROL


# Patrullar la zona
func patrol(delta: float) -> void:
	tiempo_cambio -= delta

	if tiempo_cambio <= 0.0:
		cambiar_direccion()

	velocity = direccion * SPEED


# Perseguir al jugador
func chase(delta: float) -> void:
	if gato == null or not is_instance_valid(gato):
		current_state = State.PATROL
		velocity = Vector2.ZERO
		return

	# Navegación
	tiempo_ruta -= delta

	if tiempo_ruta <= 0.0:
		nav_agent.target_position = gato.global_position
		tiempo_ruta = PATH_UPDATE_TIME

	var destino: Vector2 = gato.global_position

	# Sin ruta válida (no hay mapa de navegación o el gato está fuera de él),
	# persigue en línea recta.
	if nav_agent.get_current_navigation_path().size() > 1:
		var siguiente: Vector2 = nav_agent.get_next_path_position()

		if global_position.distance_to(siguiente) > 1.0:
			destino = siguiente

	velocity = global_position.direction_to(destino) * CHASE_SPEED


# Cambiar dirección de patrulla
func cambiar_direccion() -> void:
	direccion = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()

	tiempo_cambio = CHANGE_DIRECTION_TIME


# Atacar al jugador
func iniciar_ataque() -> void:
	if gato == null or not is_instance_valid(gato):
		return

	if gato.get("is_dead") == true or gato.get("health") <= 0:
		esperando_ataque = false
		atacando = false
		velocity = Vector2.ZERO
		animated_sprite.stop()
		return

	esperando_ataque = false
	atacando = true
	tiempo_ataque = 0.0
	velocity = Vector2.ZERO

	var hacia_gato: Vector2 = gato.global_position - global_position
	var animacion: String

	if absf(hacia_gato.x) > absf(hacia_gato.y):
		if hacia_gato.x >= 0.0:
			animacion = "dog_atack_right"
		else:
			animacion = "dog_atack_left"
	else:
		if hacia_gato.y < 0.0:
			animacion = "dog_atack_up"
		else:
			animacion = "dog_atack_down"

	animated_sprite.flip_h = false

	if not animated_sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación: " + animacion)
		atacando = false
		return

	animated_sprite.play(animacion)

	# Calcular cuánto dura la animación para evitar congelamientos.
	var frames: int = animated_sprite.sprite_frames.get_frame_count(animacion)
	var fps: float = animated_sprite.sprite_frames.get_animation_speed(animacion)

	duracion_ataque = float(frames) / maxf(fps, 1.0)

	# Aplicar daño una sola vez por ataque.
	if gato.has_method("take_damage"):
		gato.call("take_damage", damage)

	tiempo_recarga = attack_cooldown


# Actualizar la animación de movimiento
func actualizar_animacion() -> void:
	if velocity == Vector2.ZERO:
		animated_sprite.stop()
		return

	if absf(velocity.x) > absf(velocity.y):
		animated_sprite.play("Dog")
		animated_sprite.flip_h = velocity.x < 0.0
	else:
		animated_sprite.flip_h = false

		if velocity.y < 0.0:
			animated_sprite.play("dog_up")
		else:
			animated_sprite.play("dog_down")
