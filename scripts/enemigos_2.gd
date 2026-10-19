extends CharacterBody2D

## Enemigo ligero de nivel 2: patrulla, persigue al jugador dentro del campo
## de visión y ejecuta un único ataque cuando el gato entra en corto alcance.
@export var patrol_speed: float = 55.0
@export var chase_speed: float = 85.0
@export var attack_range: float = 58.0
@export var attack_cooldown: float = 1.0
@export var patrol_change_time: float = 2.0
@export var attack_hide_delay: float = 0.25
@export var post_attack_grace: float = 3.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision_area: Area2D = get_node_or_null("Area2D") as Area2D
@onready var attack_area: Area2D = get_node_or_null("Area2D3") as Area2D

var player: Node2D
var move_direction := Vector2.ZERO
var patrol_timer := 0.0
var cooldown_timer := 0.0
var attack_timer := 0.0
var attacking := false
var attack_applied := false
var hidden_player := false


# Preparar al enemigo
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	patrol_timer = patrol_change_time
	_pick_patrol_direction()
	# La animación de ataque debe terminar para devolver al enemigo al movimiento.
	if animated_sprite.sprite_frames.has_animation("attack"):
		animated_sprite.sprite_frames.set_animation_loop("attack", false)
	animated_sprite.play("down")


# Actualizar patrulla y ataque
func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(cooldown_timer - delta, 0.0)

	if attacking:
		velocity = Vector2.ZERO
		attack_timer += delta
		if not attack_applied and attack_timer >= attack_hide_delay:
			_hide_player()
		if not animated_sprite.is_playing():
			attacking = false
			_show_player()
			cooldown_timer = maxf(attack_cooldown, post_attack_grace)
			animated_sprite.play("down")
		move_and_slide()
		return

	if player == null or not is_instance_valid(player) or player.get("is_dead") == true:
		_patrol(delta)
		move_and_slide()
		if is_on_wall():
			_pick_patrol_direction()
		return

	var distance := _player_distance()
	var player_in_vision := distance < 92.0
	var player_in_attack := distance <= attack_range
	if vision_area != null:
		player_in_vision = player_in_vision or player in vision_area.get_overlapping_bodies()
	if attack_area != null:
		player_in_attack = player_in_attack or player in attack_area.get_overlapping_bodies()

	if player_in_attack and cooldown_timer <= 0.0:
		velocity = Vector2.ZERO
		_start_attack()
		move_and_slide()
		return

	if player_in_vision:
		move_direction = global_position.direction_to(player.global_position)
		velocity = move_direction * chase_speed
		_play_directional_walk(move_direction)
	else:
		_patrol(delta)
	move_and_slide()
	if is_on_wall() and not player_in_vision:
		_pick_patrol_direction()


# Medir distancia al jugador
func _player_distance() -> float:
	# El sprite y las áreas están desplazados desde el origen de la escena.
	return animated_sprite.global_position.distance_to(player.global_position)


# Patrullar la zona
func _patrol(delta: float) -> void:
	patrol_timer -= delta
	if patrol_timer <= 0.0:
		_pick_patrol_direction()
		patrol_timer = patrol_change_time
	velocity = move_direction * patrol_speed
	_play_directional_walk(move_direction)


# Elegir dirección de patrulla
func _pick_patrol_direction() -> void:
	var directions := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	move_direction = directions[randi() % directions.size()]


# Reproducir caminata direccional
func _play_directional_walk(direction: Vector2) -> void:
	if direction.length_squared() < 0.001:
		return
	var animation := "down"
	if absf(direction.x) > absf(direction.y):
		animation = "right" if direction.x > 0.0 else "left"
	else:
		animation = "down" if direction.y > 0.0 else "up"
	if animated_sprite.sprite_frames.has_animation(animation) and animated_sprite.animation != animation:
		animated_sprite.play(animation)


# Iniciar el ataque
func _start_attack() -> void:
	if not animated_sprite.sprite_frames.has_animation("attack"):
		push_warning("Enemigo 2 no tiene una animación llamada 'attack'.")
		return
	attacking = true
	attack_applied = false
	attack_timer = 0.0
	move_direction = Vector2.ZERO
	animated_sprite.play("attack")
	# El periodo de protección se inicia cuando termina la animación.
	cooldown_timer = 0.0


# Ocultar al jugador durante el ataque
func _hide_player() -> void:
	attack_applied = true
	if player == null or not is_instance_valid(player) or hidden_player:
		return
	hidden_player = true
	player.set("velocity", Vector2.ZERO)
	player.hide()
	player.set_physics_process(false)
	player.set_process_input(false)


# Mostrar al jugador de nuevo
func _show_player() -> void:
	if player == null or not is_instance_valid(player) or not hidden_player:
		return
	hidden_player = false
	player.show()
	player.set_physics_process(true)
	player.set_process_input(true)
