extends Node

const SAVE_DIRECTORY := "user://saves/"
const QUICK_SAVE_SLOT := 1

var pending_data: Dictionary = {}
var pending_scene_path: String = ""
var pending_wait_frames: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))
	set_process(true)


# Teclas rápidas de guardado y carga.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F5:
		quick_save()
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_F6:
		quick_load()
		get_viewport().set_input_as_handled()


# Guardar un nuevo punto en una ranura independiente.
func quick_save() -> bool:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var current_scene := get_tree().current_scene
	if player == null or current_scene == null or current_scene.scene_file_path.is_empty():
		push_warning("No se pudo guardar: no se encontró el jugador o la escena actual.")
		return false
	var slot_id := get_next_slot_id()
	var saved := save_game(player, current_scene.scene_file_path, slot_id)
	if saved:
		print("Partida guardada en la ranura %d." % slot_id)
	return saved


# Cargar la partida más reciente desde F6.
func quick_load() -> bool:
	var saves := get_saved_games()
	if saves.is_empty():
		push_warning("No hay partidas guardadas para cargar.")
		return false
	return load_game(int(saves[-1].get("slot_id", 0)))


# Obtener el siguiente número de ranura libre.
func get_next_slot_id() -> int:
	var highest_slot := 0
	for save_data in get_saved_games():
		highest_slot = maxi(highest_slot, int(save_data.get("slot_id", 0)))
	return highest_slot + 1


# Borrar una partida guardada.
func delete_save(slot_id: int) -> bool:
	if slot_id <= 0 or not FileAccess.file_exists(get_save_path(slot_id)):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(get_save_path(slot_id))) == OK

# Guardar estado de jugador, nivel, misiones y actores importantes.
func save_game(player: CharacterBody2D, level_path: String, slot_id: int = QUICK_SAVE_SLOT) -> bool:
	if player == null or not ResourceLoader.exists(level_path):
		return false
	if slot_id <= 0:
		slot_id = QUICK_SAVE_SLOT

	var current_scene := get_tree().current_scene
	var dog := get_tree().get_first_node_in_group("dog")		as Node2D
	var rat := get_tree().get_first_node_in_group("mr_cheese") as Node2D
	var data: Dictionary = {
		"version": 3,
		"slot_id": slot_id,
		"level_path": level_path,
		"player_position": [player.global_position.x, player.global_position.y],
		"player_health": int(player.get("health")),
		"quest_state": int(QuestManager.quest_state),
		"collected_coins": QuestManager.collected_coins,
		"rocks_in_inventory": QuestManager.rocks_in_inventory,
		"cheese_unlocked": QuestManager.cheese_unlocked,
		"cheese_count": QuestManager.cheese_count,
		"collected_cheese_ids": QuestManager.collected_cheese_ids.duplicate(),
		"cheese_delivered": QuestManager.cheese_delivered,
		"dog": _actor_state(dog, ["health", "derrotado"]),
		"jack_spoken": QuestManager.quest_state != QuestManager.QuestState.NOT_STARTED,
		"mr_cheese": _actor_state(rat, ["mission_accepted", "movement_mode", "at_exit", "already_interacted", "exit_waypoint_index", "back_door_waypoint_index"]),
		"mr_cheese_exists": rat != null,
		"scene_name": str(current_scene.name) if current_scene != null else "",
		"saved_at": Time.get_datetime_string_from_system()
	}
	if current_scene != null and current_scene.has_method("get_save_state"):
		data["level_state"] = current_scene.call("get_save_state")

	var file := FileAccess.open(get_save_path(slot_id), FileAccess.WRITE)
	if file == null:
		push_error("No se pudo escribir la partida: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


# Guardar posición y propiedades de un actor.
func _actor_state(actor: Node2D, property_names: Array[String]) -> Dictionary:
	if actor == null:
		return {}
	var state: Dictionary = {
		"position": [actor.global_position.x, actor.global_position.y]
	}
	for property_name in property_names:
		state[property_name] = actor.get(property_name)
	return state


# Obtener la ruta de una ranura.
func get_save_path(slot_id: int) -> String:
	return SAVE_DIRECTORY + "partida_%03d.json" % slot_id


# Leer una partida guardada.
func read_save(slot_id: int) -> Dictionary:
	if slot_id <= 0 or not FileAccess.file_exists(get_save_path(slot_id)):
		return {}
	var file := FileAccess.open(get_save_path(slot_id), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary and parsed.has("level_path") else {}


# Listar ranuras para la futura interfaz de carga.
func get_saved_games() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIRECTORY)
	if dir == null:
		return saves
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir() and filename.begins_with("partida_") and filename.ends_with(".json"):
			var id_text := filename.trim_prefix("partida_").trim_suffix(".json")
			if id_text.is_valid_int():
				var saved := read_save(int(id_text))
				if not saved.is_empty():
					saves.append(saved)
		filename = dir.get_next()
	dir.list_dir_end()
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("slot_id", 0)) < int(b.get("slot_id", 0)))
	return saves


# Cambiar al nivel guardado y restaurar cuando la escena esté lista.
func load_game(slot_id: int) -> bool:
	var data := read_save(slot_id)
	if data.is_empty():
		return false
	var level_path := str(data.get("level_path", ""))
	if not ResourceLoader.exists(level_path):
		push_error("No existe la escena guardada: %s" % level_path)
		return false
	pending_data = data
	pending_scene_path = level_path
	pending_wait_frames = 2
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(level_path)
	return true


