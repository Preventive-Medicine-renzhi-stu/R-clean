# Rclean 一键清洗示例
# 首次使用先安装：
#   install.packages(c("dplyr","janitor","readxl","yaml"))
#   remotes::install_github("Preventive-Medicine-renzhi-stu/Rclean")

library(Rclean)

# 包内置演示数据（含重复、非法值、缺失、离群值），第一次可直接跑通
demo_data  <- system.file("extdata", "demo_survey.xlsx", package = "Rclean")
demo_rules <- system.file("extdata", "rules_demo.yaml", package = "Rclean")

# YAML 规则版
res <- run_qc(demo_data, rules_path = demo_rules, out_dir = "qc_demo_yaml")

# Excel 规则版（非程序员可直接在 Excel 里维护规则）
demo_rules_xlsx <- system.file("extdata", "rules_demo.xlsx", package = "Rclean")
res2 <- run_qc(demo_data, rules_path = demo_rules_xlsx, out_dir = "qc_demo_xlsx")

# 你自己的数据：
# res <- run_qc("问卷数据.xlsx", rules_path = "rules_template.yaml",
#               out_dir = "qc_问卷A")
# 产出（out_dir 内）：
#   数据质控异常报告.html      ← 先看这个
#   01_重复个案.csv
#   02_非法值与逻辑异常.csv
#   02_pointblank校验报告.html （装了 pointblank 才有）
#   03_缺失值_列汇总.csv / 03_关键列缺失行.csv
#   04_异常连续变量.csv
#   清洗日志.csv / 清洗日志.txt
#   demo_survey_clean.xlsx     ← 保守清洗后的 clean 数据
