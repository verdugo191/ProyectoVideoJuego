
extends Node

signal quest_update
signal quest_completed

enum QuestState {
	NOT_STARTED,
	ACTIVE,
	READY_TO_DELIVER,
	COMPLETED
}

var quest_state: QuestState = QuestState.NOT_STARTED
var required_coins: int = 3
var collected_coins: int = 0
var rocks_in_inventory: int = 0
var cheese_unlocked: bool = false
var cheese_count: int = 0
var cheese_delivered: bool = false
var collected_cheese_ids: Array[String] = []
const required_cheese: int = 3


# Iniciar el gestor de misiones
func _ready() -> void:
	print("Sistema de misiones iniciado")


# Borrar el progreso e inventario de rocas al reiniciar el nivel 1 tras morir
func reset_rock_quest() -> void:
	quest_state = QuestState.NOT_STARTED
	collected_coins = 0
	rocks_in_inventory = 0
	quest_update.emit()

# Iniciar la misión de las rocas
func start_quest() -> void:
	if quest_state != QuestState.NOT_STARTED:
		return

	collected_coins = 0
	quest_state = QuestState.ACTIVE
	quest_update.emit()
	get_tree().call_group("goal_message", "show_message", "Defeat the dog.")
	print("Misión iniciada: recoge 3 rocas")


# Contar una roca recogida
func collect_coin() -> bool:
	rocks_in_inventory += 1

	if quest_state == QuestState.ACTIVE:
		collected_coins += 1

		if collected_coins >= required_coins:
			collected_coins = required_coins
			quest_state = QuestState.READY_TO_DELIVER
			print("¡Has recogido las 3 rocas!")
		else:
			print("Rocas: ", collected_coins, "/", required_coins)

	quest_update.emit()
	return true


# Usar una roca del inventario
func consume_rock() -> bool:
	if rocks_in_inventory <= 0:
		return false

	rocks_in_inventory -= 1
	quest_update.emit()
	return true


# Completar la misión de las rocas
func complete_quest() -> void:
	if quest_state != QuestState.READY_TO_DELIVER:
		return

	quest_state = QuestState.COMPLETED
	quest_update.emit()
	quest_completed.emit()
	print("Misión completada")


# Reiniciar la misión del queso
func start_cheese_level() -> void:
	cheese_unlocked = false
	cheese_count = 0
	cheese_delivered = false
	collected_cheese_ids.clear()
	get_tree().call_group("level_2", "update_cheese_count", cheese_count)


# Habilitar los quesos
func unlock_cheese() -> void:
	cheese_unlocked = true


# Contar un queso recogido
func collect_cheese(cheese_id: String = "", allow_before_unlock: bool = false) -> bool:
	if (not cheese_unlocked and not allow_before_unlock) or cheese_delivered or cheese_count >= required_cheese:
		return false
	cheese_count += 1
	if not cheese_id.is_empty() and not collected_cheese_ids.has(cheese_id):
		collected_cheese_ids.append(cheese_id)
	get_tree().call_group("level_2", "update_cheese_count", cheese_count)
	return true


# Entregar los quesos
func deliver_cheese() -> bool:
	if cheese_delivered or cheese_count < required_cheese:
		return false
	cheese_delivered = true
	return true
