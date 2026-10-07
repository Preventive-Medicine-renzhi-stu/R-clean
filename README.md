# Rclean

面向问卷 / 流行病学调查数据（**xlsx、csv**）的可复现质控与清洗 R 包。把固定的 8 步检查做成函数，把每份问卷不同的字段规则（范围、合法值、逻辑关系）外置成 **Excel 或 YAML 规则表**——新项目只需填规则表，一条命令产出全部异常清单、汇总报告、改动日志和 clean 数据。

## 8 步流程

| 步骤 | 内容 | 实现 |
|---|---|---|
| ① | 查找重复个案 | `janitor::get_dupes()`，支持按关键列或整行 |
| ② | 查找非法值 | in_set（合法值集合）、between（范围）、regex（正则）、not_null |
| ③ | 核查逻辑关系 | expr 跨变量 R 表达式（如发病日期 ≥ 出生日期） |
| ④ | 缺失值处理 | 每列缺失统计 + 关键列缺失行号（naniar 增强） |
| ⑤ | 异常连续变量 | IQR 法 / Z 分数法离群界值与明细 |
| ⑥ | 输出所有异常 | HTML 汇总报告 + 分问题 CSV；可选 pointblank 校验报告 |
| ⑦ | 改动并记录日志 | 每步行列变化写入《清洗日志》csv/txt |
| ⑧ | 得到 clean 数据 | 保守清洗（规范列名、去整行重复、去空行空列）后导出 xlsx/csv |

> 非法值、逻辑矛盾、缺失、离群值**不自动替换**（避免引入假数据），全部列入报告由人工核对修改；只对无争议的整行重复、空行空列、列名做自动处理并留痕。

