class_name PlatformCaps
extends RefCounted
## Platform feature gates for multi-target shipping.


## When set to a bool, overrides `OS.has_feature("mobile")` (tests only).
static var mobile_os_override: Variant = null


static func is_mobile_os() -> bool:
	if mobile_os_override is bool:
		return mobile_os_override as bool
	return OS.has_feature("mobile")


static func clear_overrides() -> void:
	mobile_os_override = null
