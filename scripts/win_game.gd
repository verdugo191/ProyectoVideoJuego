extends Label


const TOTAL_MONEDAS: int = 4

var monedas_recogidas: int = 0


func _ready() -> void:
	add_to_group("win_message")

	visible = false


func sumar_moneda_ganadora() -> void:
	monedas_recogidas += 1

	if monedas_recogidas >= TOTAL_MONEDAS:

		text = "¡FELICIDADES! ¡GANASTE!"
		visible = true

		# Mostrar la puerta
		get_tree().call_group("door", "activar_puerta")
