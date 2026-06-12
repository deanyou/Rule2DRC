# Rule2DRC KLayout 复现报告

## 1. 项目概述

**Rule2DRC** 是 ICML 2026 论文中的 LLM 基准测试，评估 LLM 从自然语言设计规则生成 KLayout DRC Ruby 脚本的能力。

- **论文**: [arXiv:2605.15669](https://arxiv.org/abs/2605.15669)
- **数据集**: [HuggingFace jusjinuk/Rule2DRC](https://huggingface.co/datasets/jusjinuk/Rule2DRC)
- **License**: MIT

---

## 2. 数据集统计

| 指标 | 数值 |
|------|------|
| 总问题数 | 1,000 |
| GDS 测试用例 | 13,921 |
| 平均每问题 GDS 数 | 13.9 |
| 唯一规则类别 | 1,000 |
| 问题类型数 | 123 |

### 规则类型分布

| 规则类型 | 数量 | 占比 |
|---------|------|------|
| enclosure (enclosed) | 396 | 39.6% |
| overlap | 204 | 20.4% |
| spacing (separation/space) | 188 | 18.8% |
| width | 87 | 8.7% |
| area | 59 | 5.9% |
| other | 65 | 6.5% |

### 问题类别分布 (Top 15)

| 类别 | 数量 |
|------|------|
| cascade_* (层叠规则) | 490 |
| hv (高压) | 23 |
| without_* | 21 |
| other | 19 |
| select_* | 19 |
| with_* | 14 |
| hvdifftap | 13 |
| vpp | 12 |
| licon | 12 |
| is_* | 12 |
| lvtn | 9 |
| via | 9 |
| polyimide | 8 |
| rpm | 8 |
| varac | 8 |

---

## 3. 环境搭建

### 3.1 KLayout 安装

```bash
brew install --cask klayout          # KLayout 0.30.4 (macOS)
mkdir -p ~/.local/bin
ln -s "/Applications/KLayout.app/Contents/MacOS/klayout" ~/.local/bin/klayout
export PATH="$HOME/.local/bin:$PATH"
klayout -v                           # KLayout 0.30.4
```

### 3.2 Python 环境

```bash
uv python pin 3.12                   # Python 3.12.4
uv sync                              # 63 packages installed
```

修改 `pyproject.toml` 将 `torch`/`transformers`/`vllm`/`faiss-cpu` 移至 `[project.optional-dependencies]`，避免 macOS x86_64 兼容性问题。

### 3.3 数据集 Materialize

```bash
python scripts/materialize_hf_dataset.py
# 输出: problems/{problem_id}/
#   ├── spec.yaml          (NL 规则 + 层定义)
#   ├── gold/{id}.drc      (标准答案)
#   └── data/gds/
#       ├── labels.csv     (标注)
#       ├── pass/*.gds     (应通过)
#       └── fail/*.gds     (应失败)
```

---

## 4. 评估结果

### 4.1 评估方法

使用 KLayout CLI 执行 DRC 脚本：
```bash
klayout -b -r <deck.drc> -rd input=<test.gds> -rd output=<result.lyrdb>
```
解析 RDB XML 输出，与 `labels.csv` 对比，计算每个 category 的 F1 分数。

**判定标准**: 所有 category F1=1.0 且 compile_rate=1.0 才算 success。

### 4.2 MiMo Code 生成的 DRC 脚本评估

| 问题 ID | 规则类型 | Category | TP | FP | FN | TN | P | R | F1 | GDS 数 | 结果 |
|---------|---------|----------|----|----|----|----|---|---|-----|--------|------|
| 0001_physical | overlap + separation | DNW_TO_PNP_SPACE_LT_5um | 2 | 0 | 0 | 2 | 1.00 | 1.00 | **1.00** | 4 | ✅ |
| 0003_physical | width (min) | PREC_RES_WIDTH_LT_2p03um | 2 | 0 | 0 | 2 | 1.00 | 1.00 | **1.00** | 4 | ✅ |
| 0004_physical | width (min) | LIRES_WIDTH_LT_0p29um | 2 | 0 | 0 | 2 | 1.00 | 1.00 | **1.00** | 4 | ✅ |
| 0005_physical | enclosed + inside | MCON_LI_ENC_LT_0p12um | 2 | 0 | 0 | 2 | 1.00 | 1.00 | **1.00** | 4 | ✅ |
| 0007_physical | self-spacing | POLYRES_SPACE_LT_0p48um | 2 | 0 | 0 | 2 | 1.00 | 1.00 | **1.00** | 4 | ✅ |
| 0008_laser_fuse | width (max, sized) | FUSE_WIDTH_GT_0p8um | 2 | 0 | 0 | 2 | 1.00 | 1.00 | **1.00** | 4 | ✅ |
| 0010_laser_fuse | overlap + separation | FUSE_TO_UNCONNECTED_SPACE_LT_0p2um | 2 | 0 | 0 | 2 | 1.00 | 1.00 | **1.00** | 4 | ✅ |
| 0012_laser_fuse | extension (sized diff) | M2_EXT_BEYOND_FUSE_GT_0p005um | 2 | 0 | 0 | 2 | 1.00 | 1.00 | **1.00** | 4 | ✅ |
| 0015_other | field layer + separation | POLY_FIELD_TO_DIFF_SPACE_LT_0p065um | 3 | 0 | 0 | 2 | 1.00 | 1.00 | **1.00** | 5 | ✅ |
| 0020_other | width (min) | MOSFET_GATE_WIDTH_SC_LT_0p075um | 2 | 0 | 0 | 2 | 1.00 | 1.00 | **1.00** | 4 | ✅ |
| 0022_other | enclosed + inside | TAP_NWELL_ENC_LT_0p22um | 2 | 0 | 0 | 2 | 1.00 | 1.00 | **1.00** | 4 | ✅ |
| 0025_other | multi-layer OR + overlap + separation | NSM_KEEPOUT_LT_1um | 19 | 0 | 0 | 2 | 1.00 | 1.00 | **1.00** | 21 | ✅ |
| 0030_other | width (min) | SCRIBE_WIDTH_LT_50um | 2 | 0 | 0 | 2 | 1.00 | 1.00 | **1.00** | 4 | ✅ |

**总体结果: 13/13 通过, success_rate = 100%, 平均 F1 = 1.00**

---

## 5. 生成的 DRC 脚本汇总

### 5.1 宽度检查 (width)
```ruby
# 0003: 精密电阻最小宽度 2.03um
prec_res.width(2.03.um).output("PREC_RES_WIDTH_LT_2p03um", "...")

# 0004: LI 电阻最小宽度 0.29um
li_res.width(0.29.um).output("LIRES_WIDTH_LT_0p29um", "...")

# 0020: MOSFET 栅极最小宽度 0.075um
poly_gate.width(0.075.um).output("MOSFET_GATE_WIDTH_SC_LT_0p075um", "...")

# 0030: 划片道最小宽度 50um
scrib.width(50.um).output("SCRIBE_WIDTH_LT_50um", "...")

# 0008: 熔丝最大宽度 0.8um (用 sized 技巧)
fuse.sized(-FSW_MAX / 2).sized(FSW_MAX / 2).output("FUSE_WIDTH_GT_0p8um", "...")
```

### 5.2 间距检查 (separation/space)
```ruby
# 0001: DNW 到 PNP 间距 ≥ 5.0um
dnw_c.separation(pnp_dg, 5.0.um).output("DNW_TO_PNP_SPACE_LT_5um", "...")

# 0007: 多晶硅电阻自间距 ≥ 0.48um
poly_res.space(0.48.um).output("POLYRES_SPACE_LT_0p48um", "...")

# 0010: 熔丝到未连接特征间距 ≥ 0.2um
fuse.separation(uncon_feat, 0.2.um).output("FUSE_TO_UNCONNECTED_SPACE_LT_0p2um", "...")

# 0025: 信号层到 NSM 间距 ≥ 1.0um
all.separation(nsm, 1.0.um).output("NSM_KEEPOUT_LT_1um", "...")
```

### 5.3 包含/重叠检查 (enclosed + inside)
```ruby
# 0005: mcon 必须在 LI 内部且被 LI 包围 ≥ 0.12um
mcon.enclosed(li1, 0.12.um).output("MCON_LI_ENC_LT_0p12um", "...")
(mcon - li1).output("MCON_LI_ENC_LT_0p12um", "Mcon not inside LI")

# 0022: TAP 必须在 NWELL 内部且被 NWELL 包围 ≥ 0.22um
tap.enclosed(nwell, 0.22.um).output("TAP_NWELL_ENC_LT_0p22um", "...")
(tap - nwell).output("TAP_NWELL_ENC_LT_0p22um", "TAP not inside NWELL")
```

### 5.4 重叠检查 (overlap)
```ruby
# 0001: DNW 和 PNP 不应重叠
(dnw_c & pnp_dg).output("DNW_TO_PNP_SPACE_LT_5um", "DNW and PNP overlap")

# 0015: poly on field 不应与 DIFF 重叠
(poly_field & diff).output("POLY_FIELD_TO_DIFF_SPACE_LT_0p065um", "...")

# 0010: 熔丝不应与未连接特征重叠
(fuse & uncon_feat).output("FUSE_TO_UNCONNECTED_SPACE_LT_0p2um", "...")
```

### 5.5 扩展检查 (extension, sized)
```ruby
# 0012: M2 超出熔丝边界 ≤ 0.005um
(m2 - fuse.sized(FEXT_MAX)).output("M2_EXT_BEYOND_FUSE_GT_0p005um", "...")
```

### 5.6 多层合并检查
```ruby
# 0025: 多层合并后检查
all = diff | poly | li1 | met1
(all & nsm).output("NSM_KEEPOUT_LT_1um", "Signal layer overlap NSM")
all.separation(nsm, 1.0.um).output("NSM_KEEPOUT_LT_1um", "...")
```

---

## 6. KLayout DRC DSL 模式总结

| 操作 | 语法 | 用途 |
|------|------|------|
| 最小宽度 | `layer.width(X.um)` | 报告宽度 < X 的区域 |
| 层间间距 | `layer1.separation(layer2, X.um)` | 报告 layer1 到 layer2 间距 < X 的区域 |
| 同层间距 | `layer.space(X.um)` | 报告同层内间距 < X 的区域 |
| 包围检查 | `inner.enclosed(outer, X.um)` | 报告 outer 包围 inner 不足 X 的区域 |
| 重叠 | `layer1 & layer2` | 布尔 AND (交集) |
| 差集 | `layer1 - layer2` | 布尔 NOT |
| 合并 | `layer1 \| layer2` | 布尔 OR (并集) |
| 扩大 | `layer.sized(d)` | 将多边形扩大 d |
| 缩小 | `layer.sized(-d)` | 将多边形缩小 d |
| 输出 | `.output("CATEGORY", "desc")` | 报告违规到指定类别 |

---

## 7. 已知问题与改进方向

### 7.1 环境限制
- KLayout 版本: 0.30.4 (Homebrew) vs 项目要求 0.30.5, 功能基本兼容
- Python 3.12.4 (通过 uv 管理)
- macOS x86_64 平台, `faiss-cpu` 无 wheel, 已移至 optional dependencies

### 7.2 评估流程
- `eval.py` 的 `--rule` 参数期望 `{rule_root}/{pid}/{pid}.drc` 目录结构
- 每个问题需要单独指定 rule root, 或使用默认 gold deck

### 7.3 扩展方向
- 批量评估全部 1000 个问题
- 接入 LLM API (vLLM/mimo) 实现自动生成
- 实现 BoN (Best-of-N) 选择策略
- 实现 SplitTester (论文方法) 进行候选选择

---

## 8. 文件结构

```
Rule2DRC/
├── problems/                          # 1000 个问题
│   ├── 0001_physical/
│   │   ├── spec.yaml                  # 问题定义
│   │   ├── gold/0001_physical.drc     # 标准答案
│   │   ├── data/gds/                  # GDS 测试用例
│   │   │   ├── labels.csv
│   │   │   ├── pass/*.gds
│   │   │   └── fail/*.gds
│   │   └── mimo/0001_physical/        # MiMo 生成的脚本
│   │       └── 0001_physical.drc
│   └── ...
├── evaluate/
│   ├── klayout_eval.py                # KLayout 评估核心
│   ├── make_prompt.py                 # Prompt 生成
│   └── prompt_template.j2             # Jinja2 模板
├── eval.py                            # 评估入口
├── bon.py                             # BoN 生成
├── gen_tests.py                       # 测试用例生成
├── score_generated_tests_ours.py      # SplitTester 方法
├── KLAYOUT.md                         # KLayout 安装指南
└── README.md
```

---

*报告生成时间: 2026-06-12*
*评估环境: macOS 13 x86_64, KLayout 0.30.4, Python 3.12.4*
