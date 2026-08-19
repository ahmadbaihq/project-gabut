extends CharacterBody3D

const SPEED = 3.0
const CHASE_SPEED = 5.0
const DETECTION_RANGE = 15.0
const CHASE_RANGE = 20.0
const KILL_RANGE = 2.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var target = null
var is_chasing = false
var patrol_points = []
var current_patrol_index = 0
var wait_timer = 0.0
var is_waiting = false

@onready var nav_agent = $NavigationAgent3D
@onready var mesh = $MeshInstance3D
@onready var detection_area = $DetectionArea
@onready var timer = $PatrolTimer

func _ready():
	patrol_points = generate_patrol_points()
	timer.wait_time = randf_range(2.0, 5.0)
	timer.start()
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	timer.timeout.connect(_on_patrol_timer_timeout)

func generate_patrol_points():
	var points = []
	for i in range(8):
		var angle = i * TAU / 8
		var radius = randf_range(5.0, 15.0)
		var point = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		points.append(point)
	return points

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	
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
		wait_timer = randf_range(1.0, 3.0)
		return
	
	var next_position = nav_agent.get_next_path_position()
	var move_direction = (next_position - global_position).normalized()
	
	velocity.x = move_direction.x * SPEED
	velocity.z = move_direction.z * SPEED
	
	if move_direction.length() > 0.1:
		look_at(global_position + move_direction, Vector3.UP)

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
			look_at(global_position + move_direction, Vector3.UP)

func start_chase():
	is_chasing = true
	if $ChaseSound.playing == false:
		$ChaseSound.play()

func stop_chase():
	is_chasing = false
	target = null
	$ChaseSound.stop()

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
	timer.wait_time = randf_range(2.0, 5.0)
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
