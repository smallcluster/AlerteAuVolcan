shader_type spatial;

uniform sampler2D noise;
uniform sampler2D lava_map;
uniform float treshold = 0.2;


void fragment() {
	vec2 uv = vec2(UV.x, UV.y);
	float density = texture(lava_map, uv).r;
	float mask = step(treshold, density);
	vec3 lava = texture(noise, uv * vec2( 1.0+sin(TIME * 0.2+3.0)*0.15, 1.0+sin(TIME * 0.2)*0.2)).rgb * mask * 1.5;
    
	EMISSION = lava;
	ALBEDO = lava;
}
