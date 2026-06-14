
<h1 align="center">Rule2DRC</h1>

<p align="center">
  <img src="assets/overview.png" width="500" alt="Rule2DRC overview">
</p>


<p align="center">
  <b>A LLM benchmark for generating Design Rule Checking (DRC) scripts from natural-language design-rule specifications.</b>
</p>

<p align="center">
  <a href="https://arxiv.org/abs/2605.15669"><img src="https://img.shields.io/badge/arXiv-2605.15669-b31b1b.svg"></a>
  <a href="https://jinukkim.me/blog/rule2drc/"><img src="https://img.shields.io/badge/Project-Rule2DRC-blue"></a>
  <a href="https://huggingface.co/papers/2605.15669"><img src="https://img.shields.io/badge/HF%20Papers-2605.15669-yellow"></a>
  <a href="https://huggingface.co/datasets/jusjinuk/Rule2DRC"><img src="https://img.shields.io/badge/Dataset-Hugging%20Face-green"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/License-MIT-orange"></a>
</p>

## Overview

Manufacturable chips should satisfy thousands of geometry-based design rules. **Design Rule Checking (DRC)** enforces these rules by running executable scripts written in domain-specific languages on layouts and checking constraints such as widths, spacings, enclosures, and overlaps. Writing DRC scripts from natural-language specifications is labor-intensive and requires specialized EDA expertise.

**Rule2DRC** evaluates whether an LLM agent can synthesize runnable KLayout DRC Ruby scripts from these specifications. Each problem contains a natural-language rule, layer definitions, the gold DRC script, and labeled GDS testcases. A generation is evaluated as successful only if the generated script compiles and matches all testcase labels for the problem. The benchmark contains **1,000 problems** and **13,921 labeled GDS testcases**.

## 项目意义

芯片制造前必须通过数千条几何设计规则。**DRC (Design Rule Check)** 通过在版图上运行领域特定语言（如 KLayout Ruby）编写的脚本来执行这些规则检查。从自然语言规范编写 DRC 脚本耗时且需要深厚的 EDA 专业知识。

Rule2DRC 填补了三个空白：

1. **标准化评估** — 此前 LLM-for-EDA 缺乏客观的、基于执行的基准测试。Rule2DRC 提供 1000 个问题，每个包含标准答案脚本和标注好的 GDS 测试用例，使 DRC 生成能力可量化。

2. **执行验证** — 生成的脚本必须在 KLayout 中编译通过且对所有测试用例分类正确（每个 category F1=1.0）才算成功，超越语法检查，验证语义正确性。

3. **测试生成驱动的候选选择** — SplitTester 方法利用 LLM 生成的 GDS 测试用例区分候选脚本，在没有标准测试用例的情况下实现 Best-of-N 选择。

**对 EDA 工作流的影响：**

| 方面 | Rule2DRC 之前 | 使用 Rule2DRC 之后 |
|------|-------------|-------------------|
| 脚本编写 | 专家手工编写，耗时数小时 | LLM 生成，分钟级完成 |
| 评估方式 | 人工审查 | 自动化 F1 评分 |
| 基准测试 | 非标准化、不可复现 | 标准化 1000 问题套件 |

**局限性：** 本 benchmark 仅覆盖 SKY130 的单规则问题；真实 PDK 有多规则、层次化约束。这是迈向完整 DRC 自动化的第一步。

## 模拟版图 Matching/Symmetry 扩展

在原始 Rule2DRC 基础上，新增 **5 个模拟版图规则**问题，覆盖 matching 和 symmetry 检查：

| 问题 ID | 规则类型 | 检查内容 | Category |
|---------|---------|---------|----------|
| 1001_diff_pair_sym | 差分对对称性 | 左右器件尺寸一致、关于 Y 轴镜像对称 | DIFF_PAIR_ASYMMETRIC |
| 1002_curr_mirror | 电流镜匹配 | 镜像管 active area (W×L) 相等 | CURR_MIRROR_MISMATCH |
| 1003_ccentroid_res | 共质心电阻阵列 | A-B-B-A 交叉排列，偶数个元素 | CCENTROID_VIOLATION |
| 1004_axis_sym | 轴对称性 | 所有结构关于 Y 轴镜像对称 | AXIS_ASYMMETRIC |
| 1005_orient_match | 电阻方向匹配 | 匹配电阻方向一致（全水平或全垂直） | ORIENT_MISMATCH |

### 检查方法

由于 KLayout DRC DSL 不支持直接的对称/matching 检查，采用 **Ruby 脚本 + RDB 输出** 方案：

```bash
# 运行模拟版图检查
klayout -b -r problems/1001_diff_pair_sym/gold/1001_diff_pair_sym.drc \
  -rd input=<test.gds> -rd output=<result.rdb>
```

检查逻辑：
- **对称性**: 比较 Y 轴左右两侧的多边形数量、面积、尺寸
- **匹配**: 比较配对器件的面积和尺寸
- **共质心**: 检查元素数量（偶数）、首尾对称性、A-A-B-B 分组检测
- **方向**: 比较多边形宽高比判断水平/垂直方向

