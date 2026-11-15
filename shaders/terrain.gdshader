shader_type canvas_item;
// Terrain for the whole map in one pass: textured biome ground, the dirt path (with
// ruts, pebbles, a sunken rim and cobbles near the gate), the stone plaza around the
// gate, animated lakes (water, ice, lava or bog), drifting cloud shadows, the
// build-mode grid, and fog over the unexplored land beyond the visible window.
//
// map_tex holds one texel per grid cell, sampled with linear filtering so shapes come
// out rounded and organic:
//   R = path (only inside the visible window)   G = lake
//   B = cobblestone road near the gate           A = unused
// The round stone plaza around the gate is computed from gate_pos.
// Detail is all procedural (hash noise, fbm, voronoi), so no image assets are needed.

uniform sampler2D map_tex : filter_linear, repeat_disable;
uniform vec2 grid_size = vec2(61.0, 37.0);
uniform float cell_size = 32.0;
uniform vec4 window_rect = vec4(0.0, 0.0, 100.0, 100.0);
uniform vec2 gate_pos = vec2(976.0, 592.0);

uniform vec3 ground_a = vec3(0.29, 0.5, 0.23);
uniform vec3 ground_b = vec3(0.4, 0.62, 0.29);
uniform vec3 detail_a = vec3(0.55, 0.78, 0.36);
uniform vec3 detail_b = vec3(1.0, 0.93, 0.6);
uniform vec3 water_deep = vec3(0.1, 0.3, 0.52);
uniform vec3 water_shallow = vec3(0.26, 0.6, 0.72);
uniform vec3 shore_col = vec3(0.52, 0.5, 0.32);
uniform vec3 fog_col = vec3(0.05, 0.09, 0.06);
uniform vec3 path_col = vec3(0.66, 0.54, 0.38);
uniform vec3 path_edge = vec3(0.36, 0.27, 0.18);
uniform vec3 path_rut = vec3(0.5, 0.39, 0.26);
uniform vec3 pebble_col = vec3(0.8, 0.71, 0.56);
uniform vec3 cobble_col = vec3(0.62, 0.6, 0.57);
uniform vec3 cobble_gap = vec3(0.32, 0.3, 0.29);
uniform vec4 grid_col = vec4(0.0, 0.0, 0.0, 0.2);
uniform int style = 0;          // 0 meadow, 1 desert, 2 tundra, 3 volcanic, 4 swamp, 5 autumn
uniform int water_style = 0;    // 0 water, 1 ice, 2 lava, 3 bog
uniform float show_grid = 0.0;
uniform float clouds = 1.0;

varying vec2 world;

void vertex() {
	world = VERTEX;
}

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float n = hash21(p);
	return vec2(n, hash21(p + n * 17.0 + 3.7));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

// Cheaper two-octave version for broad, soft shapes (clouds, fog).
float fbm2(vec2 p) {
	return 0.5 * vnoise(p) + 0.25 * vnoise(p * 2.03 + vec2(17.1, 9.2));
}

// x = distance to the nearest feature point, y = distance to the cell edge (F2 - F1),
// z = random id of the nearest cell.
vec3 voronoi(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash22(n + g) - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = hash21(n + g + 3.1);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(sqrt(d1), sqrt(d2) - sqrt(d1), id);
}

vec4 map_at(vec2 w) {
	return texture(map_tex, w / (cell_size * grid_size));
}

