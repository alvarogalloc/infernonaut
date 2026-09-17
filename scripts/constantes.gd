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
