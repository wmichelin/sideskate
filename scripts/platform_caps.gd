class_name PlatformCaps
extends RefCounted
## Platform feature gates for multi-target shipping.


## When set to a bool, overrides touch-control visibility (tests only).
static var mobile_os_override: Variant = null
## When set to a bool, overrides the web phone/tablet probe (tests only).
static var web_mobile_probe_override: Variant = null
## Set after a real screen-touch on Web (itch often lacks reliable probes until then).
static var _web_touch_seen: bool = false
static var _web_probe_cache: Variant = null

const _WEB_MOBILE_JS := "(function(){var ua=navigator.userAgent||'';if(/Android|webOS|iPhone|iPod|iPad|Mobile|Tablet|BlackBerry|IEMobile|Opera Mini/i.test(ua))return true;if(navigator.maxTouchPoints>1&&/Macintosh/i.test(ua))return true;if(typeof navigator.maxTouchPoints==='number'&&navigator.maxTouchPoints>0&&typeof window.matchMedia==='function'&&window.matchMedia('(pointer: coarse)').matches)return true;return false;})()"


static func is_mobile_os() -> bool:
	## Native phone/tablet export feature tag only.
	if mobile_os_override is bool:
		return mobile_os_override as bool
	return OS.has_feature("mobile")


static func should_show_touch_controls() -> bool:
	## Native mobile, or HTML5 phone/tablet (itch play-in-browser).
	if mobile_os_override is bool:
		return mobile_os_override as bool
	if OS.has_feature("mobile"):
		return true
	if not OS.has_feature("web"):
		return false
	# Any of these is enough — itch iframes are flaky on a single signal.
	if _web_touch_seen:
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	if _web_is_phone_or_tablet():
		return true
	return false


static func note_screen_touch() -> void:
	_web_touch_seen = true


static func clear_overrides() -> void:
	mobile_os_override = null
	web_mobile_probe_override = null
	_web_touch_seen = false
	_web_probe_cache = null


static func _web_is_phone_or_tablet() -> bool:
	if web_mobile_probe_override is bool:
		return web_mobile_probe_override as bool
	if not OS.has_feature("web"):
		return false
	if _web_probe_cache is bool:
		return _web_probe_cache as bool
	var result: Variant = _eval_web_js(_WEB_MOBILE_JS)
	var ok := false
	if typeof(result) == TYPE_BOOL:
		ok = result as bool
	elif typeof(result) == TYPE_FLOAT or typeof(result) == TYPE_INT:
		ok = int(result) != 0
	elif typeof(result) == TYPE_STRING:
		var s := str(result).to_lower()
		ok = s == "true" or s == "1"
	_web_probe_cache = ok
	return ok


static func _eval_web_js(code: String) -> Variant:
	## JavaScriptBridge is a Web singleton; call it directly (ClassDB static call is unreliable).
	if not OS.has_feature("web"):
		return null
	return JavaScriptBridge.eval(code, true)
