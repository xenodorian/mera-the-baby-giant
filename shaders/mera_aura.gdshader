shader_type canvas_item;
// Mera's body: red Fury aura (1 px outline that pulses + a warm red wash) and a white hit flash.
// Body frames are baked with 2 px of transparent padding so the outline is never clipped.
uniform float aura : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float time_s = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE;
	if (aura > 0.0) {
		float pulse = 0.65 + 0.35 * sin(time_s * 9.0);
		if (c.a < 0.01) {
			float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
				+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
			float n2 = texture(TEXTURE, UV + vec2(2.0 * px.x, 0.0)).a + texture(TEXTURE, UV - vec2(2.0 * px.x, 0.0)).a
				+ texture(TEXTURE, UV + vec2(0.0, 2.0 * px.y)).a + texture(TEXTURE, UV - vec2(0.0, 2.0 * px.y)).a;
			if (n > 0.0) { c = vec4(0.92, 0.10, 0.12, pulse * aura); }
			else if (n2 > 0.0) { c = vec4(0.55, 0.02, 0.08, 0.55 * pulse * aura); }
		} else {
			c.rgb = mix(c.rgb, vec3(0.85, 0.08, 0.10), 0.22 * aura * pulse);
		}
	}
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c * COLOR;
}
