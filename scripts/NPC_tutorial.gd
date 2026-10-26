extends Area2D

@export var nombre_personaje: String = "NPC"
@export var animacion_espera: StringName = &"calm_Down"
@export var animacion_huida: StringName = &"go_Away"
@export var velocidad_huida: float = 220.0
@export var limite_mapa: Rect2 = Rect2(0.0, 0.0, 1152.0, 648.0)
@export var margen_salida: float = 36.0
@export var retrato: Texture2D

const DIALOGOS: Array[String] = [
	"Hola amigo, la aventura te espera.",
	"Oye, ya cruza esa puerta, la aventura te espera.",
	"¿En serio? Mejor me voy."
]

var npc: Node2D
var sprite: AnimatedSprite2D
var canvas: DialogueCanvas
var jugador_cerca: bool = false
var dialogo_abierto: bool = false
var huyendo: bool = false
var interacciones: int = 0
var direccion_huida: Vector2 = Vector2.ZERO


# Preparar el NPC y sus señales.
func _ready() -> void:
	npc = get_parent().get_parent() as Node2D
	sprite = get_parent() as AnimatedSprite2D
	if npc == null or sprite == null:
		push_error("NPC_tutorial necesita estar dentro de AnimatedSprite2D/Area2D.")
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_reproducir(animacion_espera)
	_obtener_canvas()


# Recordar si el jugador está a distancia de hablar.
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		jugador_cerca = true


# Dejar de aceptar interacción cuando el jugador se aleja.
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		jugador_cerca = false


# Avanzar una frase por cada interacción con E.
func _unhandled_input(event: InputEvent) -> void:
	if huyendo or dialogo_abierto or not jugador_cerca or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or (key_event.keycode != KEY_E and key_event.physical_keycode != KEY_E):
		return
	_obtener_canvas()
	if canvas == null or canvas.is_open:
		return
	get_viewport().set_input_as_handled()
	_hablar_siguiente()


# Mostrar la frase correspondiente y esperar a que se cierre.
func _hablar_siguiente() -> void:
	if interacciones >= DIALOGOS.size():
		return
	dialogo_abierto = true
	var numero_dialogo := interacciones
	var frase := DIALOGOS[numero_dialogo]
	interacciones += 1
	canvas.show_dialogue(nombre_personaje, [frase], retrato)
	await canvas.finished
	if not is_instance_valid(self):
		return
	dialogo_abierto = false
	if numero_dialogo == 0:
		_abrir_puerta_tutorial()
	if interacciones == DIALOGOS.size():
		_iniciar_huida()


# Abrir la puerta del tutorial después del primer diálogo.
func _abrir_puerta_tutorial() -> void:
	for puerta in get_tree().get_nodes_in_group("door"):
		if puerta.has_method("activar_puerta"):
			puerta.call("activar_puerta")


# Buscar el panel de diálogo del juego.
func _obtener_canvas() -> void:
	if canvas == null or not is_instance_valid(canvas):
		canvas = get_tree().get_first_node_in_group("dialogo") as DialogueCanvas


# Iniciar la huida hacia el borde más cercano.
func _iniciar_huida() -> void:
	huyendo = true
	set_process_unhandled_input(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	direccion_huida = Vector2.LEFT
	var animacion := _buscar_animacion(animacion_huida)
	if animacion.is_empty():
		push_warning("NPC tutorial: no se encontró la animación de huida '%s'." % animacion_huida)
		return
	sprite.sprite_frames.set_animation_loop(animacion, true)
	sprite.flip_h = false
	sprite.play(animacion)


# Elegir la dirección del límite más cercano del mapa.
func _direccion_hacia_borde_mas_cercano() -> Vector2:
	var posicion := npc.global_position
	var distancias: Array[float] = [
		posicion.x - limite_mapa.position.x,
		limite_mapa.end.x - posicion.x,
		posicion.y - limite_mapa.position.y,
		limite_mapa.end.y - posicion.y
	]
	var borde := 0
	for indice in range(1, distancias.size()):
		if distancias[indice] < distancias[borde]:
			borde = indice
	match borde:
		0:
			return Vector2.LEFT
		1:
			return Vector2.RIGHT
		2:
			return Vector2.UP
		_:
			return Vector2.DOWN


# Caminar y salir del mapa.
func _physics_process(delta: float) -> void:
	if not huyendo or not is_instance_valid(npc):
		return
	npc.global_position += direccion_huida * velocidad_huida * delta
	if not limite_mapa.grow(margen_salida).has_point(npc.global_position):
		npc.queue_free()


# Reproducir una animación si existe.
func _reproducir(animacion: StringName) -> void:
	var nombre := _buscar_animacion(animacion)
	if nombre.is_empty():
		push_warning("NPC tutorial: no se encontró la animación '%s'." % animacion)
		return
	sprite.play(nombre)


# Encontrar animaciones sin distinguir mayúsculas ni separadores.
func _buscar_animacion(animacion: StringName) -> StringName:
	if sprite == null or sprite.sprite_frames == null:
		return &""
	if sprite.sprite_frames.has_animation(animacion):
		return animacion
	var buscado := String(animacion).to_lower().replace("_", "").replace(" ", "")
	for nombre in sprite.sprite_frames.get_animation_names():
		if String(nombre).to_lower().replace("_", "").replace(" ", "") == buscado:
			return nombre
	return &""
