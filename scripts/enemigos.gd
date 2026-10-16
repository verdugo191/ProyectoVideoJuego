extends CharacterBody2D

enum State {
	PATROL,
	CHASE
}

const SPEED: float = 100.0
const CHASE_SPEED: float = 160.0
const CHANGE_DIRECTION_TIME: float = 2.0

@export var damage: int = 25
@export var attack_range: float = 60.0
@export var attack_delay: float = 0.3
@export var attack_cooldown: float = 0.5

@onready var campo_vision: Area2D = $Area2D
@onready var area_ataque: Area2D = $Area2D2
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var current_state: State = State.PATROL
var gato: Node2D = null

var direccion: Vector2 = Vector2.ZERO
var tiempo_cambio: float = 0.0

var esperando_ataque: bool = false
var atacando: bool = false
var tiempo_espera: float = 0.0
var tiempo_recarga: float = 0.0
var tiempo_ataque: float = 0.0
var duracion_ataque: float = 0.0


func _ready() -> void:
	gato = get_tree().get_first_node_in_group("player") as Node2D

	cambiar_direccion()
	animated_sprite.stop()


func _physics_process(delta: float) -> void:
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
			chase()

	move_and_slide()
	actualizar_animacion()


func comprobar_gato() -> void:
	if gato == null or not is_instance_valid(gato):
		current_state = State.PATROL
		return

	var cuerpos: Array[Node2D] = campo_vision.get_overlapping_bodies()

	if gato in cuerpos:
		current_state = State.CHASE
	else:
		current_state = State.PATROL


func patrol(delta: float) -> void:
	tiempo_cambio -= delta

	if tiempo_cambio <= 0.0:
		cambiar_direccion()

	velocity = direccion * SPEED


func chase() -> void:
	if gato == null or not is_instance_valid(gato):
		current_state = State.PATROL
		velocity = Vector2.ZERO
		return

	var direccion_gato: Vector2 = global_position.direction_to(
		gato.global_position
	)

	velocity = direccion_gato * CHASE_SPEED


func cambiar_direccion() -> void:
	direccion = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized()

	tiempo_cambio = CHANGE_DIRECTION_TIME


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
