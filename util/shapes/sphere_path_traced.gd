@tool
class_name SpherePathTraced extends ShapePathTraced

@export var radius := 1.0 :
	set(value): radius = value; changed.emit()

func to_byte_array() -> PackedByteArray:
	return PackedFloat32Array([global_position.x, global_position.y, global_position.z, radius, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]).to_byte_array()