vec3 ground_color(vec2 w) {
	float big = fbm2(w * 0.0035) * 1.33;
	float mid = fbm(w * 0.018 + 7.3);
	vec3 g = mix(ground_a, ground_b, smoothstep(0.3, 0.72, big));
	g *= 0.9 + 0.2 * mid;
	if (style == 0) {
		// Meadow: grass blades and the odd tiny flower.
		float blades = vnoise(vec2(w.x * 0.9, w.y * 0.22));
		g = mix(g, detail_a, smoothstep(0.62, 0.92, blades) * 0.35);
		g *= 0.94 + 0.08 * vnoise(w * 0.3);
		vec2 fc = floor(w / 7.0);
		float h = hash21(fc);
		if (h > 0.993) {
			float r = length(fract(w / 7.0) - 0.5);
			vec3 petal = h > 0.994 ? vec3(1.0, 0.6, 0.78) : detail_b;
			g = mix(g, petal, smoothstep(0.24, 0.12, r));
		}
	} else if (style == 1) {
		// Desert: wind ripples, gravel flats and specks.
		float warp = fbm(w * 0.008) * 8.0;
		float rip = sin((w.x * 0.55 + w.y * 0.25) * 0.16 + warp);
		g *= 0.95 + 0.06 * rip;
		g = mix(g, detail_a, smoothstep(0.6, 0.76, fbm(w * 0.01 + 3.0)) * 0.45);
		vec2 sc = floor(w / 5.0);
		float speck = step(0.9, hash21(sc)) * smoothstep(0.28, 0.12, length(fract(w / 5.0) - 0.5 - (hash22(sc) - 0.5) * 0.4));
		g = mix(g, detail_b, speck * 0.55);
	} else if (style == 2) {
		// Tundra: blue-shadowed snow drifts that twinkle.
		float drift = fbm(w * 0.012 + 11.0);
		g = mix(g, detail_a, smoothstep(0.45, 0.82, drift) * 0.45);
		vec2 sc = floor(w / 4.0);
		float sp = hash21(sc);
		float twinkle = 0.5 + 0.5 * sin(TIME * 3.0 + sp * 40.0);
		g = mix(g, detail_b, step(0.988, sp) * twinkle * smoothstep(0.3, 0.0, length(fract(w / 4.0) - 0.5)));
	} else if (style == 3) {
		// Volcanic: basalt plates split by cracks, some glowing with heat.
		vec3 v = voronoi(w * 0.035);
		g *= 0.82 + 0.3 * v.z;
		g = mix(g, detail_a, smoothstep(0.08, 0.0, v.y) * 0.85);
		float hot = step(0.55, fbm(w * 0.006 + 2.0));
		float pulse = 0.65 + 0.35 * sin(TIME * 1.7 + v.z * 30.0);
		g = mix(g, detail_b, smoothstep(0.045, 0.0, v.y) * hot * pulse);
	} else if (style == 4) {
		// Swamp: dark wet mud with a slow sheen, and moss.
		float wet = smoothstep(0.55, 0.7, fbm(w * 0.012 + 5.0));
		g = mix(g, detail_b, wet * 0.6);
		g += wet * 0.04 * (0.5 + 0.5 * sin(TIME * 0.8 + w.x * 0.05));
		float moss = smoothstep(0.5, 0.75, fbm(w * 0.045 + 13.0));
		g = mix(g, detail_a, moss * 0.4 * (1.0 - wet));
		g *= 0.95 + 0.08 * vnoise(vec2(w.x * 0.7, w.y * 0.25));
	} else {
		// Autumn: leaf litter in orange, gold and red.
		vec2 lc = floor(w / 7.0);
		float h = hash21(lc);
		if (h > 0.78) {
			vec2 lp = fract(w / 7.0) - 0.5;
			float leaf = smoothstep(0.36, 0.2, length(lp * vec2(1.0, 1.7)));
			vec3 lcol = mix(detail_a, detail_b, hash21(lc + 5.0));
			if (hash21(lc + 9.0) > 0.72) {
				lcol = vec3(0.7, 0.18, 0.1);
			}
			g = mix(g, lcol, leaf * 0.8);
		}
	}
	return g;
}

vec3 cobbles(vec2 w, float scale) {
	vec3 cv = voronoi(w * scale);
	vec3 stone = cobble_col * (0.8 + 0.32 * cv.z);
	stone *= 0.92 + 0.12 * smoothstep(0.5, 0.0, cv.x);  // domed stones
	return mix(cobble_gap, stone, smoothstep(0.03, 0.11, cv.y));
}

