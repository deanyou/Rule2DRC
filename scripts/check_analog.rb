#!/usr/bin/env ruby
# check_analog.rb - Unified analog layout rule checker
# Usage: klayout -b -r check_analog.rb -rd input=X.gds -rd output=X.rdb -rd check_type=TYPE

input_path  = $input
output_path = $output
check_type  = $check_type || "diff_pair_sym"

ly = RBA::Layout.new
ly.read(input_path)
top = ly.top_cells[0]
top.flatten(true)

violations = []
category = case check_type
when "diff_pair_sym"   then "DIFF_PAIR_ASYMMETRIC"
when "curr_mirror"     then "CURR_MIRROR_MISMATCH"
when "ccentroid_res"   then "CCENTROID_VIOLATION"
when "axis_sym"        then "AXIS_ASYMMETRIC"
when "orient_match"    then "ORIENT_MISMATCH"
else "VIOLATION"
end

def read_shapes(top, layer, ly)
  shapes = []
  top.each_shape(layer) do |sh|
    if sh.is_box?
      b = sh.box
      shapes << {
        left: b.left.to_f * ly.dbu, right: b.right.to_f * ly.dbu,
        bottom: b.bottom.to_f * ly.dbu, top: b.top.to_f * ly.dbu,
        area: ((b.right - b.left) * (b.top - b.bottom)).to_f * ly.dbu * ly.dbu,
        cx: ((b.left + b.right) / 2.0).to_f * ly.dbu,
        cy: ((b.bottom + b.top) / 2.0).to_f * ly.dbu,
        width: (b.right - b.left).to_f * ly.dbu,
        height: (b.top - b.bottom).to_f * ly.dbu,
      }
    elsif sh.is_polygon?
      p = sh.polygon
      bb = p.bbox
      shapes << {
        left: bb.left.to_f * ly.dbu, right: bb.right.to_f * ly.dbu,
        bottom: bb.bottom.to_f * ly.dbu, top: bb.top.to_f * ly.dbu,
        area: p.area.to_f * ly.dbu * ly.dbu,
        cx: ((bb.left + bb.right) / 2.0).to_f * ly.dbu,
        cy: ((bb.bottom + bb.top) / 2.0).to_f * ly.dbu,
        width: (bb.right - bb.left).to_f * ly.dbu,
        height: (bb.top - bb.bottom).to_f * ly.dbu,
      }
    end
  end
  shapes
end

case check_type
when "diff_pair_sym"
  ndiff = read_shapes(top, ly.layer(65, 0), ly)
  poly  = read_shapes(top, ly.layer(66, 0), ly)

  [ndiff, poly].each_with_index do |shapes, idx|
    name = idx == 0 ? "NDIFF" : "POLY"
    next if shapes.empty?
    left_s  = shapes.select { |s| s[:cx] < -0.001 }
    right_s = shapes.select { |s| s[:cx] > 0.001 }
    if left_s.size != right_s.size
      violations << "#{name} count mismatch: left=#{left_s.size} right=#{right_s.size}"
    end
    left_s.sort_by { |s| -s[:cx] }.zip(right_s.sort_by { |s| s[:cx] }).each_with_index do |(l, r), i|
      if l && r
        # Check dimension match
        if (l[:width] - r[:width]).abs > 0.001 || (l[:height] - r[:height]).abs > 0.001
          violations << "#{name} pair#{i} dimension mismatch: L(#{l[:width].round(3)}x#{l[:height].round(3)}) R(#{r[:width].round(3)}x#{r[:height].round(3)})"
        end
        # Check position symmetry: distances from Y-axis must match
        l_dist = l[:cx].abs
        r_dist = r[:cx].abs
        if (l_dist - r_dist).abs > 0.001
          violations << "#{name} pair#{i} position asymmetric: left_dist=#{l_dist.round(3)} right_dist=#{r_dist.round(3)}"
        end
      end
    end
  end

when "curr_mirror"
  ndiff = read_shapes(top, ly.layer(65, 0), ly)
  if ndiff.size >= 2
    areas = ndiff.map { |s| s[:area] }.sort
    if (areas.first - areas.last).abs > 0.001
      violations << "NDIFF area mismatch: areas=#{areas.map { |a| a.round(4) }.inspect}"
    end
  end

when "ccentroid_res"
  res = read_shapes(top, ly.layer(66, 21), ly)
  if res.size > 0
    if res.size % 2 != 0
      violations << "Odd element count: #{res.size} (need even for common centroid)"
    end
    sorted = res.sort_by { |s| s[:cx] }
    n = sorted.size

    # Check interdigitation: detect A-A-B-B grouped pattern
    # A-A-B-B: first two same area AND last two same area AND first != last
    if n >= 4
      a01 = (sorted[0][:area] - sorted[1][:area]).abs < 0.001
      a23 = (sorted[n-2][:area] - sorted[n-1][:area]).abs < 0.001
      if a01 && a23 && (sorted[0][:area] - sorted[n-1][:area]).abs > 0.001
        violations << "A-A-B-B grouped pattern (not interdigitated)"
      end
    end
  end

when "axis_sym"
  [ly.layer(68, 0), ly.layer(66, 0)].each_with_index do |layer, idx|
    name = idx == 0 ? "MET1" : "POLY"
    shapes = read_shapes(top, layer, ly)
    next if shapes.empty?
    left_s  = shapes.select { |s| s[:cx] < -0.001 }
    right_s = shapes.select { |s| s[:cx] > 0.001 }
    if left_s.size != right_s.size
      violations << "#{name} count mismatch: left=#{left_s.size} right=#{right_s.size}"
    end
    left_s.sort_by { |s| s[:cx] }.zip(right_s.sort_by { |s| -s[:cx] }).each_with_index do |(l, r), i|
      if l && r
        if (l[:width] - r[:width]).abs > 0.001 || (l[:height] - r[:height]).abs > 0.001
          violations << "#{name} pair#{i} dimension mismatch: L(#{l[:width].round(3)}x#{l[:height].round(3)}) R(#{r[:width].round(3)}x#{r[:height].round(3)})"
        end
      end
    end
  end

when "orient_match"
  res = read_shapes(top, ly.layer(66, 21), ly)
  if res.size >= 2
    orientations = res.map { |s| s[:width] > s[:height] ? "H" : "V" }
    if orientations.uniq.size > 1
      violations << "Mixed orientations: #{orientations.inspect}"
    end
  end
end

# Write RDB XML
xml = '<?xml version="1.0" encoding="utf-8"?>'
xml += '<report-database>'
xml += "<description>Analog: #{category}</description>"
xml += '<original-file/>'
xml += '<generator>check_analog.rb</generator>'
xml += "<top-cell>#{top.name}</top-cell>"
xml += '<tags/>'
xml += "<categories><category><name>#{category}</name><description>#{category}</description><categories/></category></categories>"
xml += "<cells><cell><name>#{top.name}</name><variant/><layout-name/><references/></cell></cells>"
xml += '<items>'
violations.each do |msg|
  escaped = msg.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
  xml += "<item><tags/><category>#{category}</category><cell>#{top.name}</cell><visited>false</visited><multiplicity>1</multiplicity><comment>#{escaped}</comment><image/><values/></item>"
end
xml += '</items></report-database>'

File.write(output_path, xml)
puts "Check: #{check_type} | Violations: #{violations.size}"
violations.each { |v| puts "  #{v}" }
