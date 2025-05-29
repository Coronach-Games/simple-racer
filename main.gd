# main.gd
extends Node3D

enum GameState { COUNTDOWN, RACING, FINISHED }

# --- Tunable Game Parameters ---
@export_group("Game Flow")
@export var countdown_time: float = 3.0 # Duration of the countdown before race starts
@export var game_end_message_duration: float = 5.0 # How long the "Race Finished" message stays

# --- Node References ---
@onready var _player_car: CharacterBody3D = $World/PlayerCar
@onready var _track: Node3D = $World/Track
@onready var _hud: CanvasLayer = $CanvasLayer/HUD

# --- Internal Game State ---
var _current_game_state: GameState = GameState.COUNTDOWN
var _countdown_timer: float = 0.0

func _ready() -> void:
	# Connect signals from PlayerCar to HUD
	if _player_car and _hud:
		_player_car.speed_changed.connect(_hud.update_speed)
	
	# Connect signals from Track to HUD and Main
	if _track and _hud:
		# Explicitly cast to Track to ensure type safety for Track's signals
		var track_script: Track = _track as Track
		track_script.lap_completed.connect(_on_track_lap_completed)
		track_script.race_finished.connect(_on_track_race_finished)
	
	_countdown_timer = countdown_time
	_update_hud_lap_initial()
	_hud.show_race_state_message("Get Ready!", 0.0) # Show message immediately

func _process(delta: float) -> void:
	_handle_game_state(delta)
	
	# Always update HUD for race time, even during countdown
	if _current_game_state == GameState.COUNTDOWN:
		# Show countdown value in place of race time
		_hud.update_race_time(_countdown_timer)
	elif _track:
		_hud.update_race_time((_track as Track).get_race_time())

func _handle_game_state(delta: float) -> void:
	match _current_game_state:
		GameState.COUNTDOWN:
			_countdown_timer -= delta
			if _countdown_timer <= 0:
				_current_game_state = GameState.RACING
				(_track as Track).start_race()
				_hud.show_race_state_message("GO!", 1.0)
				print("Race started!")
			elif _countdown_timer <= 3.0 and _countdown_timer > 2.0:
				_hud.show_race_state_message("3", 0.9)
			elif _countdown_timer <= 2.0 and _countdown_timer > 1.0:
				_hud.show_race_state_message("2", 0.9)
			elif _countdown_timer <= 1.0 and _countdown_timer > 0.0:
				_hud.show_race_state_message("1", 0.9)
		GameState.RACING:
			# Player car logic is in player_car.gd, track logic in track.gd
			# This script just orchestrates
			pass
		GameState.FINISHED:
			# Potentially show results screen or allow restart
			pass

func _update_hud_lap_initial() -> void:
	# Initial update of lap counter
	if _track and _hud:
		var track_script: Track = _track as Track
		_hud.update_lap_counter(track_script.get_current_lap(), track_script.total_laps)

func _on_track_lap_completed(lap_number: int, lap_time: float) -> void:
	# lap_number here is the lap JUST COMPLETED (1-indexed)
	# Track script increments _current_lap for the *next* lap
	if _hud and _track:
		var track_script: Track = _track as Track
		_hud.update_lap_counter(lap_number, track_script.total_laps)
		_hud.show_race_state_message("Lap %d: %.2fs" % [lap_number, lap_time], 1.5)

func _on_track_race_finished(final_time: float) -> void:
	_current_game_state = GameState.FINISHED
	_hud.show_race_state_message("Race Finished! Total Time: %.2fs" % final_time, game_end_message_duration)
	print("Race Finished! Total Time: %.2f" % final_time)
	# You might want to disable player input here
	# For now, we'll just let the player keep moving
	_player_car.set_physics_process(false) # Stop car movement
	_player_car.set_process(false) # Stop speed updates