vec3 water_color(vec2 w, float depth) {
	if (water_style == 0) {
		vec3 c = mix(water_shallow, water_deep, depth);
		float n = fbm(w * 0.03 + vec2(TIME * 0.05, TIME * 0.03));
		float ripple = sin(w.x * 0.12 + w.y * 0.05 + TIME * 1.6 + n * 6.0);
		c += smoothstep(0.82, 1.0, ripple) * 0.09 * (1.0 - depth * 0.5);
		vec2 gc = floor(w / 6.0);
		float sp = hash21(gc);
		float glint = smoothstep(0.22, 0.0, length(fract(w / 6.0) - 0.5)) * step(0.975, sp);
		c += glint * (0.5 + 0.5 * sin(TIME * 4.0 + sp * 50.0)) * 0.45;
		float foam = smoothstep(0.14, 0.0, depth) * (0.55 + 0.45 * sin(TIME * 2.0 + w.x * 0.1 + w.y * 0.07));
		return mix(c, vec3(0.9, 0.96, 1.0), foam * 0.5);
	} else if (water_style == 1) {
		vec3 c = mix(water_shallow, water_deep, depth * 0.7);
		vec3 v = voronoi(w * 0.045);
		c = mix(c, vec3(1.0), smoothstep(0.04, 0.0, v.y) * 0.55);
		c += (fbm(w * 0.05) - 0.5) * 0.12;
		float sheen = smoothstep(0.95, 1.0, sin((w.x + w.y) * 0.03 - TIME * 0.6));
		return c + sheen * 0.15;
	} else if (water_style == 2) {
		float n = fbm(w * 0.025 + vec2(TIME * 0.04, -TIME * 0.03));
		float n2 = fbm(w * 0.06 - vec2(TIME * 0.07, 0.0));
		float heat = clamp(n * 0.7 + n2 * 0.5 + depth * 0.25 - 0.15, 0.0, 1.0);
		vec3 c = mix(water_deep * 0.55, water_deep, smoothstep(0.15, 0.45, heat));
		c = mix(c, water_shallow, smoothstep(0.5, 0.82, heat));
		vec3 v = voronoi(w * 0.04 + vec2(TIME * 0.02, 0.0));
		float crust = smoothstep(0.35, 0.62, v.x) * smoothstep(0.55, 0.3, heat);
		return mix(c, vec3(0.13, 0.08, 0.07), crust * 0.85);
	}
	vec3 c = mix(water_shallow, water_deep, depth);
	c *= 0.85 + 0.3 * fbm(w * 0.02 + vec2(TIME * 0.015, 0.0));
	float scum = smoothstep(0.6, 0.7, fbm(w * 0.05 + 4.0));
	c = mix(c, vec3(0.32, 0.42, 0.18), scum * 0.6);
	float bubble = step(0.995, hash21(floor(w / 5.0) + floor(TIME * 0.5)));
	return c + bubble * 0.15;
}

