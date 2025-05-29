# track.gd
extends Node3D
class_name Track

signal lap_completed(lap_number: int, lap_time: float)
signal race_finished(final_time: float)

@export_group("Race Settings")
@export var total_laps: int = 3 # Number of laps required to finish the race

# --- Internal State ---
var _current_lap: int = 0
var _lap_times: Array[float] = [] # Stores time for each completed lap
var _race_start_time: float = 0.0
var _is_race_active: bool = false
var _next_checkpoint_index: int = 0

# Ordered list of checkpoint Area3D nodes.
# The order here defines the lap progression. Start/Finish line is the first and last.
@onready var _checkpoints: Array[Area3D] = [
	$StartFinishLine,
	$Checkpoint1
	# Add more checkpoints here if you extend your track
]

func _ready() -> void:
	# Ensure all checkpoints have their body_entered signal connected to this script
	# This is a robust way to ensure connections even if you forget in the editor.
	for i in range(_checkpoints.size()):
		var checkpoint: Area3D = _checkpoints[i]
		if not checkpoint.is_connected("body_entered", Callable(self, "_on_checkpoint_body_entered")):
			checkpoint.body_entered.connect(_on_checkpoint_body_entered.bind(i))
	
	_reset_race_state()

func _reset_race_state() -> void:
	_current_lap = 0
	_lap_times.clear()
	_race_start_time = 0.0
	_is_race_active = false
	_next_checkpoint_index = 0
	_set_checkpoint_visibility(_next_checkpoint_index, true)

func start_race() -> void:
	if not _is_race_active:
		_race_start_time = Time.get_ticks_msec() / 1000.0
		_is_race_active = true
		print("Race started!")
		# Optionally hide other checkpoints until they are the "next" one.
		for i in range(1, _checkpoints.size()):
			_set_checkpoint_visibility(i, false)

func get_current_lap() -> int:
	return _current_lap

func get_race_time() -> float:
	if _is_race_active:
		return (Time.get_ticks_msec() / 1000.0) - _race_start_time
	elif not _lap_times.is_empty():
		return _lap_times.back() # Last lap time + previous lap times if race ended
	return 0.0

func _on_checkpoint_body_entered(body: Node3D, checkpoint_id: int) -> void:
	if not _is_race_active: return
	if not (body is CharacterBody3D and body.name == "PlayerCar"): return # Ensure it's our player

	# Check if the player hit the correct checkpoint in sequence
	if checkpoint_id == _next_checkpoint_index:
		print("Passed checkpoint %d" % checkpoint_id)
		# Hide current checkpoint and show next (if any)
		_set_checkpoint_visibility(_next_checkpoint_index, false)
		
		_next_checkpoint_index = (checkpoint_id + 1) % _checkpoints.size()
		
		_set_checkpoint_visibility(_next_checkpoint_index, true)

		# If we hit the Start/Finish line AND we've hit all previous checkpoints in the sequence
		# (meaning we've completed a full lap circuit, not just the start/finish for the first time)
		if checkpoint_id == 0 and _current_lap > 0: # Only count lap if it's not the initial pass of S/F
			_complete_lap()
		elif checkpoint_id == 0 and _current_lap == 0:
			# This is the initial pass of the Start/Finish line
			_current_lap = 1 # Start counting from lap 1
			print("Starting Lap %d" % _current_lap)


func _complete_lap() -> void:
	if not _is_race_active: return

	var current_race_time: float = get_race_time()
	var last_lap_time: float = 0.0
	if not _lap_times.is_empty():
		last_lap_time = current_race_time - _lap_times.back()
	else:
		last_lap_time = current_race_time # First lap time is current race time

	_lap_times.append(current_race_time)
	_current_lap += 1 # Increment lap count for the NEXT lap
	
	print("Lap %d completed! Lap Time: %.2f, Total Time: %.2f" % [_current_lap -1, last_lap_time, current_race_time])
	
	# Emit signal for HUD
	lap_completed.emit(_current_lap - 1, last_lap_time) # Emit the lap just completed

	if (_current_lap - 1) >= total_laps: # Check if completed laps meets total_laps
		_is_race_active = false
		race_finished.emit(current_race_time)
		print("Race Finished! Total Time: %.2f" % current_race_time)
		# Optionally, hide all checkpoints after race ends
		for checkpoint in _checkpoints:
			_set_checkpoint_visibility(_checkpoints.find(checkpoint), false)
	else:
		print("Starting Lap %d" % _current_lap)

func _set_checkpoint_visibility(index: int, visible: bool) -> void:
	if index >= 0 and index < _checkpoints.size():
		var checkpoint_area: Area3D = _checkpoints[index]
		# Find the MeshInstance3D or visual representation within the checkpoint Area3D
		# For this simple prototype, we'll just toggle the Area3D's debug visibility
		# or assume a visual child like a MeshInstance3D.
		# If you added a MeshInstance3D as a child to the Area3D for visualization,
		# you would access it like: checkpoint_area.get_node("CheckpointVisualMesh").visible = visible
		
		# For now, we'll just print or rely on the debug draw for areas
		# If you want a visual indicator, add a MeshInstance3D child to each Area3D
		# and toggle its visibility here.
		for child in checkpoint_area.get_children():
			if child is MeshInstance3D: # Assuming you add a visual mesh to checkpoints
				child.visible = visible
		
		# A more robust way to visualize for the team during development:
		# You can change the material/color of the collision shape itself,
		# but it requires accessing its debug properties which is more complex.
		# For production, you'd have a dedicated visual child.
