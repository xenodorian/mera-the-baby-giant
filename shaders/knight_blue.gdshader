shader_type canvas_item;
// v0.4 Blue Knight: palette swap of the chierit Fire Knight (CC-BY 4.0, credit "chierit"). Warm, saturated pixels
// (his red armour, orange flames, gold trim) are hue-rotated into blues; greys, skin-dark outlines stay as they are.
uniform float hue_shift = 0.56;
uniform float lift = 1.08;
varying vec4 tint;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * clamp(p - 1.0, 0.0, 1.0);
}

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 h = rgb2hsv(t.rgb);
	if ((h.x < 0.17 || h.x > 0.88) && h.y > 0.22) {
		h.x = fract(h.x + hue_shift);
		h.z = min(h.z * lift, 1.0);
	}
	COLOR = vec4(hsv2rgb(h), t.a) * tint;
}
