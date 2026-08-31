extends Control
## HUD de tiempo — panel fijo en pantalla, anclado en la esquina inferior
## izquierda. Solo lee/escribe estado a través de TimeManager (autoload).

@onready var _panel: Control = %PanelContainer
@onready var _phase_label: Label = %PhaseLabel
@onready var _day_label: Label = %DayLabel
@onready var _year_label: Label = %YearLabel
@onready var _pause_button: Button = %PauseButton
@onready var _speed_buttons: Dictionary = {
	1: %Speed1Button,
	2: %Speed2Button,
	4: %Speed4Button,
}
@onready var _map_switch_button: Button = %MapSwitchButton


func _ready() -> void:
	# El HUD debe seguir respondiendo a clics aunque el árbol esté en pausa
	# (por ejemplo, si se integra TimeManager con get_tree().paused).
	process_mode = Node.PROCESS_MODE_ALWAYS

	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.year_changed.connect(_on_year_changed)
	TimeManager.phase_changed.connect(_on_phase_changed)
	TimeManager.speed_changed.connect(_on_speed_changed)
	TimeManager.pause_changed.connect(_on_pause_changed)
	TimeManager.hud_visibility_changed.connect(_on_hud_visibility_changed)
	TimeManager.time_lock_changed.connect(_on_time_lock_changed)
	MapManager.map_changed.connect(_on_map_changed)

	_pause_button.pressed.connect(TimeManager.toggle_pause)
	for speed in _speed_buttons.keys():
		_speed_buttons[speed].pressed.connect(TimeManager.set_speed.bind(speed))
	_map_switch_button.pressed.connect(MapManager.toggle_map)

	_refresh_all()


func _refresh_all() -> void:
	_on_day_changed(TimeManager.day_number)
	_on_year_changed(TimeManager.year_number)
	_on_phase_changed(TimeManager.get_current_phase())
	_on_speed_changed(TimeManager.speed_multiplier)
	_on_pause_changed(TimeManager.is_paused)
	_on_hud_visibility_changed(TimeManager.is_hud_hidden)
	_on_time_lock_changed(TimeManager.is_time_locked)
	_on_map_changed(MapManager.current_map)


func _on_day_changed(new_day: int) -> void:
	_day_label.text = "Día %d / %d" % [new_day, TimeManager.DAYS_PER_YEAR]


func _on_year_changed(new_year: int) -> void:
	_year_label.text = "Año %d" % new_year


func _on_phase_changed(new_phase: int) -> void:
	# Sustituir por icono/sprite si se dispone de arte; de momento, texto.
	_phase_label.text = "Día" if new_phase == TimeManager.Phase.DAY else "Noche"


func _on_speed_changed(new_speed: int) -> void:
	for speed in _speed_buttons.keys():
		var btn: Button = _speed_buttons[speed]
		btn.button_pressed = (speed == new_speed)


func _on_pause_changed(is_paused: bool) -> void:
	_pause_button.text = "Reanudar" if is_paused else "Pausa"


func _on_hud_visibility_changed(is_hidden: bool) -> void:
	_panel.visible = not is_hidden


func _on_map_changed(new_map: int) -> void:
	_map_switch_button.text = "Ir al planeta" if new_map == MapManager.MapView.ZOO else "Volver a la reserva"


func _on_time_lock_changed(is_locked: bool) -> void:
	# En el planeta el tiempo se fuerza a pausa (TimeManager lo hace solo);
	# aquí solo reflejamos ese bloqueo deshabilitando los botones para que
	# el jugador no pueda reanudar ni cambiar de velocidad hasta volver.
	var tooltip: String = "Bloqueado mientras estás en el planeta" if is_locked else ""
	_pause_button.disabled = is_locked
	_pause_button.tooltip_text = tooltip
	for speed in _speed_buttons.keys():
		var btn: Button = _speed_buttons[speed]
		btn.disabled = is_locked
		btn.tooltip_text = tooltip
