shader_type canvas_item;

// ==================== 幕布综合着色器 ====================
// 合并了飘动效果和拉开效果。
// progress = 0.0 时为纯飘动状态，progress = 1.0 时幕布完全收拢到左侧。
// 过渡过程中飘动自然减弱，拉开褶皱逐渐增强。
// ====================================================

// ---------- 拉开控制 ----------

// 拉开进度（0.0 = 完全展开/飘动，1.0 = 完全收拢到左侧）
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// 上下进度差异（值越大，上方比下方拉得越快，右侧弧线越弯）
uniform float curve_strength : hint_range(0.0, 1.0) = 0.5;

// ---------- 飘动波浪参数 ----------

// 水平波浪幅度（值越大，左右摆动越明显）
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.02;

// 水平波浪频率（值越大，波浪越密集）
uniform float wave_frequency : hint_range(1.0, 20.0) = 8.0;

// 波浪流动速度
uniform float wave_speed : hint_range(0.0, 10.0) = 2.0;

// 垂直波浪幅度（模拟上下起伏）
uniform float vertical_amplitude : hint_range(0.0, 0.05) = 0.005;

// ---------- 飘动褶皱参数 ----------

// 飘动褶皱强度
uniform float sway_fold_intensity : hint_range(0.0, 1.0) = 0.3;

// 飘动褶皱频率
uniform float sway_fold_frequency : hint_range(1.0, 30.0) = 12.0;

// ---------- 拉开褶皱参数 ----------

// 拉开褶皱数量
uniform float pull_fold_count : hint_range(2.0, 15.0) = 5.0;

// 拉开褶皱强度
uniform float pull_fold_intensity : hint_range(0.0, 1.5) = 0.8;

// ---------- 通用参数 ----------

// 褶皱阴影颜色
uniform vec4 fold_shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// 褶皱高光颜色
uniform vec4 fold_highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// 顶部固定权重（值越大，顶部越固定）
uniform float top_weight : hint_range(0.5, 3.0) = 1.5;

// 底部下垂程度（拉开时生效）
uniform float sag_amount : hint_range(0.0, 0.1) = 0.02;

// 是否启用顶部固定（飘动时使用）
uniform bool pin_top = true;

