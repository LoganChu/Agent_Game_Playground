shader_type canvas_item;
// Day 71: the world behind a memory played from the satchel (JournalUI's veil). The screen goes
// soft, drained toward a kindle-tinted grey and darker toward the edges, so the dialogue box reads
// as somewhere else: "a memory's own look". `amount` 0 = untouched, 1 = fully remembering.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.957, 0.835, 0.553, 1.0);

void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 1.5 * amount).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(c, grey * tint.rgb, 0.75 * amount);
	float edge = smoothstep(0.2, 0.75, length(UV - vec2(0.5)) * 1.2);
	col *= 1.0 - amount * (0.3 + 0.45 * edge);
	COLOR = vec4(col, 1.0);
}
