;=====================================================================
; Rule2DRC Virtuoso adapter - golden result generator
;
; Runs the REFERENCE candidate over the test layouts and writes the
; expected violation files under golden/. The reference implementation
; is trusted by construction (it is the spec), but eyeball the golden
; files once before using them to score other candidates.
;
;   R2D_LIB=myLib virtuoso -nograph -replay harness/gen_golden.il
;=====================================================================

loadi("./harness/harness.il")

let((libName cases)
  libName = getShellEnvVar("R2D_LIB")
  unless(libName && libName != ""
    error("R2D: set R2D_LIB"))
  cases = list(
    ;; cell            rule                  golden file
    list("r2d_t1_width" "width_min,met1,0.14" "golden/r2d_t1_width.txt")
    list("r2d_t2_clean" "width_min,met1,0.14" "golden/r2d_t2_clean.txt")
    list("r2d_t3_multi" "width_min,met1,0.14" "golden/r2d_t3_multi.txt")
  )
  foreach(c cases
    R2D_runTest("./candidate/ref_width_min.il"
                libName (car c) "layout" (caddr c)
                R2D_parseRule(cadr(c))))
  printf("R2D: golden files written. Inspect them before scoring against them.\n")
)
exit(0)
