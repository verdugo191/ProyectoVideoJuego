extends Label

# Conectar el contador
func _ready() -> void:
	add_to_group("hud")
	if not QuestManager.quest_update.is_connected(actualizar):
		QuestManager.quest_update.connect(actualizar)
	actualizar()

# Mostrar las rocas del inventario
func actualizar() -> void:
	text = "Rocks: %d" % QuestManager.rocks_in_inventory
