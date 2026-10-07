#' Rclean: 问卷数据（xlsx/csv）可复现质控与清洗
#'
#' 八步流程：重复个案 → 非法值 → 逻辑关系 → 缺失值 → 连续变量离群值 →
#' 异常汇总报告 → 改动日志 → clean 数据导出。问卷规则外置为 Excel/YAML 规则表。
#'
#' 快速开始：
#' ```
#' library(Rclean)
#' run_qc(system.file("extdata", "demo_survey.xlsx", package = "Rclean"),
#'        system.file("extdata", "rules_demo.yaml", package = "Rclean"),
#'        out_dir = "qc_demo")
#' ```
#' @keywords internal
#' @import dplyr janitor
#' @importFrom stats IQR complete.cases median quantile sd
#' @importFrom tibble as_tibble tibble
#' @importFrom tools file_ext file_path_sans_ext
#' @importFrom utils capture.output head packageVersion read.csv write.csv
#' @importFrom yaml yaml.load_file
"_PACKAGE"
