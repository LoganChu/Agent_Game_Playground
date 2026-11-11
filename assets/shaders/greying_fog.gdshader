// The Greying: stacked, ground-hugging fog layers (see scripts/world/greying_fog.gd).
// UV2 carries each vertex's fog depth × layer weight (old cut, new cut; COLOR.a = new too), baked from the same
// Greying.area_depth the gameplay uses, so what you see is where the ember drains.
// No textures or depth buffer: works in the Compatibility renderer too.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 fog_color : source_color = vec4(0.78, 0.8, 0.83, 1.0);
uniform float opacity = 1.0;   // tweened for fade in/out when the story changes the areas
uniform float thin = 1.0;      // the whole Greying thinned after the ending (Day 97, game.json after_the_ember)
uniform float recut = 1.0;     // 0 → 1 dissolves the old lantern cut (UV2.x) into the new (UV2.y)
uniform float drift = 0.12;    // wind speed of the noise, m/s-ish
// The ember's pool (Greying.ember_pool_push): xyz = the Wakebearer's hand, w = radius (0 = none).
uniform vec4 ember_pool = vec4(0.0);
uniform float ember_push = 0.0;
// The leaning wall of fog at the pool's edge catches the ember's light (a faint warm rim).
uniform vec4 ember_tint : source_color = vec4(1.0, 0.6, 0.28, 1.0);
uniform float ember_rim = 0.32;

varying vec3 world_pos;

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
	// Slow swell so the layers never read as flat sheets.
	VERTEX.y += sin(TIME * 0.45 + world_pos.x * 0.35 + world_pos.z * 0.2) * 0.12;
}

void fragment() {
	vec2 p = world_pos.xz * 0.28 + vec2(TIME * drift, TIME * drift * 0.4);
	float n = value_noise(p) * 0.6 + value_noise(p * 2.3 - vec2(TIME * drift * 0.7)) * 0.4;
	float a = mix(UV2.x, UV2.y, recut) * opacity * thin * mix(0.35, 1.0, n);
	// Fade layers right in front of the camera so walking into the fog doesn't hit a wall.
	a *= smoothstep(0.4, 4.0, -VERTEX.z);
	vec3 col = fog_color.rgb;
	// The ember's pool: the fog thins round the hand (the edge ragged with the same noise, so it reads
	// as fog leaning away, not a cut-out disc) and its leaning wall catches the light.
	if (ember_pool.w > 0.0) {
		float d = distance(world_pos.xz, ember_pool.xz) + (n - 0.5) * ember_pool.w * 0.25;
		a *= 1.0 - ember_push * (1.0 - smoothstep(ember_pool.w * 0.35, ember_pool.w, d));
		float rim = smoothstep(ember_pool.w * 0.35, ember_pool.w * 0.8, d) * (1.0 - smoothstep(ember_pool.w * 0.8, ember_pool.w * 1.5, d));
		col = mix(col, ember_tint.rgb, rim * ember_rim * ember_push);
	}
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
