extends SceneTree
## Asserts headless del cambio de sala (uso: godot --headless --fixed-fps 60
## --script res://tests/assert_salas.gd). Recorre TODAS las puertas en
## ambos sentidos y exige que la camara siga al jugador.
## Fase 1: gestor OFF (deteccion pura de la camara).
## Fase 2: gestor ON (pipeline completo: wipe + teletransporte + reveal).
## Sale con codigo 0 si todo pasa, 1 si algo falla.

var _paso := 0
var _espera := 0
var _pendiente := -1
var _fallos := 0
var _checks := 0
var _jugador: Node2D
var _camara: Camera2D
var _gestor: Node
var _seq0 := 0
var _seq1 := 0
var _plan: Array = [] # cada paso: [pos_o_null, sala_esperada_o_null, etiqueta, espera_extra, checks_gestor]


var _nivel: Node
var _arrancado := false


func _initialize() -> void:
	# Solo instanciar: los _ready (grupos) corren en los primeros frames.
	var ps: PackedScene = load("res://scenes/escena_principal/escenaprincipal.tscn")
	_nivel = ps.instantiate()
	root.add_child(_nivel)
	_construir_plan()
	_espera = 8 # arranque: _readys + la camara encuadra


func _arrancar() -> void:
	_jugador = get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	_camara = get_first_node_in_group("camara_jugador")
	_gestor = get_first_node_in_group("transicion_salas")
	_jugador = get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	_camara = get_first_node_in_group("camara_jugador")
	_gestor = get_first_node_in_group("transicion_salas")
	if _jugador == null or _camara == null or _gestor == null:
		print("FAIL arranque: jugador=", _jugador, " camara=", _camara, " gestor=", _gestor)
		_espera = 20
		return
	# Neutralizar peligros y ruido: el pincho mata al pasar (pausaria el
	# arbol) y los enemigos persiguen. La escena real no se toca.
	var p := _nivel.get_node_or_null("pincho")
	if p != null:
		p.queue_free()
	for h in _nivel.get_children():
		if h is Node2D and h.name.begins_with("enemigo"):
			h.set_physics_process(false)
			h.global_position = Vector2(99999, 99999)
	_gestor.set("activa", false)
	_mover(_plan[0][0])
	_arrancado = true


func _ir(pos, esperado, etiqueta: String, extra := 0, checks = false) -> void:
	_plan.append([pos, esperado, etiqueta, extra, checks])


func _construir_plan() -> void:
	var R1 := "habitacion1"
	var R2 := "Habitacion2"
	var R3 := "habitacion3"
	var R4 := "habitacion4"
	# Ida R1 -> R2 (puerta ESTE/OESTE, y=-640).
	_ir(Vector2(1408, -640), R1, "arranque R1")
	_ir(Vector2(900, -640), null, "pasillo R1")
	_ir(Vector2(600, -640), null, "puerta R1")
	_ir(Vector2(300, -640), null, "umbral R2")
	_ir(Vector2(-200, -640), null, "entrada R2")
	_ir(Vector2(-635, -640), R2, "R1->R2 centro")
	# Vuelta R2 -> R1.
	_ir(Vector2(300, -640), null, "umbral R1")
	_ir(Vector2(700, -640), null, "puerta R1b")
	_ir(Vector2(1408, -640), R1, "R2->R1 centro")
	# Ida R2 -> R3 (puerta ABAJO de R2, x=-635).
	_ir(Vector2(-635, -640), R2, "vuelta R2")
	_ir(Vector2(-635, -300), null, "bajada R2")
	_ir(Vector2(-635, -128), null, "puerta R2 abajo")
	_ir(Vector2(-635, -20), null, "umbral R3")
	_ir(Vector2(-635, 122), null, "puerta R3 arriba")
	_ir(Vector2(-635, 400), R3, "R2->R3 dentro")
	_ir(Vector2(-636, 634), R3, "R2->R3 centro")
	# Vuelta R3 -> R2 (puerta ARRIBA de R3).
	_ir(Vector2(-636, 122), null, "puerta R3 arriba b")
	_ir(Vector2(-636, -20), null, "umbral R2b")
	_ir(Vector2(-635, -300), null, "subida R2")
	_ir(Vector2(-635, -640), R2, "R3->R2 centro")
	# Ida R3 -> R4 (puerta ABAJO de R3, x=-636).
	_ir(Vector2(-636, 634), R3, "vuelta R3")
	_ir(Vector2(-636, 900), null, "bajada R3")
	_ir(Vector2(-636, 1146), null, "puerta R3 abajo")
	_ir(Vector2(-636, 1280), null, "umbral R4")
	_ir(Vector2(-636, 1450), null, "puerta R4 arriba")
	_ir(Vector2(-636, 1700), R4, "R3->R4 dentro")
	# Vuelta R4 -> R3 (puerta ARRIBA de R4).
	_ir(Vector2(-636, 1450), null, "puerta R4 arriba b")
	_ir(Vector2(-636, 1280), null, "umbral R3b")
	_ir(Vector2(-636, 1146), null, "puerta R3 abajo b")
	_ir(Vector2(-636, 900), null, "subida R3")
	_ir(Vector2(-636, 634), R3, "R4->R3 centro")
	# Fase 2: gestor ON, cruce real R3 -> R4 con wipe + teletransporte.
	_ir("GESTOR_ON", null, "activar gestor")
	_ir(Vector2(-636, 900), null, "f2 bajada")
	_ir(Vector2(-636, 1146), null, "f2 puerta")
	_ir(Vector2(-636, 1260), null, "f2 umbral (dispara)")
	_ir(null, R4, "f2 R3->R4 con transicion", 120, true)
	# Fase 3: dash en curso hacia el norte al cruzar R4 -> R3. Sin el fix
	# del objetivo pendiente, al liberar sigue hacia el norte, vuelve a
	# cruzar y entra en ping-pong R2<->R3 de transiciones. Debe haber UNA.
	_ir("DASH_NORTE", null, "f3 dash en curso al norte")
	_ir(null, R3, "f3 llegada R3", 240, "f3a")
	_ir(null, R3, "f3 estable sin rebote", 150, "f3b")


