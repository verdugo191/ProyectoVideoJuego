extends CharacterBody2D

enum State {
	PATROL,
	CHASE,
	GO_TO_DOOR,
	WAIT_FOR_DOOR,
	ENTER_DOOR
}

const SPEED: float = 100.0
const CHASE_SPEED: float = 160.0
const CHANGE_DIRECTION_TIME: float = 2.0

# --- Ajustes de movimiento y anti-atasco ---
const PROBE_PATROL: float = 22.0          # Distancia con la que se "huele" una pared al patrullar
const PROBE_CHASE: float = 24.0           # Distancia con la que se "huele" una pared al perseguir
const STUCK_CHECK_INTERVAL: float = 0.3   # Cada cuánto se comprueba si el perro avanza
const STUCK_MIN_PROGRESS: float = 0.25    # Fracción mínima del avance esperado para no considerarse atascado
const ESCAPE_TIME: float = 0.45           # Duración del empujón lateral al atascarse
const CHASE_MEMORY: float = 1.0           # Segundos que sigue persiguiendo tras perder de vista al gato
const REPATH_INTERVAL: float = 0.25       # Cada cuánto se recalcula la ruta de navegación
const DOOR_GHOST_AFTER_STUCK: int = 3     # Atascos seguidos antes de atravesar obstáculos hacia la puerta
const DOOR_TRIP_TIMEOUT: float = 8.0      # Si tarda más que esto en llegar a la puerta, atraviesa obstáculos
const DOOR_ENTER_TIMEOUT: float = 4.0     # Seguro por si nunca llega detrás de la puerta
const DOOR_SNAP_DISTANCE: float = 3.0     # A esta distancia del punto de espera, se coloca exacto
const DOOR_WAYPOINT_REACHED: float = 14.0 # Distancia para dar por alcanzado un punto intermedio
const DOOR_FINAL_APPROACH: float = 30.0   # Desde aquí avanza recto y suave al punto de espera

@export var damage: int = 1

@export var attack_delay: float = 0.0
@export var attack_cooldown: float = 0.5
@export var max_health: int = 4

# Lado de la puerta donde el perro espera (DOWN = debajo de la puerta, como en tu captura).
# Opciones: Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT
@export var door_front_direction: Vector2 = Vector2.DOWN
# Separación (en píxeles) entre el borde de la colisión de la puerta y el cuerpo del perro.
# Auméntala si quieres que espere más lejos de la puerta, redúcela para que quede más pegado.
@export var door_wait_margin: float = 10.0

@onready var campo_vision: Area2D = $Area2D
@onready var area_ataque: Area2D = $Area2D2
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_label: Label = $HealthLabel

var current_state: State = State.PATROL
var gato: Node2D = null
var puerta: Node2D = null
var door_navigation_agent: NavigationAgent2D
var door_route_target: Vector2 = Vector2.ZERO
var door_route_started: bool = false
var health: int = 4
var derrotado: bool = false

var direccion: Vector2 = Vector2.ZERO
var tiempo_cambio: float = 0.0

var esperando_ataque: bool = false
var atacando: bool = false
var tiempo_espera: float = 0.0
var tiempo_recarga: float = 0.0
var tiempo_ataque: float = 0.0
var duracion_ataque: float = 0.0
var tiempo_sin_ver: float = 0.0

# Estado del anti-atasco
var avoid_side: int = 1
var escape_dir: Vector2 = Vector2.ZERO
var escape_timer: float = 0.0
var repath_timer: float = 0.0
var stuck_timer: float = 0.0
var stuck_last_pos: Vector2 = Vector2.ZERO
var stuck_hits: int = 0
var fantasma: bool = false
var tiempo_en_ruta_puerta: float = 0.0
var tiempo_entrando: float = 0.0
var mirando_horizontal: bool = true

# Datos de la puerta (se calculan al ser derrotado)
var mask_original: int = 1
var door_obstacle_rect: Rect2 = Rect2()
var door_has_obstacle: bool = false
var door_wait_position: Vector2 = Vector2.ZERO
var door_behind_position: Vector2 = Vector2.ZERO
var door_geometry_ok: bool = false
var door_waypoints: Array[Vector2] = []
var door_waypoint_index: int = 0
var llegada_registrada: bool = false

var _intended_dir: Vector2 = Vector2.ZERO
var _intended_speed: float = 0.0
var _colision: KinematicCollision2D = KinematicCollision2D.new()


