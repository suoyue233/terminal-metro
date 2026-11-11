extends CharacterBody2D

var host
var facing: float = 1.0
var walk_phase: float = 0.0
var ladder_mode: bool = false
var hurt_time: float = 0.0

func _ready() -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var body_shape: RectangleShape2D = RectangleShape2D.new()
	body_shape.size = Vector2(16, 34)
	shape.shape = body_shape
	shape.position.y = -17
	add_child(shape)
	collision_layer = 4
	collision_mask = 3
	floor_snap_length = 5.0
	z_index = 10

func _physics_process(delta: float) -> void:
	if host == null:
		return
	hurt_time = maxf(0.0, hurt_time - delta)
	if not host.can_move():
		velocity = Vector2.ZERO
		queue_redraw()
		return
	var axis: float = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var vertical: float = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var ladder: bool = host.on_ladder(position)
	if ladder and absf(vertical) > 0.0:
		ladder_mode = true
	if not ladder or absf(axis) > 0.0 or Input.is_physical_key_pressed(KEY_SPACE):
		ladder_mode = false
	set_collision_mask_value(2, not ladder_mode)
	var load_ratio: float = host.state.weight() / host.state.bag_capacity()
	var move_speed: float = lerpf(222.0, 148.0, load_ratio)
	if host.area == "surface" and position.x > 1700 and position.x < 1820:
		move_speed *= 0.66
	velocity.x = axis * move_speed
	if ladder_mode:
		velocity.y = vertical * 145.0
	else:
		velocity.y += 1000.0 * delta
		if is_on_floor() and Input.is_physical_key_pressed(KEY_SPACE):
			velocity.y = -390.0
	if absf(axis) > 0.1:
		facing = signf(axis)
		walk_phase += delta * 13.0
	if hurt_time > 0.55:
		velocity.x -= facing * 170.0
	move_and_slide()
	position.x = clampf(position.x, 48.0, 3540.0 if host.area == "surface" else 1210.0)
	if host.area == "surface" and not host.state.permit:
		position.x = minf(position.x, 2670.0)
	if position.y > 740:
		host.fail_trip("跌入了无法返回的设备层")
	queue_redraw()

func _draw() -> void:
	if hurt_time > 0 and int(hurt_time * 18) % 2 == 0:
		return
	var walking: bool = absf(velocity.x) > 4.0
	var leg: float = roundf(sin(walk_phase) * 3.0) if walking else 0.0
	draw_rect(Rect2(-10, -23, 7, 17), Color("344f53"))
	draw_rect(Rect2(-7, -27, 15, 19), Color("b4b29b"))
	draw_rect(Rect2(-6, -14, 13, 5), Color("655f51"))
	draw_rect(Rect2(-7, -10, 5, 8 + leg), Color("555d5b"))
	draw_rect(Rect2(2, -10, 5, 8 - leg), Color("70736a"))
	draw_rect(Rect2(-8, -3 + leg, 7, 3), Color("23373b"))
	draw_rect(Rect2(1, -3 - leg, 8, 3), Color("23373b"))
	draw_rect(Rect2(-6, -39, 14, 14), Color("cad0bc"))
	draw_rect(Rect2(-4 if facing > 0 else -7, -36, 12, 6), Color("172d35"))
	draw_rect(Rect2(1 if facing > 0 else -6, -35, 6, 3), Color("eabf78"))
	draw_rect(Rect2(6 if facing > 0 else -10, -30, 5, 5), Color("627e7b"))
	draw_rect(Rect2(8 if facing > 0 else -12, -24, 4, 13), Color("a5aa95"))
	draw_rect(Rect2(10 if facing > 0 else -15, -20, 5, 4), Color("f1d399"))
	draw_rect(Rect2(-9, -20, 3, 8), Color("de9e67"))
	if host != null and host.lamp_on and host.state.battery > 0:
		draw_circle(Vector2(12 * facing, -18), 4, Color(1, 0.85, 0.5, 0.28))
