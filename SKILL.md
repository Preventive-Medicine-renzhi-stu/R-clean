---
name: rclean
description: "面向问卷 / 流行病学调查数据（xlsx、csv）的可复现质控与清洗 R 包 Rclean：8 步检查 + 外置 Excel/YAML 规则表，一键产出异常报告、改动日志与 clean 数据。"
whenToUse: "当任务涉及问卷或 epidemiological survey 数据（xlsx/csv）的质量控制、异常核查、清洗留痕，或需要把字段规则（范围、合法值、逻辑关系）外置到非程序员可维护的规则表时使用。"
user-invocable: true
disable-model-invocation: false
---

# Rclean — 问卷数据可复现质控与清洗

## 1. 概述

`Rclean` 是一个面向 **问卷 / 流行病学调查数据（xlsx、csv）** 的质控清洗 R 包。核心设计：

- **八步流程**做成固定函数，一条 `run_qc()` 跑完。
- **规则外置**：每份问卷不同的字段规则（合法值、取值范围、正则、跨变量逻辑、重复 key、缺失 key、离群参数）写在 **Excel 或 YAML 规则表**里，不硬编码进 R 脚本。
- **保守清洗**：只有无争议的整行重复、空行空列、列名规范化由程序自动处理并记入日志；非法值、逻辑矛盾、缺失、离群值**不自动替换**，全部列入报告由人工核对。
- **全程留痕**：每步的行列变化写入《清洗日志》csv/txt。

硬依赖（最小集合）：`dplyr`、`janitor`、`readxl`、`rlang`、`stats`、`tibble`、`tools`、`utils`、`yaml`。
增强包（不装也能跑，装了报告更全）：`naniar`、`openxlsx`/`openxlsx2`、`pointblank`、`readr`、`rio`、`rmarkdown`、`validate`、`vroom`。

> 包内已自带演示数据：`inst/extdata/demo_survey.xlsx` + `inst/extdata/rules_demo.yaml`（及等价的 `.xlsx`），可直接跑通。

## 2. 八步流程

| 步 | 内容 | 默认实现 | 关键产物 |
|---|---|---|---|
| ① | 查找重复个案 | `janitor::get_dupes()`，支持按关键列或整行 | `01_重复个案.csv` |
| ② | 查找非法值 | native 引擎逐条求值（`in_set`/`between`/`regex`/`not_null`） | `02_非法值与逻辑异常.csv` |
| ③ | 核查逻辑关系 | `expr` 跨变量 R 表达式（如 `ONSETDT >= BIRTHDT`） | 同上 |
| ④ | 缺失值处理 | 每列缺失统计（naniar 增强）+ 关键列缺失行号 | `03_缺失值_列汇总.csv` / `03_关键列缺失行.csv` |
| ⑤ | 异常连续变量 | IQR 法（Q1−k·IQR / Q3+k·IQR）或 Z 分数法 | `04_异常连续变量.csv` |
| ⑥ | 输出所有异常 | HTML 汇总报告（卡片 + 各表）；可选 pointblank 校验报告 | `数据质控异常报告.html` |
| ⑦ | 改动并记录日志 | 每步行列变化写入 `清洗日志.csv` / `清洗日志.txt` | 日志 |
| ⑧ | 得到 clean 数据 | 保守清洗后导出 xlsx/csv | `\*_clean.xlsx` |

## 3. 规则表（最关键的可配置入口）

两种格式等价，二选一。模板在 `inst/templates/rules_template.xlsx` / `rules_template.yaml`。

### YAML 结构

