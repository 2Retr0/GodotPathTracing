@tool
class_name ShapePathTraced extends Node3D

signal changed

@export var material := DisneyBSDF.new() :
	set(value):
		material = value if value else DisneyBSDF.new()

func _ready() -> void:
	await get_tree().create_timer(0.1).timeout
	material.changed.connect(func(): changed.emit())
	visibility_changed.connect(func(): changed.emit())

@onready var previous_position := global_position

func _physics_process(delta: float) -> void:
	if global_position != previous_position:
		changed.emit()
		previous_position = global_position

func to_byte_array() -> PackedByteArray:
	return PackedByteArray()
