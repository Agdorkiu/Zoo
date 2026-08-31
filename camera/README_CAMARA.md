# Integración de la cámara de mapa (EX-2986)

Cámara de tipo RTS/mapa: movimiento con WASD, rotación con Q/E, zoom con la
rueda, rotación arrastrando con el botón central y paneo arrastrando con el
botón izquierdo.

## 1. Copiar archivos

```
res://camera/camera_rig/CameraRig.gd
res://camera/camera_rig/CameraRig.tscn
```

No requiere Autoload: es una escena normal que se instancia una vez en el
nivel/mapa, no un singleton global (a diferencia de `TimeManager`).

## 2. Añadir a la escena principal

```
Main (Node)
├── CanvasLayer
│   └── TimeHUD.tscn
└── World (Node3D)            <- tu mapa, terreno, EX-2986...
    └── CameraRig.tscn         <- instanciada aquí
```

El `CameraRig` es un `Node3D` normal dentro del mundo 3D. Al estar el HUD en
su propio `CanvasLayer`, separado de este árbol, el zoom/rotación/paneo de la
cámara nunca lo mueve ni lo escala: el HUD queda fijo en pantalla y es el
mapa el que se mueve respecto a la cámara, tal como se pedía.

Coloca `CameraRig` en el punto del mapa donde quieras que arranque la
partida (su posición inicial en el editor es el punto de partida de la
cámara).

## 3. Controles incluidos

| Control | Acción |
| --- | --- |
| `W A S D` | Mover la cámara por el suelo |
| `Q` / `E` | Rotar la cámara (yaw) |
| Rueda del ratón | Acercar / alejar (zoom) |
| Botón central + arrastrar (lateral) | Rotar la cámara |
| Botón izquierdo + arrastrar | Mover la cámara (paneo del mapa) |

Al igual que `TimeManager`, `CameraRig._ready()` registra automáticamente
las acciones de teclado (`camera_move_forward`, `camera_move_back`,
`camera_move_left`, `camera_move_right`, `camera_rotate_left`,
`camera_rotate_right`) si no existen ya en el proyecto. Si prefieres
definirlas tú mismo en Project Settings → Input Map con esos mismos
nombres, `CameraRig` detecta que ya existen y no las sobrescribe.

Los botones del ratón (rueda, central, izquierdo) se gestionan
directamente sobre el evento, sin pasar por el Input Map, porque el
arrastre necesita seguir el movimiento del ratón fotograma a fotograma,
no un simple "pulsado/soltado".

## 4. Por qué el clic izquierdo no rompe una futura selección de objetos

El botón izquierdo sirve para paneo, pero se necesitará también para
seleccionar cosas en el mapa (animales, edificios, etc.) en el futuro.
`CameraRig` distingue clic de arrastre por la distancia recorrida por el
ratón entre pulsar y soltar (`click_vs_drag_threshold_px`, 6 px por
defecto):

- Si el ratón se movió más que el umbral → se consideró arrastre → paneo.
- Si no → se considera un clic → se emite la señal `left_click(screen_position)`.

Cualquier sistema de selección futuro solo necesita suscribirse a esa
señal, igual que otros sistemas se suscriben a las señales de
`TimeManager`, sin duplicar lógica de detección de arrastre:

```gdscript
func _ready() -> void:
    camera_rig.left_click.connect(_on_map_clicked)

func _on_map_clicked(screen_position: Vector2) -> void:
    # Lanzar un raycast desde la cámara hacia el mapa, etc.
    pass
```

## 5. Por qué los clics en el HUD no mueven la cámara

En Godot, los nodos `Control` (botones, paneles del HUD) consumen los
eventos de ratón antes de que lleguen a `_unhandled_input`. Como
`CameraRig` escucha en `_unhandled_input` (no en `_input`), pulsar un
botón del `TimeHUD` (pausa, x1/x2/x4) nunca se interpreta como el inicio
de un paneo o una rotación de cámara. No hace falta ninguna comprobación
extra en el script de la cámara.

## 6. Parámetros ajustables

Todos los valores están expuestos como `@export` en `CameraRig.gd` y son
editables desde el Inspector sin tocar código:

- `move_speed`, `scale_speed_with_zoom` — velocidad de WASD.
- `keyboard_rotate_speed_deg` — velocidad de Q/E.
- `zoom_step`, `min_zoom`, `max_zoom` — límites y paso del zoom.
- `drag_rotate_sensitivity` — sensibilidad de rotación con botón central.
- `drag_pan_sensitivity`, `invert_pan` — sensibilidad y dirección del paneo.
- `click_vs_drag_threshold_px` — umbral para distinguir clic de arrastre.

`scale_speed_with_zoom` hace que tanto el paneo como el WASD se sientan
proporcionales al nivel de zoom: más rápidos/amplios cuando la cámara está
alejada, más precisos cuando está cerca — evita que recorrer un mapa
grande alejado se sienta desesperantemente lento.

## 7. Inclinación de la cámara

La inclinación (pitch) es fija, definida en el nodo `CameraArm` de
`CameraRig.tscn` (`rotation_degrees = (-45, 0, 0)` por defecto). La
`Camera3D` cuelga de `CameraArm` en la posición local `(0, 0, distancia)`
y no tiene rotación propia: al mirar por defecto hacia su -Z local, mira
automáticamente hacia el origen de `CameraArm` (y por tanto hacia
`CameraRig`), sin necesidad de calcular ningún ángulo de "mirar hacia
atrás". El zoom simplemente cambia esa distancia (`Camera3D.position.z`).

No se pidió inclinación libre, así que no se ha implementado; si en el
futuro se quiere un control de inclinación (por ejemplo con el botón
central + arrastre vertical, que ahora mismo se ignora a propósito), se
puede añadir sin tocar el resto del sistema, ajustando `rotation.x` del
`CameraArm` con límites (por ejemplo, entre -20° y -80°) para evitar que
la cámara mire desde debajo del suelo o casi en vertical.
