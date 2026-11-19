extends SceneTree
## Verifica la mazmorra demo: 9 salas, spawn en D, 9 puertas, llaves,
## powerups, pista de HUD, guardia que suelta llave y puerta final de 2 llaves.
## Uso: godot --headless --fixed-fps 60 --script res://tests/assert_maze.gd

var _n: Node
var _jug: Node2D
var _f := 0
var _paso := 0
var _checks := 0
var _fallos := 0
var _final: Node


func _process(_delta: float) -> bool:
	_f += 1
	match _paso:
		0:
			if _f == 1:
				_n = load("res://scenes/nivel/maze.tscn").instantiate()
				root.add_child(_n)
			elif _f == 8:
				_inicial()
				_paso = 1
		1:
			if _f == 16:
				_comprobar_guardia()
				_paso = 2
		2:
			if _f == 24:
				_comprobar_puerta_final()
				_paso = 3
		3:
			if _f == 60:
				_resumen()
				return true
	return false


func _inicial() -> void:
	var salas := 0
	for h in _n.get_children():
		if h is Node2D and _buscar(h, "blockout") != null:
			salas += 1
	_eq("9 salas", salas, 9)
	_jug = get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	_ok("jugador", _jug != null)
	if _jug != null:
		_eq("spawn en D", _jug.global_position, Vector2(270, 810))
	_ok("cámara", get_first_node_in_group("camara_jugador") != null)
	var trans := get_first_node_in_group("transicion_salas")
	_ok("transición", trans != null)
	if trans != null:
		trans.set("activa", false)

	_eq("9 puertas", _contar_puertas(_n), 9)
	_final = _buscar_puerta_final(_n)
	_ok("puerta final", _final != null)
	if _final != null:
		_eq("puerta final pide 3 llaves", _final.llaves_requeridas, 3)
		_ok("puerta final cerrada", not _final.esta_abierta())

	_eq("4 llaves iniciales", _contar_llaves(_n), 4)
	_eq("6 escudos", _contar_recompensas(_n, "escudo"), 6)
	_eq("1 dash sombra", _contar_recompensas(_n, "dash_sombra"), 1)

	_ok("HUD tutorial", get_first_node_in_group("tutorial_hud") != null)
	var hint: Node = get_first_node_in_group("action_hint")
	_ok("tooltip de acción", hint != null)
	if hint != null:
		_eq("acción de inicio", hint.call("accion_actual"), "normal")
	_jug.escudos_restantes = 0
	_jug.aplicar_recompensa("escudo")
	_jug.aplicar_recompensa("escudo")
	_eq("escudos se acumulan hasta 2", _jug.escudos_restantes, 2)
	_jug.escudos_restantes = 0
	_jug.call("dash_hacia", _jug.global_position + Vector2(300, 0), false)
	if hint != null:
		_ok("tooltip reacciona al dash", hint.call("reacciono"))


## El guardia de E (sala_4) suelta su llave al morir.
func _comprobar_guardia() -> void:
	var guardia: Node = null
	for c in _n.get_node("sala_4").get_children():
		if c is CharacterBody2D and c.get_script() != null \
				and c.get_script().resource_path.ends_with("enemigo_1.gd"):
			guardia = c
			break
	_ok("guardia en E", guardia != null)
	if guardia == null:
		return
	guardia.call("_morir")
	_ok("guardia muerto", guardia.esta_muerto)
	# El drop es diferido: damos un par de frames.
	await create_timer(0.1).timeout
	_eq("guardia suelta 1 llave", _contar_llaves(_n.get_node("sala_4")), 1)


## La puerta final consume 2 llaves.
func _comprobar_puerta_final() -> void:
	if _final == null or _jug == null:
		return
	_jug.llaves = 3
	# teletransportar() corta cualquier dash en curso; setear global_position
	# dejaba que el dash viejo arrastrara al jugador fuera del detector.
	_jug.call("teletransportar", _final.global_position + Vector2(80, 0))
	await create_timer(0.2).timeout
	_ok("puerta final abierta con 3 llaves", _final.esta_abierta())
	_eq("3 llaves consumidas", _jug.llaves, 0)


func _buscar(nodo: Node, prefijo: String) -> Node:
	if nodo.name.begins_with(prefijo):
		return nodo
	for c in nodo.get_children():
		var r := _buscar(c, prefijo)
		if r != null:
			return r
	return null


func _contar_puertas(nodo: Node) -> int:
	var n := 0
	if nodo.has_method("esta_abierta"):
		n += 1
	for c in nodo.get_children():
		n += _contar_puertas(c)
	return n


func _buscar_puerta_final(nodo: Node) -> Node:
	if nodo.has_method("esta_abierta") and nodo.get("llaves_requeridas") == 3:
		return nodo
	for c in nodo.get_children():
		var r := _buscar_puerta_final(c)
		if r != null:
			return r
	return null


func _contar_llaves(nodo: Node) -> int:
	var n := 0
	if nodo.name == "llave":
		n += 1
	for c in nodo.get_children():
		n += _contar_llaves(c)
	return n


func _contar_recompensas(nodo: Node, tipo: String) -> int:
	var n := 0
	if nodo is Area2D and nodo.get("tipo") == tipo:
		n += 1
	for c in nodo.get_children():
		n += _contar_recompensas(c, tipo)
	return n


func _resumen() -> void:
	print("==== ASSERT MAZE: ", _checks - _fallos, "/", _checks, " PASS ====")
	print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")
	quit(1 if _fallos > 0 else 0)


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
