#!/usr/bin/env ruby
# gen_analog_v2.rb - Correct analog layout testcases
# Key principle: matched devices must have IDENTICAL geometry, only position differs

um = 1000
$out_dir = "/Users/dean/Documents/git/Rule2DRC/analog_gds"
Dir.mkdir($out_dir) unless Dir.exist?($out_dir)

ly = RBA::Layout.new
ly.dbu = 0.001

def bx(c, li, x1, y1, x2, y2)
  c.shapes(li).insert(RBA::Box::new(RBA::Point::new(x1, y1), RBA::Point::new(x2, y2)))
end

def save(ly, name, shapes)
  c = ly.create_cell("TOP")
  shapes.each { |li, x1, y1, x2, y2| bx(c, li, x1, y1, x2, y2) }
  ly.write("#{$out_dir}/#{name}.gds")
  c.delete
  puts "  #{name}.gds"
end

NDIFF = ly.layer(65, 0)
POLY  = ly.layer(66, 0)
MET1  = ly.layer(68, 0)
RES   = ly.layer(66, 21)

# ================================================================
# Problem 1: DIFF_PAIR_SYMMETRY
# Rule: Left/right transistors must be IDENTICAL in size, mirrored about Y-axis
# ================================================================
puts "=== DIFF_PAIR_SYMMETRY ==="

# Diff pair device: NDIFF 2um x 1um, POLY gate 0.4um x 1.6um
dw, dh = 2000, 1000   # diff size
gw, gh = 400, 1600    # gate size (extends beyond diff)
dist = 3000            # distance from Y-axis to device center

# pass_01: Perfect mirror - identical devices, symmetric placement
save(ly, "diff_pair_sym_pass_01", [
  # Left device
  [NDIFF, -dist-dw/2, -dh/2, -dist+dw/2, dh/2],
  [POLY, -dist-gw/2, -gh/2, -dist+gw/2, gh/2],
  # Right device (mirror of left)
  [NDIFF, dist-dw/2, -dh/2, dist+dw/2, dh/2],
  [POLY, dist-gw/2, -gh/2, dist+gw/2, gh/2],
])

# pass_02: Wider devices, still symmetric
dw2, dh2 = 3000, 1500
gw2, gh2 = 500, 2000
dist2 = 4000
save(ly, "diff_pair_sym_pass_02", [
  [NDIFF, -dist2-dw2/2, -dh2/2, -dist2+dw2/2, dh2/2],
  [POLY, -dist2-gw2/2, -gh2/2, -dist2+gw2/2, gh2/2],
  [NDIFF, dist2-dw2/2, -dh2/2, dist2+dw2/2, dh2/2],
  [POLY, dist2-gw2/2, -gh2/2, dist2+gw2/2, gh2/2],
])

# fail_01: Right device WIDER (height mismatch)
save(ly, "diff_pair_sym_fail_01", [
  # Left: normal
  [NDIFF, -dist-dw/2, -dh/2, -dist+dw/2, dh/2],
  [POLY, -dist-gw/2, -gh/2, -dist+gw/2, gh/2],
  # Right: taller (dh+400 instead of dh)
  [NDIFF, dist-dw/2, -(dh+400)/2, dist+dw/2, (dh+400)/2],
  [POLY, dist-gw/2, -gh/2, dist+gw/2, gh/2],
])

# fail_02: Right device gate shifted horizontally (position asymmetry)
save(ly, "diff_pair_sym_fail_02", [
  # Left: normal
  [NDIFF, -dist-dw/2, -dh/2, -dist+dw/2, dh/2],
  [POLY, -dist-gw/2, -gh/2, -dist+gw/2, gh/2],
  # Right: diff normal, but gate shifted left (closer to center)
  [NDIFF, dist-dw/2, -dh/2, dist+dw/2, dh/2],
  [POLY, dist-gw/2-400, -gh/2, dist+gw/2-400, gh/2],
])

# ================================================================
# Problem 2: CURRENT_MIRROR_MATCH
# Rule: Mirror transistors must have equal W x L (same active area)
# ================================================================
puts "=== CURRENT_MIRROR_MATCH ==="

# pass_01: Both devices 2um x 1um = 2um^2 (identical size)
save(ly, "curr_mirror_match_pass_01", [
  [NDIFF, 0, 0, 2000, 1000],
  [POLY, -200, -200, 200, 1200],
  [NDIFF, 5000, 0, 7000, 1000],
  [POLY, 4800, -200, 5200, 1200],
])

# pass_02: Both devices 3um x 1um = 3um^2 (identical)
save(ly, "curr_mirror_match_pass_02", [
  [NDIFF, 0, 0, 3000, 1000],
  [POLY, -200, -200, 200, 1200],
  [NDIFF, 5000, 0, 8000, 1000],
  [POLY, 4800, -200, 5200, 1200],
])

# fail_01: 3um^2 vs 2um^2 (area mismatch)
save(ly, "curr_mirror_match_fail_01", [
  [NDIFF, 0, 0, 3000, 1000],       # 3um^2
  [POLY, -200, -200, 200, 1200],
  [NDIFF, 5000, 0, 7000, 1000],     # 2um^2
  [POLY, 4800, -200, 5200, 1200],
])

