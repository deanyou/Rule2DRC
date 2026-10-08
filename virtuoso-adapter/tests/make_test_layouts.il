;=====================================================================
; Rule2DRC Virtuoso adapter - test layout generator
;
; Creates three tiny test cellviews with KNOWN width violations.
; Run once in batch Virtuoso (needs a library already bound to your
; techfile - create it in Library Manager first):
;
;   R2D_LIB=myLib virtuoso -nograph -replay tests/make_test_layouts.il
;
; Layouts (threshold 0.14 um, layer met1/drawing):
;   r2d_t1_width : 1 violation (0.10 wide) + boundary 0.14 (clean)
;                  + clean 0.20 rect
;   r2d_t2_clean : all clean
;   r2d_t3_multi : 3 violations at different spots
;=====================================================================

procedure(R2D_mkRect(cvId layer x1um y1um x2um y2um)
  let((dbu)
    dbu = dbGetDbUPerUU()
    dbCreateRect(cvId
                list(layer "drawing")
                list(list(round(x1um * dbu) round(y1um * dbu))
                     list(round(x2um * dbu) round(y2um * dbu))))
  )
) ; R2D_mkRect

procedure(R2D_makeTests(libName)
  let((cvId)
    ;; ---- t1: single violation + boundary + clean ----
    cvId = dbOpenCellViewByType(libName "r2d_t1_width" "layout" "maskLayout" "w")
    R2D_mkRect(cvId "met1" 0.00 0.0 0.10 1.0)  ; violation (0.10 < 0.14)
    R2D_mkRect(cvId "met1" 0.50 0.0 0.64 1.0)  ; boundary 0.14 -> clean
    R2D_mkRect(cvId "met1" 1.00 0.0 1.20 1.0)  ; clean
    dbSave(cvId)  dbClose(cvId)

    ;; ---- t2: all clean ----
    cvId = dbOpenCellViewByType(libName "r2d_t2_clean" "layout" "maskLayout" "w")
    R2D_mkRect(cvId "met1" 0.0 0.0 0.20 1.0)
    R2D_mkRect(cvId "met1" 0.5 0.0 0.70 0.5)
    dbSave(cvId)  dbClose(cvId)

    ;; ---- t3: three violations ----
    cvId = dbOpenCellViewByType(libName "r2d_t3_multi" "layout" "maskLayout" "w")
    R2D_mkRect(cvId "met1" 0.0 0.0 0.10 1.0)   ; violation
    R2D_mkRect(cvId "met1" 0.5 0.0 0.58 1.0)   ; violation
    R2D_mkRect(cvId "met1" 1.0 0.0 1.05 2.0)   ; violation
    R2D_mkRect(cvId "met1" 2.0 0.0 2.30 1.0)   ; clean
    dbSave(cvId)  dbClose(cvId)

    printf("R2D: test layouts created in %s: r2d_t1_width r2d_t2_clean r2d_t3_multi\n"
           libName)
    t
  )
) ; R2D_makeTests

let((libName)
  libName = getShellEnvVar("R2D_LIB")
  unless(libName && libName != ""
    error("R2D: set R2D_LIB to an existing library bound to your techfile"))
  R2D_makeTests(libName)
)
exit(0)
