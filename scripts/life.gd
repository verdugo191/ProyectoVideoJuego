extends TextureProgressBar

# Vincular la interfaz de vida
func _ready() -> void:
	add_to_group("vida_ui")

# Actualizar la barra de vida
func actualizar(vida: int) -> void:
	value = vida
