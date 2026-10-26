extends StaticBody2D

signal opening_finished

@export_file("*.tscn") var destination_scene: String = ""

@onready var area: Area2D = $Area2D
@onready var area_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var solid_shape: CollisionShape2D = $CollisionShape2D

var activada: bool = false
var abierta: bool = false
var nivel_completado: bool = false


# Preparar la puerta y sus señales
func _ready() -> void:
	add_to_group("door")
	if destination_scene.is_empty():
		visible = false
		solid_shape.disabled = true
	else:
		visible = true
		solid_shape.disabled = false
		animated_sprite.play("closed")
	area.body_entered.connect(_on_area_body_entered)
	animated_sprite.animation_finished.connect(_on_animation_finished)


# Revelar la puerta cerrada al derrotar al enemigo
func revelar_puerta() -> void:
	if not destination_scene.is_empty():
		return
	visible = true
	solid_shape.set_deferred("disabled", false)
	animated_sprite.play("closed")


# Punto de llegada frente a la puerta, compensado por el collider desplazado
func get_dog_approach_position(enemy: Node2D) -> Vector2:
	var center_target := area_shape.global_position + _get_enemy_approach_direction(enemy) * 36.0
	return _enemy_root_position_for_body_center(enemy, center_target)


# Punto detrás de la puerta, compensado por el collider desplazado
func get_dog_behind_position(enemy: Node2D) -> Vector2:
	var center_target := area_shape.global_position - _get_enemy_approach_direction(enemy) * 12.0
	return _enemy_root_position_for_body_center(enemy, center_target)


# Calcular desde qué lado llega el centro físico del perro
func _get_enemy_approach_direction(enemy: Node2D) -> Vector2:
	var difference := _get_enemy_body_center(enemy) - area_shape.global_position
	if absf(difference.x) > absf(difference.y):
		return Vector2.RIGHT * signf(difference.x)
	if not is_zero_approx(difference.y):
		return Vector2.DOWN * signf(difference.y)
	return Vector2.DOWN


func _get_enemy_body_center(enemy: Node2D) -> Vector2:
	var body_shape := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return body_shape.global_position if body_shape != null else enemy.global_position


func _enemy_root_position_for_body_center(enemy: Node2D, target_center: Vector2) -> Vector2:
	var body_offset := _get_enemy_body_center(enemy) - enemy.global_position
	return target_center - body_offset

# Abrir la puerta
func activar_puerta() -> void:
	if activada:
		return

	activada = true
	visible = true
	animated_sprite.play("opening")


# Completar la animación de apertura
func _on_animation_finished() -> void:
	if animated_sprite.animation != "opening":
		return

	animated_sprite.pause()
	solid_shape.set_deferred("disabled", true)
	abierta = true
	# Dejar el marco por delante del perro cuando cruce el umbral.
	animated_sprite.z_index = maxi(animated_sprite.z_index, 1)
	opening_finished.emit()
	for body in area.get_overlapping_bodies():
		if destination_scene.is_empty():
			_intentar_entrar_al_nivel_2(body)
		else:
			_intentar_cambiar_destino(body)


# Detectar quién llega a la puerta
func _on_area_body_entered(body: Node2D) -> void:
	if not destination_scene.is_empty():
		_intentar_cambiar_destino(body)
		return
	if body.is_in_group("dog") and body.get("derrotado") == true:
		registrar_llegada_enemigo(body)
		return

	_intentar_entrar_al_nivel_2(body)


# Activar la apertura cuando el perro alcanza la puerta
func registrar_llegada_enemigo(enemy: Node2D) -> void:
	if not destination_scene.is_empty() or not is_instance_valid(enemy):
		return
	if not enemy.is_in_group("dog") or enemy.get("derrotado") != true:
		return

	if enemy.has_method("on_door_touched"):
		enemy.call("on_door_touched")
	activar_puerta()


# Entrar a la escena destino cuando la puerta ya está abierta.
func _intentar_cambiar_destino(body: Node2D) -> void:
	if not abierta or nivel_completado or not body.is_in_group("player"):
		return
	nivel_completado = true
	get_tree().call_deferred("change_scene_to_file", destination_scene)


# Completar el nivel 1 y mostrar la ventana de victoria
func _intentar_entrar_al_nivel_2(body: Node2D) -> void:
	if not activada or not abierta or nivel_completado:
		return
	if not body.is_in_group("player"):
		return

	var current_health: int = int(body.get("health"))
	if current_health <= 0 or bool(body.get("is_dead")):
		return

	var victory_screen := get_tree().get_first_node_in_group("you_win_screen")
	if victory_screen == null:
		push_error("No se encontró la escena YOU WIN en el nivel 1.")
		return

	nivel_completado = true
	print("¡Nivel 1 completado! Mostrando la pantalla YOU WIN.")
	victory_screen.call_deferred("show_victory", current_health)