// 简易伪随机哈希函数
float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// 飘动效果的衰减因子：progress 越大飘动越弱
	float sway_factor = 1.0 - smoothstep(0.0, 0.5, progress);

	// 拉开效果的增强因子
	float pull_factor = smoothstep(0.0, 0.1, progress);

	// ============ 飘动部分（progress 小时主导） ============

	// 根据垂直位置计算摆动权重（越靠下摆动越大）
	float sway_weight = 1.0;
	if (pin_top) {
		sway_weight = pow(uv.y, top_weight);
	}

	// 主波浪
	float main_wave = sin(uv.y * wave_frequency + TIME * wave_speed) * wave_amplitude;
	// 次波浪
	float secondary_wave = sin(uv.y * wave_frequency * 2.3 + TIME * wave_speed * 1.7 + 1.0) * wave_amplitude * 0.3;
	// 第三层波浪
	float tertiary_wave = sin(uv.y * wave_frequency * 4.1 + TIME * wave_speed * 0.8 + 2.5) * wave_amplitude * 0.1;

	// 合并水平偏移（乘以衰减因子）
	float total_horizontal = (main_wave + secondary_wave + tertiary_wave) * sway_weight * sway_factor;

	// 垂直起伏（乘以衰减因子）
	float vertical_wave = sin(uv.x * wave_frequency * 0.7 + TIME * wave_speed * 0.6) * vertical_amplitude * sway_weight * sway_factor;

	// 应用飘动UV偏移
	uv.x += total_horizontal;
	uv.y += vertical_wave;

	// ============ 拉开部分（progress 大时主导） ============

	// 每行独立的可见宽度：上方拉得快，下方拉得慢
	float y_factor = 1.0 - pow(uv.y, 1.5);
	float local_progress = progress * (1.0 + curve_strength * y_factor) / (1.0 + curve_strength * 0.5);
	local_progress = clamp(local_progress, 0.0, 1.0);

	// 当前行的可见宽度
	float visible_width = 1.0 - local_progress;

	// 超出可见区域或飘动越界的像素设为透明
	if (uv.x < 0.0 || uv.y < 0.0 || uv.y > 1.0 || uv.x > visible_width) {
		COLOR = vec4(0.0);
	} else {
		// 将可见区域的 UV 映射回完整纹理
		// progress=0 时 visible_width=1，mapped_x = uv.x（无变形）
		// progress>0 时进行压缩映射
		float mapped_x = uv.x / max(visible_width, 0.001);
		float mapped_y = uv.y;

		// --- 拉开褶皱形变（仅 progress>0 时生效）---
		float fold_strength = local_progress;

		float pull_fold_wave = 0.0;
		if (pull_factor > 0.0) {
			float phase1 = hash(floor(mapped_x * pull_fold_count)) * 6.28;
			float phase2 = hash(floor(mapped_x * pull_fold_count * 0.7 + 3.7)) * 6.28;
			pull_fold_wave = sin(mapped_x * pull_fold_count * 3.14159 + phase1) * 0.7
							+ sin(mapped_x * pull_fold_count * 1.7 * 3.14159 + phase2) * 0.3;
			pull_fold_wave = pull_fold_wave * fold_strength * 0.04 * sway_weight;
		}
		mapped_y += pull_fold_wave;

		// 底部下垂
		float edge_proximity = mapped_x;
		float sag_offset = sag_amount * local_progress * edge_proximity * sway_weight;
		mapped_y += sag_offset;

		// 边界安全检查
		mapped_x = clamp(mapped_x, 0.0, 1.0);
		mapped_y = clamp(mapped_y, 0.0, 1.0);

		// 采样纹理
		vec4 original_color = texture(TEXTURE, vec2(mapped_x, mapped_y));

		// ============ 褶皱光影混合 ============

		vec3 final_rgb = original_color.rgb;

		// --- 飘动褶皱光影（sway_factor 控制强度）---
		if (sway_factor > 0.0) {
			float sway_fold_value = cos(uv.y * sway_fold_frequency + TIME * wave_speed) * 0.5
								  + cos(uv.y * sway_fold_frequency * 2.1 + TIME * wave_speed * 1.5 + 0.8) * 0.3
								  + cos(uv.y * sway_fold_frequency * 3.7 + TIME * wave_speed * 0.9 + 1.6) * 0.2;
			sway_fold_value = clamp(sway_fold_value * sway_weight, -1.0, 1.0);

			float sway_intensity = sway_fold_intensity * sway_factor;
			if (sway_fold_value < 0.0) {
				final_rgb = mix(final_rgb, fold_shadow_color.rgb, abs(sway_fold_value) * sway_intensity);
			} else {
				final_rgb = mix(final_rgb, fold_highlight_color.rgb, sway_fold_value * sway_intensity * 0.5);
			}
		}

		// --- 拉开褶皱光影（pull_factor 控制强度）---
		if (pull_factor > 0.0) {
			float vertical_fold_weight = mix(1.0, 0.3, uv.y);

			float fp1 = hash(floor(mapped_x * pull_fold_count + 0.5)) * 6.28;
			float fp2 = hash(floor(mapped_x * pull_fold_count * 0.6 + 7.1)) * 6.28;
			float pull_fold_value = cos(mapped_x * pull_fold_count * 3.14159 * 2.0 + fp1) * 0.65
								  + cos(mapped_x * pull_fold_count * 2.9 * 3.14159 + fp2) * 0.35;

			pull_fold_value = clamp(pull_fold_value, -1.0, 1.0) * fold_strength * vertical_fold_weight;

			// 靠近收拢边缘的褶皱加深
			float edge_deepen = smoothstep(0.5, 1.0, edge_proximity) * local_progress * 0.4;
			float edge_fold = cos(edge_proximity * pull_fold_count * 2.0 * 3.14159 + 1.0) * edge_deepen;
			pull_fold_value = clamp(pull_fold_value + edge_fold, -1.0, 1.0);

			float current_intensity = pull_fold_intensity * fold_strength;
			if (pull_fold_value < 0.0) {
				final_rgb = mix(final_rgb, fold_shadow_color.rgb, abs(pull_fold_value) * current_intensity);
			} else {
				final_rgb = mix(final_rgb, fold_highlight_color.rgb, pull_fold_value * current_intensity * 0.6);
			}

			// 收拢边缘阴影
			float edge_shadow = smoothstep(visible_width - 0.03, visible_width, uv.x) * local_progress * 0.35;
			final_rgb = mix(final_rgb, fold_shadow_color.rgb, edge_shadow);
		}

		COLOR = vec4(final_rgb, original_color.a);
	}
}
