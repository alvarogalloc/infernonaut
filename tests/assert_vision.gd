extends SceneTree
## Línea de vista (stage 3): los enemigos solo detectan al jugador si lo ven.
## 1) enemigo_1 con una pared delante al entrar al área: NO persigue.
## 2) sin pared: persigue. 3) pierde la vista y el jugador escapa: abandona
## tras la gracia (tiempo_perder_vista). 4) cobarde no reacciona con pared;
## 5) reacciona al verlo.
## Uso: godot --headless --fixed-fps 60 --script res://tests/assert_vision.gd

var _espera := 3
var _t := 0.0
var _paso := 0
var _checks := 0
var _fallos := 0

var _enemigo: CharacterBody2D
var _cobarde: CharacterBody2D
var _jugador: Node2D
var _pared1: StaticBody2D
var _pared2: StaticBody2D


func _initialize() -> void:
	pass


func _process(delta: float) -> bool:
	if _espera > 0:
		_espera -= 1
		if _espera == 2:
			_enemigo = load("res://scenes/enemigos/enemigo_1.tscn").instantiate()
			_enemigo.global_position = Vector2(0, 0)
			root.add_child(_enemigo)
			_jugador = load("res://scenes/personaje/character_body_2d.tscn").instantiate()
			_jugador.global_position = Vector2(600, 0)
			root.add_child(_jugador)
			_pared1 = _crear_pared(300, 0)
			root.add_child(_pared1)
		return false
	_t += delta
	match _paso:
		0:
			# El jugador entra en el área con una pared delante: no persigue.
			_enemigo._on_activate_body_entered(_jugador)
			_paso = 1
		1:
			if _t > 1.0:
				_ok("enemigo_1 NO persigue con la pared delante", not _enemigo.persiguiendo)
				_pared1.collision_layer = 0
				_paso = 2
		2:
			if _t > 1.3:
				_ok("enemigo_1 persigue al ver al jugador", _enemigo.persiguiendo)
				# Pierde la vista y el jugador escapa del área de activación.
				_enemigo._on_activate_body_exited(_jugador)
				_jugador.global_position = Vector2(3000, 0)
				_pared1.collision_layer = 8
				_paso = 3
		3:
			if _t > 3.2:  # 1.3 + gracia 1.5 + margen
				_ok("enemigo_1 abandona tras perder la vista (gracia)", not _enemigo.persiguiendo)
				# Fase cobarde en una zona aparte.
				_cobarde = load("res://scenes/enemigos/cobarde/cobarde.tscn").instantiate()
				_cobarde.global_position = Vector2(0, 6000)
				root.add_child(_cobarde)
				var shape: CircleShape2D = _cobarde.area_activacion.shape.duplicate()
				shape.radius = 5000.0
				_cobarde.area_activacion.shape = shape
				_jugador.global_position = Vector2(800, 6000)
				_pared2 = _crear_pared(400, 6000)
				root.add_child(_pared2)
				_cobarde._on_activate_body_entered(_jugador)
				_paso = 4
		4:
			if _t > 4.1:
				_eq("cobarde NO reacciona con la pared delante",
						int(_cobarde._estado), int(_cobarde.Estado.INACTIVO))
				_pared2.collision_layer = 0
				_paso = 5
		5:
			if _t > 5.2:
				_ok("cobarde reacciona al ver al jugador",
						int(_cobarde._estado) != int(_cobarde.Estado.INACTIVO))
				print("==== ASSERT VISION: ", _checks - _fallos, "/", _checks, " PASS ====")
				print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")
				quit(1 if _fallos > 0 else 0)
				return true
	return false


## Pared en la capa "pared" (4 = valor 8) que bloquea la línea de vista.
## Se activa/desactiva cambiando collision_layer (0 = sin colisión).
func _crear_pared(cx: float, cy: float, alto := 1200.0) -> StaticBody2D:
	var pared := StaticBody2D.new()
	pared.collision_layer = 8
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(80, alto)
	forma.shape = rect
	pared.add_child(forma)
	pared.global_position = Vector2(cx, cy)
	return pared


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