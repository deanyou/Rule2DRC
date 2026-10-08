;=====================================================================
; Rule2DRC Virtuoso adapter - CANDIDATE CONTRACT
;
; A candidate is a SKILL file that defines exactly one procedure:
;
;   R2D_check(cvId rule) -> list of ((x1 y1) (x2 y2))
;
; Arguments
;   cvId : dbId of the layout cellview under test, opened READ-ONLY.
;          Do NOT modify it (dbCreate*/dbDeleteObject are forbidden;
;          the harness opens "r" mode, writes will fail anyway).
;   rule : list(type layerName thresholdUm), e.g.
;          list("width_min" "met1" 0.14)
;          Supported types in this skeleton: "width_min".
;          (Extend with "spacing_self", "enclosed" as next steps.)
;
; Return
;   A list of bounding boxes, each ((x1 y1) (x2 y2)), in INTEGER
;   database units (DBU). Get the scale with dbGetDbUPerUU().
;   Return nil when there are no violations.
;
; Rules of the game
;   - Pure query code only: no file IO, no ipcBeginProcess, no exit.
;   - Keep it deterministic: same layout -> same list, same order
;     (sort by x1, then y1).
;   - Keep test layouts tiny; SKILL db iteration is not KLayout-fast.
;
; This file is documentation. Copy the stub below into your candidate.
;=====================================================================

procedure(R2D_check(cvId rule)
  ;; TODO: implement your check here. See candidate/ref_width_min.il
  ;; for a complete width_min example.
  nil
) ; R2D_check