# Preparar al perro y sus señales
func _ready() -> void:
	add_to_group("dog")
	mask_original = collision_mask

	# Vista cenital: sin "suelo", sin pendientes y deslizándose siempre por las paredes.
	# Con el modo por defecto (GROUNDED) el perro se frenaba al chocar de frente.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0

	door_navigation_agent = NavigationAgent2D.new()
	door_navigation_agent.name = "DoorNavigationAgent"
	door_navigation_agent.path_desired_distance = 8.0
	door_navigation_agent.target_desired_distance = 10.0
	door_navigation_agent.radius = 10.0
	add_child(door_navigation_agent)
	health = max_health
	gato = get_tree().get_first_node_in_group("player") as Node2D
	_update_health_label()

	avoid_side = 1 if randf() < 0.5 else -1
	stuck_last_pos = global_position
	cambiar_direccion()
	animated_sprite.stop()


# Actualizar estados y movimiento
func _physics_process(delta: float) -> void:
	# En el nivel 2 el jugador se instancia desde el nodo padre después de que
	# este enemigo haya recibido _ready(); volver a buscarlo evita una referencia nula.
	if gato == null or not is_instance_valid(gato):
		gato = get_tree().get_first_node_in_group("player") as Node2D

	_intended_speed = 0.0
	escape_timer = maxf(escape_timer - delta, 0.0)
	repath_timer = maxf(repath_timer - delta, 0.0)

	if current_state == State.GO_TO_DOOR:
		ir_a_la_puerta(delta)
		move_and_slide()
		_actualizar_atasco(delta)
		actualizar_animacion()
		return

	if current_state == State.WAIT_FOR_DOOR:
		velocity = Vector2.ZERO
		animated_sprite.stop()
		move_and_slide()
		return

	if current_state == State.ENTER_DOOR:
		_mover_detras_de_la_puerta(delta)
		move_and_slide()
		actualizar_animacion()
		return

	if gato == null:
		velocity = Vector2.ZERO
		patrol(delta)
		move_and_slide()
		_actualizar_atasco(delta)
		actualizar_animacion()
		return

	if _gato_muerto():
		velocity = Vector2.ZERO
		esperando_ataque = false
		atacando = false
		animated_sprite.stop()
		move_and_slide()
		return

	if tiempo_recarga > 0.0:
		tiempo_recarga = maxf(tiempo_recarga - delta, 0.0)

	# Si está atacando, no interrumpir la animación.
	if atacando:
		velocity = Vector2.ZERO
		tiempo_ataque += delta

		if tiempo_ataque >= duracion_ataque:
			atacando = false
			animated_sprite.stop()
			comprobar_gato()

		move_and_slide()
		return

	comprobar_gato(delta)

	# Atacar solo cuando el gato entre en el área física cercana.
	var gato_cerca: bool = _gato_en_rango_de_ataque()

	if gato_cerca:
		velocity = Vector2.ZERO

		if tiempo_recarga <= 0.0:
			if attack_delay <= 0.0:
				iniciar_ataque()
			else:
				if not esperando_ataque:
					esperando_ataque = true
					tiempo_espera = attack_delay
				tiempo_espera -= delta
				if tiempo_espera <= 0.0:
					iniciar_ataque()

		move_and_slide()
		return

	# Si el gato se aleja, cancelar la espera.
	esperando_ataque = false
	tiempo_espera = 0.0

	match current_state:
		State.PATROL:
			patrol(delta)
		State.CHASE:
			chase(delta)

	move_and_slide()
	_actualizar_atasco(delta)
	actualizar_animacion()


# Saber si el gato ya murió (sin fallar si la propiedad no existe)
func _gato_muerto() -> bool:
	if gato == null or not is_instance_valid(gato):
		return false
	if gato.get("is_dead") == true:
		return true
	var vida: Variant = gato.get("health")
	if typeof(vida) == TYPE_INT or typeof(vida) == TYPE_FLOAT:
		return vida <= 0
	return false


