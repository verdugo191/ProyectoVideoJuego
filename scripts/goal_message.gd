extends Label

@export var message_duration: float = 3.0
var message_timer: Timer

# Preparar el mensaje temporal
func _ready() -> void:
	hide()
	message_timer = Timer.new()
	message_timer.one_shot = true
	message_timer.wait_time = message_duration
	message_timer.timeout.connect(hide)
	add_child(message_timer)
	call_deferred("show_message", "Talk to Jack.")


# Mostrar un objetivo
func show_message(message: String) -> void:
	text = message
	show()
	message_timer.start(message_duration)
