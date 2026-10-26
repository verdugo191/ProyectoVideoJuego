extends Area2D

@export var tutorial_respawn_delay: float = 3.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var player: Node2D = null
var player_nearby: bool = false
var collected: bool = false


# Preparar el queso
func _ready() -> void:
	add_to_group("cheese_pickups")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if not _is_tutorial_level() and QuestManager.collected_cheese_ids.has(str(name)):
		collected = true
		queue_free()
		return
	animated_sprite.play("cheese")


# Recoger el queso con E cuando el jugador está en el área
func _input(event: InputEvent) -> void:
	if collected or not player_nearby or not is_instance_valid(player):
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_E and key_event.physical_keycode != KEY_E:
		return

	if _is_tutorial_level():
		get_viewport().set_input_as_handled()
		_recoger_en_tutorial()
		return
	if not QuestManager.cheese_unlocked or not QuestManager.collect_cheese(str(name)):
		return
	get_viewport().set_input_as_handled()
	collected = true
	queue_free()


# Detectar cuando el jugador se acerca
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_nearby = true


# Detectar cuando el jugador se aleja
func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player_nearby = false
		player = null


# Reaparecer tras recogerlo solo en el tutorial
func _recoger_en_tutorial() -> void:
	collected = true
	hide()
	await get_tree().create_timer(tutorial_respawn_delay).timeout
	if not is_instance_valid(self):
		return
	collected = false
	show()


# Comprobar si estamos en el tutorial
func _is_tutorial_level() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.is_in_group("tutorial_level")