```yaml
dataset: 示例问卷                    # 仅用于报告显示

# ① 重复个案：判定重复的关键列；留空 key 或整段删除 = 整行完全一致
dupes:
  key: [ID]

# ④ 缺失值：这些列不允许缺失（关键标识列）
missing:
  key: [ID]

# ⑤ 连续变量离群值：columns 留空 = 自动检查全部数值列
outliers:
  method: iqr        # 或 zscore
  k: 1.5             # iqr 默认 1.5，zscore 默认 3
  columns: [AGE, MAXTEMP]

# ②③ 逐条规则
rules:
  - id: SEX_legal
    check: in_set           # 取值必须在 values 内（对应 EpiData LEGAL）
    column: SEX
    values: [1, 2]
    severity: error         # 仅出现在明细里，不触发自动处理

  - id: AGE_range
    check: between          # 数值范围（对应 EpiData RANGE）
    column: AGE
    min: 0
    max: 120

  - id: ID_not_null
    check: not_null
    column: ID

  - id: PHONE_regex
    check: regex
    column: PHONE
    values: ["^1[3-9][0-9]{9}$"]

  - id: date_logic
    check: expr             # 跨变量逻辑 R 表达式
    expr: "ONSETDT >= BIRTHDT | is.na(ONSETDT) | is.na(BIRTHDT)"
```

### 支持的 check 类型

| check | 含义 | 必填字段 | 示例 |
|---|---|---|---|
| `in_set` | 取值必须在集合内 | `column`、`values` | `values: [1, 2]` |
| `between` | 数值范围 | `column`、`min`/`max`（可只填一端） | `min: 0, max: 120` |
| `not_null` | 不允许缺失 | `column` | — |
| `regex` | 正则匹配 | `column`、`values`（一个正则） | `values: ["^1[3-9][0-9]{9}$"]` |
| `expr` | 跨变量逻辑 R 表达式 | `expr` | `"ONSETDT >= BIRTHDT"` |

Excel 版规则表含 `rules / dupes / missing / outliers / 说明` 五个 sheet，表头不要改名；`.parse_cell_values()` 会自动把 `"1, 2，3"` 这种单元格拆成向量并推断数值/字符。

## 4. 函数参考

### `run_qc()` — 一键跑完 8 步（最常用）

```r
run_qc(
  data_path,                       # xlsx/csv 文件路径，或内存 data.frame
  rules_path = NULL,               # 规则文件（.xlsx/.yaml/.yml）；NULL 只做①④⑤
  out_dir = "qc",                  # 异常产物输出目录
  clean_path = NULL,               # clean 数据路径；NULL 则 out_dir/原名_clean.xlsx
  engine = c("native", "validate"), # 规则引擎；validate 需 validate 包
  pointblank = TRUE,               # 装了点 pointblank 时额外生成 HTML 校验报告
  do_clean = TRUE                  # 是否执行保守清洗
)
```

返回值（不可见 list）：`data_file`、`rules_file`、`n_rows`、`n_cols`、`generated`、`dupes`、`violations`、`rule_summary`、`missing`、`missing_key_rows`、`outlier_bounds`、`outliers`、`paths`、`clean_path`、`log_path`、`log_txt`、`clean`。

输出目录典型结构：

```
qc_demo/
├── 数据质控异常报告.html        # 先看这个：四类异常计数 + 明细表
├── 01_重复个案.csv
├── 02_非法值与逻辑异常.csv
├── 02_pointblank校验报告.html   # 装了 pointblank 才有
├── 03_缺失值_列汇总.csv
├── 03_关键列缺失行.csv
├── 04_异常连续变量.csv
├── 清洗日志.csv / 清洗日志.txt
└── demo_survey_clean.xlsx       # 保守清洗后的 clean 数据
```

### `load_rules()` — 读取规则表

```r
load_rules(path)   # 路径（.xlsx/.yaml/.yml），或直接传入规则列表
```

返回 class `"qc_rules"` 的 list：`dataset`、`rules`（tibble，列 `id/check/column/values/min/max/expr/severity`）、`dupes_key`、`missing_key`、`outliers`。

### 分步函数（可单独调用）

