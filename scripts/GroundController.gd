@tool

class_name GroundController extends Node2D

const DepthBoundedCharacter = preload("res://scripts/DepthBoundedCharacter.gd")

var _FALLBACK_NUM_GROUND_SECTIONS = 3
var _ground_sections: Array[GroundSection] = []
var left_idx = 0 # used to calculate left + right offset for infinite floor

# Character tracking for collision detection
var _characters: Array[Node] = []
var _original_colors: Array[Color] = []  # Store original colors for restoration

# Auto-tiling management - track player's significant movement
var _player_last_significant_section: int = -1  # Last section where auto-tiling was triggered

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
	# Only update positioning for autotiling - sizes come from scene file
	_position_sections_for_autotiling()

func _position_sections_for_autotiling():
	var i = 0
	print("debug ", "positioning sections for autotiling")
	for ground_section in self._ground_sections:
		var section_width = _get_section_width(ground_section)
		ground_section.set_position_x(section_width * i)
		i += 1
		_debug_print_ground_section(ground_section)

func _get_section_width(ground_section: GroundSection) -> float:
	if ground_section.background:
		return ground_section.background.size.x
	else:
		return 500.0  # fallback if no background found

func _init() -> void:
	# Try to find existing GroundSections first, create if none found
	pass

func _ready():
	_find_or_create_ground_sections()
	_find_nodes_by_groups()
	_update_ground_sections()
	_assign_initial_depth_bounds()

# Find existing GroundSections from scene, or create them if none exist
func _find_or_create_ground_sections():
	_ground_sections.clear()
	_original_colors.clear()
	
	# First, try to find existing GroundSection nodes in the scene
	var section_index = 0
	for child in get_children():
		if child is GroundSection:
			# Assign different colors to make sections distinguishable
			var color_choices = GroundSection.colorChoices
			child.color = color_choices[section_index % color_choices.size()]
			if child.background:
				child.background.color = child.color
			
			# Update collision shape to match section dimensions and position
			child.update_collision_shape()
			
			_ground_sections.append(child)
			_original_colors.append(child.color)
			# Connect to section entry/exit signals
			child.character_entered_section.connect(_on_character_entered_section)
			child.character_exited_section.connect(_on_character_exited_section)
			section_index += 1
	
	# If no GroundSections found, create them
	if _ground_sections.size() == 0:
		print("No GroundSections found in scene, creating them...")
		for i in range(_FALLBACK_NUM_GROUND_SECTIONS):
			var ground_section = GroundSection.NewGroundSection(i)
			self._ground_sections.append(ground_section)
			# Store original color before adding to scene
			_original_colors.append(ground_section.color)
			add_child(ground_section)
			# Connect to section entry/exit signals
			ground_section.character_entered_section.connect(_on_character_entered_section)
			ground_section.character_exited_section.connect(_on_character_exited_section)
	else:
		print("Found ", _ground_sections.size(), " GroundSections in scene")

# Assign initial depth bounds for characters already inside sections
func _assign_initial_depth_bounds():
	for section in _ground_sections:
		if section.area_detector:
			for body in section.area_detector.get_overlapping_bodies():
				if body in _characters and body is DepthBoundedCharacter:
					_update_character_bounds(body)

func _update_character_bounds(character: DepthBoundedCharacter):
	# Find all sections this character is currently overlapping
	var overlapping_sections: Array[GroundSection] = []
	
	for section in _ground_sections:
		if section.area_detector and section.area_detector.overlaps_body(character):
			overlapping_sections.append(section)
	
	if overlapping_sections.size() == 0:
		return  # No sections, keep current bounds
	
	# Calculate combined bounds from all overlapping sections
	var combined_bounds = _calculate_combined_bounds(overlapping_sections)
	character.set_bounds(combined_bounds.min_depth, combined_bounds.max_depth, combined_bounds.min_x, combined_bounds.max_x)

func _calculate_combined_bounds(sections: Array[GroundSection]) -> Dictionary:
	if sections.size() == 0:
		return {"min_depth": 0, "max_depth": 0, "min_x": 0, "max_x": 0}
	
	# Start with the first section's bounds
	var first_bounds = sections[0].get_all_bounds()
	var min_x = first_bounds.min_x
	var max_x = first_bounds.max_x
	var min_depth = first_bounds.min_depth  
	var max_depth = first_bounds.max_depth
	
	# Expand bounds to include all overlapping sections
	for i in range(1, sections.size()):
		var bounds = sections[i].get_all_bounds()
		min_x = min(min_x, bounds.min_x)
		max_x = max(max_x, bounds.max_x)
		min_depth = min(min_depth, bounds.min_depth)
		max_depth = max(max_depth, bounds.max_depth)
	
	return {
		"min_x": min_x,
		"max_x": max_x, 
		"min_depth": min_depth,
		"max_depth": max_depth
	}

func _on_character_entered_section(section: GroundSection, character: Node2D):
	var section_index = _ground_sections.find(section)
	if section_index == -1:
		# Ignore sections we don't manage
		return

	print("Character entered section ", section_index)

	if character is DepthBoundedCharacter:
		_update_character_bounds(character)

	# Only trigger auto-tiling if player has moved significantly since last auto-tile
	# This prevents rapid triggering from boundary dancing
	var should_autotile = _player_last_significant_section != section_index
	
	# Check if player entered leftmost section (index 0) and should trigger auto-tiling
	if section_index == 0 and should_autotile:
		print("Player in leftmost section - moving rightmost section to left")
		_player_last_significant_section = section_index
		# Defer the operation to next frame to avoid lag
		call_deferred("_move_rightmost_section_to_left")
	
	# Check if player entered rightmost section (last index) and should trigger auto-tiling
	elif section_index == _ground_sections.size() - 1 and should_autotile:
		print("Player in rightmost section - moving leftmost section to right")
		_player_last_significant_section = section_index
		# Defer the operation to next frame to avoid lag
		call_deferred("_move_leftmost_section_to_right")
	
	# Reset tracking when player moves to middle sections (allows future auto-tiling)
	elif section_index > 0 and section_index < _ground_sections.size() - 1:
		_player_last_significant_section = -1

func _on_character_exited_section(section: GroundSection, character: Node2D):
	print("Character exited section: ", section.name)
	if character is DepthBoundedCharacter:
		_update_character_bounds(character)

func _move_rightmost_section_to_left():
	_move_section_to_opposite_side(false)

func _move_leftmost_section_to_right():
	_move_section_to_opposite_side(true)

func _move_section_to_opposite_side(move_left_to_right: bool):
	if _ground_sections.size() == 0:
		return
	
	var source_section: GroundSection
	var target_section: GroundSection
	var position_offset: float
	
	if move_left_to_right:
		source_section = _ground_sections[0]
		target_section = _ground_sections[_ground_sections.size() - 1]
		position_offset = _get_section_width(target_section)
	else:
		source_section = _ground_sections[_ground_sections.size() - 1]
		target_section = _ground_sections[0]
		position_offset = -_get_section_width(source_section)
	
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
