// Emberwake sky: a painted gradient (zenith → horizon mist) with a soft sun halo and a few
// slow, flat cloud bands near the horizon. No textures; works in the Compatibility renderer.
// Colours come from the region's `light` mood (scripts/world/atmosphere.gd tweens them).
shader_type sky;

uniform vec4 sky_top : source_color = vec4(0.24, 0.49, 0.65, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.78, 0.8, 0.83, 1.0);
uniform vec4 sun_color : source_color = vec4(0.96, 0.84, 0.55, 1.0);
uniform float sun_halo = 0.35;     // brightness of the glow around the sun
uniform float cloud_amount = 0.5;  // 0 = clear, 1 = heavy banks

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

void sky() {
	float up = EYEDIR.y;
	// Horizon mist rises a little above 0 so the sea melts into it; below the horizon is mist.
	float t = smoothstep(0.02, 0.55, up);
	vec3 col = mix(sky_horizon.rgb, sky_top.rgb, t);
	// Low, flat cloud bands (stylized: hard-ish edges, drifting slowly).
	// Polar mapping (direction around the horizon × height) is seamless all the way round.
	float spin = TIME * 0.004;
	vec2 around = normalize(EYEDIR.xz + vec2(1e-4)) * mat2(vec2(cos(spin), -sin(spin)), vec2(sin(spin), cos(spin)));
	vec2 cp = around * (4.0 + up * 14.0);
	float n = value_noise(cp) * 0.65 + value_noise(cp * 2.1 + 3.7) * 0.35;
	float band = smoothstep(0.03, 0.1, up) * (1.0 - smoothstep(0.16, 0.34, up));
	float cloud = smoothstep(0.62 - cloud_amount * 0.25, 0.7 - cloud_amount * 0.25, n) * band;
	col = mix(col, mix(sky_horizon.rgb, vec3(1.0), 0.35), cloud * 0.7);
	// Sun halo (the disc itself stays hidden: the Greying never quite lets it through).
	if (LIGHT0_ENABLED) {
		float d = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
		col += sun_color.rgb * (pow(d, 24.0) * 0.6 + pow(d, 4.0) * 0.25) * sun_halo;
	}
	COLOR = col;
}