### 评估结果

```
1001_diff_pair_sym: pass=OK fail=OK  F1=1.0
1002_curr_mirror:   pass=OK fail=OK  F1=1.0
1003_ccentroid_res: pass=OK fail=OK  F1=1.0
1004_axis_sym:      pass=OK fail=OK  F1=1.0
1005_orient_match:  pass=OK fail=OK  F1=1.0
```

### 文件结构

```
problems/1001_diff_pair_sym/
├── spec.yaml                      # 问题定义（NL 规则 + 层定义）
├── gold/
│   ├── 1001_diff_pair_sym.drc     # Gold DRC（Ruby 脚本）
│   └── check_sym.rb               # 对称检查核心逻辑
└── data/gds/
    ├── labels.csv                 # 标注
    ├── pass/*.gds                 # 应通过的版图
    └── fail/*.gds                 # 应失败的版图
```

## spec2drc: Foundry 规范 → DRC 脚本生成器

将结构化 DRC 规范（YAML）自动转换为可执行的 KLayout DRC Ruby 脚本。

### 使用方法

```bash
# 从 YAML spec 生成 DRC 脚本
python scripts/spec2drc.py examples/sky130_m1_rules.yaml -o output.drc

# 查看支持的规则类型
python scripts/spec2drc.py --list-rules

# 直接输出到终端
python scripts/spec2drc.py examples/nsm_keepout_spec.yaml
```

### Spec 格式

```yaml
id: my_drc_rules
title: "My DRC Rules"

layers:
  met1: [68, 20]      # layer号, datatype
  via: [68, 44]

categories:
  - M1_MIN_WIDTH
  - M1_MIN_SPACE

rules:
  - type: width_min        # 规则类型
    layer: met1            # 应用层
    threshold: 0.14        # 阈值 (um)
    category: M1_MIN_WIDTH # 输出类别
    text: "Metal1 minimum width is 0.14 um"
```

### 支持的规则类型

| 类型 | 说明 | 示例 |
|------|------|------|
| `width_min` | 最小宽度 | `layer.width(0.14.um)` |
| `width_max` | 最大宽度 (sized) | `layer.sized(-d/2).sized(d/2)` |
| `spacing` | 层间间距 | `layer1.separation(layer2, X.um)` |
| `spacing_self` | 同层自间距 | `layer.space(X.um)` |
| `enclosed` | 包围检查 | `inner.enclosed(outer, X.um)` |
| `inside` | 必须在内部 | `layer - outer` |
| `overlap` | 重叠检查 | `layer1 & layer2` |
| `no_overlap` | 不应重叠 | `layer1 & layer2` |
| `separation` | 分离间距 | `layer1.separation(layer2, X.um)` |
| `extension` | 扩展检查 | `layer - other.sized(X.um)` |
| `expression` | 自定义表达式 | 任意 DRC 表达式 |

### 示例

```bash
# 生成综合模拟版图 DRC 脚本
python scripts/spec2drc.py examples/analog_comprehensive_spec.yaml -o analog.drc

# 验证生成的脚本
klayout -b -r analog.drc -rd input=test.gds -rd output=result.rdb
```

### 工作流

```
Foundry PDF/文档
    ↓ (人工/LLM 提取)
YAML Spec 文件
    ↓ (spec2drc.py)
KLayout DRC 脚本
    ↓ (klayout -b -r)
RDB 违规报告
    ↓ (eval.py)
评估结果 (F1 Score)
```

## News

