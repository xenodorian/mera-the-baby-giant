shader_type canvas_item;
render_mode blend_add;
// front layer of shaders/fury_flame.gdshader (same code, additive)
// Kaioken-style Fury flame around Mera, drawn procedurally on a blank texture of FW x FH native px so every flame
// pixel is one art pixel (the sprite is scaled with Mera). Rising tongues = value-noise fbm scrolled upward plus
// a few sine tongues, stepped at 12 fps for a hand-animated flicker, quantised onto a dark-red -> red -> orange ramp.
// layer 0 = back flame (behind her, normal blend, full ramp); layer 1 = front flame (over her, additive, only the
// thin bright tongues), set by the material's blend mode below via `front`.
uniform float front = 1.0;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform vec2 size = vec2(72.0, 104.0);
uniform float seed = 0.0;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return 0.55 * vn(p) + 0.3 * vn(p * 2.1 + 3.1) + 0.15 * vn(p * 4.3 + 7.7); }

void fragment() {
	vec2 px = floor(UV * size);
	vec2 uv = (px + 0.5) / size;
	float t = floor(TIME * 12.0) / 12.0;
	float x = (uv.x - 0.5) * 2.0;           // -1..1
	float y = 1.0 - uv.y;                    // 0 = bottom (feet), 1 = top
	float n = fbm(vec2(x * 2.4, y * 3.0 - t * 2.6));
	float n2 = fbm(vec2(x * 5.5 + 11.0, y * 5.0 - t * 4.2));
	// onion-shaped body of flame around her, the top broken into rising tongues
	float w = (0.5 + 0.42 * sin(3.14159 * min(y * 1.6, 1.0))) * (1.0 - 0.7 * smoothstep(0.45, 1.0, y));
	w *= 0.9 + 0.25 * (n - 0.5);
	float tong = pow(0.5 + 0.5 * sin(x * 12.0 + n * 5.5 + t * 3.0), 4.0) * (0.6 + 0.8 * n2);
	float top = 0.58 + 0.34 * tong + 0.18 * (n2 - 0.5);
	float ds = abs(x) / max(w, 0.05);
	float v = step(ds, 1.0) * step(y, top) * smoothstep(0.0, 0.05, y);
	float ring = max(smoothstep(0.45, 0.98, ds), smoothstep(top - 0.22, top, y));
	float e = v * (0.3 + 0.75 * ring + 0.25 * (n2 - 0.5));
	vec3 c = vec3(0.0); float a = 0.0;
	if (front < 0.5) {
		if (e > 0.10) { c = vec3(0.30, 0.0, 0.05); a = 0.45; }
		if (e > 0.30) { c = vec3(0.56, 0.03, 0.07); a = 0.75; }
		if (e > 0.50) { c = vec3(0.86, 0.10, 0.10); a = 0.92; }
		if (e > 0.72) { c = vec3(1.0, 0.32, 0.15); a = 1.0; }
		if (e > 0.92) { c = vec3(1.0, 0.66, 0.30); a = 1.0; }
	} else {
		// front: the outer tongues licking over her outline, additive and dim
		if (e > 0.62 && e < 0.86) { c = vec3(0.32, 0.03, 0.02); a = 1.0; }
		if (e > 0.74 && e < 0.82) { c = vec3(0.55, 0.14, 0.04); a = 1.0; }
	}
	COLOR = vec4(c, a * amount);
}
