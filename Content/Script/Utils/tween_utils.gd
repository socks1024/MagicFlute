class_name TweenUtils

static func curve_interpolator(curve:Curve) -> Callable:
	return func(t: float) -> float:	return curve.sample_baked(t)
