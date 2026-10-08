extends SceneTree
## Verifica el layout proto y la cámara por tipo de sala (GDD 5.1.1):
## 1x1 fija, nx1 fija en Y, 1xn fija en X, nxm sigue ambos; zoom fijo = 1.
## Uso: godot --headless --script res://tests/assert_proto.gd

var _nivel: Node
var _camara: Camera2D
var _espera := 2
var _arrancado := false
var _checks := 0
var _fallos := 0


func _initialize() -> void:
	_nivel = GeneradorNivel.new().generar(12345, 0)
	root.add_child(_nivel)


func _process(_delta: float) -> bool:
	if _espera > 0:
		_espera -= 1
		return false
	if not _arrancado:
		_arrancar()
		_arrancado = true
		return false
	_informe()
	quit(1 if _fallos > 0 else 0)
	return true


func _arrancar() -> void:
	_camara = get_first_node_in_group("camara_jugador")
	if _camara == null:
		print("FAIL: cámara no encontrada")
		_fallos += 1
		return
	for h in _nivel.get_children():
		if h is Node2D and h.name.contains("enemigo"):
			h.set_physics_process(false)
			h.global_position = Vector2(99999, 99999)
	_quitar_pinchos(_nivel)
	var salas := _camara.get("_habitaciones") as Array
	_eq("n salas", salas.size(), 5)
	var esperadas := {
		"sala_1x1": Rect2(0, 0, 1920, 1080),
		"sala_2x1": Rect2(1920, 0, 3840, 1080),
		"sala_1x2": Rect2(1920, 1080, 1920, 2160),
		"sala_2x2": Rect2(3840, 1080, 3840, 2160),
		"sala_3x1": Rect2(0, 3240, 5760, 1080),
	}
	var por_nombre := {}
	for s in salas:
		por_nombre[(s as Node).name] = s
	for nombre in esperadas:
		if not por_nombre.has(nombre):
			_fallos += 1
			print("FAIL falta sala ", nombre)
			continue
		var r: Rect2 = _camara.sala_rect(por_nombre[nombre])
		_eq("rect " + nombre, r, esperadas[nombre])
	_conectividad(salas)
	# zoom fijo
	_camara.call("_enfocar_sala", por_nombre["sala_1x1"])
	_eq("zoom", _camara.zoom, Vector2(1, 1))
	# 1x1: fija en el centro
	_foco("1x1 fija", por_nombre["sala_1x1"], Vector2(100, 100), Vector2(960, 540))
	# 2x1: fija en Y, sigue en X con clamp
	_foco("2x1 clamp izq", por_nombre["sala_2x1"], Vector2(2000, 100), Vector2(2880, 540))
	_foco("2x1 libre", por_nombre["sala_2x1"], Vector2(4000, 100), Vector2(4000, 540))
	_foco("2x1 clamp der", por_nombre["sala_2x1"], Vector2(9999, 100), Vector2(4800, 540))
	# 1x2: fija en X, sigue en Y con clamp
	_foco("1x2 clamp arr", por_nombre["sala_1x2"], Vector2(9999, 1000), Vector2(2880, 1620))
	# 2x2: sigue ambos
	_foco("2x2 libre", por_nombre["sala_2x2"], Vector2(5000, 2000), Vector2(5000, 2000))
	# 3x1: fija en Y, clamp X
	_foco("3x1 clamp izq", por_nombre["sala_3x1"], Vector2(-500, 3600), Vector2(960, 3780))


## Laberinto: todos los tiles transitables (no-pared) del nivel deben ser UN
## solo componente conexo (salas + puertas + laberinto). Si no, hay zonas
## inalcanzables.
func _conectividad(salas: Array) -> void:
	var walk := {}
	for room in salas:
		var layer: TileMapLayer = null
		for c in (room as Node).get_children():
			if c is TileMapLayer:
				layer = c
				break
		if layer == null:
			continue
		var base := Vector2i((room as Node2D).position / 60.0)
		var used: Rect2i = layer.get_used_rect()
		for y in range(used.position.y, used.end.y):
			for x in range(used.position.x, used.end.x):
				var cel := Vector2i(x, y)
				if layer.get_cell_atlas_coords(cel) != Vector2i(1, 0):
					walk[base + cel] = true
	var claves := walk.keys()
	if claves.is_empty():
		return
	var visto := {}
	var cola: Array = [claves[0]]
	visto[claves[0]] = true
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while cola.size() > 0:
		var c: Vector2i = cola.pop_back()
		for d in dirs:
			var n: Vector2i = c + d
			if walk.has(n) and not visto.has(n):
				visto[n] = true
				cola.append(n)
	_checks += 1
	if visto.size() == claves.size():
		print("PASS laberinto conexo (", claves.size(), " tiles)")
	else:
		_fallos += 1
		var faltan: Array = []
		for k in claves:
			if not visto.has(k):
				faltan.append(k)
		var mn: Vector2i = faltan[0]
		var mx: Vector2i = faltan[0]
		for f in faltan:
			mn.x = mini(mn.x, f.x)
			mn.y = mini(mn.y, f.y)
			mx.x = maxi(mx.x, f.x)
			mx.y = maxi(mx.y, f.y)
		print("FAIL laberinto: ", visto.size(), "/", claves.size(), " alcanzables; aislados=", faltan.size(), " bbox=", mn, "..", mx)


func _foco(etiqueta: String, sala: Node2D, p: Vector2, esperado: Vector2) -> void:
	_camara.set("_actual", sala)
	var f: Vector2 = _camara.call("_foco", p)
	_eq(etiqueta + " foco", f, esperado)


func _eq(etiqueta: String, real, esperado) -> void:
	_checks += 1
	if real == esperado:
		print("PASS ", etiqueta, " = ", real)
	else:
		_fallos += 1
		print("FAIL ", etiqueta, " real=", real, " esperado=", esperado)


func _informe() -> void:
	print("==== ASSERT PROTO: ", _checks - _fallos, "/", _checks, " PASS ====")
	print("RESULTADO: ", "FAIL" if _fallos > 0 else "OK")


func _quitar_pinchos(n: Node) -> void:
	for h in n.get_children():
		if h.name.contains("pincho"):
			h.free()
		else:
			_quitar_pinchos(h)
