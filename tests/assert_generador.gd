extends SceneTree
## Genera varios niveles (2 plantillas x varias semillas) y verifica:
##  - el nivel es un solo componente conexo (siempre pasable)
##  - existen jugador, cámara, gestor, meta y enemigos
## Uso: godot --headless --script res://tests/assert_generador.gd

var _gen := GeneradorNivel.new()
var _casos := [[1, 0], [2, 0], [3, 0], [4, 0], [5, 0], [6, 1], [7, 1], [8, 1], [9, 1], [10, 1], [11, 0], [12, 1]]
var _i := 0
var _espera := 3
var _checks := 0
var _fallos := 0


func _process(_delta: float) -> bool:
	if _espera > 0:
		_espera -= 1
		return false
	if _i >= _casos.size():
		print("==== ASSERT GENERADOR: ", _checks - _fallos, "/", _checks, " PASS ====")
		print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")
		quit(1 if _fallos > 0 else 0)
		return true
	var caso: Array = _casos[_i]
	_i += 1
	var nivel: Node2D = _gen.generar(caso[0], caso[1])
	_check(nivel, caso)
	nivel.free()
	return false


func _check(nivel: Node2D, caso: Array) -> void:
	var etq := "semilla %d plantilla %d" % [caso[0], caso[1]]
	_eq(etq + " conexo", _gen.es_conexo(nivel), true)
	_eq(etq + " jugador", nivel.get_node_or_null("personaje") != null, true)
	_eq(etq + " cámara", nivel.get_node_or_null("Camera2D") != null, true)
	_eq(etq + " gestor", nivel.get_node_or_null("TransicionSalas") != null, true)
	_eq(etq + " meta", nivel.get_node_or_null("meta") != null, true)
	_eq(etq + " enemigos>0", _contar(nivel, "enemigo") > 0, true)


func _contar(nodo: Node, sub: String) -> int:
	var n := 0
	for h in nodo.get_children():
		if h.name.contains(sub):
			n += 1
		n += _contar(h, sub)
	return n


func _eq(etq: String, real, esperado) -> void:
	_checks += 1
	if real == esperado:
		print("PASS ", etq)
	else:
		_fallos += 1
		print("FAIL ", etq, " real=", real, " esperado=", esperado)
