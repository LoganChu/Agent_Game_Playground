// An inspectable's glint (scripts/world/glint.gd): a small four-point star that faces the
// camera, twinkles every few seconds and otherwise barely shows. Alpha-blended (additive vanished
// on pale ground), HDR-bright so it blooms with glow in Forward+, unshaded, depth
// tested (walls hide it), no textures — works in the Compatibility renderer.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 glint_color : source_color = vec4(0.96, 0.84, 0.55, 1.0);
uniform float strength = 1.0;  // 0..1, set by distance to the player
uniform float period = 3.2;    // seconds between twinkles
uniform float rest = 0.35;     // brightness between twinkles

varying float phase;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	phase = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
	// Billboard: keep the quad facing the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float t = fract(TIME / period + phase);
	// A quick swell and fade at the start of each period.
	float flash = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.06, 0.24, t));
	float level = mix(rest, 1.0, flash);
	// Turn the star a little as it flashes.
	float a = flash * 0.6;
	d = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * d;
	float rays = 0.015 / (abs(d.x * d.y) + 0.015);
	float core = 1.0 - smoothstep(0.0, 0.35, length(d));
	float fade = 1.0 - smoothstep(0.4, 1.0, length(d));
	float lum = (rays * mix(0.4, 1.0, flash) + core) * fade * level * strength;
	ALBEDO = mix(glint_color.rgb, vec3(1.0), core) * mix(1.0, 1.8, flash);
	ALPHA = clamp(lum, 0.0, 1.0);
}
