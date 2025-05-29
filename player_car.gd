# player_car.gd
@tool # This allows the export variables to be adjusted in the editor even when the game isn't running.
extends CharacterBody3D

signal speed_changed(new_speed: float)
signal lap_completed(lap_number: int, lap_time: float)
signal checkpoint_passed(checkpoint_id: int)

# --- Tunable Racing Parameters ---
@export_group("Movement")
@export var acceleration_force: float = 100.0 # How quickly the car speeds up
@export var max_speed_forward: float = 80.0   # Max forward speed in units/sec
@export var max_speed_reverse: float = 30.0   # Max reverse speed
@export var braking_force: float = 200.0      # How quickly the car slows down when braking
@export var friction: float = 50.0            # How quickly the car slows down when not accelerating/braking
@export var turn_speed: float = 1.5           # How quickly the car turns (radians/sec)
@export var turn_speed_at_max_speed_ratio: float = 0.5 # How much turn speed is reduced at max speed (0.0 - 1.0)
@export var min_turn_speed_threshold: float = 0.1 # Minimum absolute speed for turning to apply (e.g., in units/sec)

@export_group("Camera")
@export var camera_distance: float = 10.0  # How far behind the car the camera is
@export var camera_height: float = 5.0     # How high above the car the camera is
@export var camera_look_down_angle: float = 15.0 # Degrees the camera looks down

# --- Internal State Variables ---
var current_speed: float = 0.0
var target_rotation_y: float = 0.0 # Used for smooth turning

# --- Node References ---
@onready var _body_mesh: MeshInstance3D = $Body
@onready var _camera_arm: SpringArm3D = $CameraArm

func _ready() -> void:
	# Apply camera settings from export variables
	_camera_arm.spring_length = camera_distance
	_camera_arm.position.y = camera_height
	_camera_arm.rotation_degrees.x = -camera_look_down_angle # Negative for looking down

func _physics_process(delta: float) -> void:
	_handle_input(delta)
	_apply_movement(delta)
	_update_visuals(delta)
	_emit_speed()

func _handle_input(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var steer_input: float = input_vector.x # -1 for left, 1 for right
	var accelerate_input: float = input_vector.y # -1 for forward, 1 for backward

	# Calculate desired speed based on input
	var desired_speed: float = 0.0
	if accelerate_input > 0:
		desired_speed = max_speed_reverse
	elif accelerate_input < 0:
		desired_speed = -max_speed_forward

	# Apply acceleration / deceleration
	if accelerate_input != 0:
		current_speed = move_toward(current_speed, desired_speed, acceleration_force * delta)
	else:
		# Apply friction when no acceleration input
		current_speed = move_toward(current_speed, 0.0, friction * delta)

	# Apply braking force if 'brake' action is pressed
	if Input.is_action_pressed("brake"):
		current_speed = move_toward(current_speed, 0.0, braking_force * delta)

	var effective_turn_speed_multiplier: float = 0.0

	# Only allow turning if the absolute speed is above a threshold
	if abs(current_speed) > min_turn_speed_threshold:
		# Normalize current speed relative to max_speed_forward
		# This will be 0 when speed is 0, and 1 when speed is max_speed_forward
		var normalized_speed_ratio: float = abs(current_speed) / max_speed_forward
		normalized_speed_ratio = clampf(normalized_speed_ratio, 0.0, 1.0)

		# Apply the base turn speed scaled by how fast we're moving
		effective_turn_speed_multiplier = normalized_speed_ratio

		# Apply the high-speed reduction factor (as speed increases, turn speed might decrease)
		# This is based on the original 'turn_speed_at_max_speed_ratio'
		effective_turn_speed_multiplier *= (1.0 - (turn_speed_at_max_speed_ratio * normalized_speed_ratio))

	# As speed increases, turn speed decreases, but not below a certain ratio
	var effective_turn_speed: float = turn_speed * effective_turn_speed_multiplier

	var adjusted_steer_input: float = steer_input
	if current_speed > 0: # If the car is currently moving in reverse
		adjusted_steer_input *= -1.0 # Invert the steering input

	# Apply steering only if there's significant turn_input and the car can turn
	# Use the 'adjusted_steer_input' here
	if adjusted_steer_input != 0 and effective_turn_speed > 0.001:
		target_rotation_y -= adjusted_steer_input * effective_turn_speed * delta

	rotation.y = lerp_angle(rotation.y, target_rotation_y, 10.0 * delta)

func _apply_movement(delta: float) -> void:
	# Calculate forward direction based on current rotation
	var forward_direction: Vector3 = transform.basis.z

	# Apply speed to velocity
	# Note: CharacterBody3D's `velocity` is in global coordinates.
	# The `move_and_slide()` function handles collisions and movement.
	velocity = forward_direction * current_speed

	move_and_slide()

func _update_visuals(delta: float) -> void:
	# Simple visual feedback: tilt car slightly when turning
	var steer_input: float = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").x
	var tilt_angle: float = -steer_input * deg_to_rad(5.0) # Max 5 degrees tilt
	_body_mesh.rotation.z = lerpf(_body_mesh.rotation.z, tilt_angle, 5.0 * delta)

func _emit_speed() -> void:
	# Emit speed in a more readable unit (e.g., km/h or mph)
	# Assuming 1 Godot unit = 1 meter, then m/s * 3.6 = km/h
	# or m/s * 2.23694 = mph
	var speed_kmh: float = current_speed * 3.6
	speed_changed.emit(abs(speed_kmh)) # Emit absolute speed
