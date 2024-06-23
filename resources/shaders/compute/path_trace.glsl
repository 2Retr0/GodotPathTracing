#[compute]
#version 460

#include "random.glsl"
#include "material.glsl"
#include "intersection.glsl"

#define MAX_BOUNCES (7)
#define PI    (3.14159265359)
#define T_MAX (1e10)

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout (std140, set = 0, binding = 0) restrict readonly uniform Uniforms {
	vec3 light_dir;
	uint frame;
	float time;
	uint num_objects;
	uint tris_offset;
};

layout (std140, set = 0, binding = 1) readonly uniform Spheres {
	Sphere spheres[100];
};

layout (std140, set = 0, binding = 1) readonly uniform Tris {
	Tri tris[100];
};

layout (std140, set = 0, binding = 2) restrict readonly uniform Materials {
	DisneyBSDFAttributes materials[100];
};

layout(rgba16f, set = 0, binding = 3) uniform restrict image2D render_texture;

layout(push_constant) restrict readonly uniform PushConstants {
	mat4 inv_view_matrix;
	mat4 inv_projection_matrix;
};

#define intersect(start, end, shape_intersect, shape_buffer) \
for (uint i = start; i < end; ++i) { \
	float t = shape_intersect(ro, rd, shape_buffer[i]); \
	if (t > 1e-4 && t < t_min) { t_min = t; hit_index = i;}}
vec3 get_color(in vec3 ro, in vec3 rd) {
	bool has_scattered = true;
	vec3 energy = vec3(1.0);
	vec3 emitted = vec3(0.0);
	for (int bounce = 0; bounce < MAX_BOUNCES && dot(energy, energy) >= 1e-3 && has_scattered; ++bounce) {
		float t_min = T_MAX;
		uint hit_index = 0;
		intersect(0, tris_offset, sphere_intersect, spheres);
		intersect(tris_offset, num_objects, tri_intersect, tris);

		if (t_min != T_MAX) {
			ro = ro + t_min*rd;
			vec3 normal = hit_index < tris_offset ? sphere_normal(ro, spheres[hit_index]) : tri_normal(tris[hit_index]);
			float front_face = dot(rd, normal);
			normal *= -sign(front_face);

			vec3 light;
			DisneyBSDFAttributes material = materials[hit_index];
			vec3 attenuation = disney_bsdf_sample(material, has_scattered, light, -rd, normal);
			// light = normalize(normal + random_in_unit_hemisphere(normal, seed));
			// col *= 0.5;
			rd = light;
			
			emitted += energy * attenuation*(material.light_strength - 1.0);
			energy *= attenuation + emitted;
		} else break;
	}
	return emitted;
}

void main() {
	const ivec2 dims = imageSize(render_texture);
	const ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(id, dims))) return;

	seed = float(hash(id)) / float(0xFFFFFFFFU) + time;

	vec2 uv = (vec2(id) + hash2(seed)-0.5) / vec2(dims) * 2.0 - 1.0;
	uv.y *= -1.0;

	vec3 ro = inv_view_matrix[3].xyz;
	vec3 rd = normalize((inv_view_matrix * vec4((inv_projection_matrix * vec4(uv, 0, 1)).xyz, 0.0)).xyz);
	vec3 col = get_color(ro, rd);

	// float t = 0.5*rd.y + 0.5;
	// col *= mix(vec3(1.0), vec3(0.5,0.7,1.0), t);

	col += imageLoad(render_texture, id).rgb;
	imageStore(render_texture, id, vec4(col, float(frame) + 1.0));
}