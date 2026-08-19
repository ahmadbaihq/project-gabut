extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_speed = SPEED
var flashlight_on = true
var flicker_timer = 0.0

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var flashlight = $Head/Camera3D/Flashlight
@onready var raycast = $Head/Camera3D/Raycast
@onready var interact_label = $UI/InteractLabel
@onready var crosshair_dot = $UI/CrosshairUI/CrosshairDot
@onready var breath_sound = $BreathSound

var keys_collected = 0
var is_alive = true

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	$UI/GameOverScreen.visible = false
	$UI/WinScreen.visible = false
	$UI/KeyCount.text = "Kunci: 0/5"
	if flashlight:
		flashlight.visible = true

func _unhandled_input(event):
	if not is_alive:
		return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()

func _physics_process(delta):
	if not is_alive:
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if Input.is_action_pressed("sprint"):
		current_speed = SPRINT_SPEED
	else:
		current_speed = SPEED
	
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	move_and_slide()
	
	flicker_flashlight(delta)
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and collider.is_in_group("keys"):
			interact_label.visible = true
			if Input.is_action_just_pressed("interact"):
				pickup_key(collider)
		else:
			interact_label.visible = false
	else:
		interact_label.visible = false

func toggle_flashlight():
	flashlight_on = !flashlight_on
	if flashlight:
		flashlight.visible = flashlight_on

func flicker_flashlight(delta):
	if not flashlight or not flashlight_on:
		return
	
	flicker_timer += delta
	if randf() < 0.005:
		flashlight.light_energy = randf_range(2.0, 3.5)
	elif flashlight.light_energy < 3.0:
		flashlight.light_energy = move_toward(flashlight.light_energy, 3.0, delta * 5.0)

func pickup_key(key_node):
	keys_collected += 1
	key_node.queue_free()
	$UI/KeyCount.text = "Kunci: " + str(keys_collected) + "/5"
	$PickupSound.play()
	if keys_collected >= 5:
		win_game()

func win_game():
	is_alive = false
	$UI/WinScreen.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$WinSound.play()

func game_over():
	if not is_alive:
		return
	is_alive = false
	velocity = Vector3.ZERO
	$UI/GameOverScreen.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$DeathSound.play()

func _on_restart_pressed():
	get_tree().reload_current_scene()

func _on_quit_pressed():
	get_tree().quit()
