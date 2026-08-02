class_name PlatformCaps
extends RefCounted
## Platform feature gates for multi-target shipping.


## When set to a bool, overrides touch-control visibility (tests only).
static var mobile_os_override: Variant = null
## When set to a bool, overrides the web phone/tablet probe (tests only).
static var web_mobile_probe_override: Variant = null

const _WEB_MOBILE_JS := """
(function () {
	var ua = navigator.userAgent || "";
	if (/Android|webOS|iPhone|iPod|iPad|Mobile|Tablet|BlackBerry|IEMobile|Opera Mini/i.test(ua)) {
		return true;
	}
	// iPadOS 13+ often reports as Macintosh with touch.
	if (navigator.maxTouchPoints > 1 && /Macintosh/i.test(ua)) {
		return true;
	}
	if (
		typeof navigator.maxTouchPoints === "number"
		&& navigator.maxTouchPoints > 0
		&& typeof window.matchMedia === "function"
		&& window.matchMedia("(pointer: coarse)").matches
	) {
		return true;
	}
	return false;
})()
"""


static func is_mobile_os() -> bool:
	## Native phone/tablet export feature tag only.
	if mobile_os_override is bool:
		return mobile_os_override as bool
	return OS.has_feature("mobile")


static func should_show_touch_controls() -> bool:
	## Native mobile, or HTML5 phone/tablet browser (itch play-in-browser).
	if mobile_os_override is bool:
		return mobile_os_override as bool
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web") and _web_is_phone_or_tablet():
		return true
	return false


static func clear_overrides() -> void:
	mobile_os_override = null
	web_mobile_probe_override = null


static func _web_is_phone_or_tablet() -> bool:
	if web_mobile_probe_override is bool:
		return web_mobile_probe_override as bool
	if not OS.has_feature("web"):
		return false
	var result: Variant = _eval_web_js(_WEB_MOBILE_JS)
	if typeof(result) == TYPE_BOOL:
		return result as bool
	# Some embeds return 0/1.
	if typeof(result) == TYPE_FLOAT or typeof(result) == TYPE_INT:
		return int(result) != 0
	# Last resort on Web if JS bridge is unavailable.
	return DisplayServer.is_touchscreen_available()


static func _eval_web_js(code: String) -> Variant:
	## Call JavaScriptBridge without a hard parse-time global (desktop/headless).
	if not ClassDB.class_exists("JavaScriptBridge"):
		return null
	if not ClassDB.class_has_method("JavaScriptBridge", "eval"):
		return null
	return ClassDB.class_call_static("JavaScriptBridge", "eval", code, true)
