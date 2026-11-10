class_name Progreso
extends RefCounted
## Progreso persistente mínimo: solo si el tutorial se completó alguna vez.

const RUTA := "user://progreso.cfg"


static func tutorial_completado() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(RUTA) == OK and bool(cfg.get_value("tutorial", "completado", false))


static func marcar_tutorial_completado() -> void:
	var cfg := ConfigFile.new()
	cfg.load(RUTA)
	cfg.set_value("tutorial", "completado", true)
	cfg.save(RUTA)
