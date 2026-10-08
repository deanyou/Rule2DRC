# Rule2DRC Virtuoso Adapter (skeleton)

把 [Rule2DRC](https://github.com/snu-mllab/Rule2DRC)（ICML 2026：LLM 合成 DRC 脚本，
execution-guided 评测）的执行验证闭环搬到 Virtuoso/SKILL 链路。
上游用 KLayout 跑候选脚本；这里用 Virtuoso batch 跑候选 SKILL 代码。

核心思想不变：**verification 决定真相**——LLM 写 SKILL，真版图、真 db API
执行，结果跟 golden 对比打分。

## 文件结构

```
harness/
  harness.il          固定 harness：加载 candidate → 只读打开版图 →
                      调 R2D_check(cvId rule) → violation 写结果文件
  run.il              batch 入口（读 R2D_* 环境变量，跑完 exit）
  gen_golden.il       用参考实现生成 golden 结果（人工复核后再当标准）
  score.py            candidate vs golden：TP/FP/FN、precision/recall/F1
candidate/
  R2D_contract.il     候选合约：必须定义 R2D_check(cvId rule)
  ref_width_min.il    width_min 参考实现（rect 精确，polygon 用 bbox 近似）
tests/
  make_test_layouts.il  生成 3 个已知 violation 的微型测试版图
golden/               golden 结果文件（gen_golden.il 生成，git 可追踪）
```

## 候选合约

```skill
R2D_check(cvId rule) -> list of ((x1 y1) (x2 y2))
```

- `cvId`：只读打开的 layout cellview，不得修改。
- `rule`：`list("width_min" "met1" 0.14)` —— 类型、层名、阈值(um)。
- 返回：整数 DBU 坐标的 bbox 列表，按 (x1, y1) 排序，无 violation 返回 nil。
- 纯查询代码：禁文件 IO、禁 `ipcBeginProcess`、禁 `exit`。

## 运行流程（5 步）

```bash
cd rule2drc-virtuoso-adapter

# 1. 在 Library Manager 建好库并绑定 techfile（只需一次），生成测试版图
R2D_LIB=myLib virtuoso -nograph -replay tests/make_test_layouts.il

# 2. 用参考实现生成 golden（生成后人工看一眼 golden/ 再当标准）
R2D_LIB=myLib virtuoso -nograph -replay harness/gen_golden.il

# 3. 跑候选（这里先用参考实现自举验证链路）
R2D_CANDIDATE=candidate/ref_width_min.il R2D_LIB=myLib \
R2D_CELL=r2d_t1_width R2D_VIEW=layout R2D_RESULT=/tmp/out.txt \
R2D_RULE="width_min,met1,0.14" \
virtuoso -nograph -replay harness/run.il -log /tmp/r2d.log

# 4. 打分
python3 harness/score.py /tmp/out.txt golden/r2d_t1_width.txt

# 5. 换 LLM 生成的 candidate.il 重复 3-4，对比 F1
```

## 已知限制（诚实版）

- **未经 Virtuoso 实测**：本机无 Virtuoso，SKILL 代码是按语言手册写的，
  第一遍跑通前请当草稿看，重点核 `dbOpenCellViewByType` 参数顺序和
  `shape~>lpp` 返回形状。
- SKILL 没有内置 DRC 引擎：width 用短边判定（rect 精确）；
  polygon 用 bbox 近似，L 形会误判——生产级做法是负 sizing
 （`dbLayerSize` -threshold/2 后看哪些 shape 消失），留作下一步。
- 需要 Virtuoso license 才能跑 batch；KLayout 那种公开 leaderboard
  玩法复制不了，仅内部 benchmark。
- SKILL 遍历比 KLayout C++ 引擎慢一个量级，测试版图必须保持微型。

## 下一步

1. 在 Virtuoso 里跑通 5 步流程，修 SKILL 细节。
2. 加 `spacing_self`：候选用例两两 bbox 间距 < threshold 即报。
3. 加 `enclosed`：via1 不被 met1 包裹 threshold 即报。
4. width 改负 sizing 实现，去掉 polygon 近似。
5. 把 `examples/sky130_m1_rules.yaml` 的规则类型映射到 R2D_rule，
   让 spec2drc 的输出直接成为 candidate 输入。
