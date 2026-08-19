extends CharacterBody3D

const SPEED = 3.0
const CHASE_SPEED = 5.5
const DETECTION_RANGE = 15.0
const CHASE_RANGE = 22.0
const KILL_RANGE = 2.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var target = null
var is_chasing = false
var patrol_points = []
var current_patrol_index = 0
var wait_timer = 0.0
var is_waiting = false
var anim_time = 0.0
var idle_breathe = 0.0

@onready var nav_agent = $NavigationAgent3D
@onready var body_mesh = $BodyMesh
@onready var left_eye = $Eyes/LeftEye
@onready var right_eye = $Eyes/RightEye
@onready var eye_light_l = $Eyes/LeftEye/LeftEyeLight
@onready var eye_light_r = $Eyes/RightEye/RightEyeLight
@onready var detection_area = $DetectionArea
@onready var timer = $PatrolTimer
@onready var chase_sound = $ChaseSound
@onready var idle_sound = $IdleSound
@onready var step_sound = $StepSound

func _ready():
	patrol_points = generate_patrol_points()
	timer.wait_time = randf_range(3.0, 6.0)
	timer.start()
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	timer.timeout.connect(_on_patrol_timer_timeout)
	if idle_sound:
		idle_sound.play()

func generate_patrol_points():
	var points = []
	for i in range(6):
		var angle = i * TAU / 6
		var radius = randf_range(4.0, 12.0)
		var point = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		points.append(point)
	return points

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	anim_time += delta
	idle_breathe += delta * 2.0

	animate_body(delta)

	if target and is_chasing:
		chase_target()
	elif target and not is_chasing:
		if global_position.distance_to(target.global_position) < DETECTION_RANGE:
			start_chase()
		else:
			patrol(delta)
	else:
		patrol(delta)

	move_and_slide()

func animate_body(delta):
	if body_mesh == null:
		return

	if is_chasing:
		body_mesh.position.y = sin(anim_time * 12.0) * 0.15 + 0.9
		body_mesh.rotation.z = sin(anim_time * 8.0) * 0.15
		eye_light_l.light_energy = 2.0 + sin(anim_time * 10.0) * 0.5
		eye_light_r.light_energy = 2.0 + sin(anim_time * 10.0) * 0.5
	elif not is_waiting:
		body_mesh.position.y = sin(anim_time * 4.0) * 0.08 + 0.9
		body_mesh.rotation.z = sin(anim_time * 3.0) * 0.05
		eye_light_l.light_energy = 1.5
		eye_light_r.light_energy = 1.5
	else:
		body_mesh.position.y = sin(idle_breathe) * 0.05 + 0.9
		body_mesh.rotation.z = 0.0
		eye_light_l.light_energy = 1.0 + sin(idle_breathe * 0.5) * 0.3
		eye_light_r.light_energy = 1.0 + sin(idle_breathe * 0.5) * 0.3

	if left_eye and right_eye:
		left_eye.material_override.albedo_color = Color(1.0, 0.1, 0.05, 1.0)
		right_eye.material_override.albedo_color = Color(1.0, 0.1, 0.05, 1.0)
		left_eye.material_override.emission_enabled = true
		left_eye.material_override.emission = Color(1.0, 0.0, 0.0)
		left_eye.material_override.emission_energy_multiplier = 3.0
		right_eye.material_override.emission_enabled = true
		right_eye.material_override.emission = Color(1.0, 0.0, 0.0)
		right_eye.material_override.emission_energy_multiplier = 3.0

func patrol(delta):
	if is_waiting:
		wait_timer -= delta
		velocity.x = move_toward(velocity.x, 0, 0.1)
		velocity.z = move_toward(velocity.z, 0, 0.1)
		if wait_timer <= 0:
			is_waiting = false
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		return

	if patrol_points.is_empty():
		return

	var target_point = patrol_points[current_patrol_index]
	nav_agent.target_position = target_point

	if nav_agent.is_navigation_finished():
		is_waiting = true
		wait_timer = randf_range(1.5, 4.0)
		return

	var next_position = nav_agent.get_next_path_position()
	var move_direction = (next_position - global_position).normalized()

	velocity.x = move_direction.x * SPEED
	velocity.z = move_direction.z * SPEED

	if move_direction.length() > 0.1:
		var target_angle = atan2(move_direction.x, move_direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 0.1)

func chase_target():
	if not target:
		return

	var distance = global_position.distance_to(target.global_position)

	if distance > CHASE_RANGE:
		stop_chase()
		return

	if distance < KILL_RANGE:
		kill_player()
		return

	nav_agent.target_position = target.global_position

	if not nav_agent.is_navigation_finished():
		var next_position = nav_agent.get_next_path_position()
		var move_direction = (next_position - global_position).normalized()

		velocity.x = move_direction.x * CHASE_SPEED
		velocity.z = move_direction.z * CHASE_SPEED

		if move_direction.length() > 0.1:
			var target_angle = atan2(move_direction.x, move_direction.z)
			rotation.y = lerp_angle(rotation.y, target_angle, 0.15)

func start_chase():
	if is_chasing:
		return
	is_chasing = true
	if idle_sound and idle_sound.playing:
		idle_sound.stop()
	if chase_sound and not chase_sound.playing:
		chase_sound.play()

func stop_chase():
	is_chasing = false
	target = null
	if chase_sound and chase_sound.playing:
		chase_sound.stop()
	if idle_sound and not idle_sound.playing:
		idle_sound.play()

func kill_player():
	if target and target.has_method("game_over"):
		target.game_over()
	stop_chase()

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		target = body
		start_chase()

func _on_detection_area_body_exited(body):
	if body == target:
		stop_chase()

func _on_patrol_timer_timeout():
	timer.wait_time = randf_range(3.0, 6.0)
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