# fail_02: 1um^2 vs 4um^2 (severe mismatch)
save(ly, "curr_mirror_match_fail_02", [
  [NDIFF, 0, 0, 1000, 1000],       # 1um^2
  [POLY, -200, -200, 200, 1200],
  [NDIFF, 5000, 0, 7000, 2000],     # 4um^2
  [POLY, 4800, -200, 5200, 2200],
])

# ================================================================
# Problem 3: COMMON_CENTROID_ARRAY
# Rule: A-B-B-A interdigitated pattern with identical elements
# ================================================================
puts "=== COMMON_CENTROID_ARRAY ==="

wA = 500   # Type A width
wB = 800   # Type B width
h  = 10000 # height (same for all)
gap = 300

# pass_01: A-B-B-A (proper interdigitation, different element sizes)
# A(0-500) gap B(800-1600) gap B(1900-2700) gap A(3000-3500)
save(ly, "ccentroid_res_pass_01", [
  [RES, 0, 0, wA, h],                                      # A
  [RES, wA+gap, 0, wA+wB+gap, h],                          # B
  [RES, wA+wB+2*gap, 0, 2*wA+wB+2*gap, h],                # B
  [RES, 2*(wA+wB)+3*gap, 0, 2*(wA+wB)+wA+3*gap, h]       # A
])

# pass_02: A-B-A-B (also valid interdigitation)
save(ly, "ccentroid_res_pass_02", [
  [RES, 0, 0, wA, h],                                      # A
  [RES, wA+gap, 0, wA+wB+gap, h],                          # B
  [RES, wA+wB+2*gap, 0, 2*wA+wB+2*gap, h],                # A
  [RES, 2*wA+wB+3*gap, 0, 2*wA+2*wB+3*gap, h]             # B
])

# fail_01: A-B-A (odd count - 3 elements)
save(ly, "ccentroid_res_fail_01", [
  [RES, 0, 0, wA, h],
  [RES, wA+gap, 0, wA+wB+gap, h],
  [RES, wA+wB+2*gap, 0, 2*wA+wB+2*gap, h],
])

# fail_02: A-A-B-B (grouped, not interdigitated)
save(ly, "ccentroid_res_fail_02", [
  [RES, 0, 0, wA, h],                                      # A
  [RES, wA+gap, 0, 2*wA+gap, h],                           # A (same as first)
  [RES, 2*wA+2*gap, 0, 2*wA+wB+2*gap, h],                 # B
  [RES, 2*wA+wB+3*gap, 0, 2*wA+2*wB+3*gap, h]             # B
])

# ================================================================
# Problem 4: AXIS_SYMMETRY
# Rule: All structures must be mirror-symmetric about Y-axis
# ================================================================
puts "=== AXIS_SYMMETRY ==="

# pass_01: Perfect mirror
save(ly, "axis_sym_pass_01", [
  [MET1, -5000, -2000, -1000, 2000],
  [MET1, 1000, -2000, 5000, 2000],
  [POLY, -3000, -1000, -2000, 1000],
  [POLY, 2000, -1000, 3000, 1000],
])

# pass_02: Mirror with center structure
save(ly, "axis_sym_pass_02", [
  [MET1, -6000, -3000, -2000, 3000],
  [MET1, 2000, -3000, 6000, 3000],
  [MET1, -1000, -1000, 1000, 1000],  # center (self-symmetric)
])

# fail_01: Right MET1 has different Y-extent
save(ly, "axis_sym_fail_01", [
  [MET1, -5000, -2000, -1000, 2000],
  [MET1, 1000, -1500, 5000, 1500],   # shorter
])

# fail_02: Missing right-side POLY
save(ly, "axis_sym_fail_02", [
  [MET1, -5000, -2000, -1000, 2000],
  [MET1, 1000, -2000, 5000, 2000],
  [POLY, -3000, -1000, -2000, 1000],
  # missing: POLY on right
])

# ================================================================
# Problem 5: ORIENTATION_MATCHING
# Rule: All matched resistors must have same orientation (all H or all V)
# ================================================================
puts "=== ORIENTATION_MATCHING ==="

# pass_01: All horizontal (width > height)
save(ly, "orient_match_pass_01", [
  [RES, 0, 0, 5000, 500],
  [RES, 0, 2000, 5000, 2500],
  [RES, 0, 4000, 5000, 4500],
])

# pass_02: All vertical (height > width)
save(ly, "orient_match_pass_02", [
  [RES, 0, 0, 500, 5000],
  [RES, 2000, 0, 2500, 5000],
  [RES, 4000, 0, 4500, 5000],
])

# fail_01: Two horizontal + one vertical
save(ly, "orient_match_fail_01", [
  [RES, 0, 0, 5000, 500],      # H
  [RES, 0, 2000, 5000, 2500],   # H
  [RES, 8000, 0, 8500, 5000],   # V (mismatch!)
])

# fail_02: Two vertical + one horizontal
save(ly, "orient_match_fail_02", [
  [RES, 0, 0, 500, 5000],       # V
  [RES, 2000, 0, 2500, 5000],   # V
  [RES, 4000, 0, 9000, 500],    # H (mismatch!)
])

puts "Done! Generated all V2 analog test GDS files."
