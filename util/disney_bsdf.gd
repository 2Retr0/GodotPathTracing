@tool
class_name DisneyBSDF extends Resource

@export_group('Diffuse')
@export_color_no_alpha var diffuse_color := Color.FLORAL_WHITE :
	set(value): diffuse_color = value; changed.emit()
@export_range(0, 1) var subsurface_scattering_strength := 0.15 :
	set(value): subsurface_scattering_strength = value; changed.emit()

@export_group('Specular')
@export_range(0, 1) var metallic_strength := 0.0 :
	set(value): metallic_strength = value; changed.emit()
@export_range(0, 1) var roughness_strength := 1.0 :
	set(value): roughness_strength = value; changed.emit()
@export_range(0, 1) var anisotropic_strength := 0.8 :
	set(value): anisotropic_strength = value; changed.emit()

@export_group('Clearcoat')
@export_range(0, 1) var clearcoat_gloss := 1.0 :
	set(value): clearcoat_gloss = value; changed.emit()
@export_range(0, 1) var clearcoat_strength := 0.0 :
	set(value): clearcoat_strength = value; changed.emit()

@export_group('Glass')
@export_range(0, 1) var specular_transmission_strength := 0.0 :
	set(value): specular_transmission_strength = value; changed.emit()
@export_range(0, 3) var index_of_refraction := 1.5 :
	set(value): index_of_refraction = value; changed.emit()

@export_group('Sheen')
@export_range(0, 1) var sheen_strength := 1.0 :
	set(value): sheen_strength = value; changed.emit()
@export_range(0, 1) var sheen_tint_strength := 1.0 :
	set(value): sheen_tint_strength = value; changed.emit()

@export_group('Light')
@export_range(0, 100) var light_strength := 0.0 :
	set(value): light_strength = value; changed.emit()

func to_byte_array() -> PackedByteArray:
	return PackedFloat32Array([diffuse_color.r, diffuse_color.g, diffuse_color.b, subsurface_scattering_strength, metallic_strength, roughness_strength*roughness_strength, anisotropic_strength, clearcoat_gloss, clearcoat_strength, specular_transmission_strength, index_of_refraction, sheen_strength, sheen_tint_strength, light_strength*light_strength + 1.0, 0.0, 0.0]).to_byte_array()