| 函数 | 用途 | 关键参数 |
|---|---|---|
| `qc_dupes(df, key = NULL)` | 找重复；`key=NULL` 按整行 | 返回含 `dupe_count` 的 tibble |
| `qc_rules(df, rules, engine = "native", pointblank_report = NULL)` | ②③ 非法值+逻辑 | 返回 `violations` / `summary` / `agent` / `cf` |
| `qc_missing(df, key = NULL)` | ④ 缺失 | 返回 `summary`（variable/n_missing/pct_missing）与 `key_missing_rows` |
| `qc_outliers(df, columns = NULL, method = "iqr", k = NULL)` | ⑤ 离群 | 返回 `bounds`（含各列上下界与 `n_outlier`）与 `outliers` 长表 |
| `qc_logger(csv_path = NULL)` | ⑦ 改动日志 | 返回记录器对象（`log()` / `write()` / `data()` / `set_dataset()`） |
| `read_survey(path, sheet = NULL, ...)` | 读数据 | rio 优先，回退 readxl / vroom / base R；支持 xlsx/csv/tsv |
| `export_clean(df, path, ...)` | 写 clean 数据 | rio 优先，xlsx 回退 openxlsx2/openxlsx，csv 带 UTF-8 BOM |
| `build_qc_report(x, path)` | 生成 HTML 汇总报告 | `x` 为 `run_qc()` 返回的结果列表 |

引擎细节：`qc_rules()` 的 native 引擎用 `.rule_to_expr()` 把规则翻译成 R 表达式在数据框上 `eval(parse())`；`validate` 引擎通过 `validate::confront()`；pointblank 报告通过 `col_vals_in_set` / `col_vals_between` / `col_vals_not_null` / `col_vals_regex` / `col_vals_expr` 逐条构建后 `interrogate()`。

## 5. 推荐工作目录

```
问卷A/
├── 原始数据.xlsx          # 只读，永不覆盖
├── my_rules.xlsx          # 本问卷规则表
├── qc_问卷A/              # run_qc 产物（异常+日志）
└── clean/问卷A_clean.xlsx # 人工核对修改后的最终数据
```

## 6. 快速开始

```r
library(Rclean)

# 用包内置演示数据跑通（故意埋了重复、非法值、缺失、离群值）
run_qc(
  system.file("extdata", "demo_survey.xlsx", package = "Rclean"),
  rules_path = system.file("extdata", "rules_demo.yaml", package = "Rclean"),
  out_dir    = "qc_demo"
)

# 非程序员用 Excel 规则表：
run_qc("问卷数据.xlsx", rules_path = "my_rules.xlsx", out_dir = "qc_问卷A")
```

## 7. 常见坑

- **规则引用的列名不存在**：`.check_columns()` 会直接报错，先对一下数据列名。
- **`between` 只填了一端**：合法，生成单侧不等式；但两端都空会报错。
- **`expr` 求值失败**：native 引擎会停住并打印失败的规则 id 与表达式；先单独跑 `qc_rules()` 定位。
- **`values` 写成字符串**：`.parse_cell_values()` 会尝试转数值，`"1, 2"` → `c(1, 2)`；含非数字时保留字符。
- **离群值不自动处理**：`qc_outliers()` 只出界值与明细，不会删行。
- **空结果**：`write_csv()` 会自动写出"未发现问题"占位行，避免产出空 CSV。
- **中文乱码**：CSV 统一写 UTF-8 BOM，Excel 直接打开不会乱码。
- **R 未安装时**：包本身只有 R 源码，需要先装 R ≥ 3.6；`rio` 等可选包按需安装。

## 8. 与外部工具的衔接

- 交互式探索可 `library(tidylog)` 让 dplyr/tidyr 的改动实时打印到控制台（包本身不依赖）。
- 可选独立探索工具（本包不依赖）：`tidylog`、`dlookr`、`DataExplorer`、`visdat`。
- `inst/templates/qc_report.Rmd` 里还保留了一份基于 Rmd 的报告模板（`run_qc(..., do_clean=FALSE)` 后可引用），当前默认走 `build_qc_report()` 内联 HTML。