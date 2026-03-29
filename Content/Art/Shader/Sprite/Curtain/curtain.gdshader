shader_type canvas_item;

// ==================== 幕布飘动着色器 ====================
// 模拟布料/幕布的飘动效果，包含波浪形变、褶皱阴影和边缘柔化。
// 适用于：幕布、旗帜、布条、帷幔等需要飘动感的 2D 元素。
// 用法：将此 shader 设置为 TextureRect/Sprite2D 等节点的 Material，
//       通过调整各参数控制飘动的幅度、速度和褶皱效果。
// ====================================================

// ---------- 波浪参数 ----------

// 水平波浪幅度（值越大，左右摆动越明显）
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;

// 水平波浪频率（值越大，波浪越密集）
uniform float wave_frequency : hint_range(1.0, 20.0) = 8.0;

// 波浪流动速度
uniform float wave_speed : hint_range(0.0, 10.0) = 2.0;

// 垂直波浪幅度（模拟上下起伏）
uniform float vertical_amplitude : hint_range(0.0, 0.05) = 0.005;

// ---------- 褶皱参数 ----------

// 褶皱强度（值越大，褶皱明暗对比越强）
uniform float fold_intensity : hint_range(0.0, 1.0) = 0.3;

// 褶皱频率（值越大，褶皱越密）
uniform float fold_frequency : hint_range(1.0, 30.0) = 12.0;

// 褶皱阴影颜色
uniform vec4 fold_shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// 褶皱高光颜色
uniform vec4 fold_highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// ---------- 悬挂参数 ----------

// 顶部固定程度（值越大，顶部越固定、底部摆动越大）
uniform float top_weight : hint_range(0.0, 3.0) = 1.5;

// 是否启用顶部固定（true 时顶部几乎不动，模拟悬挂效果）
uniform bool pin_top = true;

void fragment() {
	vec2 uv = UV;

	// 根据垂直位置计算摆动权重（越靠下摆动越大）
	float sway_weight = 1.0;
	if (pin_top) {
		sway_weight = pow(uv.y, top_weight);
	}

	// --- 主波浪：大幅度的慢速摆动 ---
	float main_wave = sin(uv.y * wave_frequency + TIME * wave_speed) * wave_amplitude;

	// --- 次波浪：较快的小幅波动，增加自然感 ---
	float secondary_wave = sin(uv.y * wave_frequency * 2.3 + TIME * wave_speed * 1.7 + 1.0) * wave_amplitude * 0.3;

	// --- 第三层波浪：更细碎的抖动 ---
	float tertiary_wave = sin(uv.y * wave_frequency * 4.1 + TIME * wave_speed * 0.8 + 2.5) * wave_amplitude * 0.1;

	// 合并水平偏移
	float total_horizontal = (main_wave + secondary_wave + tertiary_wave) * sway_weight;

	// --- 垂直起伏 ---
	float vertical_wave = sin(uv.x * wave_frequency * 0.7 + TIME * wave_speed * 0.6) * vertical_amplitude * sway_weight;

	// 应用UV偏移
	uv.x += total_horizontal;
	uv.y += vertical_wave;

	// 边界检查：超出范围的像素设为透明
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		// 采样原始纹理
		vec4 original_color = texture(TEXTURE, uv);

		// --- 褶皱光影计算 ---
		// 通过波浪的导数（斜率）模拟法线方向，产生明暗变化
		float fold_value = cos(uv.y * fold_frequency + TIME * wave_speed) * 0.5
						 + cos(uv.y * fold_frequency * 2.1 + TIME * wave_speed * 1.5 + 0.8) * 0.3
						 + cos(uv.y * fold_frequency * 3.7 + TIME * wave_speed * 0.9 + 1.6) * 0.2;

		// 将褶皱值映射到 [-1, 1] 范围
		fold_value = clamp(fold_value * sway_weight, -1.0, 1.0);

		// 根据褶皱值混合阴影或高光
		vec3 final_rgb = original_color.rgb;
		if (fold_value < 0.0) {
			// 凹处：混合阴影
			final_rgb = mix(original_color.rgb, fold_shadow_color.rgb, abs(fold_value) * fold_intensity);
		} else {
			// 凸处：混合高光
			final_rgb = mix(original_color.rgb, fold_highlight_color.rgb, fold_value * fold_intensity * 0.5);
		}

		COLOR = vec4(final_rgb, original_color.a);
	}
}