- **Aug 2026**: We will present Rule2DRC at [Agentic AI Summit 2026 @ UC Berkeley](https://rdi.berkeley.edu/events/agentic-ai-summit-2026).
- **May 2026**: Rule2DRC is released and accepted to ICML 2026.

## Dataset

The dataset is hosted on Hugging Face:

```python
from datasets import load_dataset

tasks = load_dataset("jusjinuk/Rule2DRC", "tasks", split="test")
testcases = load_dataset("jusjinuk/Rule2DRC", "testcases", split="test")
```

The `tasks` config has one row per benchmark problem, including `problem_id`, `prompt`, `spec_yaml`, `gold_drc`, and metadata. The `testcases` config has one row per GDS testcase, including `problem_id`, `gds_path`, `label`, `labels_json`, and binary `gds` bytes.

First materialize the Hugging Face dataset into the directory layout expected by the evaluation scripts:

```bash
python scripts/materialize_hf_dataset.py
```

This creates:

```text
problems/{problem_id}/spec.yaml
problems/{problem_id}/gold/{problem_id}.drc
problems/{problem_id}/data/gds/labels.csv
problems/{problem_id}/data/gds/{pass,fail}/*.gds
```

## Installation

Install Python dependencies:

```bash
uv sync
source .venv/bin/activate
```

KLayout is required for DRC execution. See [KLAYOUT.md](./KLAYOUT.md) for installation instructions, then make sure `klayout` is on `PATH`:

```bash
klayout -v
```

## Quick Start

Render a prompt:

```bash
python evaluate/make_prompt.py problems 0001
```

Evaluate the gold decks:

```bash
python eval.py --dir problems --jobs 100
```

Evaluate a single problem:

```bash
python eval.py --dir problems --problem 0001 --jobs 1
```

Outputs are written under `out_eval/`.

## Generating and Evaluating Model Outputs

The generation scripts use an OpenAI-compatible API. By default, the wrappers point to local vLLM at `http://127.0.0.1:8000/v1`.

### Start vLLM

Start an OpenAI-compatible server, for example:

```bash
export OPENAI_API_KEY=dummy
bash scripts/vllm/run_vllm.sh openai/gpt-oss-120b 8000
```

Most wrappers can be configured with environment variables such as `MODEL`, `BASE_URL`, `API_KEY`, `PROBLEMS_DIR`, `JOBS`, and `REASONING_EFFORT`.

### Generate Best-of-N (BoN) Candidates and Initial GDS Tests

Generate the maximum BoN candidate pool once:

```bash
bash scripts/run_bon.sh 60
```

This writes a Bon60 run under `out_drc/problems/{bon60_run}/`. Reuse this same directory for Bon10 x 3, Bon15 x 3, and Bon20 x 3 by partitioning the candidates into pools.

Generate self-generated GDS tests for candidate selection:

```bash
bash scripts/run_gen_tests.sh 8
```

This writes a test-generation run under `out_gds/problems/{gds_run}/`.

### Score Generated Tests

Bon60 is only the shared candidate source. Reported settings partition it into smaller pools:

| Setting | `<cand_min>` | `<cand_max>` | `<pool_size>` |
|:---|---:|---:|---:|
| Bon10 x 3 runs | 0 | 30 | 10 |
| Bon15 x 3 runs | 0 | 45 | 15 |
| Bon20 x 3 runs | 0 | 60 | 20 |

First score the generated GDS tests on the chosen partition. Scoring wrappers take `<cand_min> <cand_max> <pool_size>`:

```bash
# Generated Tests baseline
bash scripts/score_generated_tests.sh out_drc/problems/{bon60_run} out_gds/problems/{gds_run} <cand_min> <cand_max> <pool_size>
```

### Run Tester Agents

Run tester agents after `score_generated_tests.sh`, since they reuse generated-test scores and artifacts. `score_ours.sh` runs **SplitTester (Ours)**; the other scripts run comparison baselines.

```bash
# SplitTester (Ours)
bash scripts/score_ours.sh out_drc/problems/{bon60_run} out_gds/problems/{gds_run} <cand_min> <cand_max> <pool_size>

# S* baseline
bash scripts/score_s_star.sh out_drc/problems/{bon60_run} out_gds/problems/{gds_run} <cand_min> <cand_max> <pool_size>

# CodeMonkey-style baseline
bash scripts/score_codemonkey_select.sh out_drc/problems/{bon60_run} out_gds/problems/{gds_run} <cand_min> <cand_max> <pool_size>

# LLM judge baseline
bash scripts/score_llm_judge.sh out_drc/problems/{bon60_run} <cand_min> <cand_max> <pool_size>
```

### Aggregate Scores

Aggregate with the corresponding method key. Aggregation also takes `<cand_min> <cand_max> <pool_size>`:

```bash
bash scripts/aggregate_bon_scores.sh out_drc/problems/{bon60_run} <method_key> <cand_min> <cand_max> <pool_size> out_gds/problems/{gds_run}
```

Method keys:

- `generated_tests`: select by self-generated GDS tests.
- `generated_tests_ours`: select with **SplitTester (Ours)**.
- `generated_tests_s_star`: select with the S* baseline.
- `generated_tests_codemonkey_select`: select with the CodeMonkey-style baseline.
- `llm_judge`: select with an LLM judge over generated DRC code.

Aggregated JSON files are saved under the BoN run directory as `bon_pool<pool_size>__<method_key>.json`, for example `out_drc/problems/{bon60_run}/bon_pool10__generated_tests_ours.json`.

## TODO

- [ ] Build a public leaderboard website.
- [ ] Add private held-out tasks.
- [ ] Evaluate additional models and upload their results.

## Citation

```bibtex
@InProceedings{kim2026rule2drc,
  title     = {{Rule2DRC: Benchmarking LLM Agents for DRC Script Synthesis with Execution-Guided Test Generation}},
  author    = {Kim, Jinuk and Byun, Junsoo and Hwang, Donghwi and Park, Seong-Jin and Song, Hyun Oh},
  booktitle = {Proceedings of the 43rd International Conference on Machine Learning},
  year      = {2026},
  volume    = {306},
  series    = {Proceedings of Machine Learning Research},
  publisher = {PMLR}
}
```

## License

MIT
