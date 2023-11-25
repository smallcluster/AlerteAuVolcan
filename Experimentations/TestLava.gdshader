shader_type spatial;

uniform sampler2D noise;

uniform sampler2D lava_map;
uniform sampler2D normal_map;

uniform float treshold = 0.2;
uniform float rock_slope = 0.7;
uniform float speed = 0.1;
uniform float scale = 2.0;

uniform bool debug = false;
uniform bool normals = false;

varying vec3 norm_model;

void vertex(){
	norm_model = NORMAL;
}


void fragment() {
	
	vec2 uv = vec2(UV.x, UV.y);
	
	
	// Lava mask
	float density = texture(lava_map, uv).r;
	float mask = step(treshold, density);
	
	// Animated lava texture
	vec3 n = 2.0 * texture(normal_map, uv).rgb - vec3(1.0);
	
	vec2 f = n.rg;
	
	float anim = TIME * speed;
	vec2 uv1 = uv * scale + f * mod(anim, 1.0);
	vec2 uv2 = uv * scale + f * mod(anim+0.5, 1.0);
	
	vec3 lava1 = texture(noise, uv1).rgb * mask;
	vec3 lava2 = texture(noise, uv2).rgb * mask;
	
	float m = abs(mod(anim, 1.0) * 2.0 - 1.0);
	
	// Final lava color
	vec3 lava = mix(lava1, lava2, m);
	
	// Final color
	// vec3 color = lava + vec3(0.0, 0.5, 0.0) * (1.0-mask);
	
	float angle = norm_model.g;
	
	float grass = step(rock_slope, angle) * (1.0-mask);
	float rock = 1.0 - grass;


	float sand = step(0.4, distance(uv,vec2(0.5))) * max(step(0.45, distance(uv,vec2(0.5)) ) , step(0.9, norm_model.g*norm_model.g) );
	sand = sand * (1.0-mask);
	
	grass = grass * (1.0-sand);
	rock = (1.0-grass) * (1.0-sand);
	
	vec3 color =  vec3(0.0, 0.25, 0.0) * grass + lava * mask + vec3(0.1) * rock + vec3(0.5, 0.5, 0.2) * sand;
	
    
	EMISSION = debug ? vec3(0.0)  : 1.5 * lava * mask;
	
	ALBEDO = debug ? (normals ? norm_model : vec3(density))  : color;
	
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	METALLIC = 0.0;
}
