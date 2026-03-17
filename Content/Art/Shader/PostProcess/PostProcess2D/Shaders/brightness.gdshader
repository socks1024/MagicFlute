shader_type canvas_item;

// ============================================
// 亮度后处理效果 (Brightness Post-Processing)
// ============================================
// 使用方法：
// 1. 创建一个覆盖全屏的 ColorRect 或 TextureRect
// 2. 为其创建 ShaderMaterial 并赋予此 shader
// 3. 调整参数以获得理想的亮度效果

// --- 亮度参数 ---
// 整体亮度调节
uniform float brightness : hint_range(0.5, 1.5, 0.01) = 1.0;

// --- 屏幕纹理（Godot 4.x 标准写法） ---
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;

	// --- 采样屏幕颜色 ---
	vec3 color = texture(SCREEN_TEXTURE, uv).rgb;

	// --- 亮度 ---
	color *= brightness;

	COLOR = vec4(color, 1.0);
}
