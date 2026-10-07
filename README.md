```
flowchart TD
    A["原始问卷数据<br/>xlsx / csv"] --> B["①查找重复个案<br/>janitor::get_dupes()"]
    B --> C["②查找非法值<br/>in_set / between / regex / not_null"]
    C --> D["③核查逻辑关系<br/>跨变量expr表达式校验"]
    D --> E["④缺失值处理<br/>列缺失统计 + 关键缺失行号"]
    E --> F["⑤异常连续变量<br/>IQR / Z分数离群值"]
    F --> G["⑥输出所有异常<br/>HTML报告 + 异常明细CSV"]
    G --> H["⑦改动并记录日志<br/>写入清洗日志csv/txt"]
    H --> I["⑧得到clean数据<br/>保守清洗导出xlsx/csv"]
```
# Rclean

面向问卷 / 流行病学调查数据（**xlsx、csv**）的可复现质控与清洗 R 包。把固定的 8 步检查做成函数，把每份问卷不同的字段规则（范围、合法值、逻辑关系）外置成 **Excel 或 YAML 规则表**—— 新项目只需填规则表，一条命令产出全部异常清单、汇总报告、改动日志和 clean 数据。

## 8 步流程

| 步骤 | 内容 | 实现 |
| --- | --- | --- |
| ① | 查找重复个案 | `janitor::get_dupes()`，支持按关键列或整行 |
| ② | 查找非法值 | in_set（合法值集合）、between（范围）、regex（正则）、not_null |
| ③ | 核查逻辑关系 | expr 跨变量 R 表达式（如发病日期 ≥ 出生日期） |
| ④ | 缺失值处理 | 每列缺失统计 + 关键列缺失行号（naniar 增强） |
| ⑤ | 异常连续变量 | IQR 法 / Z 分数法离群界值与明细 |
| ⑥ | 输出所有异常 | HTML 汇总报告 + 分问题 CSV；可选 pointblank 校验报告 |
| ⑦ | 改动并记录日志 | 每步行列变化写入《清洗日志》csv/txt |
| ⑧ | 得到 clean 数据 | 保守清洗（规范列名、去整行重复、去空行空列）后导出 xlsx/csv |

> 
> 非法值、逻辑矛盾、缺失、离群值**不自动替换**（避免引入假数据），全部列入报告由人工核对修改；只对无争议的整行重复、空行空列、列名做自动处理并留痕。
## 安装

```
# 硬依赖（最小集合）
install.packages(c("dplyr", "janitor", "readxl", "yaml", "tibble", "tidyr"))
# 从 GitHub 安装本包
install.packages("remotes")
remotes::install_github("Preventive-Medicine-renzhi-stu/Rclean")
# 建议同时安装增强包（不装也能跑，装了报告更全）
install.packages(c("rio", "vroom", "openxlsx2", "validate", "pointblank",
                   "naniar", "readr", "rmarkdown"))
# 可选的独立探索工具（本包不依赖，按需安装）：
# install.packages(c("tidylog", "dlookr", "DataExplorer", "visdat"))
```

## 快速开始

```
library(Rclean)
# 用包内置演示数据跑通（故意埋了重复、非法值、缺失、离群值）
run_qc(
  system.file("extdata", "demo_survey.xlsx", package = "Rclean"),
  rules_path = system.file("extdata", "rules_demo.yaml", package = "Rclean"),
  out_dir    = "qc_demo"
)
# 你自己的数据（规则表也可以用 rules_demo.xlsx）
run_qc("问卷数据.xlsx", rules_path = "my_rules.yaml", out_dir = "qc_问卷A")
```

输出目录内容：

```
qc_demo/
├── 数据质控异常报告.html       # 先看这个：四类异常计数 + 明细表
├── 01_重复个案.csv
├── 02_非法值与逻辑异常.csv
├── 02_pointblank校验报告.html  # 装了 pointblank 才有
├── 03_缺失值_列汇总.csv
├── 03_关键列缺失行.csv
├── 04_异常连续变量.csv
├── 清洗日志.csv / 清洗日志.txt
└── demo_survey_clean.xlsx      # 保守清洗后的 clean 数据
```

## 规则表怎么写

两种格式等价，二选一：

- **Excel**：复制 `inst/templates/rules_template.xlsx`，含 `rules / dupes / missing / outliers / 说明` 五个 sheet，表头不要改名。
- **YAML**：复制 `inst/templates/rules_template.yaml`。

支持的检查类型：

| check | 含义 | 必填字段 |
| --- | --- | --- |
| `in_set` | 取值必须在集合内（对应 EpiData LEGAL） | column、values |
| `between` | 数值范围（对应 EpiData RANGE） | column、min/max（可只填一端） |
| `not_null` | 不允许缺失 | column |
| `regex` | 正则匹配 | column、values（一个正则） |
| `expr` | 跨变量逻辑 R 表达式 | expr |

## 主要函数

- `run_qc()`：一键跑完 8 步
- `load_rules()`：读取 Excel/YAML 规则
- `qc_dupes()` / `qc_rules()` / `qc_missing()` / `qc_outliers()`：分步检查，可单独使用
- `qc_logger()`：改动日志记录器
- `read_survey()` / `export_clean()`：xlsx/csv 读写（rio 优先，自动回退）

## 建议的工作目录

```
问卷A/
├── 原始数据.xlsx          # 只读，永不覆盖
├── my_rules.xlsx          # 本问卷规则表
├── qc_问卷A/              # run_qc 产物（异常+日志）
└── clean/问卷A_clean.xlsx # 人工核对修改后的最终数据
```

## License

MIT

```
直接全选复制，粘贴到md文件。Mermaid改成纵向从上往下排版，不会横向超长。

如果你后续需要，我可以再给一个横向紧凑版Mermaid。
```
