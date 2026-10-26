extends TextureProgressBar

const MAX_STARS := 4


func _ready() -> void:
	min_value = 0
	max_value = MAX_STARS
	step = 1
	value = 0


# Mostrar las estrellas obtenidas.
func set_stars(count: int) -> void:
	value = clampi(count, 0, MAX_STARS)
