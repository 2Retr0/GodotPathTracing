struct Sphere {
	vec3 position;
	float radius;
    vec4 _pad0;
    vec4 _pad1;
};

struct Tri {
	vec3 a;
	float _pad0;
	vec3 b;
	float _pad1;
	vec3 c;
	float _pad2;
};


// Source: https://iquilezles.org/articles/intersectors/
float sphere_intersect(in vec3 ro, in vec3 rd, in Sphere sphere) {
    vec3 oc = ro - sphere.position;
    float b = dot(oc, rd);
    vec3 qc = oc - b*rd;
    float h = sphere.radius*sphere.radius - dot(qc, qc);
	h = sqrt(h);
	return min(-b-h, -b+h);
}

vec3 sphere_normal(in vec3 hit_pos, in Sphere sphere) {
	return (hit_pos - sphere.position) / sphere.radius;
}

// Source: https://iquilezles.org/articles/intersectors/
float tri_intersect(in vec3 ro, in vec3 rd, in Tri tri) {
    vec3 ba = tri.b - tri.a;
    vec3 ca = tri.c - tri.a;
    vec3 ra = ro - tri.a;
    vec3  n = cross(ba, ca);
    vec3  q = cross(ra, rd);
    float d = 1.0 / dot(rd, n);
    float u = dot(-q, ca) * d;
    float v = dot( q, ba) * d;
    float t = dot(-n, ra) * d;
    if(min(u, v) < 0.0 || (u+v) > 1.0) t = -1.0;
    return t; //vec3(t, u, v);
}

vec3 tri_normal(in Tri tri) {
    vec3 ba = tri.b - tri.a;
    vec3 ca = tri.c - tri.a;
	return normalize(cross(ba, ca) + 1e-10);
}