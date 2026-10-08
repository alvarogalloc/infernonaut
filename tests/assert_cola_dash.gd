extends SceneTree
## Verifica la cola de dashes cortos: encolar 4 debe ejecutar 4 dashes
## encadenados (una subida de `_dashing` por dash), sin quedarse trabado.
## Uso: godot --headless --fixed-fps 60 --script res://tests/assert_cola_dash.gd

var _nivel: Node2D
var _jugador: Node2D
var _espera := 2
var _enviado := false
var _t := 0
var _checks := 0
var _fallos := 0


func _initialize() -> void:
	_nivel = GeneradorNivel.new().generar(12345, 0)
	root.add_child(_nivel)


func _process(_delta: float) -> bool:
	if _espera > 0:
		_espera -= 1
		return false
	if _jugador == null:
		_setup()
		return false
	if not _enviado:
		var base := _jugador.global_position
		for i in 4:
			_jugador.call("_encolar_dash", base + Vector2(300.0 * (i + 1), 0.0))
		_enviado = true
		return false
	_t += 1
	if _t >= 240:
		_checks += 1
		var lanzados := int(_jugador.get("dashes_lanzados"))
		if lanzados == 4 and _jugador.get("_cola").is_empty():
			print("PASS cola: 4 dashes encadenados")
		else:
			_fallos += 1
			print("FAIL cola: dashes=", lanzados, " (esperaba 4)")
		print("==== ASSERT COLA DASH: ", _checks - _fallos, "/", _checks, " PASS ====")
		print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")
		quit(1 if _fallos > 0 else 0)
		return true
	return false


func _setup() -> void:
	_jugador = get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	for h in _nivel.get_children():
		if h is Node2D and h.name.contains("enemigo"):
			h.set_physics_process(false)
			h.global_position = Vector2(99999, 99999)
	_quitar_pinchos(_nivel)
	var g = get_first_node_in_group("transicion_salas")
	if g:
		g.set("activa", false)
	_jugador.set("collision_mask", 0)


func _quitar_pinchos(n: Node) -> void:
	for h in n.get_children():
		if h.name.contains("pincho"):
			h.free()
		else:
			_quitar_pinchos(h)
