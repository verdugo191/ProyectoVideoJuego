extends Area2D

@export var dialogue_portrait: Texture2D


# Obtener el retrato para el diálogo
func get_dialogue_portrait() -> Texture2D:
	if dialogue_portrait != null:
		return dialogue_portrait
	var animated_sprite := get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return null
	if not animated_sprite.sprite_frames.has_animation("rat_CalmDown"):
		return null
	return animated_sprite.sprite_frames.get_frame_texture("rat_CalmDown", 0)
