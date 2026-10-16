extends TextureProgressBar

func _ready() -> void:
	add_to_group("vida_ui")

func actualizar(vida: int) -> void:
	value = vida
