extends Node3D
## MapViewSwitcher — activa la vista de zoo o la de planeta según MapManager.
##
## Se coloca en el nodo raíz del mundo, que debe tener dos hijos directos:
## "ZooView" y "PlanetView", cada uno con su propia cámara (CameraRig y
## PlanetCameraRig respectivamente). Este script no decide cuándo cambiar de
## mapa (eso lo hace el botón del HUD llamando a MapManager.toggle_map): solo
## reacciona a la señal `map_changed` y deja el mundo 3D en el estado correcto.
##
## Al cambiar de vista se hacen tres cosas a la vez:
##   1. Se oculta la vista inactiva y se muestra la activa.
##   2. Se pone PROCESS_MODE_DISABLED en la vista inactiva, para que su
##      cámara (WASD, arrastre, rueda del ratón...) deje de procesar
##      entrada. Sin esto, las dos cámaras responderían a la vez a los
##      mismos controles.
##   3. Se marca como `current` la Camera3D de la vista activa, para que el
##      motor sepa por cuál renderizar.

@onready var _zoo_view: Node3D = $ZooView
@onready var _zoo_camera: Camera3D = $ZooView/CameraRig/CameraPivot/CameraArm/Camera3D


func _ready() -> void:
	MapManager.map_changed.connect(_on_map_changed)
	_on_map_changed(MapManager.current_map)


func _on_map_changed(new_map: int) -> void:
	var is_zoo: bool = new_map == MapManager.MapView.ZOO

	_zoo_view.visible = is_zoo

	_zoo_view.process_mode = Node.PROCESS_MODE_INHERIT if is_zoo else Node.PROCESS_MODE_DISABLED

	_zoo_camera.current = is_zoo