# Atacar cuando Area2D2 toca la cápsula del jugador
func _gato_en_rango_de_ataque() -> bool:
	if gato == null or not is_instance_valid(gato):
		return false
	if gato in area_ataque.get_overlapping_bodies():
		return true

	var attack_shape := area_ataque.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var player_shape := gato.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if attack_shape == null or player_shape == null:
		return false

	if attack_shape.shape is CircleShape2D and player_shape.shape is CapsuleShape2D:
		var attack_circle := attack_shape.shape as CircleShape2D
		var player_capsule := player_shape.shape as CapsuleShape2D
		var attack_scale := attack_shape.global_transform.get_scale().abs()
		var player_basis_x := player_shape.global_transform.x
		var player_basis_y := player_shape.global_transform.y
		var attack_radius := attack_circle.radius * maxf(attack_scale.x, attack_scale.y)
		var player_radius := player_capsule.radius * maxf(player_basis_x.length(), player_basis_y.length())
		var capsule_half_segment := maxf(player_capsule.height * 0.5 - player_capsule.radius, 0.0)
		var capsule_axis := player_basis_y.normalized()
		var capsule_half_length := capsule_half_segment * player_basis_y.length()
		var capsule_start := player_shape.global_position - capsule_axis * capsule_half_length
		var capsule_end := player_shape.global_position + capsule_axis * capsule_half_length
		var closest_point := Geometry2D.get_closest_point_to_segment(
			_get_attack_center(),
			capsule_start,
			capsule_end
		)
		return closest_point.distance_to(_get_attack_center()) <= attack_radius + player_radius

	return _get_attack_center().distance_to(_get_player_body_center()) <= 46.0


func _get_attack_center() -> Vector2:
	var shape := area_ataque.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return shape.global_position if shape != null else area_ataque.global_position


func _get_player_body_center() -> Vector2:
	if gato == null or not is_instance_valid(gato):
		return global_position
	var shape := gato.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return shape.global_position if shape != null else gato.global_position


# Recibir un impacto de roca
func take_rock_hit() -> void:
	if derrotado:
		return

	health = maxi(health - 1, 0)
	_update_health_label()
	print("Vida del perro: ", health, "/", max_health)

	if health == 0:
		derrotado = true
		esperando_ataque = false
		atacando = false
		velocity = Vector2.ZERO
		_iniciar_secuencia_puerta(true)


# Preparar todo para que el perro vaya hacia la puerta (derrota y carga de partida)
func _iniciar_secuencia_puerta(mostrar_mensaje: bool) -> bool:
	campo_vision.set_deferred("monitoring", false)
	area_ataque.set_deferred("monitoring", false)
	puerta = get_tree().get_first_node_in_group("door") as Node2D
	if puerta == null:
		push_warning("No se encontró la puerta para el perro.")
		return false

	if not puerta.is_connected("opening_finished", _on_door_opening_finished):
		puerta.connect("opening_finished", _on_door_opening_finished)

	if puerta.has_method("revelar_puerta"):
		puerta.call("revelar_puerta")
	if mostrar_mensaje:
		get_tree().call_group("goal_message", "show_message", "Head to the door.")

	door_route_started = false
	llegada_registrada = false
	tiempo_en_ruta_puerta = 0.0
	_desactivar_modo_fantasma()
	stuck_hits = 0
	stuck_timer = 0.0
	stuck_last_pos = global_position
	current_state = State.GO_TO_DOOR
	return true


# Esperar a que la puerta se abra
func on_door_touched() -> void:
	if not derrotado:
		return

	current_state = State.WAIT_FOR_DOOR
	velocity = Vector2.ZERO
	animated_sprite.stop()


# Cruzar directamente la puerta abierta y desaparecer
func _on_door_opening_finished() -> void:
	if not derrotado or not is_instance_valid(self):
		return
	var body_collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_collision != null:
		body_collision.set_deferred("disabled", true)
	_activar_modo_fantasma()
	tiempo_entrando = 0.0
	current_state = State.ENTER_DOOR
	_set_door_route_target(_get_door_behind_position())


# Moverse por el umbral sin depender de la malla de navegación
func _mover_detras_de_la_puerta(delta: float) -> void:
	if not is_instance_valid(puerta):
		queue_free()
		return
	if not door_route_started:
		_set_door_route_target(_get_door_behind_position())

	tiempo_entrando += delta
	var diferencia := door_route_target - global_position
	if diferencia.length() <= 12.0 or tiempo_entrando >= DOOR_ENTER_TIMEOUT:
		velocity = Vector2.ZERO
		queue_free()
		return

	_aplicar_movimiento(diferencia.normalized(), CHASE_SPEED)


# Actualizar los corazones del perro
func _update_health_label() -> void:
	if health <= 0:
		health_label.hide()
		return

	var hearts := ""
	for index in range(max_health):
		hearts += "♥ " if index < health else "♡ "
	health_label.text = hearts.strip_edges()
	health_label.show()


# Restaurar vida y comportamiento guardados.
func refresh_after_load() -> void:
	health = clampi(health, 0, max_health)
	_update_health_label()
	if not derrotado:
		return
	_iniciar_secuencia_puerta(false)


