;=====================================================================
; Rule2DRC Virtuoso adapter - execution harness (SKILL)
;
; Fixed harness. Loads a CANDIDATE skill file, opens a test layout
; read-only, calls the candidate's R2D_check(cvId rule), and writes
; the reported violations to a result file (one "x1 y1 x2 y2" per line,
; integer DBU coordinates).
;
; Driven by environment variables so it can be scripted from shell:
;   R2D_CANDIDATE  path to candidate .il file (must define R2D_check)
;   R2D_LIB        library name of the test layout
;   R2D_CELL       cell name of the test layout
;   R2D_VIEW       view name (usually "layout")
;   R2D_RESULT     path of the result file to write
;   R2D_RULE       rule spec "type,layer,threshold_um"
;                  e.g. "width_min,met1,0.14"
;
; Batch run example:
;   R2D_CANDIDATE=candidate/ref_width_min.il R2D_LIB=r2d_tests \
;   R2D_CELL=r2d_t1_width R2D_VIEW=layout R2D_RESULT=out.txt \
;   R2D_RULE="width_min,met1,0.14" \
;   virtuoso -nograph -replay harness/harness.il -log /tmp/r2d.log
;=====================================================================

;; Parse "type,layer,threshold" into list(type layer threshold)
procedure(R2D_parseRule(ruleStr)
  let((parts)
    parts = parseString(ruleStr ",")
    unless(length(parts) == 3
      error("R2D: bad R2D_RULE %L, want \"type,layer,threshold_um\"" ruleStr))
    list(car(parts) cadr(parts) atof(caddr(parts)))
  )
) ; R2D_parseRule

;; Run one test: load candidate, execute, serialize violations.
;; Returns t on success.
procedure(R2D_runTest(candidateFile libName cellName viewName resultFile rule)
  let((cvId viols outPort n)
    unless(loadi(candidateFile)
      error("R2D: cannot load candidate file %s" candidateFile))
    unless(isCallable('R2D_check)
      error("R2D: candidate %s must define procedure R2D_check(cvId rule)"
            candidateFile))
    cvId = dbOpenCellViewByType(libName cellName viewName "maskLayout" "r")
    unless(cvId
      error("R2D: cannot open %s/%s/%s read-only" libName cellName viewName))
    viols = R2D_check(cvId rule)   ; <-- candidate code runs here
    dbClose(cvId)
    unless(listp(viols)
      error("R2D: R2D_check must return a list, got %L" viols))
    outPort = outfile(resultFile "w")
    unless(outPort
      error("R2D: cannot write result file %s" resultFile))
    n = 0
    foreach(v viols
      ;; v = ((x1 y1) (x2 y2)) in DBU
      fprintf(outPort "%d %d %d %d\n"
              caar(v) cadar(v) caadr(v) cadadr(v))
      n++)
    close(outPort)
    printf("R2D: %s/%s -> %d violation(s) written to %s\n"
           cellName viewName n resultFile)
    t
  )
) ; R2D_runTest

;; Entry point for -replay: read env, run, exit.
procedure(R2D_main()
  let((candidateFile libName cellName viewName resultFile ruleStr rule)
    candidateFile = getShellEnvVar("R2D_CANDIDATE")
    libName       = getShellEnvVar("R2D_LIB")
    cellName      = getShellEnvVar("R2D_CELL")
    viewName      = getShellEnvVar("R2D_VIEW")
    resultFile    = getShellEnvVar("R2D_RESULT")
    ruleStr       = getShellEnvVar("R2D_RULE")
    foreach(v list(candidateFile libName cellName viewName resultFile ruleStr)
      unless(v && v != ""
        error("R2D: missing env var (need R2D_CANDIDATE/LIB/CELL/VIEW/RESULT/RULE)")))
    rule = R2D_parseRule(ruleStr)
    R2D_runTest(candidateFile libName cellName viewName resultFile rule)
    t
  )
) ; R2D_main

;; NOTE: this file only defines procedures. Batch entry lives in run.il
;; (loads this file, then calls R2D_main which exits when done).
