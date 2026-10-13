extends SceneTree
## Recompensas de salas tesoro: el generador coloca al menos una recompensa
## por nivel, sobre el suelo de su sala; al tocarla el jugador real recibe la
## mejora (escudo o dash sombra) y el nodo se elimina.
## Uso: godot --headless --script res://tests/assert_recompensas.gd

var _checks := 0
var _fallos := 0
var _paso := 0
var _i := 0
var _seeds: Array = []
var _jugador: CharacterBody2D


func _initialize() -> void:
	for sem in range(1, 21):
		_seeds.append([sem, sem % 2])


func _process(_delta: float) -> bool:
	if _paso == 0:
		_jugador = load("res://scenes/personaje/character_body_2d.tscn").instantiate()
		root.add_child(_jugador)
		_probar_mejoras()
		_paso = 1
		return false
	if _i >= _seeds.size():
		_resumen()
		return true
	var caso: Array = _seeds[_i]
	_i += 1
	var nivel := GeneradorNivel.new().generar(caso[0], caso[1])
	root.add_child(nivel)
	_comprobar_nivel(nivel, caso)
	root.remove_child(nivel)
	nivel.free()
	return false


func _probar_mejoras() -> void:
	_jugador.escudos_restantes = 0
	_jugador.cargas_dash_sombra = 0
	_jugador.aplicar_recompensa("escudo")
	_eq("escudo: +1 golpe", _jugador.escudos_restantes, 1)
	_jugador._actualizar_aura()
	_ok("aura escudo activa con escudo", _jugador._aura_escudo != null and _jugador._aura_escudo.emitting)
	_jugador.golpear()
	_eq("escudo absorbe el golpe letal", _jugador._muerto, false)
	_eq("escudo gastado tras golpear", _jugador.escudos_restantes, 0)
	_jugador._invulnerable_hasta = 0 ## sin invulnerabilidad residual de franja
	_jugador._actualizar_aura()
	_ok("aura escudo apagada sin escudo", _jugador._aura_escudo == null or not _jugador._aura_escudo.emitting)
	_jugador.golpear()
	_eq("segundo golpe ya mata", _jugador._muerto, true)
	_jugador._muerto = false
	_jugador.escudos_restantes = 0
	_jugador.cargas_dash_sombra = 0
	_jugador.cargas_actuales = 1
	_jugador.aplicar_recompensa("dash_sombra")
	_eq("dash sombra: +5 cargas", _jugador.cargas_dash_sombra, 5)
	_jugador._actualizar_aura()
	_ok("aura sombra activa con cargas", _jugador._aura_sombra != null and _jugador._aura_sombra.emitting)
	_ok("dash sombra oscurece el sprite", _jugador.animacion.self_modulate == Color(0.5, 0.5, 0.65))


func _comprobar_nivel(nivel: Node2D, caso: Array) -> void:
	var etq := "sem %d p%d" % [caso[0], caso[1]]
	var recs: Array = []
	_cosechar(nivel, recs)
	_ok(etq + " hay al menos una recompensa", recs.size() >= 1)
	for r in recs:
		_ok(etq + " recompensa válida", r.tipo in ["escudo", "dash_sombra"])
		_ok(etq + " recompensa sobre el suelo", _sobre_suelo(r))
		_jugador.global_position = r.global_position + Vector2(0, -40)
		r._on_body_entered(_jugador)
		_ok(etq + " se elimina al recogerla", r.is_queued_for_deletion())


func _cosechar(nodo: Node, out: Array) -> void:
	if nodo.name.contains("recompensa"):
		out.append(nodo)
	for c in nodo.get_children():
		_cosechar(c, out)


func _sobre_suelo(r: Node2D) -> bool:
	var room := r.get_parent()
	var layer := _capa(room)
	if layer == null:
		return true
	var used: Rect2i = layer.get_used_rect()
	return r.position.x >= 0 and r.position.y >= 0 \
		and r.position.x <= used.end.x * 60 and r.position.y <= used.end.y * 60


func _capa(nodo: Node) -> TileMapLayer:
	if nodo is TileMapLayer:
		return nodo
	for c in nodo.get_children():
		var l := _capa(c)
		if l != null:
			return l
	return null


func _resumen() -> void:
	print("==== ASSERT RECOMPENSAS: ", _checks - _fallos, "/", _checks, " PASS ====")
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