# Dirigirse hacia la puerta
func ir_a_la_puerta(delta: float) -> void:
	if not is_instance_valid(puerta):
		velocity = Vector2.ZERO
		return
	if not door_route_started:
		_preparar_ruta_a_la_puerta()

	# Ya está en su sitio frente a la puerta: quedarse quieto hasta que se abra.
	if llegada_registrada:
		velocity = Vector2.ZERO
		_registrar_llegada_en_la_puerta()
		return

	tiempo_en_ruta_puerta += delta

	# Si tarda demasiado, ya no importa la física. Es seguro porque todos los tramos
	# de la ruta rodean la puerta: nunca la cruzan antes de que se abra.
	if tiempo_en_ruta_puerta >= DOOR_TRIP_TIMEOUT:
		_activar_modo_fantasma()

	var objetivo := door_waypoints[door_waypoint_index]
	var es_ultimo := door_waypoint_index >= door_waypoints.size() - 1
	var distancia := global_position.distance_to(objetivo)

	if es_ultimo:
		# Último tramo: avanzar recto y frenar justo en el punto de espera.
		if distancia <= DOOR_SNAP_DISTANCE:
			_terminar_llegada_a_la_puerta()
			return
		if distancia <= DOOR_FINAL_APPROACH or fantasma:
			var rapidez := minf(CHASE_SPEED, distancia / maxf(delta, 0.0001))
			_aplicar_movimiento(global_position.direction_to(objetivo), rapidez)
			return
	else:
		if distancia <= DOOR_WAYPOINT_REACHED:
			door_waypoint_index += 1
			return
		if fantasma:
			_aplicar_movimiento(global_position.direction_to(objetivo), CHASE_SPEED)
			return

	var direccion_ruta := _direccion_hacia(objetivo)
	_aplicar_movimiento(_steer(direccion_ruta, PROBE_CHASE), CHASE_SPEED)


# Calcular dónde esperar y por dónde ir sin rozar las esquinas de la puerta
func _preparar_ruta_a_la_puerta() -> void:
	_calcular_geometria_de_la_puerta()
	_calcular_ruta_a_la_puerta()
	door_waypoint_index = 0
	door_route_started = true
	door_route_target = door_wait_position


# Colocar al perro exacto en su sitio, mirar hacia la puerta y avisar que llegó
func _terminar_llegada_a_la_puerta() -> void:
	global_position = door_wait_position
	velocity = Vector2.ZERO
	_desactivar_modo_fantasma()
	llegada_registrada = true
	_mirar_hacia_la_puerta()
	_registrar_llegada_en_la_puerta()


func _registrar_llegada_en_la_puerta() -> void:
	if is_instance_valid(puerta) and puerta.has_method("registrar_llegada_enemigo"):
		puerta.call("registrar_llegada_enemigo", self)


# Dejar al perro quieto mirando hacia la puerta
func _mirar_hacia_la_puerta() -> void:
	var hacia := -_frente_de_la_puerta()
	var frames := animated_sprite.sprite_frames
	if frames == null:
		return
	var animacion: String
	if absf(hacia.x) > absf(hacia.y):
		animacion = "Dog"
		animated_sprite.flip_h = hacia.x < 0.0
	else:
		animacion = "dog_up" if hacia.y < 0.0 else "dog_down"
		animated_sprite.flip_h = false
	if frames.has_animation(animacion):
		animated_sprite.animation = animacion
		animated_sprite.frame = 0
	animated_sprite.stop()


func _frente_de_la_puerta() -> Vector2:
	if door_front_direction.length() < 0.01:
		return Vector2.DOWN
	return door_front_direction.normalized()


# Medir la colisión de la puerta y fijar el punto de espera (y el de salida)
func _calcular_geometria_de_la_puerta() -> void:
	door_has_obstacle = false
	door_geometry_ok = false

	var formas: Array[CollisionShape2D] = []
	_buscar_formas(puerta, true, formas)
	if formas.is_empty():
		_buscar_formas(puerta, false, formas)

	var primero := true
	var rect := Rect2()
	for forma in formas:
		var r := _rect_global_de_forma(forma)
		if r.size == Vector2.ZERO:
			continue
		rect = r if primero else rect.merge(r)
		primero = false

	if primero:
		# No se encontró ninguna colisión: usar los puntos que da la propia puerta.
		door_wait_position = _get_door_approach_position()
		door_behind_position = _get_door_behind_position_de_la_puerta()
		return

	door_obstacle_rect = rect
	door_has_obstacle = true
	door_geometry_ok = true

	var frente := _frente_de_la_puerta()
	var mitad_puerta := rect.size * 0.5
	var mitad_perro := _medio_tamano_del_perro()
	var eje_x := absf(frente.x)
	var eje_y := absf(frente.y)
	var hasta_espera := eje_x * (mitad_puerta.x + mitad_perro.x) + eje_y * (mitad_puerta.y + mitad_perro.y)
	door_wait_position = rect.get_center() + frente * (hasta_espera + door_wait_margin)
	# Punto al otro lado de la puerta, en línea recta desde donde espera
	# Entrar solo un poco en el umbral; la puerta oculta al perro mientras desaparece.
	door_behind_position = rect.get_center() - frente * 12.0


