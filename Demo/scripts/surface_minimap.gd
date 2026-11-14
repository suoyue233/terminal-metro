extends Control

const Block = preload("res://scripts/surface_block.gd")
const CELL_SIZE := Vector2(28, 28)
const SPACING := Vector2(76, 48)
const CURRENT_COLOR := Color("f0cc91")
const VISITED_COLOR := Color("b9b3cb")
const UNVISITED_COLOR := Color("51495f")

var street: Block
var font: Font
var current := Vector2i(-1, -1)
var links: Array[Array] = []

func setup(block: Block, ui_font: Font) -> void:
	street = block
	font = ui_font
	links = Block.map_connections()
	mouse_filter = MOUSE_FILTER_IGNORE
	street.moved.connect(update_location)
	update_location()

func update_location() -> void:
	var point := street.cell()
	if point != current:
		current = point
		queue_redraw()

func center(point: Vector2i) -> Vector2:
	var span := Vector2(Block.CELL_NAMES[0].size() - 1, Block.CELL_NAMES.size() - 1) * SPACING
	return (size - span) * 0.5 + Vector2(point) * SPACING

func _draw() -> void:
	if street == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("211f31ed"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("72617a"), false)
	for link in links:
		draw_line(center(link[0]), center(link[1]), Color("897991"), 5.0)
	for row in range(Block.CELL_NAMES.size()):
		for column in range(Block.CELL_NAMES[row].size()):
			var point := Vector2i(column, row)
			var fill := UNVISITED_COLOR
			if point == current:
				fill = CURRENT_COLOR
			elif street.visited.has(point):
				fill = VISITED_COLOR
			var bounds := Rect2(center(point) - CELL_SIZE * 0.5, CELL_SIZE)
			draw_rect(bounds, fill)
			draw_rect(bounds, fill.lightened(0.28), false)
	for station in Block.STATIONS:
		var point := Vector2i(Block.street_column(station.x), station.row)
		var at := center(point)
		var label_y := at.y + 28.0 if point.y == Block.SOUTH else at.y - 18.0
		var ink := Color("f2eadd") if point == current else VISITED_COLOR
		draw_string(font, Vector2(at.x - 38, label_y), station.name, HORIZONTAL_ALIGNMENT_CENTER, 76, 13, ink)
