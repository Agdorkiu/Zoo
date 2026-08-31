extends Node
## MapManager — controlador global de la vista de mapa activa en EX-2986.
##
## Registrar como Autoload (singleton) con el nombre "MapManager".
## El juego tiene dos "mapas" alternables desde el HUD:
##   - ZOO:    la reserva donde se construye y se gestiona la actividad
##             principal.
##   - PLANET: la vista de planeta completo, usada para investigación y
##             exploración (de momento sin regiones; se añadirán después).
##
## Este nodo no sabe nada de escenas ni de cámaras: solo guarda cuál de
## las dos vistas está activa y avisa mediante señal. Cualquier sistema
## interesado (el conmutador de escenas del mundo, el botón del HUD, etc.)
## se suscribe a `map_changed` en vez de mantener su propio estado.

signal map_changed(new_map: int)

enum MapView { ZOO, PLANET }

var current_map: int = MapView.ZOO


func toggle_map() -> void:
	set_map(MapView.PLANET if current_map == MapView.ZOO else MapView.ZOO)


func set_map(value: int) -> void:
	if current_map == value:
		return
	current_map = value
	map_changed.emit(current_map)


func is_zoo() -> bool:
	return current_map == MapView.ZOO


func is_planet() -> bool:
	return current_map == MapView.PLANET
