## Ayudante de línea de vista para los enemigos.
## Solo las paredes (capa física 4 = valor 8, "pared") bloquean la visión;
## pinchos, otros enemigos y el propio emisor no.
class_name Vision
extends RefCounted

const MASCARA_PARED := 8

## true si algún rayo (centro + ambos bordes del cuerpo del jugador) llega
## desde los "ojos" del emisor al objetivo sin tocar una pared.
## `origen_offset` son los ojos del emisor; `ancho` abanica la puntería.
static func ve_a(emisor: Node2D, objetivo: Node2D, origen_offset := Vector2(0, -40), ancho := 24.0) -> bool:
	if emisor == null or objetivo == null or not emisor.is_inside_tree() \
			or not objetivo.is_inside_tree():
		return false
	var espacio := emisor.get_world_2d().direct_space_state
	var desde := emisor.global_position + origen_offset
	var centro := objetivo.global_position
	var perp := (centro - desde).orthogonal().normalized() * ancho * 0.5
	for punto in [centro, centro + perp, centro - perp]:
		var q := PhysicsRayQueryParameters2D.create(desde, punto, MASCARA_PARED)
		q.exclude = [emisor.get_rid()]
		if espacio.intersect_ray(q).is_empty():
			return true
	return false