
extends StaticBody2D

signal opening_finished

@onready var area: Area2D = $Area2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var solid_shape: CollisionShape2D = $CollisionShape2D

var activada: bool = false
var abierta: bool = false
var nivel_completado: bool = false

# Preparar la puerta y sus señales
func _ready() -> void:
	add_to_group("door")
	visible = false
	solid_shape.disabled = true
	area.body_entered.connect(_on_area_body_entered)
	animated_sprite.animation_finished.connect(_on_animation_finished)

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
	opening_finished.emit()
	# Si el jugador llegó mientras la puerta se animaba, no exigimos que salga
	# del área y vuelva a entrar para completar la transición.
	for body in area.get_overlapping_bodies():
		_intentar_entrar_al_nivel_2(body)

# Detectar quién llega a la puerta
func _on_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("dog") and body.get("derrotado") == true:
		if body.has_method("on_door_touched"):
			body.call("on_door_touched")
		activar_puerta()
		return

	_intentar_entrar_al_nivel_2(body)


# Cambiar al segundo nivel
func _intentar_entrar_al_nivel_2(body: Node2D) -> void:
	if not activada or not abierta or nivel_completado:
		return
	if not body.is_in_group("player"):
		return

	nivel_completado = true
	print("¡Nivel 1 completado! Entrando al segundo nivel.")
	get_tree().call_deferred("change_scene_to_file", "res://scenes/level_2.tscn")
