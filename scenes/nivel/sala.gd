class_name Sala
extends Node2D
## Controlador de una sala. Cuenta sus enemigos y abre TODAS sus puertas
## cuando no queda ninguno vivo. El generador lo configura explícitamente
## (no depende de grupos ni de `_ready`), así funciona también en tests que
## no añaden el nivel al árbol.

signal sala_limpiada

var _restantes := 0
var _puertas: Array = []
var _abierta := false


## `enemigos` = enemigos de la sala; `puertas` = puertas cuyo dueño es esta
## sala (las que dan acceso a las salas vecinas).
func configurar(enemigos: Array, puertas: Array) -> void:
	_puertas = puertas
	for e in enemigos:
		if e.esta_muerto:
			continue
		_restantes += 1
		e.murio.connect(_al_morir)
	if _restantes == 0:
		_abrir()


func abierta() -> bool:
	return _abierta


func enemigos_restantes() -> int:
	return _restantes


func _al_morir() -> void:
	_restantes -= 1
	if _restantes <= 0:
		_abrir()


func _abrir() -> void:
	if _abierta:
		return
	_abierta = true
	for p in _puertas:
		if is_instance_valid(p):
			p.abrir()
	sala_limpiada.emit()