# Recoger las CollisionShape2D de la puerta (cuerpos físicos o, si no hay, áreas)
func _buscar_formas(nodo: Node, solo_cuerpos: bool, resultado: Array[CollisionShape2D]) -> void:
	if nodo is CollisionShape2D:
		var forma := nodo as CollisionShape2D
		var padre := forma.get_parent()
		var vale := false
		if solo_cuerpos:
			vale = padre is PhysicsBody2D
		else:
			vale = padre is Area2D
		if vale and not forma.disabled and forma.shape != null:
			resultado.append(forma)
	for hijo in nodo.get_children():
		_buscar_formas(hijo, solo_cuerpos, resultado)


# Rectángulo (en coordenadas globales) que ocupa una forma de colisión
func _rect_global_de_forma(forma: CollisionShape2D) -> Rect2:
	var local := Rect2()
	var s := forma.shape
	if s is RectangleShape2D:
		var tamano := (s as RectangleShape2D).size
		local = Rect2(-tamano * 0.5, tamano)
	elif s is CircleShape2D:
		var radio := (s as CircleShape2D).radius
		local = Rect2(Vector2(-radio, -radio), Vector2(radio * 2.0, radio * 2.0))
	elif s is CapsuleShape2D:
		var capsula := s as CapsuleShape2D
		local = Rect2(Vector2(-capsula.radius, -capsula.height * 0.5), Vector2(capsula.radius * 2.0, capsula.height))
	elif s.has_method("get_rect"):
		var rect_forma: Variant = s.call("get_rect")
		if rect_forma is Rect2:
			local = rect_forma

	var xf := forma.global_transform
	var esquinas: Array[Vector2] = [
		xf * local.position,
		xf * Vector2(local.end.x, local.position.y),
		xf * local.end,
		xf * Vector2(local.position.x, local.end.y)
	]
	var resultado := Rect2(esquinas[0], Vector2.ZERO)
	for punto in esquinas:
		resultado = resultado.expand(punto)
	return resultado


# Mitad del ancho y alto de la colisión del perro
func _medio_tamano_del_perro() -> Vector2:
	var forma := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if forma == null or forma.shape == null:
		return Vector2(12.0, 12.0)
	return _rect_global_de_forma(forma).size * 0.5


# Ruta más corta hasta el punto de espera rodeando la colisión de la puerta
func _calcular_ruta_a_la_puerta() -> void:
	door_waypoints.clear()
	var destino := door_wait_position
	if not door_has_obstacle:
		door_waypoints.append(destino)
		return

	var mitad_perro := _medio_tamano_del_perro()
	var holgura := maxf(mitad_perro.x, mitad_perro.y) + 6.0
	var zona := door_obstacle_rect.grow(holgura)
	var zona_prueba := zona.grow(-1.0)
	# El punto de espera debe quedar fuera de la zona de rodeo; si no, se reduce la holgura.
	while zona_prueba.has_point(destino) and holgura > 2.0:
		holgura -= 2.0
		zona = door_obstacle_rect.grow(holgura)
		zona_prueba = zona.grow(-1.0)

	var inicio := global_position
	var puntos_iniciales: Array[Vector2] = []
	if zona_prueba.has_point(inicio):
		# Está muy pegado a la puerta: primero salir de su zona por el borde más cercano.
		inicio = _punto_fuera_de_rect(zona, inicio)
		puntos_iniciales.append(inicio)

	var nodos: Array[Vector2] = [
		inicio,
		zona.position,
		Vector2(zona.end.x, zona.position.y),
		zona.end,
		Vector2(zona.position.x, zona.end.y),
		destino
	]

	# Dijkstra sobre 6 nodos; solo hay arista si el segmento no atraviesa la puerta.
	var cantidad := nodos.size()
	var distancia: Array[float] = []
	var previo: Array[int] = []
	var visitado: Array[bool] = []
	for i in range(cantidad):
		distancia.append(INF)
		previo.append(-1)
		visitado.append(false)
	distancia[0] = 0.0

	for _paso in range(cantidad):
		var actual := -1
		var mejor := INF
		for i in range(cantidad):
			if not visitado[i] and distancia[i] < mejor:
				mejor = distancia[i]
				actual = i
		if actual == -1:
			break
		visitado[actual] = true
		for j in range(cantidad):
			if visitado[j]:
				continue
			if _segmento_cruza_rect(nodos[actual], nodos[j], zona_prueba):
				continue
			var costo := distancia[actual] + nodos[actual].distance_to(nodos[j])
			if costo < distancia[j]:
				distancia[j] = costo
				previo[j] = actual

	if previo[cantidad - 1] == -1:
		door_waypoints.append(destino)
		return

	var camino: Array[Vector2] = []
	var cursor := cantidad - 1
	while cursor > 0:
		camino.push_front(nodos[cursor])
		cursor = previo[cursor]

	for punto in puntos_iniciales:
		door_waypoints.append(punto)
	for punto in camino:
		door_waypoints.append(punto)


