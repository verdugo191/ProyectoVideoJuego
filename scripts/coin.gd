
extends Area2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var throw_speed: float = 500.0
@export var respawn_delay: float = 3.0
var player: Node2D = null
var player_nearby: bool = false
var is_thrown: bool = false
var is_available: bool = true
var spawn_position: Vector2

var throw_direction: Vector2 = Vector2.RIGHT
var throw_timer: float = 0.0
var throw_duration: float = 0.8


# Preparar la roca
func _ready() -> void:
	spawn_position = global_position

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if animated_sprite.sprite_frames.has_animation("inmobile"):
		animated_sprite.play("inmobile")


# Recoger la roca con E
func _input(event: InputEvent) -> void:
	# Recoger la roca con E al estar cerca.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			if player_nearby and is_available and not is_thrown:
				if not _is_tutorial_level() and QuestManager.quest_state == QuestManager.QuestState.NOT_STARTED:
					print("Primero habla con el NPC para desbloquear las piedras.")
					return
				_pick_up_rock()


# Mover la roca lanzada
func _physics_process(delta: float) -> void:
	# Desplazar la roca después de lanzarla.
	if is_thrown:
		global_position += throw_direction * throw_speed * delta
		throw_timer += delta

		if throw_timer >= throw_duration:
			_finish_throw()


# Detectar proximidad e impactos
func _on_body_entered(body: Node2D) -> void:
	if is_thrown:
		if body.is_in_group("player"):
			return
		if body.is_in_group("dog") and body.has_method("take_rock_hit"):
			body.call("take_rock_hit")

		_finish_throw()
		return

	if body.is_in_group("player"):
		if not is_available:
			return
		player = body
		player_nearby = true

		print("Pulsa E para recoger la roca.")


# Detectar cuando el jugador se aleja
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and not is_thrown:
		player_nearby = false

		if not is_thrown:
			player = null


# Recoger y reaparecer la roca
func _pick_up_rock() -> void:
	if not is_instance_valid(player):
		return

	if not _is_tutorial_level() and QuestManager.quest_state == QuestManager.QuestState.NOT_STARTED:
		return

	QuestManager.collect_coin()
	print("Has recogido la roca.")

	is_available = false
	player_nearby = false
	player = null
	hide()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	await get_tree().create_timer(respawn_delay).timeout
	if not is_instance_valid(self):
		return

	global_position = spawn_position
	is_available = true
	show()
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)


# Lanzar la roca
func launch(from_player: Node2D, direction: Vector2) -> void:
	player = from_player
	throw_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	global_position = player.global_position + throw_direction * 16.0
	player_nearby = false
	is_thrown = true
	throw_timer = 0.0
	if not animated_sprite.sprite_frames.has_animation("rock"):
		push_warning("No existe la animación llamada rock.")
		queue_free()
		return

	# Calcular la duración de la animación de lanzamiento.
	var frames: int = animated_sprite.sprite_frames.get_frame_count("rock")
	var fps: float = animated_sprite.sprite_frames.get_animation_speed("rock")

	if fps > 0.0:
		throw_duration = float(frames) / fps
	else:
		throw_duration = 0.8

	animated_sprite.play("rock")


# Finalizar el lanzamiento
func _finish_throw() -> void:
	print("La roca ha terminado su lanzamiento.")
	queue_free()

# Permitir recoger objetos antes de hablar solo en el tutorial.
func _is_tutorial_level() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.is_in_group("tutorial_level")
