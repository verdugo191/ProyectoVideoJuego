extends Node

const SAVE_DIRECTORY := "user://saves/"
const FIRST_LEVEL := "res://scenes/level_1.tscn"

var pending_data: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(
		SAVE_DIRECTORY
	)


# Crear una partida completamente nueva.
func new_game() -> void:
	pending_data.clear()
	get_tree().paused = false

	# Reiniciar la misión anterior.
	QuestManager.reset_quest()

	get_tree().change_scene_to_file.call_deferred(
		FIRST_LEVEL
	)


# Obtener una ruta segura a partir del ID.
func get_save_path(slot_id: int) -> String:
	return SAVE_DIRECTORY + "partida_%03d.json" % slot_id


# Buscar el próximo ID disponible.
func get_next_slot_id() -> int:
	var slot_id := 1

	while FileAccess.file_exists(
		get_save_path(slot_id)
	):
		slot_id += 1

	return slot_id


# Guardar una partida.
# slot_id = 0 crea un archivo nuevo.
# slot_id > 0 sobrescribe ese archivo.
func save_game(
	player: CharacterBody2D,
	level_path: String,
	slot_id: int = 0
) -> bool:

	if player == null:
		return false

	if not ResourceLoader.exists(level_path):
		push_error("La escena del nivel no existe")
		return false

	if slot_id <= 0:
		slot_id = get_next_slot_id()

	var data: Dictionary = {
		"version": 1,
		"slot_id": slot_id,
		"level_path": level_path,
		"health": player.health,
		"position_x": player.global_position.x,
		"position_y": player.global_position.y,
		"quest_state": int(QuestManager.quest_state),
		"collected_crystals": QuestManager.collected_crystals,
		"collected_crystal_ids": QuestManager.collected_crystal_ids.duplicate(),
		"saved_at": Time.get_datetime_string_from_system()
	}

	var path := get_save_path(slot_id)

	var file := FileAccess.open(
		path,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"Error al guardar: %s" %
			FileAccess.get_open_error()
		)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	print("Partida guardada en: ", path)
	return true


# Leer un archivo sin cargar todavía el nivel.
func read_save(slot_id: int) -> Dictionary:
	if slot_id <= 0:
		return {}

	var path := get_save_path(slot_id)

	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		return {}

	var json_text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)

	if not (parsed is Dictionary):
		return {}

	var data: Dictionary = parsed

	if not data.has("level_path"):
		return {}

	return data


# Listar todas las partidas disponibles.
func get_saved_games() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []

	var dir := DirAccess.open(SAVE_DIRECTORY)

	if dir == null:
		return saves

	dir.list_dir_begin()

	var filename := dir.get_next()

	while filename != "":
		if not dir.current_is_dir():
			if filename.begins_with("partida_") \
			and filename.ends_with(".json"):

				var id_text := filename.trim_prefix(
                    "partida_"
				).trim_suffix(".json")

				if id_text.is_valid_int():
					var slot_id := int(id_text)

					if slot_id > 0:
						var data := read_save(slot_id)

						if not data.is_empty():
							data["slot_id"] = slot_id
							saves.append(data)

		filename = dir.get_next()

	dir.list_dir_end()

	saves.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["slot_id"]) < int(b["slot_id"])
	)

	return saves


# Cargar la partida seleccionada.
func load_game(slot_id: int) -> bool:
	var data := read_save(slot_id)

	if data.is_empty():
		push_warning("No se encontró la partida")
		return false

	var level_path := str(data["level_path"])

	if not ResourceLoader.exists(level_path):
		push_error("No existe el nivel guardado")
		return false

	pending_data = data

	get_tree().paused = false

	get_tree().change_scene_to_file.call_deferred(
		level_path
	)

	return true


# Aplicar los datos al jugador del nivel cargado.
func apply_saved_data(
	player: CharacterBody2D
) -> void:

	if pending_data.is_empty():
		return

	var data := pending_data.duplicate(true)

	# Restaurar la vida del jugador
	player.health = clampi(
		int(data.get("health", player.max_health)),
		0,
		player.max_health
	)
	
	# Notificar al GameHUD para actualizar la barra de vida
	player.health_changed.emit(
		player.health,
		player.max_health
	)

	# Restaurar posición.
	player.global_position = Vector2(
		float(data.get("position_x", 0)),
		float(data.get("position_y", 0))
	)

	# Restaurar misión.
	QuestManager.collected_crystals = int(
		data.get("collected_crystals", 0)
	)

	QuestManager.quest_state = int(
		data.get("quest_state", 0)
	) as QuestManager.QuestState

	QuestManager.collected_crystal_ids.clear()

	for crystal_id in data.get(
		"collected_crystal_ids", []
	):
		QuestManager.collected_crystal_ids.append(
			str(crystal_id)
		)

	# Eliminar cristales ya recolectados.
	for crystal in get_tree().get_nodes_in_group(
        "crystals"
	):
		if crystal.crystal_id in \
		QuestManager.collected_crystal_ids:
			crystal.queue_free()

	QuestManager.quest_updated.emit()

	pending_data.clear()

	print("Partida recuperada correctamente")