# Empujar un punto que está dentro de un rectángulo hasta su borde más cercano (hacia afuera)
func _punto_fuera_de_rect(r: Rect2, p: Vector2) -> Vector2:
	var izquierda := p.x - r.position.x
	var derecha := r.end.x - p.x
	var arriba := p.y - r.position.y
	var abajo := r.end.y - p.y
	var minimo := minf(minf(izquierda, derecha), minf(arriba, abajo))
	if is_equal_approx(minimo, izquierda):
		return Vector2(r.position.x - 1.0, p.y)
	if is_equal_approx(minimo, derecha):
		return Vector2(r.end.x + 1.0, p.y)
	if is_equal_approx(minimo, arriba):
		return Vector2(p.x, r.position.y - 1.0)
	return Vector2(p.x, r.end.y + 1.0)


# ¿El segmento a-b atraviesa el rectángulo? (Liang-Barsky)
func _segmento_cruza_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var p: Array[float] = [-d.x, d.x, -d.y, d.y]
	var q: Array[float] = [
		a.x - r.position.x,
		r.end.x - a.x,
		a.y - r.position.y,
		r.end.y - a.y
	]
	for i in range(4):
		if is_zero_approx(p[i]):
			if q[i] < 0.0:
				return false
		else:
			var t := q[i] / p[i]
			if p[i] < 0.0:
				if t > t1:
					return false
				t0 = maxf(t0, t)
			else:
				if t < t0:
					return false
				t1 = minf(t1, t)
	return t0 <= t1


# Configurar el destino de navegación
func _set_door_route_target(target_position: Vector2) -> void:
	door_route_target = target_position
	door_route_started = true
	if door_navigation_agent != null:
		door_navigation_agent.target_position = door_route_target


# Punto frente a la puerta
func _get_door_approach_position() -> Vector2:
	if puerta.has_method("get_dog_approach_position"):
		return puerta.call("get_dog_approach_position", self)
	return _get_door_target_position()


# Punto al otro lado de la puerta, en línea recta desde donde espera el perro
func _get_door_behind_position() -> Vector2:
	if door_geometry_ok:
		return door_behind_position
	return _get_door_behind_position_de_la_puerta()


# Punto detrás de la puerta según el script de la puerta
func _get_door_behind_position_de_la_puerta() -> Vector2:
	if puerta.has_method("get_dog_behind_position"):
		return puerta.call("get_dog_behind_position", self)
	return _get_door_target_position()


# Centro de la puerta
func _get_door_target_position() -> Vector2:
	var sensor_shape := puerta.get_node_or_null("Area2D/CollisionShape2D") as Node2D
	if sensor_shape != null:
		return sensor_shape.global_position
	return puerta.global_position


# Comprobar si el gato está cerca
func comprobar_gato(delta: float = 0.0) -> void:
	if gato == null or not is_instance_valid(gato):
		current_state = State.PATROL
		return

	var detectado: bool = gato in campo_vision.get_overlapping_bodies()
	if not detectado:
		var forma_vision := campo_vision.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if forma_vision != null and forma_vision.shape is CircleShape2D:
			var alcance: float = (forma_vision.shape as CircleShape2D).radius
			var escala_vision := forma_vision.global_transform.get_scale().abs()
			alcance *= maxf(escala_vision.x, escala_vision.y)
			detectado = forma_vision.global_position.distance_to(_get_player_body_center()) <= alcance

	if detectado:
		tiempo_sin_ver = 0.0
		current_state = State.CHASE
		return

	# Recordar al gato un instante para no alternar PATROL/CHASE en el borde de la visión.
	tiempo_sin_ver += delta
	if current_state == State.CHASE and tiempo_sin_ver < CHASE_MEMORY:
		return
	current_state = State.PATROL


