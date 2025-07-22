extends StaticBody3D


@export var PITCH_LENGTH := 60;
@export var PITCH_WIDTH := 40;


# Using shell-texturing
const SHELL_SEPARATION := 0.2;
const NUM_SHELLS := 12;


const GRASS_PER_UNIT = 8;




func _ready() -> void:
	create_shell_texture_layers()



func create_shell_texture_layers():
	var sep := SHELL_SEPARATION / NUM_SHELLS
	var shader = preload("res://scenes/world/pitch/shell_texture.gdshader")

	for i in range(NUM_SHELLS):
		var mesh_instance := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		# mesh.subdivide_width = PITCH_LENGTH
		# mesh.subdivide_depth = PITCH_WIDTH
		var size := Vector2(PITCH_LENGTH, PITCH_WIDTH)
		mesh.size = size
		mesh_instance.mesh = mesh

		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("shell_index", i)
		material.set_shader_parameter("grass_grid_size", size * GRASS_PER_UNIT)
		mesh_instance.material_override = material

		var t = Transform3D()
		t.origin = Vector3(0.0, 0.001 + i * sep, 0.0)
		mesh_instance.transform = t

		add_child(mesh_instance)
