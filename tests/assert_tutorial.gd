extends SceneTree
## Verifica el tutorial curado: 6 salas, llaves, puertas por llave, HUD con
## tooltips y luces en modo Mix. Uso:
## godot --headless --fixed-fps 60 --script res://tests/assert_tutorial.gd

var _n: Node
var _jug: Node2D
var _puerta: Node
var _llave: Node
var _f := 0
var _paso := 0
var _checks := 0
var _fallos := 0


func _process(_delta: float) -> bool:
	_f += 1
	match _paso:
		0:
			if _f == 1:
				_n = load("res://scenes/nivel/tutorial.tscn").instantiate()
				root.add_child(_n)
			elif _f == 6:
				_inicial()
				_puerta = _n.get_node("sala_0/puerta_0")
				_llave = _buscar(_n.get_node("sala_0"), "llave")
				_jug.global_position = Vector2(1900, 540)
				_paso = 1
		1:
			if _f == 14:
				_ok("puerta cerrada sin llave", not _puerta.esta_abierta())
				_jug.global_position = _llave.global_position
				_paso = 2
		2:
			if _f == 24:
				_eq("llave recogida", _jug.llaves, 1)
				_ok("llave eliminada", not is_instance_valid(_llave))
				_jug.global_position = Vector2(1900, 540)
				_paso = 3
		3:
			if _f == 34:
				_ok("puerta abierta con llave", _puerta.esta_abierta())
				_eq("llave consumida", _jug.llaves, 0)
				_resumen()
				return true
	return false


func _inicial() -> void:
	var salas := 0
	for h in _n.get_children():
		if h is Node2D and _buscar(h, "blockout") != null:
			salas += 1
	_eq("6 salas", salas, 6)
	_jug = get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	_ok("jugador", _jug != null)
	_ok("cámara", get_first_node_in_group("camara_jugador") != null)
	var trans := get_first_node_in_group("transicion_salas")
	_ok("transición", trans != null)
	if trans != null:
		trans.set("activa", false) ## el test teletransporta: sin wipe
	_ok("HUD tutorial", get_first_node_in_group("tutorial_hud") != null)
	_ok("meta", _buscar(_n.get_node("sala_5"), "meta") != null)
	for i in 5:
		_ok("puerta %d" % i, _n.get_node_or_null("sala_%d/puerta_%d" % [i, i]) != null)

	# HUD de mejoras: visible y con tooltip.
	var hud := _jug.get_node("CanvasLayer/BloodHud")
	for fila in ["Llave", "Escudo", "Sombra"]:
		var nodo := hud.get_node_or_null(fila)
		_ok("HUD %s" % fila, nodo != null and nodo.tooltip_text != "")

	# Luces aditivas suaves (Mix dibujaría el fondo negro de la textura como
	# cajas negras) y antorchas con parpadeo.
	var luces: Array = []
	_cosechar_luces(_n, luces)
	_ok("hay luces", luces.size() > 0)
	var aditivas := true
	for luz in luces:
		if luz.blend_mode != Light2D.BLEND_MODE_ADD or luz.energy > 1.0:
			aditivas = false
	_ok("luces aditivas suaves", aditivas)
	var antorcha := _buscar(_n.get_node("sala_0"), "torch")
	_ok("antorcha animada", antorcha != null and antorcha.get_script() != null \
			and antorcha.get_script().resource_path.ends_with("torch.gd"))


func _buscar(nodo: Node, prefijo: String) -> Node:
	if nodo.name.begins_with(prefijo):
		return nodo
	for c in nodo.get_children():
		var r := _buscar(c, prefijo)
		if r != null:
			return r
	return null


func _cosechar_luces(nodo: Node, out: Array) -> void:
	if nodo is PointLight2D:
		out.append(nodo)
	for c in nodo.get_children():
		_cosechar_luces(c, out)


func _resumen() -> void:
	print("==== ASSERT TUTORIAL: ", _checks - _fallos, "/", _checks, " PASS ====")
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
