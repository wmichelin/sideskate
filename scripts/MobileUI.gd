extends Control

class_name MobileUI

func _ready():
	# Only show mobile UI on mobile web platforms
	if is_mobile_web():
		show()
	else:
		hide()

func is_mobile_web() -> bool:
	return true
	# Check if running on web platform
	#if not OS.has_feature("web"):
		#return false
	#
	## Check for mobile characteristics
	#var is_touch_available = DisplayServer.is_touchscreen_available()
	#
	## Consider it mobile if touch is available
	#return is_touch_available
