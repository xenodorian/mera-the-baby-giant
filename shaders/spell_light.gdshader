shader_type canvas_item;
render_mode blend_add;
// additive beam halo; deep red in Fury mode
uniform float fury : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (fury > 0.5) {
		float l = max(c.r, max(c.g, c.b));
		c.rgb = vec3(l * 1.6, l * 0.12, l * 0.16);
	}
	COLOR = vec4(c.rgb * c.a, c.a);
}
