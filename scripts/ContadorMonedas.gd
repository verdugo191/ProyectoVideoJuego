extends Label

var monedas := 0

func _ready() -> void:
	add_to_group("hud")
	actualizar()

func sumar_moneda() -> void:
	monedas += 1
	actualizar()

func actualizar() -> void:
	text = "Monedas: %d" % monedas
