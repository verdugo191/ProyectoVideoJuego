extends CharacterBody2D

# Señales
signal health_change(current_health: int, maximum_health: int)
signal dead

# Constantes
const SPEED: float = 150.0
const INVULNERABLE_TIME: float = 0.8
const HEALTH_BAR_SEGMENTS: int = 4
const ROCK_SCENE: PackedScene = preload("res://level/coins/coin.tscn")

# Variables
@export var max_health: int = 4
@export var test_damage_with_space: bool = false
@export var camera_zoom: float = 2.0

var health: int
var is_dead: bool = false
var is_invulnerable: bool = false
var facing_direction: Vector2 = Vector2.RIGHT

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D


# Inicializar jugador y cámara
func _ready() -> void:
	camera.zoom = Vector2(camera_zoom, camera_zoom)
	health = max_health
	health_change.emit(health, max_health)
	_update_health_bar.call_deferred()


# Movimiento
func _physics_process(_delta: float) -> void:
	if is_dead:
		return

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		animated_sprite.stop()
	else:
		facing_direction = direction.normalized()
		velocity = direction * SPEED

		if abs(direction.x) > abs(direction.y):
			animated_sprite.play("walk")
			animated_sprite.flip_h = direction.x < 0
		else:
			animated_sprite.flip_h = false
			if direction.y < 0:
				animated_sprite.play("walk_up")
			else:
				animated_sprite.play("walk_down")

	move_and_slide()


# Recibir daño
func take_damage(amount: int) -> void:
	if is_dead or is_invulnerable:
		return

	health = maxi(health - amount, 0)
	print("Vida actual: ", health)

	health_change.emit(health, max_health)
	_update_health_bar()

	# Animación al recibir un golpe
	animated_sprite.play("walk_demage")

	if health <= 0:
		die()
		return

	is_invulnerable = true
	await get_tree().create_timer(INVULNERABLE_TIME).timeout
	is_invulnerable = false


# Terminar la animación de daño
func _on_damage_animation_finished() -> void:
	if is_dead:
		return

	if not is_invulnerable:
		return

	animated_sprite.stop()


# Gestionar la derrota del jugador
func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	animated_sprite.stop()

	dead.emit()
	print("El jugador ha muerto")


# Actualizar corazones
func _update_health_bar() -> void:
	var cuadros := ceili(float(HEALTH_BAR_SEGMENTS) * health / max_health)
	get_tree().call_group("vida_ui", "actualizar", cuadros)


# Lanzar roca y probar daño
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if QuestManager.consume_rock():
			var rock := ROCK_SCENE.instantiate()
			get_tree().current_scene.add_child(rock)
			rock.scale = Vector2(0.5, 0.5)
			rock.launch(self, facing_direction)
			get_viewport().set_input_as_handled()

	if test_damage_with_space and event.is_action_pressed("ui_accept"):
		take_damage(1)
