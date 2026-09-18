extends Node3D
## CameraRig — cámara de mapa/RTS para EX-2986.
##
## Jerarquía esperada (ver CameraRig.tscn):
##   CameraRig (este script, Node3D)         -> posición en el plano del suelo
##     └── CameraPivot (Node3D)               -> rotación Y (yaw)
##           └── CameraArm (Node3D)           -> inclinación fija (pitch)
##                 └── Camera3D                -> distancia = position.z (zoom)
##
## La cámara no tiene rotación propia: al estar colocada en (0, 0, distancia)
## dentro de CameraArm y mirar por defecto hacia su -Z local, mira de forma
## automática hacia el origen de CameraArm (y por tanto hacia CameraRig),
## sin necesidad de calcular ningún ángulo de "mirar hacia atrás".
##
## Controles:
##   - Teclado WASD: mover la cámara por el suelo.
##   - Teclado Q/E: rotar la cámara (yaw).
##   - Rueda del ratón: acercar / alejar (zoom).
##   - Botón central + arrastrar a los lados: rotar la cámara (yaw).
##   - Botón derecho + arrastrar: mover la cámara (paneo del mapa).
##
## Importante: el HUD (TimeHUD, etc.) vive en un CanvasLayer, independiente
## de este árbol 3D, así que nunca se ve afectado por este nodo. Además,
## los Control absorben el clic antes de que llegue a _unhandled_input,
## así que pulsar botones del HUD no mueve ni rota la cámara.

signal zoom_changed(new_distance: float)

## --- Movimiento por teclado ------------------------------------------------
## Velocidad base de desplazamiento (unidades/seg) al zoom de referencia.
@export var move_speed: float = 20.0
## Si es true, la velocidad de movimiento aumenta cuando la cámara está más
## alejada (zoom out), para que recorrer el mapa no se sienta lento.
@export var scale_speed_with_zoom: bool = true

## --- Rotación por teclado ---------------------------------------------------
## Velocidad de rotación con Q/E, en grados/seg.
@export var keyboard_rotate_speed_deg: float = 90.0

## --- Zoom (rueda del ratón) -------------------------------------------------
@export var zoom_step: float = 2.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 60.0

## --- Arrastre con botón central: rotar ---------------------------------
## Radianes de rotación por píxel de arrastre horizontal.
@export var drag_rotate_sensitivity: float = 0.006

## --- Arrastre con botón derecho: mover (paneo) ------------------------------
## Unidades de mundo por píxel de arrastre, al zoom de referencia (min_zoom).
@export var drag_pan_sensitivity: float = 0.02
## Invierte la dirección del paneo si se siente "al revés".
@export var invert_pan: bool = false
## Movimiento máximo (en píxeles) antes de considerar que un clic derecho
## fue en realidad un arrastre. Por debajo de esto, se emite `right_click`
## para que un futuro sistema de selección lo use sin pisar el paneo.
@export var click_vs_drag_threshold_px: float = 6.0

## Emite la posición de pantalla de un clic derecho que NO se convirtió
## en arrastre (para un futuro sistema de selección de objetos del mapa).
signal right_click(screen_position: Vector2)

@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/CameraArm/Camera3D

var _is_panning: bool = false
var _is_rotating: bool = false
var _right_press_position: Vector2 = Vector2.ZERO
var _right_drag_distance: float = 0.0


func _ready() -> void:
	_ensure_action("camera_move_forward", [KEY_W])
	_ensure_action("camera_move_back", [KEY_S])
	_ensure_action("camera_move_left", [KEY_A])
	_ensure_action("camera_move_right", [KEY_D])
	_ensure_action("camera_rotate_left", [KEY_E])
	_ensure_action("camera_rotate_right", [KEY_Q])

	_camera.position.z = clamp(_camera.position.z, min_zoom, max_zoom)


func _process(delta: float) -> void:
	_process_keyboard_movement(delta)
	_process_keyboard_rotation(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


# --- Movimiento por teclado (WASD) ------------------------------------------

func _process_keyboard_movement(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("camera_move_right") - Input.get_action_strength("camera_move_left"),
		Input.get_action_strength("camera_move_back") - Input.get_action_strength("camera_move_forward")
	)
	if input_dir == Vector2.ZERO:
		return

	input_dir = input_dir.normalized()

	var speed := move_speed
	if scale_speed_with_zoom:
		speed *= _zoom_speed_factor()

	# Movimiento relativo a hacia dónde mira el pivote (yaw), proyectado
	# sobre el plano del suelo (ignora la inclinación de la cámara).
	var forward := -_pivot.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := _pivot.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var motion := (right * input_dir.x + forward * -input_dir.y) * speed * delta
	global_position += motion


# --- Rotación por teclado (Q/E) ---------------------------------------------

func _process_keyboard_rotation(delta: float) -> void:
	var rotate_input := Input.get_action_strength("camera_rotate_right") - Input.get_action_strength("camera_rotate_left")
	if rotate_input == 0.0:
		return
	_pivot.rotation.y -= rotate_input * deg_to_rad(keyboard_rotate_speed_deg) * delta


# --- Ratón: botones -----------------------------------------------------

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom(-zoom_step)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom(zoom_step)
		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_is_panning = true
				_right_press_position = event.position
				_right_drag_distance = 0.0
			else:
				_is_panning = false
				if _right_drag_distance <= click_vs_drag_threshold_px:
					right_click.emit(_right_press_position)
		MOUSE_BUTTON_MIDDLE:
			_is_rotating = event.pressed


# --- Ratón: movimiento (arrastre) -------------------------------------------

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_panning:
		_right_drag_distance += event.relative.length()
		_pan(event.relative)
	if _is_rotating:
		# Solo el componente horizontal del arrastre rota la cámara, tal
		# como pide el diseño ("moviendo a los laterales").
		_pivot.rotation.y -= event.relative.x * drag_rotate_sensitivity


func _pan(relative: Vector2) -> void:
	var sign_factor := -1.0 if invert_pan else 1.0
	var scale_factor := drag_pan_sensitivity * _zoom_speed_factor() * sign_factor

	var forward := -_pivot.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := _pivot.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	# Arrastrar hacia la derecha/abajo mueve el mapa hacia la derecha/abajo
	# (la cámara se mueve en sentido contrario, como si "agarraras" el suelo).
	var motion := (-right * relative.x - forward * -relative.y) * scale_factor
	global_position += motion


# --- Zoom ------------------------------------------------------------------

func _zoom(delta_distance: float) -> void:
	_camera.position.z = clamp(_camera.position.z + delta_distance, min_zoom, max_zoom)
	zoom_changed.emit(_camera.position.z)


## Factor de escala usado para que el paneo y el movimiento por teclado
## se sientan proporcionales al nivel de zoom actual (más rápido/amplio
## cuando la cámara está más alejada).
func _zoom_speed_factor() -> float:
	return _camera.position.z / min_zoom


# --- Utilidades internas (mismo patrón que TimeManager) ---------------------

func _ensure_action(action_name: String, keys: Array) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action_name, ev)
