// A lantern's halo (scripts/world/lantern_halo.gd): a soft round glow that faces the camera,
// breathing a little like a flame. Faint close up (the glass itself does the work there), full
// from the middle distance on, so a lantern reads across a clearing or through the fog.
// Alpha-blended, unshaded, depth tested, no textures — works in the Compatibility renderer.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 halo_color : source_color = vec4(0.96, 0.84, 0.55, 1.0);
uniform float strength = 0.8;
uniform float near_fade = 2.5;  // metres from the camera where the halo starts to show
uniform float full_at = 9.0;    // ...and where it is at full strength
uniform float bloom = 0.0;      // a wide, faint glow over the whole quad: the fog lit round a beacon

varying float phase;
varying float dist;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	phase = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.283;
	dist = length((VIEW_MATRIX * vec4(origin, 1.0)).xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float flicker = 0.9 + 0.06 * sin(TIME * 7.3 + phase) + 0.04 * sin(TIME * 13.1 + phase * 2.0);
	float glow = pow(max(1.0 - r, 0.0), 2.2);
	float core = 1.0 - smoothstep(0.0, 0.18, r);
	float near = smoothstep(near_fade, full_at, dist);
	ALBEDO = mix(halo_color.rgb, vec3(1.0, 0.95, 0.85), core * 0.6) * 1.6;
	float wide = bloom * (1.0 - smoothstep(0.0, 1.0, r)) * (1.0 - smoothstep(0.0, 1.0, r));
	ALPHA = clamp((glow * 0.8 + core * 0.4 + wide) * strength * flicker * mix(0.25, 1.0, near), 0.0, 1.0);
}
