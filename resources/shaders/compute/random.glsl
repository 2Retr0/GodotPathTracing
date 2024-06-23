#define PI (3.14159265359)

float seed = 0.0; // Seed used for random number generation

// Source: https://www.shadertoy.com/view/Xt3cDn
uint hash(vec2 x) {
	uvec2 p = floatBitsToUint(x);
    p = 1103515245U * ((p >> 1U) ^ p.yx);
    uint h32 = 1103515245U * (p.x ^ (p.y >> 3U));
    return h32 ^ (h32 >> 16);
}

// Source: https://www.shadertoy.com/view/Xt3cDn
vec2 hash2(inout float seed) {
    uint n = hash(vec2(seed += 0.1, seed += 0.1));
    uvec2 rz = uvec2(n, n*48271U);
    return vec2(rz & uvec2(0x7FFFFFFFU)) / float(0x7FFFFFFF);
}

// // Source: https://www.shadertoy.com/view/Xt3cDn
// vec3 hash3(inout float seed) {
//     uint n = hash(vec2(seed += 0.1, seed += 0.1));
//     uvec3 rz = uvec3(n, n*16807U, n*48271U);
//     return vec3(rz & uvec3(0x7FFFFFFFU)) / float(0x7FFFFFFF);
// }

// Source: https://github.com/LWJGL/lwjgl3-demos/blob/main/res/org/lwjgl/demo/opengl/raytracing/randomCommon.glsl
vec3 random_in_unit_sphere(inout float seed) {
    vec2 h = hash2(seed) * vec2(PI, 1)*2.0 - vec2(0, 1);
	return vec3(sqrt(1.0 - h.y*h.y) * vec2(cos(h.x), sin(h.x)), h.y);
}

vec3 random_in_unit_hemisphere(in vec3 normal, inout float seed) {
    vec3 r = random_in_unit_sphere(seed);
    return r * -sign(dot(r, normal));
}

vec3 random_cos_weighted_hemisphere_direction( const vec3 n, inout float seed ) {
  	vec2 r = hash2(seed);
	vec3  uu = normalize(cross(n, abs(n.y) > .5 ? vec3(1.,0.,0.) : vec3(0.,1.,0.)));
	vec3  vv = cross(uu, n);
	float ra = sqrt(r.y);
	float rx = ra*cos(6.28318530718*r.x); 
	float ry = ra*sin(6.28318530718*r.x);
	float rz = sqrt(1.-r.y);
	vec3  rr = vec3(rx*uu + ry*vv + rz*n);
    return normalize(rr);
}