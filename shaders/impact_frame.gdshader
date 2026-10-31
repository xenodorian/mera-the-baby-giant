shader_type canvas_item;
// v0.8 SUPER EARTHQUAKE impact frame: the whole screen as a hard black/white silhouette (anime "impact frame").
// invert = 1: bright -> black, dark -> white (first beat); invert = 0: plain high-contrast black/white (second beat).
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float invert = 1.0;
uniform float threshold = 0.22;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float v = step(threshold, l);
	v = mix(v, 1.0 - v, invert);
	COLOR = vec4(vec3(v), 1.0);
}
