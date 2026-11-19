extends Area2D
## Llave recogible. Las puertas consumen una al tocarlas. Al recogerla, un haz
## de color (mismo plano del mundo) señala la puerta abrible más cercana para
## que el jugador sepa a dónde ir sin romper el ritmo.

const DURACION_HAZ := 0.55

var _t := 0.0
var _y := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_y = position.y


func _process(delta: float) -> void:
	_t += delta
	position.y = _y + sin(_t * 3.0) * 6.0


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(Constantes.GRUPO_PERSONAJES) or not body.has_method("agregar_llave"):
		return
	body.agregar_llave()
	_señalar_puerta()
	queue_free()


## Haz rápido de la llave a la puerta abrible más cercana, tintado con el color
## de su requisito. Vive en la sala (no en el HUD) y se desvanece solo.
func _señalar_puerta() -> void:
	var puerta := _puerta_mas_cercana()
	var padre := get_parent()
	if puerta == null or padre == null:
		return
	var haz := Line2D.new()
	haz.width = 14.0
	haz.default_color = puerta.color_requerida()
	haz.z_index = Constantes.Z_EFECTO
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	haz.material = mat
	haz.points = PackedVector2Array([
		padre.to_local(global_position), padre.to_local(puerta.global_position)
	])
	padre.add_child(haz)
	var tw := haz.create_tween()
	tw.tween_property(haz, "width", 3.0, 0.15)
	tw.parallel().tween_property(haz, "modulate:a", 0.0, DURACION_HAZ)
	tw.tween_callback(haz.queue_free)


func _puerta_mas_cercana() -> Node2D:
	var mejor: Node2D = null
	var mejor_dist := INF
	for p in get_tree().get_nodes_in_group(Constantes.GRUPO_PUERTAS):
		if not is_instance_valid(p) or p.call("esta_abierta"):
			continue
		var d := global_position.distance_squared_to(p.global_position)
		if d < mejor_dist:
			mejor_dist = d
			mejor = p
	return mejor
