extends Node

@onready var player: Player = $Player
@onready var ground: GroundController = $GroundController

func _ready():
	# Connect to player signals
	if player:
		player.jumped.connect(_on_player_jumped)
		print("Level: Connected to player jumped signal")
	else:
		print("Level: Warning - Player node not found")

func _on_player_jumped():
	ground.player_did_jump()
	# Add any level-wide reactions to player jumping here
	# Examples:
	# - Screen shake
	# - Camera effects  
	# - Environmental reactions
	# - Sound effects
	# - Particle effects
