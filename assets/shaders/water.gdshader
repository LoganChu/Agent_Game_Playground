// Emberwake water: flat-shaded low-poly waves, shallow→deep colour and a foam line where
// the sea meets the shore. Depth isn't read from the depth buffer (unavailable in the
// Compatibility renderer): scripts/world/water_builder.gd bakes each vertex's water depth
// over the sculpted ground into COLOR.r (0 = at the shoreline, 1 = DEEP metres or more).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.36, 0.64, 0.7, 1.0);
uniform vec4 deep_color : source_color = vec4(0.12, 0.23, 0.37, 1.0);
uniform vec4 foam_color : source_color = vec4(0.93, 0.9, 0.84, 1.0);
uniform float foam_width = 0.13;   // normalised depth covered by the shore foam
uniform float wave_height = 0.07;  // metres, full height only in deep water
uniform float wash_strength = 1.0; // the broken foam lines washing in (0 = none: still water)
uniform vec4 sheen_color : source_color = vec4(0.78, 0.8, 0.83, 1.0);
uniform float mirror = 0.0;        // 0..1: still water taking the sky's colour at a glancing look

varying vec3 world_pos;
varying float depth;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	depth = COLOR.r;
	// Swell grows with depth, so the shoreline (and the foam on it) stays put.
	float swell = sin(TIME * 0.9 + world_pos.x * 0.45 + world_pos.z * 0.2)
			+ sin(TIME * 0.7 - world_pos.z * 0.6 + world_pos.x * 0.15) * 0.6;
	VERTEX.y += swell * wave_height * smoothstep(0.1, 0.8, depth);
}

void fragment() {
	// Faceted normal from the screen-space derivatives: each triangle catches light flat.
	vec3 n_flat = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = dot(n_flat, VIEW) < 0.0 ? -n_flat : n_flat;
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.05, 0.85, depth));
	float n = value_noise(world_pos.xz * 0.8 + vec2(TIME * 0.12, TIME * 0.05));
	// Shore foam: a ragged band that breathes with the noise.
	float edge = foam_width * (0.55 + 0.7 * n);
	float foam = 1.0 - smoothstep(edge * 0.55, edge, depth);
	// A second, broken line washing in towards the shore.
	float wash = fract(depth * 3.5 - TIME * 0.18);
	float line = smoothstep(0.9, 0.97, wash) * (1.0 - smoothstep(0.15, 0.5, depth)) * step(0.45, n);
	foam = max(foam, line * 0.8 * wash_strength);
	// Still water: a glancing look sees the sky (a fresnel-ish blend), nearly black straight down.
	float glance = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	col = mix(col, sheen_color.rgb, mirror * clamp(0.15 + glance * 1.2, 0.0, 0.92));
	ALBEDO = mix(col, foam_color.rgb, foam);
	ROUGHNESS = mix(mix(0.22, 0.05, mirror), 0.9, foam);
	SPECULAR = 0.45;
	ALPHA = max(mix(0.72, 0.95, smoothstep(0.0, 0.6, depth)), foam);
}