<html style="margin:0;padding:0;">
<title>R 语言 xlsx/csv 数据清洗流程与高星包映射</title>
<div style="width:100%;box-sizing:border-box;font-family:-apple-system,'PingFang SC','Microsoft YaHei',sans-serif;background:#f6f8fb;padding:20px 16px;">
  <div style="font-size:20px;font-weight:700;color:#1f2d3d;margin-bottom:4px;">R 语言 · xlsx/csv 数据清洗 8 步流程与高星包</div>
  <div style="font-size:13px;color:#5b6b7c;margin-bottom:16px;">星数为 2026-10-07 GitHub 实测；读写层贯穿始终，清洗主流程按你的 8 步排列</div>
  <div style="background:#eef4ee;border:1px solid #cfe0cf;border-radius:10px;padding:10px 12px;margin-bottom:16px;">
    <div style="font-size:14px;font-weight:700;color:#2f7d5a;margin-bottom:6px;">文件读写层（xlsx / csv）</div>
    <div style="display:flex;flex-wrap:wrap;gap:8px;font-size:13px;color:#1f2d3d;">
      <span style="background:#fff;border:1px solid #d5e2d5;border-radius:6px;padding:4px 8px;"><b>rio</b> 621★ · import()/export() 统一读写</span>
      <span style="background:#fff;border:1px solid #d5e2d5;border-radius:6px;padding:4px 8px;"><b>readxl</b> 754★ · read_excel() 读 xlsx</span>
      <span style="background:#fff;border:1px solid #d5e2d5;border-radius:6px;padding:4px 8px;"><b>vroom</b> 643★ · 极速读 csv/tsv</span>
      <span style="background:#fff;border:1px solid #d5e2d5;border-radius:6px;padding:4px 8px;"><b>openxlsx</b> 241★ · write.xlsx() 写回（新版 openxlsx2 200★）</span>
    </div>
  </div>
  <div style="display:flex;flex-wrap:wrap;align-items:center;gap:6px;margin-bottom:16px;">
    <div style="display:flex;align-items:center;gap:6px;background:#e8eef7;border:1px solid #c7d6ea;border-radius:20px;padding:5px 10px;"><span style="width:20px;height:20px;border-radius:50%;background:#3b6fd4;color:#fff;font-size:13px;font-weight:700;display:flex;align-items:center;justify-content:center;">1</span><span style="font-size:14px;color:#1f2d3d;font-weight:600;">重复个案</span></div>
    <span style="color:#9aa8b8;font-size:14px;">→</span>
    <div style="display:flex;align-items:center;gap:6px;background:#e8eef7;border:1px solid #c7d6ea;border-radius:20px;padding:5px 10px;"><span style="width:20px;height:20px;border-radius:50%;background:#3b6fd4;color:#fff;font-size:13px;font-weight:700;display:flex;align-items:center;justify-content:center;">2</span><span style="font-size:14px;color:#1f2d3d;font-weight:600;">非法值</span></div>
    <span style="color:#9aa8b8;font-size:14px;">→</span>
    <div style="display:flex;align-items:center;gap:6px;background:#e8eef7;border:1px solid #c7d6ea;border-radius:20px;padding:5px 10px;"><span style="width:20px;height:20px;border-radius:50%;background:#3b6fd4;color:#fff;font-size:13px;font-weight:700;display:flex;align-items:center;justify-content:center;">3</span><span style="font-size:14px;color:#1f2d3d;font-weight:600;">逻辑关系</span></div>
    <span style="color:#9aa8b8;font-size:14px;">→</span>
    <div style="display:flex;align-items:center;gap:6px;background:#e8eef7;border:1px solid #c7d6ea;border-radius:20px;padding:5px 10px;"><span style="width:20px;height:20px;border-radius:50%;background:#3b6fd4;color:#fff;font-size:13px;font-weight:700;display:flex;align-items:center;justify-content:center;">4</span><span style="font-size:14px;color:#1f2d3d;font-weight:600;">缺失值</span></div>
    <span style="color:#9aa8b8;font-size:14px;">→</span>
    <div style="display:flex;align-items:center;gap:6px;background:#e8eef7;border:1px solid #c7d6ea;border-radius:20px;padding:5px 10px;"><span style="width:20px;height:20px;border-radius:50%;background:#3b6fd4;color:#fff;font-size:13px;font-weight:700;display:flex;align-items:center;justify-content:center;">5</span><span style="font-size:14px;color:#1f2d3d;font-weight:600;">异常连续变量</span></div>
    <span style="color:#9aa8b8;font-size:14px;">→</span>
    <div style="display:flex;align-items:center;gap:6px;background:#e8eef7;border:1px solid #c7d6ea;border-radius:20px;padding:5px 10px;"><span style="width:20px;height:20px;border-radius:50%;background:#3b6fd4;color:#fff;font-size:13px;font-weight:700;display:flex;align-items:center;justify-content:center;">6</span><span style="font-size:14px;color:#1f2d3d;font-weight:600;">输出异常</span></div>
    <span style="color:#9aa8b8;font-size:14px;">→</span>
    <div style="display:flex;align-items:center;gap:6px;background:#e8eef7;border:1px solid #c7d6ea;border-radius:20px;padding:5px 10px;"><span style="width:20px;height:20px;border-radius:50%;background:#3b6fd4;color:#fff;font-size:13px;font-weight:700;display:flex;align-items:center;justify-content:center;">7</span><span style="font-size:14px;color:#1f2d3d;font-weight:600;">改动记录日志</span></div>
    <span style="color:#9aa8b8;font-size:14px;">→</span>
    <div style="display:flex;align-items:center;gap:6px;background:#2f7d5a;border:1px solid #1f5f44;border-radius:20px;padding:5px 10px;"><span style="width:20px;height:20px;border-radius:50%;background:#fff;color:#2f7d5a;font-size:13px;font-weight:700;display:flex;align-items:center;justify-content:center;">8</span><span style="font-size:14px;color:#fff;font-weight:600;">clean 数据</span></div>
  </div>
  <div style="display:flex;flex-wrap:wrap;gap:10px;">
    <div style="flex:1 1 160px;min-width:160px;background:#fff;border:1px solid #dfe6ef;border-radius:10px;padding:12px;">
      <div style="font-size:14px;font-weight:700;color:#3b6fd4;margin-bottom:6px;">① 重复个案</div>
      <div style="font-size:14px;line-height:1.55;color:#1f2d3d;"><b>janitor</b> 1459★<br><a href="https://github.com/sfirke/janitor" style="color:#2f7d5a;">github.com/sfirke/janitor</a><br><span style="color:#5b6b7c;font-size:12px;">get_dupes() 列出全部重复记录</span></div>
    </div>
    <div style="flex:1 1 160px;min-width:160px;background:#fff;border:1px solid #dfe6ef;border-radius:10px;padding:12px;">
      <div style="font-size:14px;font-weight:700;color:#3b6fd4;margin-bottom:6px;">② 非法值</div>
      <div style="font-size:14px;line-height:1.55;color:#1f2d3d;"><b>pointblank</b> 1050★<br><a href="https://github.com/rstudio/pointblank" style="color:#2f7d5a;">github.com/rstudio/pointblank</a><br><span style="color:#5b6b7c;font-size:12px;">col_vals_in_set / between / regex</span></div>
      <div style="font-size:14px;line-height:1.55;color:#1f2d3d;margin-top:6px;"><b>assertr</b> 484★<br><a href="https://github.com/tonyfischetti/assertr" style="color:#2f7d5a;">github.com/tonyfischetti/assertr</a></div>
    </div>
    <div style="flex:1 1 160px;min-width:160px;background:#fff;border:1px solid #dfe6ef;border-radius:10px;padding:12px;">
      <div style="font-size:14px;font-weight:700;color:#3b6fd4;margin-bottom:6px;">③ 逻辑关系</div>
      <div style="font-size:14px;line-height:1.55;color:#1f2d3d;"><b>validate</b> 434★<br><a href="https://github.com/data-cleaning/validate" style="color:#2f7d5a;">github.com/data-cleaning/validate</a><br><span style="color:#5b6b7c;font-size:12px;">validator() 写跨变量规则，confront() 比对，violations() 出问题清单</span></div>
      <div style="font-size:14px;line-height:1.55;color:#1f2d3d;margin-top:6px;"><b>pointblank</b>：col_vals_expr() 行内表达式</div>
    </div>
    <div style="flex:1 1 160px;min-width:160px;background:#fff;border:1px solid #dfe6ef;border-radius:10px;padding:12px;">
      <div style="font-size:14px;font-weight:700;color:#3b6fd4;margin-bottom:6px;">④ 缺失值</div>
      <div style="font-size:14px;line-height:1.55;color:#1f2d3d;"><b>naniar</b> 675★<br><a href="https://github.com/njtierney/naniar" style="color:#2f7d5a;">github.com/njtierney/naniar</a><br><span style="color:#5b6b7c;font-size:12px;">miss_var_summary() 缺失统计</span></div>
      <div style="font-size:14px;line-height:1.55;color:#1f2d3d;margin-top:6px;"><b>visdat</b> 463★ · <b>dlookr</b> 214★<br><a href="https://github.com/ropensci/visdat" style="color:#2f7d5a;">github.com/ropensci/visdat</a><br><span style="color:#5b6b7c;font-size:12px;">vis_miss() 可视化；imputate_na() 插补</span></div>
    </div>
    <div style="flex:1 1 160px;min-width:160px;background:#fff;border:1px solid #dfe6ef;border-radius:10px;padding:12px;">
      <div style="font-size:14px;font-weight:700;color:#3b6fd4;margin-bottom:6px;">⑤ 异常连续变量</div>
      <div style="font-size:14px;line-height:1.55;color:#1f2d3d;"><b>dlookr</b> 214★<br><a href="https://github.com/choonghyunryu/dlookr" style="color:#2f7d5a;">github.com/choonghyunryu/dlookr</a><br><span style="color:#5b6b7c;font-size:12px;">diagnose_outlier() 离群值诊断</span></div>
      <div style="font-size:14px;line-height:1.55;color:#1f2d3d;margin-top:6px;"><b>dataReporter</b>（原 dataMaid 143★）<br><a href="https://github.com/ekstroem/dataReporter" style="color:#2f7d5a;">github.com/ekstroem/dataReporter</a><br><span style="color:#5b6b7c;font-size:12px;">identifyOutliers 检查</span></div>
    </div>
    <div style="flex:1 1 160px;min-width:160px;background:#fff;border:1px solid #dfe6ef;border-radius:10px;padding:12px;">
      <div style="font-size:14px;font-weight:700;color:#3b6fd4;margin-bottom:6px;">⑥ 输出所有异常</div>
      <div style="font-size:14px;line-height:1.55;color:#1f2d3d;"><b>DataExplorer</b> 544★<br><a href="https://github.com/boxuancui/DataExplorer" style="color:#2f7d5a;">github.com/boxuancui/DataExplorer</a><br><span style="color:#5b6b7c;font-size:12px;">create_report() 一键 HTML 报告</span></div>
      <div style="font-size:14px;line-height:1.55;color:#1f2d3d;margin-top:6px;"><b>dlookr</b> diagnose_report() · <b>pointblank</b> get_agent_report() · <b>skimr</b> 控制台速览 <a href="https://github.com/ropensci/skimr" style="color:#2f7d5a;">链接</a></div>
    </div>
    <div style="flex:1 1 160px;min-width:160px;background:#fff;border:1px solid #dfe6ef;border-radius:10px;padding:12px;">
      <div style="font-size:14px;font-weight:700;color:#3b6fd4;margin-bottom:6px;">⑦ 改动并记录日志</div>
      <div style="font-size:14px;line-height:1.55;color:#1f2d3d;"><b>tidylog</b> 623★<br><a href="https://github.com/elbersb/tidylog" style="color:#2f7d5a;">github.com/elbersb/tidylog</a><br><span style="color:#5b6b7c;font-size:12px;">自动打印每步 filter/mutate/join 的增删行数，天然改动日志</span></div>
      <div style="font-size:14px;line-height:1.55;color:#1f2d3d;margin-top:6px;"><b>validate</b>：violations() 导出异常明细留痕</div>
    </div>
    <div style="flex:1 1 160px;min-width:160px;background:#2f7d5a;border:1px solid #1f5f44;border-radius:10px;padding:12px;">
      <div style="font-size:14px;font-weight:700;color:#fff;margin-bottom:6px;">⑧ clean 数据</div>
      <div style="font-size:14px;line-height:1.55;color:#eaf5ef;"><b>rio::export()</b> 写回 xlsx/csv；或 openxlsx::write.xlsx() / readr::write_csv()。异常报告 + 日志一并归档，可复现。</div>
    </div>
  </div>
  <div style="font-size:12px;color:#8a99a8;margin-top:14px;">注：pointblank 的 R 主仓库是 rstudio/pointblank（posit-dev/pointblank 为 Python 移植版）；openxlsx 原 awalker89 仓库已移交 ycphs 维护。</div>
</div>
</html>

## 安装

```r
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

```r
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
|---|---|---|
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
