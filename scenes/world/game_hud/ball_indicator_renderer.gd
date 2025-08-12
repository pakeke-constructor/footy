extends Control

@export_group("Indicator Appearance")
@export var draw_background_circle: bool = true
@export var background_color: Color = Color(1.0, 0.8, 0.0, 0.8)
@export var background_radius: float = 25.0
@export_range(10.0, 100.0, 5.0) var screen_margin: float = 30.0

@export_group("Indicator Texture")
@export var arrow_texture: Texture2D
@export var texture_scale: float = 1.0
@export var texture_color: Color = Color(1.0, 1.0, 1.0, 1.0)

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if not camera or not GameManager.ball or not GameManager.ball.is_inside_tree():
		return
		
	var ball_position := GameManager.ball.global_position
	
	var viewport_rect := get_viewport_rect().size
	var center := viewport_rect / 2
	
	var camera_position := camera.global_position
	var to_ball := ball_position - camera_position
	
	var is_in_front := to_ball.dot(camera.global_transform.basis.z) < 0
	
	var screen_position: Vector2
	var direction: Vector2
	
	if is_in_front:
		screen_position = camera.unproject_position(ball_position)
		
		var is_visible := Rect2(Vector2.ZERO, viewport_rect).has_point(screen_position)
		
		if not is_visible:
			direction = (screen_position - center).normalized()
			var edge_position := _get_edge_position(center, direction, viewport_rect)
			_draw_indicator(edge_position, direction)
	else:
		var opposite_position := camera_position - to_ball.normalized() * 10.0
		screen_position = camera.unproject_position(opposite_position)
		direction = (center - screen_position).normalized()
		var edge_position := _get_edge_position(center, direction, viewport_rect)
		
		_draw_indicator(edge_position, direction)


func _get_edge_position(center: Vector2, direction: Vector2, viewport_size: Vector2) -> Vector2:
	var min_x := screen_margin
	var min_y := screen_margin
	var max_x := viewport_size.x - screen_margin
	var max_y := viewport_size.y - screen_margin
	
	var position := center
	var scale := 1000.0
	
	var target := center + direction * scale
	
	var top_intersection: Variant = _line_intersection(
		center, target,
		Vector2(min_x, min_y), Vector2(max_x, min_y)
	)
	var bottom_intersection: Variant = _line_intersection(
		center, target,
		Vector2(min_x, max_y), Vector2(max_x, max_y)
	)
	var left_intersection: Variant = _line_intersection(
		center, target,
		Vector2(min_x, min_y), Vector2(min_x, max_y)
	)
	var right_intersection: Variant = _line_intersection(
		center, target,
		Vector2(max_x, min_y), Vector2(max_x, max_y)
	)
	
	var intersections := [top_intersection, bottom_intersection, left_intersection, right_intersection]
	var min_distance := INF
	
	for intersection in intersections:
		if intersection:
			var distance := center.distance_to(intersection)
			if distance < min_distance:
				min_distance = distance
				position = intersection
	
	return position


func _draw_indicator(position: Vector2, direction: Vector2) -> void:
	if not arrow_texture:
		return
	
	var angle := direction.angle() + PI/2
	
	if draw_background_circle:
		draw_circle(position, background_radius, background_color)
	
	var texture_size := arrow_texture.get_size() * texture_scale
	var texture_position := position - texture_size / 2
	
	var transform := Transform2D().rotated(angle)
	draw_set_transform_matrix(transform.translated(position))
	draw_texture_rect(
		arrow_texture,
		Rect2(-texture_size / 2, texture_size),
		false,
		texture_color
	)
	draw_set_transform_matrix(Transform2D())


func _line_intersection(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> Variant:
	# Line 1 represented as a1x + b1y = c1
	var a1 := p2.y - p1.y
	var b1 := p1.x - p2.x
	var c1 := a1 * p1.x + b1 * p1.y
	
	# Line 2 represented as a2x + b2y = c2
	var a2 := p4.y - p3.y
	var b2 := p3.x - p4.x
	var c2 := a2 * p3.x + b2 * p3.y
	
	var determinant := a1 * b2 - a2 * b1
	
	if determinant == 0:
		# Lines are parallel
		return null
	
	var x := (b2 * c1 - b1 * c2) / determinant
	var y := (a1 * c2 - a2 * c1) / determinant
	
	# Check if intersection is within both line segments
	var on_segment1 := _is_point_on_segment(Vector2(x, y), p1, p2)
	var on_segment2 := _is_point_on_segment(Vector2(x, y), p3, p4)
	
	if on_segment1 and on_segment2:
		return Vector2(x, y)
	
	return null


# Helper function to check if a point is on a line segment
func _is_point_on_segment(p: Vector2, q: Vector2, r: Vector2) -> bool:
	return (
		p.x <= max(q.x, r.x) and p.x >= min(q.x, r.x) and
		p.y <= max(q.y, r.y) and p.y >= min(q.y, r.y)
	)
