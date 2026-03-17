shader_type canvas_item;

// ============================================
// 暗角后处理效果 (Vignette Post-Processing)
// ============================================
// 使用方法：
// 1. 创建一个覆盖全屏的 ColorRect 或 TextureRect
// 2. 为其创建 ShaderMaterial 并赋予此 shader
// 3. 调整参数以获得理想的暗角效果

// --- 暗角参数 ---
// 暗角强度（0 = 无暗角）
uniform float vignette_strength : hint_range(0.0, 2.0, 0.01) = 0.4;
// 暗角半径（值越小暗角越大）
uniform float vignette_radius : hint_range(0.0, 1.5, 0.01) = 0.8;

// --- 屏幕纹理（Godot 4.x 标准写法） ---
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// 计算暗角遮罩
float get_vignette(vec2 uv) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	return smoothstep(vignette_radius, vignette_radius - 0.3, dist);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// --- 采样屏幕颜色 ---
	vec3 color = texture(SCREEN_TEXTURE, uv).rgb;

	// --- 暗角 ---
	float vignette = get_vignette(uv);
	color *= mix(1.0 - vignette_strength, 1.0, vignette);

	COLOR = vec4(color, 1.0);
}
