
extends StaticBody2D

@onready var area: Area2D = $Area2D

var activada: bool = false
var nivel_completado: bool = false

func _ready() -> void:
	add_to_group("door")
	visible = false
	area.body_entered.connect(_on_area_body_entered)

func activar_puerta() -> void:
	activada = true
	visible = true

func _on_area_body_entered(body: Node2D) -> void:
	if not activada or nivel_completado:
		return

	if body.is_in_group("player"):
		nivel_completado = true
		print("¡NIVEL COMPLETADO!")
		get_tree().paused = true
