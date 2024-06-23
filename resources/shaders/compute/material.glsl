#define PI (3.14159265359)

// --- MATERIAL HELPER FUNCTIONS ---
/** Calculates Fresnel reflectance for dielectrics */
float fresnel(vec2 z, vec2 cos_theta) {
	vec2 a = z*cos_theta;
	float b = (a.x - a.y) / (a.x + a.y);
	return b*b;
}

float schlick_weight(in float cos_theta) {
	float f = 1.0 - cos_theta;
	float f_sq = f*f;
	return f_sq*f_sq*f;
}

/** Schlick Fresnel approximation */
float schlick_fresnel(in float base_reflectance, in float max_reflectance, in float weight) {
	return base_reflectance + (max_reflectance - base_reflectance) * weight;
}

/** Isotropic Generalized Trowbridge-Reitz distribution (gamma=1) */
// `h` is the halfway vector projected to tangent space.
float gtr1_distribution(in float alpha, in vec3 h) {
	float a = alpha*alpha;
	float b = a - 1.0;
	return b / (PI*log2(a) * (1.0 + b*h.z*h.z));
}

/** Anisotropic Generalized Trowbridge-Reitz distribution (gamma=2) (GGX) */
// `h` is the halfway vector projected to tangent space.
float gtr2_distribution(in vec2 alpha, in vec3 h) {
	vec2 a = h.xy/alpha;
	float b = a.x*a.x + a.y*a.y + h.z*h.z;
	return 1.0 / (PI*alpha.x*alpha.y * b*b);
}

/** Anisotropic Smith Masking-Shadowing function */
// `w` is a vector projected to tangent space.
float smith_masking_shadowing(vec2 alpha, vec3 w) {
	vec2 a = w.xy*alpha;
	return 2.0 / (1.0 + sqrt(1.0 + (a.x*a.x + a.y*a.y)/(w.z*w.z)));
}

// --- DISNEY BSDF ---
struct DisneyBSDFAttributes {
	// Diffuse
    vec3 diffuse_color;
    float subsurface_scattering_strength;
    // Specular
    float metallic_strength;
    float roughness_strength;
    float anisotropic_strength;
    // Clearcoat
    float clearcoat_gloss;
    float clearcoat_strength;
    // Glass
    float specular_transmission_strength;
    float index_of_refraction;
    // Sheen
    float sheen_strength;
	float sheen_tint_strength;
	// Light
	float light_strength;
	float _pad1;
	float _pad2;
};

struct DisneyBSDFWeights {
	float diffuse;
	float glass;
	float specular;
	float clearcoat;
	float sheen;
};

mat3 get_tangent_matrix(vec3 normal) {
    vec3 tangent = normalize(vec3(0., normal.z, -normal.y));
    vec3 binormal = cross(normal, tangent);
    return transpose(mat3(tangent, binormal, normal));
}

