shader_type canvas_item;

// ============================================
// Bloom 后处理效果 (Bloom Post-Processing)
// ============================================
// 通过提取高亮区域、应用高斯模糊，然后叠加到原始图像上来实现辉光效果

// --- Bloom 参数 ---
uniform float threshold : hint_range(0.0, 2.0, 0.01) = 0.8;  // 亮度阈值：高于此亮度的像素才会产生辉光
uniform float intensity : hint_range(0.0, 2.0, 0.01) = 0.5;   // 辉光强度
uniform float blur_size : hint_range(0.0, 5.0, 0.1) = 1.5;    // 模糊扩散范围
uniform int blur_samples : hint_range(1, 12) = 6;              // 模糊采样数（越高越平滑，性能消耗越大）

// --- 屏幕纹理（Godot 4.x 标准写法） ---
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;

	// --- 采样屏幕原始颜色 ---
	vec3 original_color = texture(SCREEN_TEXTURE, uv).rgb;

	// --- 提取高亮区域并进行高斯模糊 ---
	vec3 bloom_color = vec3(0.0);
	float total_weight = 0.0;
	vec2 pixel_size = 1.0 / vec2(textureSize(SCREEN_TEXTURE, 0));

	for (int x = -blur_samples; x <= blur_samples; x++) {
		for (int y = -blur_samples; y <= blur_samples; y++) {
			vec2 offset = vec2(float(x), float(y)) * pixel_size * blur_size;
			vec3 sample_color = texture(SCREEN_TEXTURE, uv + offset).rgb;

			// 提取高亮部分：只保留超过阈值的亮度
			float sample_brightness = dot(sample_color, vec3(0.299, 0.587, 0.114));
			vec3 highlight = sample_color * max(sample_brightness - threshold, 0.0);

			// 高斯权重
			float weight = exp(-float(x * x + y * y) / (2.0 * blur_size * blur_size + 0.001));
			bloom_color += highlight * weight;
			total_weight += weight;
		}
	}

	// 归一化
	if (total_weight > 0.0) {
		bloom_color /= total_weight;
	}

	// --- 叠加辉光到原始画面 ---
	vec3 final_color = original_color + bloom_color * intensity;

	// 限制最终颜色，避免过曝
	final_color = min(final_color, vec3(1.5));

	COLOR = vec4(final_color, 1.0);
}