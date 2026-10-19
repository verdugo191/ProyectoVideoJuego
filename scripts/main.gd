extends Node2D

var score: int = 0
var totalCoins: int = 4

# Sumar un objeto al contador
func add_score():
	score += 1
	$UI/ScoreLabel.text = "Rocks: " + str(score)
	if score >= totalCoins:
		win_game()

# Mostrar la victoria
func win_game():
	$UI/WinGame.text = "YOU WIN!"

# Inicializar la escena
func _ready() -> void:
	pass # Replace with function body.


# Actualizar la escena
func _process(_delta: float) -> void:
	pass


# Procesar un objeto recogido
func _on_coin_collected() -> void:
	add_score()
	pass # Replace with function body.
