extends Node3D

var keys_total = 5
var game_started = false
var game_over = false

@onready var player = $Player
@onready var monster = $Monster

func _ready():
	game_started = true

func _process(_delta):
	pass
