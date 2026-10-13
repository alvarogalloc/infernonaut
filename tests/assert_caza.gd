extends SceneTree
## Gracia anti-caza al cambiar de sala: los enemigos de la sala nueva ven al
## jugador pero NO inician la caza durante `gracia_anti_caza`; al expirar
## vuelven a la normalidad. `detener_persecucion()` los devuelve al reposo.
## Uso: godot --headless --fixed-fps 60 --script res://tests/assert_caza.gd

var _checks := 0
var _fallos := 0
var _paso := 0
var _enemigo: CharacterBody2D
var _cobarde: CharacterBody2D
var _jugador: Node2D
var _sala: Node2D


func _initialize() -> void:
	pass


func _process(_delta: float) -> bool:
	if _paso == 0:
		_montar()
		_paso = 1
		return false
	_probar()
	_resumen()
	return true


func _montar() -> void:
	_jugador = load("res://scenes/personaje/character_body_2d.tscn").instantiate()
	_jugador.global_position = Vector2(600, 0)
	root.add_child(_jugador)

	_enemigo = load("res://scenes/enemigos/enemigo_1.tscn").instantiate()
	_enemigo.global_position = Vector2(0, 0)
	root.add_child(_enemigo)
	_enemigo.set_physics_process(false)

	_cobarde = load("res://scenes/enemigos/cobarde/cobarde.tscn").instantiate()
	_cobarde.global_position = Vector2(0, 6000)
	root.add_child(_cobarde)
	_cobarde.set_physics_process(false)

	_sala = Node2D.new()
	root.add_child(_sala)
	var e2: CharacterBody2D = load("res://scenes/enemigos/enemigo_1.tscn").instantiate()
	e2.global_position = Vector2(10000, 10000)
	_sala.add_child(e2)
	var c2: CharacterBody2D = load("res://scenes/enemigos/cobarde/cobarde.tscn").instantiate()
	c2.global_position = Vector2(10100, 10000)
	_sala.add_child(c2)


func _probar() -> void:
	# --- enemigo_1: la gracia bloquea el inicio de la caza ---
	_enemigo.jugador = _jugador
	_enemigo._jugador_en_area = true
	_enemigo.pausar_caza(Time.get_ticks_msec() + 60000)
	_ok("enemigo_1 pausada", _enemigo._caza_pausada())
	_enemigo._iniciar_persecucion()
	_ok("enemigo_1 no caza durante la gracia", not _enemigo.persiguiendo)
	_enemigo.pausar_caza(0)
	_enemigo._iniciar_persecucion()
	_ok("enemigo_1 caza al expirar la gracia", _enemigo.persiguiendo)
	_enemigo.detener_persecucion()
	_ok("detener resetea la caza", not _enemigo.persiguiendo and _enemigo.jugador == null)
	_ok("detener limpia el área", not _enemigo._jugador_en_area)

	# --- cobarde: la gracia bloquea la reacción ---
	_cobarde.jugador = _jugador
	_cobarde._jugador_en_area = true
	_cobarde.pausar_caza(Time.get_ticks_msec() + 60000)
	_cobarde._physics_process(0.016)
	_eq("cobarde INACTIVO durante la gracia", int(_cobarde._estado), int(_cobarde.Estado.INACTIVO))
	_cobarde.pausar_caza(0)
	_cobarde._physics_process(0.016)
	_ok("cobarde reacciona al expirar la gracia", int(_cobarde._estado) != int(_cobarde.Estado.INACTIVO))
	_cobarde._cambiar_estado(_cobarde.Estado.HUYENDO)
	_ok("cobarde en HUYENDO", _cobarde._estado == _cobarde.Estado.HUYENDO)
	_cobarde.detener_persecucion()
	_eq("detener cobarde -> INACTIVO", int(_cobarde._estado), int(_cobarde.Estado.INACTIVO))

	# --- recolector de enemigos por sala ---
	var trans: Node = load("res://scenes/escena_principal/transicion_salas.gd").new()
	_eq("_enemigos_de_sala halla los 2 de la sala", trans._enemigos_de_sala(_sala).size(), 2)
	var vacia := Node2D.new()
	root.add_child(vacia)
	_eq("_enemigos_de_sala: sala vacía = 0", trans._enemigos_de_sala(vacia).size(), 0)
	trans.free()


func _resumen() -> void:
	print("==== ASSERT CAZA: ", _checks - _fallos, "/", _checks, " PASS ====")
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