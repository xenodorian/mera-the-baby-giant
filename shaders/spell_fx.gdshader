shader_type canvas_item;
// Mera's spell effects (slashes, charge orbs, beams, shots, explosions, lightning, barrier).
// fury = 1: every pixel is remapped by brightness onto a deep-red ramp (Fury mode).
// remap = 1: map a foreign palette (the blue ansimuz electro-shock) onto the explosion palette.
uniform float fury : hint_range(0.0, 1.0) = 0.0;
uniform int remap = 0;

vec3 warm(float l) {
	if (l < 0.22) return vec3(105.0, 27.0, 43.0) / 255.0;
	if (l < 0.40) return vec3(163.0, 33.0, 33.0) / 255.0;
	if (l < 0.58) return vec3(207.0, 86.0, 56.0) / 255.0;
	if (l < 0.78) return vec3(250.0, 169.0, 83.0) / 255.0;
	return vec3(255.0, 248.0, 230.0) / 255.0;
}
vec3 deep_red(float l) {
	if (l < 0.16) return vec3(46.0, 3.0, 10.0) / 255.0;
	if (l < 0.30) return vec3(84.0, 5.0, 14.0) / 255.0;
	if (l < 0.46) return vec3(128.0, 8.0, 18.0) / 255.0;
	if (l < 0.64) return vec3(172.0, 14.0, 22.0) / 255.0;
	if (l < 0.82) return vec3(214.0, 32.0, 30.0) / 255.0;
	return vec3(255.0, 110.0, 96.0) / 255.0;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (remap == 1) { c.rgb = warm(l); }
	if (fury > 0.5) { c.rgb = deep_red(l); }
	COLOR = c;
}
