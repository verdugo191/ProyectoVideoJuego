extends Area2D

enum State { QUIETO, HABLANDO, SALIENDO }

@export var nombre_personaje: String = "Jack"
@export var retrato: Texture2D
@export var velocidad: float = 120.0
@export var direccion_salida: Vector2 = Vector2.LEFT
@export var limite_mapa: Rect2 = Rect2(0, 0, 1152, 648)
@export var margen_salida: float = 80.0
@export var anim_quieto: String = "calmDown"
@export var anim_salida: String = "goAway"
@export var animacion_mira_izquierda: bool = true

var dialogos: Array[String] = [
	"Oh, hello, friend. Be careful; there's a dog roaming around here.",
	"Maybe you can scare it away by picking up some of the rocks nearby."
]

var state: State = State.QUIETO
var jugador_cerca: bool = false
var cancelado: bool = false
var canvas: DialogueCanvas = null
var npc: Node2D = null
var sprite: AnimatedSprite2D = null


# Preparar a Jack y sus señales
func _ready() -> void:
	npc = owner as Node2D
	if npc == null:
		npc = get_parent() as Node2D
	if npc != null:
		npc.add_to_group("jack_npc")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var sprites := npc.find_children("*", "AnimatedSprite2D", true, false)
	if not sprites.is_empty():
		sprite = sprites[0] as AnimatedSprite2D

	direccion_salida = direccion_salida.normalized()
	_reproducir(anim_quieto)


# Detectar cercanía del jugador
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		jugador_cerca = true


# Detectar cuando el jugador se aleja
func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	jugador_cerca = false

	if state == State.HABLANDO and canvas != null:
		cancelado = true
		canvas.close_dialogue()


# Iniciar diálogo con E
func _unhandled_input(event: InputEvent) -> void:
	if state != State.QUIETO or not jugador_cerca:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		get_viewport().set_input_as_handled()
		_hablar()


# Mostrar el diálogo de Jack
func _hablar() -> void:
	canvas = get_tree().get_first_node_in_group("dialogo") as DialogueCanvas

	if canvas == null:
		push_warning("No encuentro el CanvasLayer del diálogo (grupo dialogo)")
		return

	state = State.HABLANDO
	cancelado = false
	canvas.show_dialogue(nombre_personaje, dialogos, retrato)
	await canvas.finished

	if cancelado:
		state = State.QUIETO
		return

	QuestManager.start_quest()
	_salir()


# Hacer salir a Jack del mapa
func _salir() -> void:
	state = State.SALIENDO

	set_deferred("monitoring", false)

	if sprite != null and direccion_salida.x != 0.0:
		var va_a_la_derecha := direccion_salida.x > 0.0
		sprite.flip_h = va_a_la_derecha == animacion_mira_izquierda

	_reproducir(anim_salida)


# Mover a Jack al salir
func _physics_process(delta: float) -> void:
	if state != State.SALIENDO:
		return

	npc.global_position += direccion_salida * velocidad * delta

	var fuera := limite_mapa.grow(margen_salida)

	if not fuera.has_point(npc.global_position):
		npc.queue_free()


# Reproducir una animación
func _reproducir(animacion: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		push_warning("Jack no encuentra su AnimatedSprite2D o no tiene SpriteFrames")
		return

	var nombre := _buscar_animacion(animacion)

	if nombre == "":
		push_warning("Jack no tiene la animación '%s'. Disponibles: %s" % [animacion, sprite.sprite_frames.get_animation_names()])
		return

	sprite.play(nombre)


# Buscar una animación por nombre
func _buscar_animacion(animacion: String) -> String:
	var frames := sprite.sprite_frames

	if frames.has_animation(animacion):
		return animacion

	var buscado := animacion.to_lower().replace("_", "").replace(" ", "")

	for nombre in frames.get_animation_names():
		if String(nombre).to_lower().replace("_", "").replace(" ", "") == buscado:
			return nombre

	return ""
