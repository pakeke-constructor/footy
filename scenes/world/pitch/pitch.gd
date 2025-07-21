extends StaticBody3D


@export var PITCH_LENGTH = 60.0;
@export var PITCH_WIDTH = 40.0;


func _ready() -> void:
	var plane: MeshInstance3D = $DirtPlane
	plane.mesh.size = Vector2(PITCH_LENGTH, PITCH_WIDTH)


func create_shell_texture_layers():
	var multi_mesh_instance = MultiMeshInstance3D.new()
	add_child(multi_mesh_instance)
	
	var multi_mesh = MultiMesh.new()
	multi_mesh_instance.multimesh = multi_mesh
	
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(2.0, 2.0)  # 2x2 plane
	
	multi_mesh.mesh = plane_mesh
	multi_mesh.instance_count = 3
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	
	for i in range(3):
		var t = Transform3D()
		t.origin = Vector3(0, i * 1.5, 0)  # Stack them 1.5 units apart
		multi_mesh.set_instance_transform(i, t)



