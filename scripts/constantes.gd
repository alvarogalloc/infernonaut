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

## ---------------------------------------------------------------- Capas Z
## Bandas de dibujo (z_index) de todo lo que vive en el mundo, de atrás a
## delante. Regla: cada tipo de cosa ocupa SU banda — nunca reutilices un
## número de otra banda o un literal suelto, o una entidad ocultará a otra.
## Nota: los -1 sueltos en .tscn (AnimatedSprite del enemigo, DashParticles
## del personaje) son decoración local del MISMO nodo entidad, no bandas.
const Z_TILEMAP := -100 ## suelo, laberinto, paredes (TileMapLayer "blockout")
const Z_DECOR_SUELO := -90 ## marcas en el suelo: telégrafos del cobarde
const Z_PUERTA := -80 ## puertas (sprite pegado a la pared, bajo las entidades)
const Z_ANTORCHA := -10 ## antorchas y objetos de pared: DEBAJO de las entidades
const Z_ENTIDAD := 0 ## jugador, enemigos, pinchos, recompensas, meta
const Z_PROYECTIL := 10 ## proyectiles: que se vean por encima de las entidades
const Z_EFECTO := 20 ## partículas/muerte y feedback sobre todo el mundo
