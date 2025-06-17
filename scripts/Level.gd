extends Node

@onready var player: Player = $Player
@onready var Ground: Node2D = $Ground

func _ready():
	# Connect to player signals
	if player:
		player.jumped.connect(_on_player_jumped)
		print("Level: Connected to player jumped signal")
	else:
		print("Level: Warning - Player node not found")

func _on_player_jumped():
	print("Level: Player jumped! Could trigger screen shake, sound effects, etc.")
	# Add any level-wide reactions to player jumping here
	# Examples:
	# - Screen shake
	# - Camera effects  
	# - Environmental reactions
	# - Sound effects
	# - Particle effects
