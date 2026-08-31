extends Node
## TimeManager — controlador global de tiempo de EX-2986.
##
## Registrar como Autoload (singleton) con el nombre "TimeManager".
## Ningún otro sistema debe mantener su propio reloj: todos se suscriben
## a las señales de este nodo o consultan sus propiedades públicas.

signal speed_changed(new_speed: int)
signal pause_changed(is_paused: bool)
signal phase_changed(new_phase: int) # ver enum Phase
signal day_changed(new_day: int)
signal year_changed(new_year: int)
signal hud_visibility_changed(is_hidden: bool)
signal time_lock_changed(is_locked: bool)

enum Phase { DAY, NIGHT }

## Duración real, en segundos, de 1 día de juego a velocidad x1.
const GAME_DAY_LENGTH_SEC: float = 10.0
## Fracción del día que corresponde a la fase de luz diurna (60 %).
const DAY_PHASE_RATIO: float = 0.6
## Días por año, heredado del marco físico del planeta.
const DAYS_PER_YEAR: int = 287
## Escalones de velocidad disponibles, en orden.
const SPEED_STEPS: Array[int] = [1, 2, 4]

var speed_multiplier: int = 1
var is_paused: bool = false
var is_hud_hidden: bool = false
## true mientras la vista de planeta está activa: el tiempo queda forzado
## a pausa y el jugador no puede cambiar velocidad ni reanudar hasta volver
## al zoo. Ver _on_map_changed.
var is_time_locked: bool = false

## Segundos transcurridos dentro del día actual (0 .. GAME_DAY_LENGTH_SEC).
var current_day_time: float = 0.0
var day_number: int = 1
var year_number: int = 1

var _current_phase: int = Phase.DAY


func _ready() -> void:
	# Este nodo sigue procesando aunque el árbol esté en pausa (get_tree().paused),
	# para poder seguir escuchando "reanudar" si se integra con la pausa del motor.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_action("time_speed_up", [KEY_EQUAL, KEY_KP_ADD])
	_ensure_action("time_speed_down", [KEY_MINUS, KEY_KP_SUBTRACT])
	_ensure_action("time_pause_toggle", [KEY_SPACE])
	MapManager.map_changed.connect(_on_map_changed)


func _process(delta: float) -> void:
	if is_paused:
		return

	current_day_time += delta * float(speed_multiplier)

	if current_day_time >= GAME_DAY_LENGTH_SEC:
		current_day_time -= GAME_DAY_LENGTH_SEC
		_advance_day()

	_update_phase()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("time_speed_up"):
		increase_speed()
	elif event.is_action_pressed("time_speed_down"):
		decrease_speed()
	elif event.is_action_pressed("time_pause_toggle"):
		toggle_pause()


# --- Calendario -------------------------------------------------------

func _advance_day() -> void:
	day_number += 1
	day_changed.emit(day_number)

	if day_number > DAYS_PER_YEAR:
		day_number = 1
		year_number += 1
		year_changed.emit(year_number)


func _update_phase() -> void:
	var threshold: float = GAME_DAY_LENGTH_SEC * DAY_PHASE_RATIO
	var new_phase: int = Phase.DAY if current_day_time < threshold else Phase.NIGHT
	if new_phase != _current_phase:
		_current_phase = new_phase
		phase_changed.emit(_current_phase)


## Progreso dentro del día actual, de 0.0 a 1.0. Útil para interpolar
## iluminación, cielo, etc. sin depender de la fase discreta.
func get_day_progress() -> float:
	return current_day_time / GAME_DAY_LENGTH_SEC


func get_current_phase() -> int:
	return _current_phase


# --- Bloqueo de tiempo al entrar al planeta --------------------------------

## Al entrar a la vista de planeta, el tiempo se fuerza a pausa y queda
## bloqueado: el jugador no puede reanudarlo ni cambiar de velocidad hasta
## volver al zoo. Esto se resuelve aquí (no en el HUD) porque TimeManager es
## el único dueño del estado de pausa/velocidad; el HUD solo refleja
## `is_time_locked` deshabilitando sus botones.
func _on_map_changed(new_map: int) -> void:
	if new_map == MapManager.MapView.PLANET:
		_force_pause(true)
		is_time_locked = true
	else:
		is_time_locked = false
	time_lock_changed.emit(is_time_locked)


## Igual que set_paused, pero sin pasar por el bloqueo: es lo único que
## puede pausar el tiempo mientras is_time_locked es true (el propio
## sistema que impone el bloqueo).
func _force_pause(value: bool) -> void:
	if is_paused == value:
		return
	is_paused = value
	pause_changed.emit(is_paused)
	if not is_paused and is_hud_hidden:
		set_hud_hidden(false)


# --- Velocidad ----------------------------------------------------------

func increase_speed() -> void:
	var idx: int = SPEED_STEPS.find(speed_multiplier)
	if idx < SPEED_STEPS.size() - 1:
		set_speed(SPEED_STEPS[idx + 1])


func decrease_speed() -> void:
	var idx: int = SPEED_STEPS.find(speed_multiplier)
	if idx > 0:
		set_speed(SPEED_STEPS[idx - 1])


func set_speed(value: int) -> void:
	if is_time_locked:
		return
	if not SPEED_STEPS.has(value):
		push_warning("TimeManager: velocidad no válida (%d). Usa 1, 2 o 4." % value)
		return
	if speed_multiplier != value:
		speed_multiplier = value
		speed_changed.emit(speed_multiplier)


# --- Pausa ----------------------------------------------------------------

func toggle_pause() -> void:
	set_paused(not is_paused)


func set_paused(value: bool) -> void:
	if is_time_locked:
		return
	if is_paused == value:
		return
	is_paused = value
	pause_changed.emit(is_paused)

	# Regla de diseño: el HUD no puede quedar oculto fuera de la pausa.
	if not is_paused and is_hud_hidden:
		set_hud_hidden(false)


# --- Visibilidad del HUD ---------------------------------------------------

func set_hud_hidden(value: bool) -> void:
	if value and not is_paused:
		return # Solo se puede ocultar en pausa (o al salir del juego).
	if is_hud_hidden != value:
		is_hud_hidden = value
		hud_visibility_changed.emit(is_hud_hidden)


func toggle_hud_hidden() -> void:
	set_hud_hidden(not is_hud_hidden)


# --- Utilidades internas ----------------------------------------------

func _ensure_action(action_name: String, keys: Array) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action_name, ev)
