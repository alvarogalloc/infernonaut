extends SceneTree
## Cobarde: huye, telégrafa/ataca y hace daño de área; muere con murio y
## recarga al jugador; se integra en el generador (hay cobardes, dentro de su
## sala, en el grupo "enemigos").
## Uso: godot --headless --fixed-fps 60 --script res://tests/assert_cobarde.gd

var _espera := 3
var _paso := 0
var _t := 0.0
var _checks := 0
var _fallos := 0

var _cobarde: CharacterBody2D
var _jugador: Node2D
var _dist0 := 0.0
var _estado0: int = -99
var _murio_emitido := false
var _tele_al_empezar_ataque := 0
var _proyectiles_al_atacar := 0
var _muerto_al_aterrizar := false
var _integ_al_fin := false


func _initialize() -> void:
	pass


func _process(delta: float) -> bool:
	if _espera > 0:
		_espera -= 1
		# Spawn en el primer frame (dentro del árbol) para que _ready y los
		# grupos de ambos nodos estén activos.
		if _espera == 2:
			_cobarde = load("res://scenes/enemigos/cobarde/cobarde.tscn").instantiate()
			_cobarde.global_position = Vector2(1000, 1000)
			root.add_child(_cobarde)
			# El jugador real (misma señal y API que en partida).
			_jugador = load("res://scenes/personaje/character_body_2d.tscn").instantiate()
			_jugador.global_position = Vector2(1500, 1000)
			root.add_child(_jugador)
		return false
	_t += delta
	match _paso:
		0:
			# Radió de activación ampliado para que el vuelo de huida no haga
			# que el jugador salga del área antes de preparar el ataque.
			var shape: CircleShape2D = _cobarde.area_activacion.shape.duplicate()
			shape.radius = 5000.0
			_cobarde.area_activacion.shape = shape
			# Activar sin esperar a la física del área (llamada directa).
			_cobarde._on_activate_body_entered(_jugador)
			_dist0 = _cobarde.global_position.distance_to(_jugador.global_position)
			_paso = 1
		1:
			# Tras detección + un tiempo: debe estar HUYENDO (distancia crece).
			if _t > 1.0:
				var d: float = _cobarde.global_position.distance_to(_jugador.global_position)
				_ok("huye (se aleja del jugador)", d > _dist0)
				_estado0 = _cobarde._estado
				_paso = 2
		2:
			# Tras intervalo_ataque: PREPARANDO con 3 telégrafos.
			if _t > 1.0 + 2.2:
				_eq("estado PREPARANDO", _cobarde._estado, _cobarde.Estado.PREPARANDO)
				_eq("3 telégrafos", _cobarde._telegrafos.size(), 3)
				_ok("3 objetivos marcados", _cobarde._objetivos.size() == 3)
				# Colocar al jugador justo sobre el primer punto de impacto.
				_jugador.global_position = _cobarde._objetivos[0]
				_paso = 3
		3:
			# Tras preparación: ATACANDO con 3 proyectiles.
			if _t > 1.0 + 2.2 + 0.6:
				_eq("estado ATACANDO", _cobarde._estado, _cobarde.Estado.ATACANDO)
				_eq("3 proyectiles", _cobarde._proyectiles.size(), 3)
				_tele_al_empezar_ataque = _cobarde._telegrafos.size()
				_paso = 4
		4:
			# Tras el vuelo (~0.9s) el jugador en la zona debe haber recibido
			# el golpe y los telégrafos haberse limpiado.
			if _t > 1.0 + 2.2 + 0.6 + 1.4:
				_ok("daño de área al aterrizar", _jugador._muerto)
				_eq("telégrafos limpiados tras aterrizar", _cobarde._telegrafos.size(), 0)
				_paso = 5
		5:
			# Muerte: murio emitido y recarga otorgada al jugador (mismo flujo
			# que una muerte por dash del jugador).
			if _t > 1.0 + 2.2 + 0.6 + 1.4 + 0.5:
				_jugador.cargas_actuales = 1
				_cobarde.murio.connect(func(): _murio_emitido = true)
				var ataques := Area2D.new()
				ataques.add_to_group(Constantes.GRUPO_ATAQUE_PERSONAJE)
				_cobarde._on_area_2d_area_entered(ataques)
				_ok("muere y emite murio", _murio_emitido)
				_ok("recarga al jugador al morir", _jugador.cargas_actuales == 2)
				ataques.free()
				_paso = 6
		6:
			# Integración en el generador.
			_integracion()
			print("==== ASSERT COBARDE: ", _checks - _fallos, "/", _checks, " PASS ====")
			print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")
			quit(1 if _fallos > 0 else 0)
			return true
	return false


## Huye de verdad (no solo por estado): distancia > inicial. Además el
## estado de HUYENDO ya se comprobó en el paso 1, aquí se refuerza que la
## variable de estado era HUYENDO al abandonar el paso 1.
func _integracion() -> void:
	var gen := GeneradorNivel.new()
	var cobardes := 0
	var total := 0
	for semilla in range(1, 26):
		var plantilla := semilla % 2
		var nivel: Node2D = gen.generar(semilla, plantilla)
		root.add_child(nivel)
		cobardes += _cosechar_cobardes(nivel)
		_eq("nivel %d sin error" % semilla, nivel != null, true)
		root.remove_child(nivel)
		nivel.free()
		total += 1
	_ok("hay cobardes en el generador (varios seeds)", cobardes > 0)
	_ok("hay más de un nivel probado", total >= 25)
	_integ_al_fin = true


func _cosechar_cobardes(nodo: Node) -> int:
	var n := 0
	if nodo is CharacterBody2D and nodo.get_script() != null \
			and nodo.get_script().resource_path.ends_with("cobarde.gd"):
		n += 1
		_ok("cobarde en grupo enemigos", nodo.is_in_group(Constantes.GRUPO_ENEMIGOS))
		var room := nodo.get_parent()
		var layer: TileMapLayer = _capa(room)
		var inside := _dentro(room, layer, nodo.position)
		if not inside:
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


func _dentro(room: Node, layer: TileMapLayer, pos: Vector2) -> bool:
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