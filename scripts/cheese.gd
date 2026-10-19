extends Area2D

@export var interaction_distance: float = 42.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var player: Node2D
var collected: bool = false


# Preparar el queso
func _ready() -> void:
	add_to_group("cheese_pickups")
	animated_sprite.play("cheese")
	_find_player()


# Recoger el queso con E
func _unhandled_input(event: InputEvent) -> void:
	if collected or not QuestManager.cheese_unlocked:
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_E and key_event.physical_keycode != KEY_E:
		return
	if player == null or not is_instance_valid(player):
		_find_player()
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) > interaction_distance:
		return

	if not QuestManager.collect_cheese():
		return
	collected = true
	get_viewport().set_input_as_handled()
	queue_free()


# Buscar al jugador
func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
