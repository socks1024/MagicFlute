shader_type canvas_item;

// ==================== 幕布拉开着色器 ====================
// 通过 progress 参数控制幕布从右向左拉开，带物理感的褶皱堆叠效果。
// progress = 0.0 时幕布完全展开，progress = 1.0 时幕布完全收拢到左侧。
// 特性：上方折叠快、下方折叠慢，右侧边缘呈弧线；褶皱少而明显、不均匀。
// ====================================================

// ---------- 拉开控制 ----------

// 拉开进度（0.0 = 完全展开，1.0 = 完全收拢到左侧）
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// 上下进度差异（值越大，上方比下方拉得越快，右侧弧线越弯）
uniform float curve_strength : hint_range(0.0, 1.0) = 0.5;

// ---------- 褶皱参数 ----------

// 褶皱数量（少量大褶皱更有物理感）
uniform float fold_count : hint_range(2.0, 15.0) = 5.0;

// 褶皱强度（明暗对比程度，值越大褶皱越明显）
uniform float fold_intensity : hint_range(0.0, 1.5) = 0.8;

// 褶皱阴影颜色
uniform vec4 fold_shadow_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// 褶皱高光颜色
uniform vec4 fold_highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// ---------- 悬挂参数 ----------

// 底部下垂程度
uniform float sag_amount : hint_range(0.0, 0.1) = 0.02;

// 顶部固定权重（值越大，顶部越固定）
uniform float top_weight : hint_range(0.5, 3.0) = 1.5;

// 简易伪随机哈希函数，用于打破褶皱的均匀感
float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// --- 每行独立的可见宽度：上方拉得快，下方拉得慢 ---
	// y=0（顶部）进度更大，y=1（底部）进度更小，形成弧线边缘
	// 用 pow 曲线让上下差异更自然（不是线性的）
	float y_factor = 1.0 - pow(uv.y, 1.5); // 顶部=1，底部≈0
	float local_progress = progress * (1.0 + curve_strength * y_factor) / (1.0 + curve_strength * 0.5);
	local_progress = clamp(local_progress, 0.0, 1.0);

	// 当前行的可见宽度
	float visible_width = 1.0 - local_progress;

	// 超出可见区域的像素设为透明
	if (uv.x > visible_width) {
		COLOR = vec4(0.0);
	} else {
		// --- 将可见区域的 UV 映射回完整纹理 ---
		float mapped_x = uv.x / max(visible_width, 0.001);

		// --- 褶皱形变 ---
		float fold_strength = local_progress;

		// 垂直摆动权重（顶部固定，底部摆动大）
		float sway_weight = pow(uv.y, top_weight);

		// 不均匀褶皱：用多个不同频率的波叠加，加上伪随机偏移打破规律
		float phase1 = hash(floor(mapped_x * fold_count)) * 6.28;
		float phase2 = hash(floor(mapped_x * fold_count * 0.7 + 3.7)) * 6.28;
		float fold_wave = sin(mapped_x * fold_count * 3.14159 + phase1) * 0.7
						+ sin(mapped_x * fold_count * 1.7 * 3.14159 + phase2) * 0.3;
		fold_wave = fold_wave * fold_strength * 0.04 * sway_weight;
		float mapped_y = uv.y + fold_wave;

		// 底部下垂
		float edge_proximity = mapped_x;
		float sag_offset = sag_amount * local_progress * edge_proximity * sway_weight;
		mapped_y += sag_offset;

		// 边界安全检查
		mapped_x = clamp(mapped_x, 0.0, 1.0);
		mapped_y = clamp(mapped_y, 0.0, 1.0);

		// 采样纹理
		vec4 original_color = texture(TEXTURE, vec2(mapped_x, mapped_y));

		// --- 褶皱光影 ---
		// 上方折叠程度更高 → 上方褶皱更深更明显
		// 用 (1.0 - uv.y) 让顶部褶皱强度更大
		float vertical_fold_weight = mix(1.0, 0.3, uv.y); // 顶部=1.0，底部=0.3

		// 不均匀的褶皱明暗：少量大褶皱 + 随机相位偏移
		float fp1 = hash(floor(mapped_x * fold_count + 0.5)) * 6.28;
		float fp2 = hash(floor(mapped_x * fold_count * 0.6 + 7.1)) * 6.28;
		float fold_value = cos(mapped_x * fold_count * 3.14159 * 2.0 + fp1) * 0.65
						 + cos(mapped_x * fold_count * 2.9 * 3.14159 + fp2) * 0.35;

		// 应用垂直权重和进度
		fold_value = clamp(fold_value, -1.0, 1.0) * fold_strength * vertical_fold_weight;

		// 靠近收拢边缘的褶皱略微加深（布料堆叠）
		float edge_deepen = smoothstep(0.5, 1.0, edge_proximity) * local_progress * 0.4;
		float edge_fold = cos(edge_proximity * fold_count * 2.0 * 3.14159 + 1.0) * edge_deepen;
		fold_value = clamp(fold_value + edge_fold, -1.0, 1.0);

		// 混合阴影和高光
		vec3 final_rgb = original_color.rgb;
		float current_intensity = fold_intensity * fold_strength;
		if (fold_value < 0.0) {
			// 凹处：阴影（强度完整）
			final_rgb = mix(original_color.rgb, fold_shadow_color.rgb, abs(fold_value) * current_intensity);
		} else {
			// 凸处：高光（强度稍弱）
			final_rgb = mix(original_color.rgb, fold_highlight_color.rgb, fold_value * current_intensity * 0.6);
		}

		// 收拢边缘阴影，模拟布料厚度
		float edge_shadow = smoothstep(visible_width - 0.03, visible_width, uv.x) * local_progress * 0.35;
		final_rgb = mix(final_rgb, fold_shadow_color.rgb, edge_shadow);

		COLOR = vec4(final_rgb, original_color.a);
	}
}
