; Batch entry: load the harness, run one test from env vars, exit.
; Usage: virtuoso -nograph -replay harness/run.il   (with R2D_* env set)
loadi("./harness/harness.il")
R2D_main()
exit(0)
