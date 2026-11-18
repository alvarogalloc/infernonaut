extends SceneTree
## Sangre: al morir un enemigo sale un chorro de partículas y quedan manchas
## en el suelo de la sala. Cubre enemigo_1 y cobarde.
## Uso: godot --headless --fixed-fps 60 --script res://tests/assert_sangre.gd

var _t := 0.0
var _paso := 0
var _checks := 0
var _fallos := 0
var _sala: Node2D
var _pos_e1 := Vector2.ZERO
var _pos_cob := Vector2.ZERO


func _process(delta: float) -> bool:
	_t += delta
	match _paso:
		0:
			_montar()
			_paso = 1
		1:
			if _t >= 0.1:
				_revisar_estallido(_pos_e1)
				_revisar_estallido(_pos_cob)
				# _morir() se llamó dos veces por enemigo: los guardas evitan duplicar.
				_eq("dos chorros de partículas (uno por enemigo)", _contar(CPUParticles2D), 2)
				_eq("dos charcos (uno por enemigo)", _contar(Sangre.Mancha), 2)
				_paso = 2
		2:
			if _t >= 1.6:
				# Los chorros se liberan solos al terminar; las manchas se quedan.
				_eq("los chorros se liberan al terminar", _contar(CPUParticles2D), 0)
				_eq("las manchas persisten", _contar(Sangre.Mancha), 2)
				print("==== ASSERT SANGRE: ", _checks - _fallos, "/", _checks, " PASS ====")
				print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")
				quit(1 if _fallos > 0 else 0)
				return true
	return false


func _montar() -> void:
	_sala = Node2D.new()
	_sala.position = Vector2(500, 300)
	root.add_child(_sala)

	var e1: Node2D = load("res://scenes/enemigos/enemigo_1.tscn").instantiate()
	_sala.add_child(e1)
	e1.global_position = _sala.position + Vector2(100, 0)
	_pos_e1 = e1.global_position

	var cob: Node2D = load("res://scenes/enemigos/cobarde/cobarde.tscn").instantiate()
	_sala.add_child(cob)
	cob.global_position = _sala.position + Vector2(400, 0)
	_pos_cob = cob.global_position

	e1._morir()
	cob._morir()
	e1._morir()
	cob._morir()
	_ok("enemigo_1 queda muerto", e1.esta_muerto)
	_ok("cobarde queda muerto", cob.esta_muerto)


func _revisar_estallido(pos: Vector2) -> void:
	var chorro: CPUParticles2D = null
	var charco: Node2D = null
	for c in _sala.get_children():
		if c is CPUParticles2D and c.global_position.distance_to(pos) < 1.0:
			chorro = c
		elif c is Sangre.Mancha and c.global_position.distance_to(pos) < 1.0:
			charco = c
	_ok("sale sangre donde muere el enemigo (%s)" % pos, chorro != null and charco != null)
	if chorro == null or charco == null:
		return
	_ok("chorro con muchas partículas", chorro.amount >= 80)
	_ok("chorro en un solo estallido", chorro.one_shot and chorro.explosiveness > 0.9)
	_ok("gota redonda generada (no cuadrado blanco)", chorro.texture != null)
	_eq("chorro en la banda de efectos", chorro.z_index, Constantes.Z_EFECTO)
	_eq("charco en la banda de decoración del suelo", charco.z_index, Constantes.Z_DECOR_SUELO)


func _contar(tipo: Variant) -> int:
	var n := 0
	for c in _sala.get_children():
		if is_instance_of(c, tipo):
			n += 1
	return n


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
