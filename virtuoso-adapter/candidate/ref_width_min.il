;=====================================================================
; Rule2DRC Virtuoso adapter - reference candidate: width_min
;
; Implements the candidate contract (see R2D_contract.il) for rule type
; "width_min": every shape on <layer>/drawing whose width is smaller
; than <threshold_um> is reported as a violation.
;
; Method
;   rect    -> exact: width = shorter edge of the rectangle.
;   polygon -> APPROXIMATION: bbox width stands in for true geometric
;              width. L-/U-shaped polygons can be misjudged. This is a
;              documented limit of the skeleton, not a bug to hide:
;              a production check would use negative sizing
;              (dbLayerSize by -threshold/2, shapes that vanish violate).
;   other   -> skipped (paths, donuts, ...).
;
; Coordinates are integer DBU; threshold is converted with
; dbGetDbUPerUU() so the file works in any tech with any DBU scale.
;=====================================================================

procedure(R2D_bBoxLessp(a b)
  ;; strict weak ordering on bboxes: by x1, then y1. Keeps output
  ;; deterministic so golden comparison is stable.
  let((ax1 ay1 bx1 by1)
    ax1 = caar(a)  ay1 = cadar(a)
    bx1 = caar(b)  by1 = cadar(b)
    or(ax1 < bx1
       and(ax1 == bx1  ay1 < by1))
  )
) ; R2D_bBoxLessp

procedure(R2D_check(cvId rule)
  let((ruleType layerName threshUm dbuPerUm threshDbu lpp viols)
    ruleType  = car(rule)
    layerName = cadr(rule)
    threshUm  = caddr(rule)
    unless(ruleType == "width_min"
      error("ref_width_min: unsupported rule type %s (want width_min)"
            ruleType))
    dbuPerUm  = dbGetDbUPerUU()
    threshDbu = round(threshUm * dbuPerUm)
    lpp       = list(layerName "drawing")
    viols     = nil
    foreach(shape cvId~>shapes
      when(equal(shape~>lpp lpp)
        let((bBox x1 y1 x2 y2 w)
          bBox = shape~>bBox
          x1 = caar(bBox)   y1 = cadar(bBox)
          x2 = caadr(bBox)  y2 = cadadr(bBox)
          w  = min(x2 - x1  y2 - y1)
          when(w < threshDbu
            ;; rect: exact. polygon: bbox approximation (see header).
            when(member(shape~>objType '("rect" "polygon"))
              viols = cons(list(list(x1 y1) list(x2 y2)) viols)))
        ) ; let
      ) ; when
    ) ; foreach
    sort(viols 'R2D_bBoxLessp)
  )
) ; R2D_check
