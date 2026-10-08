extends SceneTree
## Regresión del ping-pong al cruzar puertas con pisos solapados (R1<->R2).
## Mueve al jugador con dash real (no teletransporte) de ida y vuelta y exige
## UNA transición por cruce, sin quedarse bloqueado ni rebotar.
## Uso: godot --headless --fixed-fps 60 --script res://tests/assert_rebote_salas.gd
## Sale con 0 si todo pasa, 1 si falla.

var _nivel: Node
var _jugador: Node2D
var _camara: Camera2D
var _gestor: Node
var _arrancado := false
var _espera := 8
var _fallos := 0
var _checks := 0
# Cada tramo: destino del dash + sala esperada al llegar.
var _tramos: Array = [
	[Vector2(0, -640), "Habitacion2"],
	[Vector2(1408, -640), "habitacion1"],
	[Vector2(0, -640), "Habitacion2"],
	[Vector2(1408, -640), "habitacion1"],
]
var _tramo := 0
var _seq_previo := 0
var _timeout := 0
var _en_transicion := false
var _destino := Vector2.ZERO


func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/escena_principal/escenaprincipal.tscn")
	_nivel = ps.instantiate()
	root.add_child(_nivel)


func _arrancar() -> void:
	_jugador = get_first_node_in_group(Constantes.GRUPO_PERSONAJES)
	_camara = get_first_node_in_group("camara_jugador")
	_gestor = get_first_node_in_group("transicion_salas")
	if _jugador == null or _camara == null or _gestor == null:
		print("FAIL arranque: jugador=", _jugador, " camara=", _camara, " gestor=", _gestor)
		quit(1)
		return
	var p := _nivel.get_node_or_null("pincho")
	if p != null:
		p.queue_free()
	for h in _nivel.get_children():
		if h is Node2D and h.name.begins_with("enemigo"):
			h.set_physics_process(false)
			h.global_position = Vector2(99999, 99999)
	_jugador.set("collision_mask", 0) # aislar la transición de colisiones
	_gestor.set("activa", true)
	_camara.set("_actual", null)
	_jugador.global_position = Vector2(1408, -640)
	_jugador.set("target_position", Vector2(1408, -640))
	_seq_previo = int(_gestor.get("_seq"))
	_lanzar_tramo()


func _lanzar_tramo() -> void:
	_destino = _tramos[_tramo][0]
	_en_transicion = false
	_timeout = 900
	_re_dash()


## Los dashes son discretos: relanza uno fuerte hacia la puerta hasta cruzar.
func _re_dash() -> void:
	_jugador.call("dash_hacia", _destino, true)


func _process(_delta: float) -> bool:
	if _espera > 0:
		_espera -= 1
		return false
	if not _arrancado:
		_arrancar()
		_arrancado = true
		return false
	var tr: bool = bool(_jugador.get("transicionando"))
	if not _en_transicion and tr:
		_en_transicion = true
		_timeout = 900
	if _timeout > 0:
		_timeout -= 1
	if not _en_transicion:
		if _timeout <= 0:
			_fallos += 1
			print("FAIL tramo ", _tramo, ": no cruzó de sala (pos=", _jugador.global_position, ")")
			return _avanzar()
		# sin dash en curso: relanzar hacia la puerta
		if not bool(_jugador.get("_dashing")):
			_re_dash()
		return false
	# esperar a que termine la transición
	if tr:
		if _timeout <= 0:
			_fallos += 1
			print("FAIL tramo ", _tramo, ": la transición no termina (ping-pong)")
			return _avanzar()
		return false
	# terminó: comprobar UNA transición y sala correcta
	_checks += 1
	var seq := int(_gestor.get("_seq"))
	var esperada: String = _tramos[_tramo][1]
	var actual := "<null>"
	if _camara.get("_actual") != null:
		actual = (_camara.get("_actual") as Node).name
	var overlay: float = ((_gestor.get_node("Capa/Color").material) as ShaderMaterial).get_shader_parameter("progreso")
	if seq == _seq_previo + 1 and actual == esperada and overlay == 0.0:
		print("PASS tramo ", _tramo, " -> ", actual, " (1 transición)")
	else:
		_fallos += 1
		print("FAIL tramo ", _tramo, ": seq ", _seq_previo, "->", seq, " (esperaba +1) sala=", actual, " esperaba=", esperada, " overlay=", overlay)
	_seq_previo = seq
	return _avanzar()


func _avanzar() -> bool:
	_tramo += 1
	if _tramo >= _tramos.size():
		print("==== ASSERT REBOTE SALAS: ", _checks - _fallos, "/", _checks, " PASS ====")
		print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")
		quit(1 if _fallos > 0 else 0)
		return true
	_lanzar_tramo()
	return false
