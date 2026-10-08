extends SceneTree
## Verifica:
##  - el dash normal NO activa la hitbox que daña (solo el fuerte)
##  - el fuerte sí la activa y el normal deja al jugador vulnerable
##  - tras aterrizar, la animación vuelve a "idle" (fix del dash pegado)
## Uso: godot --headless --fixed-fps 60 --script res://tests/assert_dash_dano.gd

var _nivel: Node
var _jugador: Node2D
var _espera := 2
var _paso := 0
var _t := 0
var _checks := 0
var _fallos := 0
const ORIGEN := Vector2(960, 540)


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
	_t += 1
	match _paso:
		0:
			_jugador.call("dash_hacia", ORIGEN + Vector2(300, 0), false) # normal
			_paso = 1
			_t = 0
		1:
			if _t >= 3:
				_check_emision("normal", true, false)
				_paso = 2
		2:
			if not bool(_jugador.get("_dashing")):
				_paso = 3
				_t = 0
		3:
			if _t >= 2:
				_check_idle("tras normal")
				_jugador.global_position = ORIGEN
				_jugador.set("target_position", ORIGEN)
				_jugador.call("dash_hacia", ORIGEN + Vector2(600, 0), true) # fuerte
				_paso = 4
				_t = 0
		4:
			if _t >= 3:
				_check_emision("fuerte", false, true)
				_paso = 5
		5:
			if not bool(_jugador.get("_dashing")):
				_paso = 6
				_t = 0
		6:
			if _t >= 2:
				_check_idle("tras fuerte")
				_informe()
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
	_jugador.global_position = ORIGEN
	_jugador.set("target_position", ORIGEN)


func _check_emision(etiqueta: String, dash_off: bool, idle_off: bool) -> void:
	_checks += 1
	var ed: bool = (_jugador.get("emisiondash") as CollisionShape2D).disabled
	var ei: bool = (_jugador.get("emisionidle") as CollisionShape2D).disabled
	if ed == dash_off and ei == idle_off:
		print("PASS emisión ", etiqueta, " (dash_disabled=", ed, " idle_disabled=", ei, ")")
	else:
		_fallos += 1
		print("FAIL emisión ", etiqueta, " dash_disabled=", ed, " esperaba=", dash_off, " idle_disabled=", ei, " esperaba=", idle_off)


func _check_idle(etiqueta: String) -> void:
	_checks += 1
	var anim: StringName = (_jugador.get("animacion") as AnimatedSprite2D).animation
	if anim == &"idle":
		print("PASS ", etiqueta, " -> idle")
	else:
		_fallos += 1
		print("FAIL ", etiqueta, " animación=", anim, " (esperaba idle)")


func _informe() -> void:
	print("==== ASSERT DASH DAÑO/FEEDBACK: ", _checks - _fallos, "/", _checks, " PASS ====")
	print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")


func _quitar_pinchos(n: Node) -> void:
	for h in n.get_children():
		if h.name.contains("pincho"):
			h.free()
		else:
			_quitar_pinchos(h)
