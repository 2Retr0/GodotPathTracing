@tool
class_name TriPathTraced extends ShapePathTraced

## Offset of first vertex
@export var a := Vector3(0, 0.433, 0) :
	set(value): a = value; changed.emit()
## Offset of second vertex
@export var b := Vector3(-0.5, -0.433, 0) :
	set(value): b = value; changed.emit()
## Offset of third vertex
@export var c := Vector3(0.5, -0.433, 0) :
	set(value): c = value; changed.emit()

func to_byte_array() -> PackedByteArray:
	var a_global := global_position + a;
	var b_global := global_position + b;
	var c_global := global_position + c;
	
	return PackedFloat32Array([a_global.x, a_global.y, a_global.z, 0.0, b_global.x, b_global.y, b_global.z, 0.0, c_global.x, c_global.y, c_global.z, 0.0]).to_byte_array()
