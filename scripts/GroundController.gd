extends Node2D

# References to scene nodes - assign in editor or use groups
@export var player: Player
@export var enemy: Enemy
@onready var top_anchor: Node2D = $"Top Anchor"
@onready var bottom_anchor: Node2D = $"Bottom Anchor"

# Alternative: find by groups if nodes are added to groups
func _find_nodes_by_groups():
	if not player:
		player = get_tree().get_first_node_in_group("Player")
	if not enemy:
		enemy = get_tree().get_first_node_in_group("Enemies")

func _ready():
	_find_nodes_by_groups()
	# Verify all references are valid
	if not player:
		print_debug("Warning: Player reference not found")
	if not enemy:
		print_debug("Warning: Enemy reference not found")
	if not top_anchor:
		print_debug("Warning: Top Anchor reference not found")
	if not bottom_anchor:
		print_debug("Warning: Bottom Anchor reference not found")
		
	
