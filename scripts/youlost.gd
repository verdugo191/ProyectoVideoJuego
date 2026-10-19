extends Label

@export var jugador: Node2D


# Preparar el mensaje de derrota
func _ready() -> void:
	text = "YOU LOST!"
	visible = false

	# Si no se asignó en el Inspector, buscar al jugador por su grupo
	if jugador == null:
		jugador = get_tree().get_first_node_in_group("player") as Node2D

	if jugador == null:
		push_warning("YouLost: no se encontró al jugador")
		return

	# Mostrar el mensaje cuando el jugador emita la señal "dead"
	jugador.dead.connect(_on_jugador_dead)


# Mostrar la derrota
func _on_jugador_dead() -> void:
	visible = true
