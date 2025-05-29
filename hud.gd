# hud.gd
extends CanvasLayer

# --- Node References ---
@onready var _speed_label_value: Label = $VBoxContainer/SpeedDisplay/SpeedLabelValue
@onready var _lap_label_value: Label = $VBoxContainer/LapDisplay/LapLabelValue
@onready var _time_label_value: Label = $VBoxContainer/TimeDisplay/TimeLabelValue
@onready var _fps_label_value: Label = $VBoxContainer/FPSText/FPSLabelValue
@onready var _race_state_label: Label = $VBoxContainer/RaceStateLabel

# --- Internal State ---
var _current_fps: int = 0
var _display_time: float = 0.0

func _process(delta: float) -> void:
	_update_fps()
	_update_time_display()

func update_speed(speed_kmh: float) -> void:
	_speed_label_value.text = "%.2f km/h" % speed_kmh

func update_lap_counter(current_lap: int, total_laps: int) -> void:
	_lap_label_value.text = "%d/%d" % [current_lap, total_laps]

func update_race_time(time_in_seconds: float) -> void:
	_display_time = time_in_seconds # Store for _update_time_display

func _update_time_display() -> void:
	var minutes: int = int(_display_time / 60.0)
	var seconds: float = fmod(_display_time, 60.0)
	_time_label_value.text = "%02d:%05.2f" % [minutes, seconds]

func _update_fps() -> void:
	_current_fps = Engine.get_frames_per_second()
	_fps_label_value.text = str(_current_fps)

func show_race_state_message(message: String, duration: float = 2.0) -> void:
	_race_state_label.text = message
	var tween: Tween = create_tween()
	tween.tween_property(_race_state_label, "modulate", Color(1, 1, 1, 1), 0.2) # Fade in
	tween.tween_interval(duration)
	tween.tween_property(_race_state_label, "modulate", Color(1, 1, 1, 0), 0.5) # Fade out
	_race_state_label.modulate = Color(1, 1, 1, 0) # Hide initially
