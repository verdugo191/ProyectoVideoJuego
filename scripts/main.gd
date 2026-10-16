extends Node2D

var score: int = 0
var totalCoins: int = 4

#Funcion para actualizar el score
func add_score():
	score += 1
	$UI/ScoreLabel.text = "Monedas: " + str(score)
	if score >= totalCoins:
		win_game()

#Funcion para saber cuando gane
func win_game():
	$UI/WinGame.text = "GANASTE!"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_coin_collected() -> void:
	add_score()
	pass # Replace with function body.
