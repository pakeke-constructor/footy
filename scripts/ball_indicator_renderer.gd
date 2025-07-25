extends Control

# Configuration for the indicator
@export_group("Indicator Appearance")
@export var draw_background_circle: bool = true
@export var background_color: Color = Color(1.0, 0.8, 0.0, 0.8)  # Yellow with some transparency
@export var background_radius: float = 25.0
@export_range(10.0, 100.0, 5.0) var screen_margin: float = 30.0  # Distance from screen edge

@export_group("Indicator Texture")
@export var arrow_texture: Texture2D
@export var texture_scale: float = 1.0
@export var texture_color: Color = Color(1.0, 1.0, 1.0, 1.0)  # White by default

func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Make sure we have a camera and ball
	var camera := get_viewport().get_camera_3d()
	if not camera or not GameManager.ball:
		return
		
	var ball_position := GameManager.ball.global_position
	
	# Get viewport size
	var viewport_rect := get_viewport_rect().size
	var center := viewport_rect / 2
	
	# Calculate direction from camera to ball in world space
	var camera_position := camera.global_position
	var to_ball := ball_position - camera_position
	
	# Check if ball is in front of camera
	var is_in_front := to_ball.dot(camera.global_transform.basis.z) < 0
	
	# Handle ball position based on whether it's in front of or behind camera
	var screen_position: Vector2
	var direction: Vector2
	
	if is_in_front:
		# Ball is in front of camera, use normal projection
		screen_position = camera.unproject_position(ball_position)
		
		# Check if ball is visible on screen (with some margin)
		var is_visible := Rect2(Vector2.ZERO, viewport_rect).has_point(screen_position)
		
		if not is_visible:
			# Ball is off-screen but in front of camera
			direction = (screen_position - center).normalized()
			
			# Calculate position on screen edge
			var edge_position := _get_edge_position(center, direction, viewport_rect)
			
			# Draw the indicator
			_draw_indicator(edge_position, direction)
	else:
		# Ball is behind camera, show indicator in opposite direction
		# Project a point in front of camera in the opposite direction of the ball
		var opposite_position := camera_position - to_ball.normalized() * 10.0
		screen_position = camera.unproject_position(opposite_position)
		
		# Direction is from screen center to this projected point, but reversed
		direction = (center - screen_position).normalized()
		
		# Calculate position on screen edge
		var edge_position := _get_edge_position(center, direction, viewport_rect)
		
		# Draw the indicator
		_draw_indicator(edge_position, direction)


# Calculate position on screen edge
func _get_edge_position(center: Vector2, direction: Vector2, viewport_size: Vector2) -> Vector2:
	# Calculate screen bounds with margin
	var min_x := screen_margin
	var min_y := screen_margin
	var max_x := viewport_size.x - screen_margin
	var max_y := viewport_size.y - screen_margin
	
	# Find intersection with screen edges
	var position := center
	
	# Scale the direction vector to ensure it reaches the edge
	var scale := 1000.0  # Large enough to reach any edge
	
	# Calculate potential intersection with each edge
	var target := center + direction * scale
	
	# Check intersection with top edge
	var top_intersection: Variant = _line_intersection(
		center, target,
		Vector2(min_x, min_y), Vector2(max_x, min_y)
	)
	
	# Check intersection with bottom edge
	var bottom_intersection: Variant = _line_intersection(
		center, target,
		Vector2(min_x, max_y), Vector2(max_x, max_y)
	)
	
	# Check intersection with left edge
	var left_intersection: Variant = _line_intersection(
		center, target,
		Vector2(min_x, min_y), Vector2(min_x, max_y)
	)
	
	# Check intersection with right edge
	var right_intersection: Variant = _line_intersection(
		center, target,
		Vector2(max_x, min_y), Vector2(max_x, max_y)
	)
	
	# Find the valid intersection closest to center
	var intersections := [top_intersection, bottom_intersection, left_intersection, right_intersection]
	var min_distance := INF
	
	for intersection in intersections:
		if intersection:
			var distance := center.distance_to(intersection)
			if distance < min_distance:
				min_distance = distance
				position = intersection
	
	return position


# Draw the indicator at the specified position pointing in the given direction
func _draw_indicator(position: Vector2, direction: Vector2) -> void:
	if not arrow_texture:
		return
		
	# Calculate the angle for the texture rotation
	# Subtract PI/2 (90 degrees) to correct the rotation
	var angle := direction.angle() + PI/2
	
	# Draw background circle if enabled
	if draw_background_circle:
		draw_circle(position, background_radius, background_color)
	
	# Calculate texture size and position
	var texture_size := arrow_texture.get_size() * texture_scale
	var texture_position := position - texture_size / 2
	
	# Draw the texture with rotation
	var transform := Transform2D().rotated(angle)
	draw_set_transform_matrix(transform.translated(position))
	draw_texture_rect(
		arrow_texture,
		Rect2(-texture_size / 2, texture_size),
		false,
		texture_color
	)
	draw_set_transform_matrix(Transform2D())


# Helper function to find intersection between two line segments
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