vec3 disney_bsdf(in DisneyBSDFAttributes attributes, in DisneyBSDFWeights weights, in vec3 light, in vec3 view, in vec3 normal) {
    vec3 col = vec3(0.0);
    vec3 halfway = normalize(light + view);

    mat3 tangent_matrix = get_tangent_matrix(normal);
	vec3 halfway_tangent = tangent_matrix*halfway;
	vec3 light_tangent = tangent_matrix*light;
	vec3 view_tangent = tangent_matrix*view;

    float dot_hl = abs(dot(halfway, light));
    float dot_hv = abs(dot(halfway, view));
	float dot_nl = abs(dot(normal, light));
    float dot_nv = abs(dot(normal, view));
	
	float fl = schlick_weight(dot_nl);
	float fv = schlick_weight(dot_nv);
	float fh = schlick_weight(dot_hl);
    
	const float luminance = dot(vec3(0.299, 0.587, 0.114), attributes.diffuse_color);
	const vec3 tint = (luminance > 0.0) ? attributes.diffuse_color / luminance : vec3(1.0);

	// --- SHEEN ---
    vec3 sheen = mix(vec3(1.0), tint, attributes.sheen_tint_strength) * fh;
    col += sheen * weights.sheen;

    // --- DIFFUSE ---
	vec3 roughness_color = attributes.diffuse_color;//mix(reflection_color, attributes.diffuse_color, roughness_strength)/**ALBEDO*/;
	float sss_reflectance = attributes.roughness_strength * dot_hl*dot_hl;
	float retro_reflectance = 0.5 + 2.0*sss_reflectance;
	float diffuse_base = schlick_fresnel(1.0, retro_reflectance, fl)*schlick_fresnel(1.0, retro_reflectance, fv);
	float diffuse_sss = 1.25*(schlick_fresnel(1.0, sss_reflectance, fl)*schlick_fresnel(1.0, sss_reflectance, fv)*(1.0/(dot_nl + dot_nv) - 0.5) + 0.5);
	vec3 diffuse = (roughness_color/PI) * mix(diffuse_base, diffuse_sss, attributes.subsurface_scattering_strength);
	col += diffuse * weights.diffuse;

    // --- CLEARCOAT ---
	if (weights.clearcoat > 0.0) {
		float alpha_clearcoat = mix(1e-1, 1e-3, attributes.clearcoat_gloss);
		// Reflectance is hardcoded for an index of refraction=1.5 and alpha is hardcoded to alpha=0.25.
		float fresnel_clearcoat = schlick_fresnel(0.04, 1.0, fh);
		float microfacet_distribution_clearcoat = gtr1_distribution(alpha_clearcoat, halfway_tangent);
		float geometric_attenuation_clearcoat = smith_masking_shadowing(vec2(0.25), light_tangent) * smith_masking_shadowing(vec2(0.25), view_tangent);
		float clearcoat = fresnel_clearcoat*microfacet_distribution_clearcoat*geometric_attenuation_clearcoat;
		col += 0.25 * clearcoat * weights.clearcoat;
	}

	if (weights.diffuse == 1.0) return min(col, vec3(1.0));

	// --- SPECULAR ---		
	const vec2 eta = vec2(attributes.index_of_refraction, 1.0);
	const float aspect = sqrt(1.0 - 0.9*attributes.anisotropic_strength);
	const vec2 alpha_specular = max(vec2(1e-4), vec2(1.0/aspect, aspect)*attributes.roughness_strength*attributes.roughness_strength);
	const float specular_tint_strength = 1.0; // Hardcoded! ...Because too many parameters :(
	const float specular_strength = 1.0 - attributes.roughness_strength; // Hardcoded!

	float specular_reflectance = fresnel(vec2(1), eta);
	vec3 specular_col = mix(specular_strength*specular_reflectance*mix(vec3(1.0), tint, specular_tint_strength), /* reflection_color */attributes.diffuse_color, attributes.metallic_strength);
	
	vec3 fresnel_specular = specular_col + (1.0 - specular_col)*fh;
	float microfacet_distribution_specular = gtr2_distribution(alpha_specular, halfway_tangent);
	float geometric_attenuation_specular = smith_masking_shadowing(alpha_specular, light_tangent) * smith_masking_shadowing(alpha_specular, view_tangent);
	vec3 specular = fresnel_specular*microfacet_distribution_specular*geometric_attenuation_specular;
	col += specular * weights.specular * 0.25;

	if (weights.glass == 0.0) return min(col, vec3(1.0));
	// --- GLASS ---
	vec3 glass = vec3(microfacet_distribution_specular*geometric_attenuation_specular);
	vec2 dot_l = vec2(dot_hv, dot_hl);
	float reflectance_s = fresnel(eta.yx, dot_l);
	float reflectance_p = fresnel(eta.xy, dot_l);

	float fresnel_glass = 0.5*(reflectance_s*reflectance_s + reflectance_p*reflectance_p);
	if (dot_nl * dot_nv > 0.0) {
		glass *= 0.25*attributes.diffuse_color * fresnel_glass;
	} else {
		float rd = dot_hv + attributes.index_of_refraction*dot_hl;
		glass *= sqrt(attributes.diffuse_color) * (1.0 - fresnel_glass) * abs(dot_hv*dot_hl)/(rd*rd);
	}
	col += (0.9 + glass)/** glass*/ * weights.glass;

    return min(col, vec3(1.0));
}

vec3 disney_bsdf_sample(in DisneyBSDFAttributes attributes, out bool has_scattered, out vec3 light, in vec3 view, in vec3 normal) {	
	DisneyBSDFWeights weights;
	weights.glass = attributes.specular_transmission_strength*(1.0 - attributes.metallic_strength);
	if (dot(-view, normal) <= 0.0) {
		weights.diffuse = (1.0 - attributes.specular_transmission_strength)*(1.0 - attributes.metallic_strength);
		weights.specular = 1.0 - weights.glass;
		weights.clearcoat = 0.25 * attributes.clearcoat_strength;
		weights.sheen = (1.0 - attributes.metallic_strength) * attributes.sheen_strength;
	}
	float weight_norm = 1.0 / (weights.diffuse + weights.glass + weights.specular + weights.clearcoat);

	float cdf[4];
	cdf[0] = weights.diffuse*weight_norm;
	cdf[1] = cdf[0] + weights.glass*weight_norm;
	cdf[2] = cdf[1] + weights.specular*weight_norm;
	cdf[3] = cdf[2] + weights.clearcoat*weight_norm;

	vec2 rand = hash2(seed);
	has_scattered = attributes.light_strength <= 1.0;
	if (rand.x <= cdf[0]) {
		light = normalize(normal + random_in_unit_sphere(seed));
	} else if (rand.x <= cdf[1]) {
		bool is_front_face = dot(-view, normal) <= 0.0;
		attributes.index_of_refraction = is_front_face ? 1.0/attributes.index_of_refraction : attributes.index_of_refraction;

		float cos_theta = dot(view, normal);
		float sin_theta = sqrt(1.0 - cos_theta*cos_theta);
		bool should_refract = attributes.index_of_refraction*sin_theta < 1.0;
		if (!should_refract || schlick_fresnel(fresnel(vec2(1, attributes.index_of_refraction), vec2(1)), 1.0, schlick_weight(cos_theta)) > rand.y) {
			light = normalize(reflect(-view, normal) + (attributes.roughness_strength * random_in_unit_sphere(seed)));
		} else {
			light = normalize(refract(-view, normal, attributes.index_of_refraction) + (attributes.roughness_strength * random_in_unit_sphere(seed)));
		}
	} else if (rand.x <= cdf[2]) {
		light = normalize(reflect(-view, normal) + (attributes.roughness_strength * random_in_unit_sphere(seed)));
		has_scattered = has_scattered && dot(light, normal) > 0.0;
	} else/**(rand.x <= cdf[3])*/{
		light = normalize(reflect(-view, normal) + ((1.0 - attributes.clearcoat_gloss) * random_in_unit_sphere(seed)));
	}

	return disney_bsdf(attributes, weights, light, view, normal);
}