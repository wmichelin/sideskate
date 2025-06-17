@tool

class_name GroundController extends Node

var NUM_GROUND_SECTIONS = 3
var SECTION_HEIGHT = 350
var SECTION_WIDTH = 500
var _ground_sections: Array[GroundSection] = []
var left_idx = 0 # used to calculate left + right offset for infinite floor

# Character tracking for intersection detection
var _characters: Array[Node] = []
var _original_colors: Array[Color] = []  # Store original colors for restoration


# Alternative: find by groups if nodes are added to groups
func _find_nodes_by_groups():
	if Engine.is_editor_hint():
		return  # Don't find characters in editor
	_characters = get_tree().get_nodes_in_group("Characters")
	print("Found ", _characters.size(), " characters for intersection tracking")

func _debug_print_ground_section(ground_section: GroundSection) -> void:
	print("========== GROUND SECTION DEBUG ==========")
	print("Node Name: ", ground_section.name)
	print("Node Type: ", ground_section.get_class())
	print("Is Valid: ", is_instance_valid(ground_section))

func _update_ground_sections():
	var i = 0
	print("debug ", "iter ground sections")
	for ground_section in self._ground_sections:
		ground_section.set_size(SECTION_WIDTH, SECTION_HEIGHT)
		ground_section.set_position_x(SECTION_WIDTH * i)
		i += 1
		_debug_print_ground_section(ground_section)


func _init() -> void:
	for i in range(NUM_GROUND_SECTIONS):
		var ground_section = GroundSection.NewGroundSection(i)
		self._ground_sections.append(ground_section)
		# Store original color before adding to scene
		_original_colors.append(ground_section.color)
		add_child(ground_section)
		# Connect to section entry signal
		ground_section.character_entered_section.connect(_on_character_entered_section)

	self._update_ground_sections()

func _ready():
	#_update_width_live()
	_find_nodes_by_groups()
	_update_ground_sections()
	# Verify all references are valid
	#if not characters:
		#return

func _on_character_entered_section(section: GroundSection, character: Node2D):
	var section_index = _ground_sections.find(section)
	if section_index == -1:
		return
	
	print("Character entered section ", section_index)
	
	# Check if player entered leftmost section (index 0)
	if section_index == 0:
		print("Player in leftmost section - moving rightmost section to left")
		_move_rightmost_section_to_left()
	
	# Check if player entered rightmost section (last index)
	elif section_index == NUM_GROUND_SECTIONS - 1:
		print("Player in rightmost section - moving leftmost section to right") 
		_move_leftmost_section_to_right()

func _move_rightmost_section_to_left():
	_move_section_to_opposite_side(false)

func _move_leftmost_section_to_right():
	_move_section_to_opposite_side(true)

func _move_section_to_opposite_side(move_left_to_right: bool):
	var source_section: GroundSection
	var target_section: GroundSection
	var position_offset: float
	
	if move_left_to_right:
		source_section = _ground_sections[0]
		target_section = _ground_sections[NUM_GROUND_SECTIONS - 1]
		position_offset = SECTION_WIDTH
	else:
		source_section = _ground_sections[NUM_GROUND_SECTIONS - 1]
		target_section = _ground_sections[0]
		position_offset = -SECTION_WIDTH
	
	# Position the source section next to the target section
	source_section.position.x = target_section.position.x + position_offset
	
	# Reorder array
	_ground_sections.erase(source_section)
	if move_left_to_right:
		_ground_sections.push_back(source_section)
	else:
		_ground_sections.push_front(source_section)

func player_did_jump() -> void:
	for ground_section in self._ground_sections:
		_debug_print_ground_section(ground_section)
