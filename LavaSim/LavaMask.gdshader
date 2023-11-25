shader_type canvas_item;

uniform sampler2D lava_map;
uniform float treshold = 0.2;

void fragment() {
	float density = texture(lava_map, UV.xy).r;
	float mask = step(treshold, density);
	COLOR = vec4(vec3(mask), 1.0);
}
