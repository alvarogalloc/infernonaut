extends SceneTree
## Cobarde:
##  - huye si el jugador entra en su área de activación
##  - con el jugador lejos se queda plantado y sigue atacando mientras lo vea
##  - si una pared se interpone deja de atacar y vuelve a reposo
##  - el ataque LLEGA al jugador aunque la escena lo escale (0.175)
##  - muere con el dash, recarga al jugador y aparece en la arena del tutorial
## Uso: godot --headless --fixed-fps 60 --script res://tests/assert_cobarde.gd

const ESCALA := 0.175 ## la misma que ESC_ENEMIGO del generador

var _espera := 3
var _paso := 0
var _t := 0.0
var _checks := 0
var _fallos := 0

var _cob: CharacterBody2D
var _jug: Node2D
var _pared: StaticBody2D
var _dist0 := 0.0
var _pos_lejos := Vector2.ZERO
var _alcance := 0.0
var _murio_emitido := false


func _process(delta: float) -> bool:
	if _espera > 0:
		_espera -= 1
		if _espera == 2:
			_montar(Vector2.ZERO, Vector2(100, 0))
			_dist0 = _cob.global_position.distance_to(_jug.global_position)
		return false

	_t += delta
	match _paso:
		0:
			if _t > 1.0:
				_ok("huye al acercarse (se aleja del jugador)",
						_cob.global_position.distance_to(_jug.global_position) > _dist0)
				_eq("estado HUYENDO", _cob._estado, _cob.Estado.HUYENDO)
				_siguiente()
		1:
			if _cob._estado == _cob.Estado.PREPARANDO:
				_alcance = _cob._largo_ataque * ESCALA
				var distancia: float = _cob.boca.global_position.distance_to(_jug.global_position)
				_ok("alcance del ataque = distancia al jugador (%.0f vs %.0f)" % [_alcance, distancia],
						absf(_alcance - distancia) < 5.0)
				_jug.global_position = _cob.boca.global_position \
						+ Vector2.RIGHT.rotated(_cob._angulo_ataque) * _alcance
				_siguiente()
		2:
			if _cob._estado == _cob.Estado.ATACANDO and _cob._tiempo_estado > 0.2:
				var hitbox := (_cob.shape_ataque.shape as RectangleShape2D).size.x * ESCALA
				_ok("la hitbox crece hasta el objetivo (%.0f de %.0f)" % [hitbox, _alcance],
						absf(hitbox - _alcance) < 10.0)
				_siguiente()
		3:
			if _cob._estado != _cob.Estado.ATACANDO:
				_ok("el jugador parado en el telégrafo muere", _jug._muerto)
				_muerte_por_dash()
				_siguiente()
		4:
			# Lejos y sin paredes: no huye, pero sigue disparando.
			_montar(Vector2(3000, 0), Vector2(3800, 0))
			_cob._on_activate_body_entered(_jug)
			_cob._on_activate_body_exited(_jug) # el jugador se alejó del área
			_pos_lejos = _cob.global_position
			_siguiente()
		5:
			if _t > 1.0:
				_eq("lejos: estado HUYENDO", _cob._estado, _cob.Estado.HUYENDO)
				_ok("lejos: no huye (se queda quieto)",
						_cob.global_position.distance_to(_pos_lejos) < 5.0)
				_ok("lejos y a la vista: puede disparar", _cob._puede_disparar())
				_crear_pared(Vector2(3000, 0), Vector2(3800, 0))
				_siguiente()
		6:
			if _t > 0.1:
				_ok("con pared en medio: NO puede disparar", not _cob._puede_disparar())
				_siguiente()
		7:
			# El temporizador de ataque vence con la pared puesta: no ataca.
			if _cob._estado == _cob.Estado.INACTIVO:
				_ok("con pared: no ataca y vuelve a reposo", true)
				_pared.queue_free()
				_siguiente()
			elif _cob._estado == _cob.Estado.PREPARANDO:
				_fallos += 1
				print("FAIL con pared en medio disparó igual")
				_pared.queue_free()
				_siguiente()
		8:
			# Sin pared y lejos: vuelve a enganchar y dispara desde 800px.
			if _cob._estado == _cob.Estado.PREPARANDO:
				var alcance_lejos: float = _cob._largo_ataque * ESCALA
				_ok("dispara desde lejos (%.0f px)" % alcance_lejos, absf(alcance_lejos - 800.0) < 30.0)
				_integracion()
				print("==== ASSERT COBARDE: ", _checks - _fallos, "/", _checks, " PASS ====")
				print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")
				quit(1 if _fallos > 0 else 0)
				return true
	return false


