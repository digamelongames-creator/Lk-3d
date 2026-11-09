shader_type spatial;
// Contorno de un enemigo (carcasa invertida): el modelo, un poco más gordo, de un solo color y solo por detrás.
// Se pone como material_overlay en sus mallas. El grosor va en metros y no depende de la escala del modelo.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.08, 0.04, 1.0);
uniform float grosor = 0.03;
// la carcasa se aparta un poco de la cámara: así solo asoma por el borde y no por los huecos del modelo
uniform float fondo = 0.25;

void vertex() {
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.xyz += n * grosor;
	v.z -= fondo;
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	ALBEDO = color.rgb;
}
