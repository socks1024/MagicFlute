shader_type canvas_item;

// ============================================
// 扫描线后处理效果 (Scanline Post-Processing)
// ============================================
// 使用方法：
// 1. 创建一个覆盖全屏的 ColorRect 或 TextureRect
// 2. 为其创建 ShaderMaterial 并赋予此 shader
// 3. 调整参数以获得理想的扫描线效果

// --- 扫描线参数 ---
// 扫描线密度（值越大线越密）
uniform float scanline_density : hint_range(1.0, 2000.0, 1.0) = 200.0;
// 扫描线强度（0 = 无效果，1 = 最强）
uniform float scanline_strength : hint_range(0.0, 1.0, 0.01) = 0.3;
// 扫描线滚动速度（0 = 静止）
uniform float scroll_speed : hint_range(0.0, 50.0, 0.1) = 3.0;

// --- 屏幕纹理（Godot 4.x 标准写法） ---
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;

	vec3 color = texture(SCREEN_TEXTURE, uv).rgb;

	// --- 扫描线 ---
	// 基于屏幕UV的y轴生成正弦波扫描线，叠加时间滚动
	float scanline = sin((uv.y * scanline_density + TIME * scroll_speed) * 3.14159) * 0.5 + 0.5;
	// 将扫描线映射到 [1 - strength, 1] 范围
	scanline = 1.0 - scanline_strength * scanline;
	color *= scanline;

	COLOR = vec4(color, 1.0);
}