void fragment() {
	vec2 w = world;
	vec4 m = map_at(w);
	vec3 col = ground_color(w);
	if (style == 0 || style == 4 || style == 5) {
		// Gusts of wind rolling across grassy ground.
		float gust = sin(dot(w, vec2(0.014, 0.006)) - TIME * 1.3 + fbm2(w * 0.004) * 4.0);
		col *= 1.0 + 0.045 * smoothstep(0.4, 1.0, gust) * vnoise(vec2(w.x * 0.9, w.y * 0.22));
	}

	// Round stone plaza around the gate, with a darker kerb and a soft shadow ring.
	float gd = length(w - gate_pos) / cell_size + (fbm(w * 0.08 + 1.0) - 0.5) * 0.25;
	if (gd < 2.2) {
		float plaza = smoothstep(1.62, 1.55, gd);
		col *= 1.0 - 0.22 * smoothstep(2.1, 1.6, gd) * (1.0 - plaza);
		vec3 stones = cobbles(w, 0.09);
		stones = mix(stones, cobble_gap * 1.2, smoothstep(1.3, 1.55, gd) * 0.5);
		col = mix(col, stones, plaza);
	}

	// Path: sampled path weight is 1 on the centerline and falls off to the sides, so a
	// noisy threshold gives soft, irregular edges and rounded corners.
	float path_a = 0.0;
	if (m.r > 0.25) {
		float wobble = (fbm(w * 0.09) - 0.5) * 0.16;
		float edge = 0.56 + wobble;
		path_a = smoothstep(edge - 0.02, edge + 0.02, m.r);
		float d = clamp((1.0 - m.r) * 2.0, 0.0, 1.0);
		vec3 pc = path_col * (0.88 + 0.22 * fbm(w * 0.05 + 2.0));
		pc = mix(pc, path_rut, smoothstep(0.12, 0.0, abs(d - 0.36)) * 0.5);
		vec2 pcell = floor(w / 6.0);
		vec2 pp = fract(w / 6.0) - 0.5 - (hash22(pcell) - 0.5) * 0.4;
		float pebble = step(0.82, hash21(pcell));
		pc = mix(pc, path_edge, pebble * smoothstep(0.24, 0.12, length(pp - vec2(0.05, 0.06))) * 0.4);
		pc = mix(pc, pebble_col * (0.85 + 0.3 * hash21(pcell + 2.0)), pebble * smoothstep(0.2, 0.1, length(pp)));
		if (m.b > 0.02) {
			pc = mix(pc, cobbles(w, 0.11), smoothstep(0.15, 0.8, m.b));
		}
		pc = mix(pc, path_edge, smoothstep(edge + 0.14, edge + 0.01, m.r) * 0.6);
		// Grass just beside the path is shaded by the bank.
		col *= 1.0 - 0.2 * smoothstep(edge - 0.2, edge, m.r) * (1.0 - path_a);
		col = mix(col, pc, path_a);
	}

	// Lakes. The lake weight is blurred over a few taps so shorelines come out round.
	float lake = 0.0;
	if (m.g > 0.05) {
		float o = cell_size * 0.75;
		float d = cell_size * 0.55;
		m.g = m.g * 0.2
			+ 0.12 * (map_at(w + vec2(o, 0.0)).g + map_at(w - vec2(o, 0.0)).g + map_at(w + vec2(0.0, o)).g + map_at(w - vec2(0.0, o)).g)
			+ 0.08 * (map_at(w + vec2(d, d)).g + map_at(w - vec2(d, d)).g + map_at(w + vec2(d, -d)).g + map_at(w - vec2(d, -d)).g);
	}
	if (m.g > 0.2) {
		float wob = (fbm(w * 0.05 + 9.0) - 0.5) * 0.28;
		lake = smoothstep(0.5 + wob - 0.02, 0.5 + wob + 0.02, m.g);
		float shore = smoothstep(0.3 + wob, 0.5 + wob, m.g) * (1.0 - lake);
		col = mix(col, shore_col * (0.88 + 0.24 * fbm(w * 0.08)), shore * 0.85);
		if (water_style == 2) {
			col += water_deep * 0.45 * smoothstep(0.25, 0.5 + wob, m.g) * (1.0 - lake);  // lava glow on the rocks
		}
		float depth = smoothstep(0.5 + wob, 0.98, m.g);
		col = mix(col, water_color(w, depth), lake);
	}

	// Drifting cloud shadows (lava glows through them).
	float cl = fbm2(w * 0.0022 + vec2(TIME * 0.018, TIME * 0.009)) * 1.33;
	float lit = water_style == 2 ? 1.0 - lake : 1.0;
	col *= 1.0 - smoothstep(0.52, 0.76, cl) * clouds * 0.2 * lit;

	// Build-mode grid on open ground.
	if (show_grid > 0.001) {
		vec2 cg = fract(w / cell_size);
		float lx = smoothstep(0.035, 0.0, min(cg.x, 1.0 - cg.x));
		float ly = smoothstep(0.035, 0.0, min(cg.y, 1.0 - cg.y));
		col = mix(col, grid_col.rgb, max(lx, ly) * grid_col.a * show_grid * (1.0 - path_a) * (1.0 - lake));
	}

	// The visible window: a soft inner vignette, a dark rim, and fog beyond it.
	vec2 lo = window_rect.xy;
	vec2 hi = window_rect.xy + window_rect.zw;
	vec2 out_v = max(lo - w, w - hi);
	float outside = max(out_v.x, out_v.y);
	col *= mix(0.82, 1.0, smoothstep(0.0, 28.0, -outside));
	float fog_n = fbm2(w * 0.006 + vec2(TIME * 0.01, TIME * 0.006)) * 1.33;
	float fog_t = smoothstep(-1.0, 8.0 + fog_n * 26.0, outside);
	vec3 grey = vec3(dot(col, vec3(0.3, 0.59, 0.11)));
	vec3 dim = mix(grey, col, 0.35) * 0.3;
	vec3 fog = mix(fog_col, fog_col * 1.9 + 0.03, fog_n);
	col = mix(col, mix(dim, fog, clamp(outside / 140.0, 0.0, 0.75) + 0.25), fog_t);
	col = mix(col, vec3(0.0), smoothstep(3.0, 0.0, abs(outside)) * 0.3);

	COLOR = vec4(col, 1.0);
}