# Patrullar sin quedarse empujando una pared
func patrol(delta: float) -> void:
	tiempo_cambio -= delta
	if tiempo_cambio <= 0.0 or test_move(global_transform, direccion * PROBE_PATROL):
		cambiar_direccion()

	if direccion == Vector2.ZERO:
		velocity = Vector2.ZERO
		return

	_aplicar_movimiento(direccion, SPEED)


# Perseguir hasta que el área de ataque toque al jugador
func chase(_delta: float) -> void:
	if gato == null or not is_instance_valid(gato):
		current_state = State.PATROL
		velocity = Vector2.ZERO
		return

	var desplazamiento := _get_player_body_center() - _get_attack_center()
	if desplazamiento.length_squared() < 0.001:
		velocity = Vector2.ZERO
		return

	# Destino: el punto donde el área de ataque quedaría encima del gato.
	var destino := global_position + desplazamiento
	var direccion_deseada := _direccion_hacia(destino)
	_aplicar_movimiento(_steer(direccion_deseada, PROBE_CHASE), CHASE_SPEED)


# Elegir una dirección despejada para patrullar
func cambiar_direccion() -> void:
	var opciones: Array[Vector2] = [
		Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
		Vector2(1.0, 1.0).normalized(), Vector2(-1.0, 1.0).normalized(),
		Vector2(1.0, -1.0).normalized(), Vector2(-1.0, -1.0).normalized()
	]
	opciones.shuffle()

	for candidata in opciones:
		if not test_move(global_transform, candidata * PROBE_PATROL):
			direccion = candidata
			tiempo_cambio = randf_range(0.9, 1.8)
			return

	direccion = Vector2.ZERO
	tiempo_cambio = 0.25


# --- Navegación y esquiva ---

# ¿Hay una malla de navegación con regiones sobre la que calcular rutas?
func _navegacion_disponible() -> bool:
	if door_navigation_agent == null:
		return false
	var mapa := door_navigation_agent.get_navigation_map()
	if not mapa.is_valid():
		return false
	if NavigationServer2D.map_get_iteration_id(mapa) == 0:
		return false
	return NavigationServer2D.map_get_regions(mapa).size() > 0


# Dirección hacia un destino: sigue la ruta navegable si existe; si no, va en línea recta.
func _direccion_hacia(destino: Vector2) -> Vector2:
	if _navegacion_disponible():
		if repath_timer <= 0.0 or door_navigation_agent.target_position.distance_to(destino) > 24.0:
			door_navigation_agent.target_position = destino
			repath_timer = REPATH_INTERVAL
		var siguiente := door_navigation_agent.get_next_path_position()
		var hacia_siguiente := siguiente - global_position
		if hacia_siguiente.length() > 3.0:
			return hacia_siguiente.normalized()
	return global_position.direction_to(destino)


# Ajustar la dirección deseada para no pegarse contra obstáculos.
# Primero desliza por la pared, y si va de frente rodea siempre por el mismo lado.
func _steer(deseada: Vector2, distancia: float) -> Vector2:
	if deseada == Vector2.ZERO:
		return Vector2.ZERO
	deseada = deseada.normalized()

	# Empujón lateral tras detectar un atasco
	if escape_timer > 0.0 and escape_dir != Vector2.ZERO:
		if not test_move(global_transform, escape_dir * distancia):
			return escape_dir

	if not test_move(global_transform, deseada * distancia, _colision):
		return deseada

	# 1) Choque de refilón: deslizarse a lo largo de la superficie.
	var deslizada := deseada.slide(_colision.get_normal())
	if deslizada.length() > 0.2:
		var candidata := deslizada.normalized()
		if not test_move(global_transform, candidata * distancia):
			return candidata

	# 2) Choque de frente: rodear, manteniendo el lado elegido para no oscilar.
	var angulos: Array[float] = [60.0, 90.0, 120.0, 150.0]
	for angulo in angulos:
		var lados: Array[int] = [avoid_side, -avoid_side]
		for lado in lados:
			var rotada := deseada.rotated(deg_to_rad(angulo) * float(lado))
			if not test_move(global_transform, rotada * distancia):
				avoid_side = lado
				return rotada

	return Vector2.ZERO


# Guardar la dirección que se intenta seguir (la usa el detector de atascos y la animación)
func _aplicar_movimiento(dir: Vector2, rapidez: float) -> void:
	if dir == Vector2.ZERO:
		velocity = Vector2.ZERO
		return
	_intended_dir = dir
	_intended_speed = rapidez
	velocity = dir * rapidez


