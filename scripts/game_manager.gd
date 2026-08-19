extends Node3D

var keys_total = 5
var keys_collected = 0
var game_started = false
var game_over = false

@onready var player = $Player
@onready var monster = $Monster
@onready var ui = $UI

func _ready():
	game_started = true
	$Timer.start()

func _process(delta):
	if game_over:
		return

func add_key():
	keys_collected += 1
	$UI/KeyCount.text = "Kunci: " + str(keys_collected) + "/5"
	
	if keys_collected >= keys_total:
		player.win_game()

func _on_timer_timeout():
	if not game_over:
		pass
