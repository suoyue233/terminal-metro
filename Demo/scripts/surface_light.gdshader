shader_type canvas_item;
render_mode unshaded;

uniform vec2 interior_size;
uniform vec2 lamp_position;
uniform float facing = 1.0;
uniform bool lamp_on = false;

void fragment() {
	vec2 point = UV * interior_size;
	vec2 offset = point - lamp_position;
	float lit = 0.0;
	if (lamp_on && offset.y > -74.0 && offset.y < 38.0) {
		float distance_ahead = offset.x * facing;
		float cone_width = 9.0 + max(0.0, distance_ahead) * 0.43;
		float cone = (1.0 - smoothstep(cone_width - 6.0, cone_width + 11.0, abs(offset.y)));
		cone *= smoothstep(-8.0, 14.0, distance_ahead) * (1.0 - smoothstep(111.0, 198.0, distance_ahead));
		float nearby = (1.0 - smoothstep(17.0, 63.0, length(offset))) * 0.76;
		lit = max(cone, nearby);
	}
	vec3 shade = mix(vec3(0.039, 0.032, 0.066), vec3(0.99, 0.76, 0.46), lit);
	COLOR = vec4(shade, mix(0.86, 0.12, lit));
}