# Detectar si el perro intenta moverse pero casi no avanza
func _actualizar_atasco(delta: float) -> void:
	if _intended_speed <= 0.0 or fantasma:
		stuck_timer = 0.0
		stuck_hits = 0
		stuck_last_pos = global_position
		return

	stuck_timer += delta
	if stuck_timer < STUCK_CHECK_INTERVAL:
		return

	var avance := global_position.distance_to(stuck_last_pos)
	var esperado := _intended_speed * stuck_timer
	stuck_last_pos = global_position
	stuck_timer = 0.0

	if avance < esperado * STUCK_MIN_PROGRESS:
		stuck_hits += 1
		_al_atascarse()
	else:
		stuck_hits = 0


# Reaccionar a un atasco: cambiar de lado, empujón lateral y, en la puerta, atravesar
func _al_atascarse() -> void:
	avoid_side = -avoid_side
	var base := _intended_dir if _intended_dir != Vector2.ZERO else Vector2.RIGHT
	escape_dir = base.rotated(deg_to_rad(randf_range(80.0, 130.0)) * float(avoid_side))
	escape_timer = ESCAPE_TIME

	if current_state == State.PATROL:
		cambiar_direccion()
	elif current_state == State.GO_TO_DOOR and stuck_hits >= DOOR_GHOST_AFTER_STUCK:
		_activar_modo_fantasma()


# El perro derrotado deja de chocar con el mundo para poder llegar a la puerta.
# Se mantiene su forma de colisión activa para que la puerta aún pueda detectarlo.
func _activar_modo_fantasma() -> void:
	if fantasma:
		return
	fantasma = true
	collision_mask = 0


# Volver a chocar con el mundo con normalidad
func _desactivar_modo_fantasma() -> void:
	fantasma = false
	collision_mask = mask_original


# Atacar al jugador
func iniciar_ataque() -> void:
	if gato == null or not is_instance_valid(gato):
		return

	if _gato_muerto():
		esperando_ataque = false
		atacando = false
		velocity = Vector2.ZERO
		animated_sprite.stop()
		return

	esperando_ataque = false
	atacando = true
	tiempo_ataque = 0.0
	velocity = Vector2.ZERO

	var sprite_gato := gato.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var posicion_gato: Vector2 = sprite_gato.global_position if sprite_gato != null else gato.global_position
	var hacia_gato: Vector2 = posicion_gato - animated_sprite.global_position
	var animacion: String

	if absf(hacia_gato.x) > absf(hacia_gato.y):
		if hacia_gato.x >= 0.0:
			animacion = "dog_atack_right"
		else:
			animacion = "dog_atack_left"
	else:
		if hacia_gato.y < 0.0:
			animacion = "dog_atack_up"
		else:
			animacion = "dog_atack_down"

	animated_sprite.flip_h = false

	if not animated_sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación: " + animacion)
		atacando = false
		return

	animated_sprite.stop()
	animated_sprite.frame = 0
	animated_sprite.play(animacion)

	# Calcular cuánto dura la animación para evitar congelamientos.
	var frames: int = animated_sprite.sprite_frames.get_frame_count(animacion)
	var fps: float = animated_sprite.sprite_frames.get_animation_speed(animacion)

	duracion_ataque = float(frames) / maxf(fps, 1.0)

	# Aplicar daño una sola vez por ataque.
	if gato.has_method("take_damage"):
		gato.call("take_damage", damage)

	tiempo_recarga = attack_cooldown


# Actualizar la animación de movimiento
func actualizar_animacion() -> void:
	# Usar el movimiento real (ya deslizado por las paredes) para no mostrar
	# al perro "caminando" en el sitio cuando está bloqueado.
	var movimiento := get_real_velocity()
	if _intended_speed <= 0.0 or movimiento.length() < 8.0:
		animated_sprite.stop()
		return

	var ax := absf(movimiento.x)
	var ay := absf(movimiento.y)
	# Con un pequeño margen para que no parpadee entre izquierda/derecha y arriba/abajo.
	if ax > ay * 1.25:
		mirando_horizontal = true
	elif ay > ax * 1.25:
		mirando_horizontal = false

	if mirando_horizontal:
		animated_sprite.play("Dog")
		animated_sprite.flip_h = movimiento.x < 0.0
	else:
		animated_sprite.flip_h = false

		if movimiento.y < 0.0:
			animated_sprite.play("dog_up")
		else:
			animated_sprite.play("dog_down")
