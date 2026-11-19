## Constantes compartidas del juego.
## No necesita ser Autoload: al tener "class_name" ya es accesible
## desde cualquier script escribiendo Constantes.LO_QUE_SEA
class_name Constantes
extends RefCounted

## Color que se aplica cuando algo (jugador o enemigo) muere
const COLOR_MUERTE := Color(18.892, 0.0, 0.0, 1.0)

## Tiempo que se espera mostrando el color de muerte antes de
## avisar (señal) o destruir al personaje/enemigo
const TIEMPO_FADE_MUERTE := 0.5

## Grupos usados para identificar nodos por tipo
const GRUPO_PERSONAJES := "personajes"
const GRUPO_ATAQUE_PERSONAJE := "ataque_personaje"
const GRUPO_ENEMIGOS := "enemigos"
const GRUPO_PUERTAS := "puertas"
const GRUPO_SALAS := "salas"

## Margen interior de una sala (px): mantiene a los enemigos fuera del marco
## de paredes y del hueco de las puertas.
const MARGEN_SALA := 60.0


## Sala (Node2D en GRUPO_SALAS) a la que pertenece `nodo`, o null si no está
## dentro de una sala.
static func sala_de(nodo: Node) -> Node2D:
	var n := nodo
	while n != null:
		if n.is_in_group(GRUPO_SALAS):
			return n as Node2D
		n = n.get_parent()
	return null


## true si `nodo` está en la sala que la cámara considera actual. Fuera de una
## sala (tests, escenas sueltas) devuelve true para no bloquear nada.
static func en_sala_actual(nodo: Node) -> bool:
	var sala := sala_de(nodo)
	var cam := _camara()
	if sala == null or cam == null:
		return true
	return cam.call("sala_actual") == sala


## Rect interior de la sala de `nodo` (sin el marco de paredes). Vacío si no
## hay sala o cámara.
static func rect_interior(nodo: Node) -> Rect2:
	var sala := sala_de(nodo)
	var cam := _camara()
	if sala == null or cam == null:
		return Rect2()
	var r: Rect2 = cam.call("sala_rect", sala)
	return r.grow(-MARGEN_SALA)


## Mantiene a un cuerpo dentro del interior de su sala: nunca se queda en el
## hueco de una puerta. Devuelve true si lo movió.
static func limitar_a_sala(cuerpo: CharacterBody2D) -> bool:
	var r := rect_interior(cuerpo)
	if r.size == Vector2.ZERO:
		return false
	var p := cuerpo.global_position.clamp(r.position, r.end)
	if p == cuerpo.global_position:
		return false
	cuerpo.global_position = p
	cuerpo.velocity = Vector2.ZERO
	return true


static func _camara() -> Camera2D:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).get_first_node_in_group("camara_jugador") as Camera2D
	return null


## ---------------------------------------------------------------- Capas Z
## Bandas de dibujo (z_index) de todo lo que vive en el mundo, de atrás a
## delante. Regla: cada tipo de cosa ocupa SU banda — nunca reutilices un
## número de otra banda o un literal suelto, o una entidad ocultará a otra.
## Nota: los -1 sueltos en .tscn (AnimatedSprite del enemigo, DashParticles
## del personaje) son decoración local del MISMO nodo entidad, no bandas.
const Z_TILEMAP := -100 ## suelo y paredes (TileMapLayer "blockout")
const Z_DECOR_SUELO := -90 ## marcas en el suelo: telégrafos del cobarde
const Z_PUERTA := -80 ## puertas (sprite pegado a la pared, bajo las entidades)
const Z_ANTORCHA := -10 ## antorchas y objetos de pared: DEBAJO de las entidades
const Z_ENTIDAD := 0 ## jugador, enemigos, pinchos, recompensas, meta
const Z_PROYECTIL := 10 ## proyectiles: que se vean por encima de las entidades
const Z_EFECTO := 20 ## partículas/muerte y feedback sobre todo el mundo