func _mover(pos: Vector2) -> void:
	_jugador.global_position = pos
	_jugador.set("target_position", pos) # sin esto el dash reanuda solo


func _actual_nombre() -> String:
	var a = _camara.get("_actual")
	if a == null or not is_instance_valid(a):
		return "<null>"
	return (a as Node).name


func _process(_delta: float) -> bool:
	if _espera > 0:
		_espera -= 1
		return false
	if not _arrancado:
		_arrancar()
		_espera = 20
		return false
	if _pendiente >= 0:
		_evaluar(_pendiente)
		_pendiente = -1
	if _paso >= _plan.size():
		_informe()
		quit(1 if _fallos > 0 else 0)
		return true
	var s: Array = _plan[_paso]
	_paso += 1
	if s[0] is String and s[0] == "GESTOR_ON":
		_gestor.set("activa", true)
		print("[fase2] gestor activado")
	elif s[0] is String and s[0] == "DASH_NORTE":
		_seq0 = int(_gestor.get("_seq"))
		_jugador.call("dash_hacia", Vector2(-636, 0), true) # dash fuerte al norte
		print("[fase3] dash en curso, seq=", _seq0)
	elif s[0] != null:
		_mover(s[0])
	_pendiente = _paso - 1
	_espera = 4 + int(s[3])
	return false


func _evaluar(i: int) -> void:
	var s: Array = _plan[i]
	var etiqueta: String = s[2]
	var esperado = s[1]
	var real := _actual_nombre()
	if esperado == null:
		print("  ... ", etiqueta, " pos=", s[0], " sala=", real)
		return
	_checks += 1
	if real == esperado:
		print("PASS ", etiqueta, " -> ", real)
	else:
		_fallos += 1
		print("FAIL ", etiqueta, " esperaba=", esperado, " real=", real, " pos=", s[0])
	if str(s[4]) == "f3a":
		_chequeos_fase3a()
	elif str(s[4]) == "f3b":
		_chequeos_fase3b()
	elif bool(s[4]):
		_chequeos_gestor()


func _chequeos_gestor() -> void:
	_checks += 1
	var color: ColorRect = _gestor.get_node("Capa/Color")
	var prog: float = (color.material as ShaderMaterial).get_shader_parameter("progreso")
	var bloqueado: bool = bool(_jugador.get("transicionando"))
	var ocupada: bool = bool(_gestor.get("_ocupada"))
	var dir: Vector2 = (color.material as ShaderMaterial).get_shader_parameter("direccion")
	var dentro: bool = _camara.sala_rect(_camara.sala_actual()).grow(-10.0).has_point(_jugador.global_position)
	if prog == 0.0 and not bloqueado and not ocupada and dentro:
		print("PASS pipeline transicion (overlay=0, libre, dentro de sala)")
	else:
		_fallos += 1
		print("FAIL pipeline: progreso=", prog, " transicionando=", bloqueado, " ocupada=", ocupada, " dentro=", dentro)
	# R3->R4 es hacia abajo: la direccion del wipe no puede quedar en el
	# valor por defecto (la cámara debe emitir antes de mover sala_actual).
	_checks += 1
	if dir == Vector2(0, 1):
		print("PASS wipe direccional (0,1)")
	else:
		_fallos += 1
		print("FAIL wipe direccion=", dir, " (esperaba (0, 1))")


func _informe() -> void:
	print("==== ASSERT SALAS: ", _checks - _fallos, "/", _checks, " PASS ====")
	if _fallos > 0:
		print("RESULTADO: FAIL (", _fallos, " fallos)")
	else:
		print("RESULTADO: OK")


## Fase 3a: tras el dash en curso, UNA sola transicion, objetivo muerto,
## overlay limpio y jugador quieto dentro de R3.
func _chequeos_fase3a() -> void:
	_checks += 1
	_seq1 = int(_gestor.get("_seq"))
	var color: ColorRect = _gestor.get_node("Capa/Color")
	var prog: float = (color.material as ShaderMaterial).get_shader_parameter("progreso")
	var quieto: bool = _jugador.global_position.distance_to(_jugador.get("target_position")) < 1.0
	if _seq1 == _seq0 + 1 and quieto and prog == 0.0:
		print("PASS f3a una transicion, dash muerto, overlay=0")
	else:
		_fallos += 1
		print("FAIL f3a: transiciones=", _seq1 - _seq0, " (esperaba 1) quieto=", quieto, " overlay=", prog)


## Fase 3b: sin rebote con el tiempo (el ping-pong sumaria transiciones).
func _chequeos_fase3b() -> void:
	_checks += 1
	var seq2 := int(_gestor.get("_seq"))
	if seq2 == _seq1 and _actual_nombre() == "habitacion3":
		print("PASS f3b estable en R3, sin rebotes (seq=", seq2, ")")
	else:
		_fallos += 1
		print("FAIL f3b: seq=", seq2, " (era ", _seq1, ") sala=", _actual_nombre())
