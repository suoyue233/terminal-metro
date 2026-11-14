extends Control

var host: Control
var container: String
var cell_size := 52
var hover_cell := Vector2i(-1, -1)

func setup(owner_ui: Control, target: String, pixels: int) -> void:
	host = owner_ui
	container = target
	cell_size = pixels
	size = Vector2(host.state.grid_size(container) * cell_size)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_exited.connect(_leave_grid)

func _leave_grid() -> void:
	hover_cell = Vector2i(-1, -1)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_cell = cell_at(event.position)
		queue_redraw()
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			host.click_cell(container, cell_at(event.position))
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			host.clear_selection()
			accept_event()

func cell_at(at: Vector2) -> Vector2i:
	return Vector2i((at / cell_size).floor())

func _get_tooltip(at: Vector2) -> String:
	var entry: Dictionary = host.state.entry_at(container, cell_at(at))
	if entry.is_empty():
		return ""
	var shape: Vector2i = host.state.footprint(entry.kind, entry.rotated)
	var name: String = host.state.item_name(entry.kind)
	if entry.kind == "aaa":
		return "%s · %d%%" % [name, entry.charge]
	return "%s · %s · %d × %d" % [name, host.state.rarity_name(entry.kind), shape.x, shape.y]

func _get_drag_data(at: Vector2) -> Variant:
	var entry: Dictionary = host.state.entry_at(container, cell_at(at))
	if entry.is_empty():
		return null
	host.select_cargo(container, entry.id)
	set_drag_preview(host.drag_preview())
	return host.selection

func drag_cell() -> Vector2i:
	# Use the viewport event position for both local and remotely injected drags.
	var local := get_global_transform_with_canvas().affine_inverse() * Vector2(host.pointer_position)
	return cell_at(local)

func _can_drop_data(_at: Vector2, payload: Variant) -> bool:
	hover_cell = drag_cell()
	queue_redraw()
	# A wheel event can change the footprint without another mouse motion.
	# Validate the final orientation in move_cargo when the button is released.
	var bounds: Vector2i = host.state.grid_size(container)
	return payload is Dictionary and payload == host.selection and Rect2i(Vector2i.ZERO, bounds).has_point(hover_cell)

func _drop_data(_at: Vector2, _payload: Variant) -> void:
	host.move_cargo(container, drag_cell())

func _draw() -> void:
	if host == null:
		return
	var bounds: Vector2i = host.state.grid_size(container)
	draw_rect(Rect2(Vector2.ZERO, size), Color("141420"))
	for y in range(bounds.y):
		for x in range(bounds.x):
			var origin := Vector2(x * cell_size, y * cell_size)
			var square := Rect2(origin + Vector2.ONE, Vector2.ONE * (cell_size - 2))
			draw_rect(square, Color("242437"))
			draw_rect(square, Color("3d3c53"), false)
			draw_rect(Rect2(origin + Vector2(5, 5), Vector2(2, 2)), Color("51506a"))
	for entry in host.state.entries(container):
		var box: Rect2i = host.state.item_rect(entry)
		var rect := Rect2(box.position * cell_size, box.size * cell_size).grow(-3)
		var tint: Color = host.state.rarity_color(entry.kind)
		var active: bool = host.selection.get("source") == container and host.selection.get("id") == entry.id
		draw_rect(rect, tint.darkened(0.72))
		draw_rect(rect, tint if active else tint.darkened(0.22), false, 2)
		draw_rect(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 3)), tint)
		var short_name: String = {"copper": "铜线", "tools": "工具", "book": "手册", "meds": "医疗", "circuit": "电路", "powercore": "电源", "relic": "相机", "aaa": "电池", "water": "饮水", "ration": "口粮", "car_battery": "车电池"}.get(entry.kind, host.state.item_name(entry.kind))
		var title: String = host.state.item_name(entry.kind) if box.size.x >= 2 else short_name
		draw_string(host.font, rect.position + Vector2(7, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f0ebdf"))
		if entry.kind == "aaa":
			draw_string(host.font, rect.position + Vector2(7, 43), "%d%%" % entry.charge, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, tint)
		elif box.size.y >= 2:
			draw_string(host.font, rect.end + Vector2(-39, -10), "%d×%d" % [box.size.x, box.size.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tint)
	if host.selection.is_empty() or not Rect2i(Vector2i.ZERO, bounds).has_point(hover_cell):
		return
	var selected: Dictionary = host.state.picked(host.selection.source, host.selection.id)
	if selected.is_empty():
		return
	var shape: Vector2i = host.state.footprint(selected.kind, host.selection.rotated)
	var visible_shape := shape.min(bounds - hover_cell)
	var ghost := Rect2(hover_cell * cell_size, visible_shape * cell_size).grow(-2)
	var valid: bool = host.state.can_place(host.selection, container, hover_cell)
	var color := Color("91ddc0") if valid else Color("ff9a8d")
	draw_rect(ghost, Color(color, 0.28))
	draw_rect(ghost, color, false, 2)