func _siguiente() -> void:
	_paso += 1
	_t = 0.0


func _montar(pos_enemigo: Vector2, pos_jugador: Vector2) -> void:
	if is_instance_valid(_cob):
		_cob.queue_free()
	if is_instance_valid(_jug):
		_jug.queue_free()
	# Mismo montaje que en partida: enemigo escalado por _pone() del generador.
	_cob = load("res://scenes/enemigos/cobarde/cobarde.tscn").instantiate()
	_cob.global_position = pos_enemigo
	_cob.scale = Vector2(ESCALA, ESCALA)
	root.add_child(_cob)
	_jug = load("res://scenes/personaje/character_body_2d.tscn").instantiate()
	_jug.global_position = pos_jugador
	root.add_child(_jug)
	# El contacto cuerpo a cuerpo con el enemigo mataría al jugador (su área
	# idle lo detecta). Acá probamos el ataque a distancia, así que el jugador
	# deja de detectar cuerpos pero sigue siendo detectable por la hitbox.
	_jug.area_idle.monitoring = false


func _crear_pared(desde: Vector2, hasta: Vector2) -> void:
	_pared = StaticBody2D.new()
	_pared.collision_layer = Vision.MASCARA_PARED
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 1200)
	forma.shape = rect
	_pared.add_child(forma)
	_pared.global_position = (desde + hasta) * 0.5
	root.add_child(_pared)


func _muerte_por_dash() -> void:
	_jug.cargas_actuales = 1
	_cob.murio.connect(func(): _murio_emitido = true)
	var ataques := Area2D.new()
	ataques.add_to_group(Constantes.GRUPO_ATAQUE_PERSONAJE)
	_cob._on_area_2d_area_entered(ataques)
	_ok("muere y emite murio", _murio_emitido)
	_ok("recarga al jugador al morir", _jug.cargas_actuales == 2)
	ataques.free()


## Integración en la arena del tutorial (cobarde dentro de su sala).
func _integracion() -> void:
	var nivel: Node2D = load("res://scenes/nivel/tutorial.tscn").instantiate()
	nivel.solo_arena = true
	root.add_child(nivel)
	var cobardes := _cosechar_cobardes(nivel)
	_ok("la arena tiene cobarde", cobardes > 0)
	root.remove_child(nivel)
	nivel.free()


func _cosechar_cobardes(nodo: Node) -> int:
	var n := 0
	if nodo is CharacterBody2D and nodo.get_script() != null \
			and nodo.get_script().resource_path.ends_with("cobarde.gd"):
		n += 1
		_ok("cobarde en grupo enemigos", nodo.is_in_group(Constantes.GRUPO_ENEMIGOS))
		var room := nodo.get_parent()
		var layer: TileMapLayer = _capa(room)
		if not _dentro(layer, nodo.position):
			_fallos += 1
			print("FAIL cobarde fuera de su sala: ", nodo.name, " padre=", room.name)
	for c in nodo.get_children():
		n += _cosechar_cobardes(c)
	return n


func _capa(nodo: Node) -> TileMapLayer:
	if nodo is TileMapLayer:
		return nodo
	for c in nodo.get_children():
		var l := _capa(c)
		if l != null:
			return l
	return null


func _dentro(layer: TileMapLayer, pos: Vector2) -> bool:
	if layer == null:
		return true
	var used: Rect2i = layer.get_used_rect()
	return pos.x >= 0 and pos.y >= 0 and pos.x <= used.end.x * 60 and pos.y <= used.end.y * 60


func _eq(etq: String, real, esperado) -> void:
	_checks += 1
	if real == esperado:
		print("PASS ", etq)
	else:
		_fallos += 1
		print("FAIL ", etq, " real=", real, " esperado=", esperado)


func _ok(etq: String, cond: bool) -> void:
	_checks += 1
	if cond:
		print("PASS ", etq)
	else:
		_fallos += 1
		print("FAIL ", etq)
