extends Button
## Control de visibilidad del HUD de tiempo.
##
## Este botón NO va en el HUD (panel siempre visible durante la partida).
## Va en el menú de pausa y/o en el menú principal, es decir, en pantallas
## que solo existen cuando TimeManager.is_paused == true o cuando la
## partida no está en curso.
##
## TimeManager ya impone la regla de que el HUD no puede ocultarse fuera
## de la pausa (ver TimeManager.set_hud_hidden). Si este botón se coloca en
## el menú principal, recuerda llamar a TimeManager.set_paused(true) al
## volver a ese menú para que la misma regla siga siendo válida ahí.

func _ready() -> void:
	TimeManager.hud_visibility_changed.connect(_on_hud_visibility_changed)
	pressed.connect(TimeManager.toggle_hud_hidden)
	_on_hud_visibility_changed(TimeManager.is_hud_hidden)


func _on_hud_visibility_changed(is_hidden: bool) -> void:
	text = "Mostrar HUD de tiempo" if is_hidden else "Ocultar HUD de tiempo"
