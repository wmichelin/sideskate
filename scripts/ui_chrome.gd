class_name UiChrome
extends RefCounted
## Shared flat button / panel styles for menus.


static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 16
	s.content_margin_top = 10
	s.content_margin_right = 16
	s.content_margin_bottom = 10
	return s


static func apply_menu_button(
	btn: Button, font_size: int = 20, min_size: Vector2 = Vector2(420, 48)
) -> void:
	var normal := button_style(Color(0.14, 0.16, 0.18, 0.95), Color(0.85, 0.55, 0.28, 0.55))
	var hover := button_style(Color(0.22, 0.18, 0.12, 0.98), Color(0.95, 0.65, 0.3, 0.9))
	btn.custom_minimum_size = min_size
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", hover)
