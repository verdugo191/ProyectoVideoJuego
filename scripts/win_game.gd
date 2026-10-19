extends Label


const TOTAL_MONEDAS: int = 4

var monedas_recogidas: int = 0


# Preparar el mensaje de victoria
func _ready() -> void:
	add_to_group("win_message")

	visible = false


# Contar los objetos recogidos
func sumar_moneda_ganadora() -> void:
	monedas_recogidas += 1

	if monedas_recogidas >= TOTAL_MONEDAS:

		text = "CONGRATULATIONS! YOU WIN!"
		visible = true

		# Mostrar la puerta
		get_tree().call_group("door", "activar_puerta")
