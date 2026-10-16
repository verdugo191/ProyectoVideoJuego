extends Area2D

signal collected

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Reproducir la animación de la moneda
	animated_sprite.play("coin")


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		
		
		collected.emit()

		# Actualizar contador
		get_tree().call_group("hud", "sumar_moneda")
		
		# Actualizar sistema de victoria
		get_tree().call_group("win_message", "sumar_moneda_ganadora")
		
		
		# Eliminar la moneda recogida
		queue_free()