# Esperar a que el jugador de la escena cargada esté listo.
func _process(_delta: float) -> void:
	if pending_data.is_empty():
		return
	if pending_wait_frames > 0:
		pending_wait_frames -= 1
		return
	var current_scene := get_tree().current_scene
	if current_scene == null or current_scene.scene_file_path != pending_scene_path:
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null or not player.is_node_ready():
		return
	_apply_save(player, current_scene, pending_data)
	pending_data.clear()
	pending_scene_path = ""
	print("Partida cargada correctamente.")


# Indicar a los niveles que no reinicien sus misiones durante una carga.
func is_loading_save() -> bool:
	return not pending_data.is_empty()


# Aplicar todos los valores guardados.
func _apply_save(player: CharacterBody2D, current_scene: Node, data: Dictionary) -> void:
	var position_data: Array = data.get("player_position", [player.global_position.x, player.global_position.y])
	player.global_position = Vector2(float(position_data[0]), float(position_data[1]))
	if _has_property(player, "health"):
		player.set("health", clampi(int(data.get("player_health", player.get("max_health"))), 0, int(player.get("max_health"))))
		if player.has_signal("health_change"):
			player.emit_signal("health_change", player.get("health"), player.get("max_health"))
		elif player.has_signal("health_changed"):
			player.emit_signal("health_changed", player.get("health"), player.get("max_health"))
		elif player.has_method("_update_health_bar"):
			player.call("_update_health_bar")

	QuestManager.quest_state = int(data.get("quest_state", QuestManager.QuestState.NOT_STARTED)) as QuestManager.QuestState
	QuestManager.collected_coins = int(data.get("collected_coins", 0))
	QuestManager.rocks_in_inventory = int(data.get("rocks_in_inventory", 0))
	QuestManager.cheese_unlocked = bool(data.get("cheese_unlocked", false))
	QuestManager.cheese_count = clampi(int(data.get("cheese_count", 0)), 0, QuestManager.required_cheese)
	QuestManager.cheese_delivered = bool(data.get("cheese_delivered", false))
	QuestManager.collected_cheese_ids.clear()
	for cheese_id in data.get("collected_cheese_ids", []):
		QuestManager.collected_cheese_ids.append(str(cheese_id))
	QuestManager.quest_update.emit()
	get_tree().call_group("level_2", "update_cheese_count", QuestManager.cheese_count)
	get_tree().call_group("vida_ui", "actualizar", int(player.get("health")))
	_restore_collected_cheese()

	_restore_actor(get_tree().get_first_node_in_group("dog") as Node2D, data.get("dog", {}))
	if bool(data.get("jack_spoken", false)):
		for jack in get_tree().get_nodes_in_group("jack_npc"):
			jack.queue_free()
	_restore_actor(get_tree().get_first_node_in_group("mr_cheese") as Node2D, data.get("mr_cheese", {}))
	if not bool(data.get("mr_cheese_exists", true)):
		for rat in get_tree().get_nodes_in_group("mr_cheese"):
			rat.queue_free()
	# No volver a mostrar instrucciones iniciales al cargar.
	if current_scene.has_method("suppress_intro_after_load"):
		current_scene.call("suppress_intro_after_load")
	if current_scene.has_method("restore_save_state"):
		current_scene.call("restore_save_state", data.get("level_state", {}))


# Restaurar la posición y los campos guardados de un actor.
func _restore_actor(actor: Node2D, state: Variant) -> void:
	if actor == null or not (state is Dictionary) or state.is_empty():
		return
	var saved_position: Array = state.get("position", [actor.global_position.x, actor.global_position.y])
	actor.global_position = Vector2(float(saved_position[0]), float(saved_position[1]))
	for key in state:
		if key != "position" and _has_property(actor, StringName(key)):
			actor.set(key, state[key])
	if actor.has_method("refresh_after_load"):
		actor.call("refresh_after_load")


# Comprobar una propiedad de un objeto.
func _has_property(object: Object, property_name: StringName) -> bool:
	for property_info in object.get_property_list():
		if StringName(property_info["name"]) == property_name:
			return true
	return false


# Quitar del mapa la cantidad de quesos que ya se había recogido.
func _restore_collected_cheese() -> void:
	var cheese_nodes := get_tree().get_nodes_in_group("cheese_pickups")
	if not QuestManager.collected_cheese_ids.is_empty():
		for cheese in cheese_nodes:
			if QuestManager.collected_cheese_ids.has(str(cheese.name)):
				cheese.queue_free()
		return
	# Compatibilidad con partidas guardadas antes de guardar IDs por queso.
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		cheese_nodes.sort_custom(func(a: Node, b: Node) -> bool:
			return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position)
		)
	else:
		cheese_nodes.sort_custom(func(a: Node, b: Node) -> bool: return str(a.name) < str(b.name))
	var to_remove := mini(QuestManager.cheese_count, cheese_nodes.size())
	for index in range(to_remove):
		var cheese: Node = cheese_nodes[index]
		QuestManager.collected_cheese_ids.append(str(cheese.name))
		cheese.queue_free()
