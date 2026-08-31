extends Node3D
## PlanetCameraRig — cámara orbital para la vista de planeta de EX-2986.
##
## A diferencia de CameraRig (cámara de mapa/RTS que se desplaza libremente
## por el suelo de la reserva), esta cámara jamás se traslada: vive anclada
## en el centro del planeta y todo lo que hace el jugador es girar alrededor
## de ese punto y acercar/alejar el zoom. El planeta es el eje fijo, nunca
## la cámara. Esto es intencionado de cara a añadir regiones en el futuro:
## cualquier región vivirá pegada a la superficie del planeta y quedará
## automáticamente "en su sitio" sin importar cómo haya orbitado el jugador.
##
## Jerarquía esperada (ver PlanetCameraRig.tscn):
##   PlanetCameraRig (este script, Node3D)  -> colocado en (0,0,0), el centro
##                                              del planeta. No se mueve nunca.
##     └── OrbitPitch (Node3D)               -> inclinación (pitch) de la órbita
##           └── Camera3D                    -> distancia = position.z (zoom)
##
## Igual que en CameraRig, la Camera3D no tiene rotación propia: al estar en
## (0, 0, distancia) dentro de OrbitPitch y mirar por defecto hacia su -Z
## local, mira automáticamente hacia el centro del planeta.
##
## Controles:
##   - Teclado WASD: orbitar alrededor del planeta (A/D = acimut, W/S = altura).
##   - Teclado Q/E: orbitar solo en acimut (yaw), igual que en CameraRig.
##   - Rueda del ratón: acercar / alejar (zoom), sin poder atravesar la superficie.
##   - Botón izquierdo + arrastrar: orbitar libremente (acimut + altura).
##     Es el control preferido; si no se usa, el botón central del ratón
##     hace exactamente lo mismo (por si el izquierdo hace falta en el
##     futuro para seleccionar cosas sobre el planeta, como en CameraRig).
##
## Reutiliza las mismas acciones de entrada que CameraRig
## (camera_move_forward/back/left/right, camera_rotate_left/right) para que
## WASD/Q/E se sientan igual en ambas vistas sin duplicar el Input Map.

signal zoom_changed(new_distance: float)

## --- Planeta -----------------------------------------------------------
## Radio del planeta (debe coincidir con el de su malla/colisión), usado
## para no dejar que el zoom atraviese la superficie.
@export var planet_radius: float = 10.0

## --- Órbita por teclado y arrastre --------------------------------------
@export var orbit_speed_deg: float = 40.0
@export var drag_orbit_sensitivity: float = 0.15
## Límites de inclinación (en grados) para no pasar por encima de los polos
## ni voltear la cámara del revés.
@export var min_pitch_deg: float = -85.0
@export var max_pitch_deg: float = 85.0

## --- Zoom (rueda del ratón) ----------------------------------------------
@export var zoom_step: float = 2.0
## Distancia mínima de la cámara al centro del planeta. Debe ser mayor que
## `planet_radius` para no atravesar la superficie; el margen por defecto
## dependerá de cuánto se quiera poder "acercar" a la superficie.
@export var min_zoom_margin: float = 4.0
@export var max_zoom: float = 60.0

@onready var _pitch_node: Node3D = $OrbitPitch
@onready var _camera: Camera3D = $OrbitPitch/Camera3D

var _is_orbiting: bool = false
## Cuántos de los botones que activan la órbita (izquierdo, central) están
## pulsados a la vez. Se usa en vez de un simple bool por botón para que
## soltar uno no corte la órbita si el otro sigue pulsado.
var _orbit_buttons_down: int = 0


func _ready() -> void:
	# Estas acciones ya las registra CameraRig si la vista del zoo se ha
	# inicializado antes; _ensure_action no las duplica si ya existen.
	_ensure_action("camera_move_forward", [KEY_W])
	_ensure_action("camera_move_back", [KEY_S])
	_ensure_action("camera_move_left", [KEY_A])
	_ensure_action("camera_move_right", [KEY_D])
	_ensure_action("camera_rotate_left", [KEY_Q])
	_ensure_action("camera_rotate_right", [KEY_E])

	var min_zoom: float = planet_radius + min_zoom_margin
	_camera.position.z = clamp(_camera.position.z, min_zoom, max_zoom)


func _process(delta: float) -> void:
	_process_keyboard_orbit(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


# --- Órbita por teclado (WASD orbita, Q/E solo acimut) ----------------------

func _process_keyboard_orbit(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("camera_move_right") - Input.get_action_strength("camera_move_left"),
		Input.get_action_strength("camera_move_back") - Input.get_action_strength("camera_move_forward")
	)
	var rotate_input := Input.get_action_strength("camera_rotate_right") - Input.get_action_strength("camera_rotate_left")

	if input_dir != Vector2.ZERO:
		_orbit(input_dir.x * orbit_speed_deg * delta, -input_dir.y * orbit_speed_deg * delta)

	if rotate_input != 0.0:
		_orbit(rotate_input * orbit_speed_deg * delta, 0.0)


# --- Ratón: botones -------------------------------------------------------

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom(-zoom_step)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom(zoom_step)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
			# Preferido: botón izquierdo. Si no, el central hace lo mismo.
			# Se cuenta cuántos de los dos están pulsados a la vez para no
			# cortar la órbita si se suelta uno mientras el otro sigue
			# pulsado.
			if event.pressed:
				_orbit_buttons_down += 1
			else:
				_orbit_buttons_down = max(_orbit_buttons_down - 1, 0)
			_is_orbiting = _orbit_buttons_down > 0


# --- Ratón: movimiento (arrastre) -----------------------------------------

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _is_orbiting:
		return
	_orbit(
		event.relative.x * drag_orbit_sensitivity,
		event.relative.y * drag_orbit_sensitivity
	)


# --- Órbita alrededor del planeta ------------------------------------------

## Gira la cámara alrededor del centro del planeta. `delta_yaw_deg` mueve la
## cámara "de lado" (acimut); `delta_pitch_deg` la mueve "arriba/abajo"
## (altura sobre la superficie), con los límites de `min_pitch_deg` /
## `max_pitch_deg` para no pasar por encima de los polos.
func _orbit(delta_yaw_deg: float, delta_pitch_deg: float) -> void:
	rotation.y -= deg_to_rad(delta_yaw_deg)

	var new_pitch: float = _pitch_node.rotation.x - deg_to_rad(delta_pitch_deg)
	_pitch_node.rotation.x = clamp(new_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))


# --- Zoom -------------------------------------------------------------------

func _zoom(delta_distance: float) -> void:
	var min_zoom: float = planet_radius + min_zoom_margin
	_camera.position.z = clamp(_camera.position.z + delta_distance, min_zoom, max_zoom)
	zoom_changed.emit(_camera.position.z)


# --- Utilidades internas (mismo patrón que CameraRig/TimeManager) ----------

func _ensure_action(action_name: String, keys: Array) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action_name, ev)
