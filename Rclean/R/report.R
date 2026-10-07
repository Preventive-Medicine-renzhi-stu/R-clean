#' 一键跑完 8 步质控清洗
#'
#' @param data_path xlsx/csv 数据文件
#' @param rules_path 规则文件（xlsx/yaml）；NULL 则只做整行重复、缺失扫描与数值列离群检查
#' @param out_dir 异常产物输出目录
#' @param clean_path clean 数据输出路径；NULL 表示放到 out_dir 下并沿用原扩展名
#' @param engine 规则引擎，"native" 或 "validate"
#' @param pointblank 已装 pointblank 时是否额外生成 HTML 校验报告
#' @param do_clean 是否执行保守清洗（规范列名、去整行重复、去空行空列）
#' @return 不可见 list，含全部产物路径与异常计数
#' @export
run_qc <- function(data_path, rules_path = NULL, out_dir = "qc",
                   clean_path = NULL, engine = c("native", "validate"),
                   pointblank = TRUE, do_clean = TRUE) {
  engine <- match.arg(engine)
  .ensure_dir(out_dir)
  is_file <- is.character(data_path)
  data_name <- if (is_file) basename(data_path) else "\u5185\u5b58\u6570\u636e\u6846"
  stem <- if (is_file) tools::file_path_sans_ext(data_name) else "clean_data"
  ext <- if (is_file) paste0(".", tools::file_ext(data_path)) else ".csv"
  logger <- qc_logger(file.path(out_dir, "\u6e05\u6d17\u65e5\u5fd7.csv"))
  logger$set_dataset(data_name)

  .msg("\u8bfb\u5165\u6570\u636e\uff1a", if (is_file) data_path else data_name)
  raw <- read_survey(data_path)
  logger$log("\u8bfb\u5165\u6570\u636e", after = raw, note = data_name)

  rules <- if (!is.null(rules_path)) {
    .msg("\u52a0\u8f7d\u89c4\u5219\uff1a", if (is.character(rules_path)) rules_path else "\u89c4\u5219\u5217\u8868"); load_rules(rules_path)
  } else .normalize_rules(list())

  # ① 重复个案
  .msg("\u2460 \u67e5\u627e\u91cd\u590d\u4e2a\u6848")
  dupes <- qc_dupes(raw, rules$dupes_key)
  p_dupes <- file.path(out_dir, "01_\u91cd\u590d\u4e2a\u6848.csv")
  .write_csv(dupes, p_dupes)

  # ②③ 非法值 + 逻辑关系
  .msg("\u2461\u2462 \u975e\u6cd5\u503c\u4e0e\u903b\u8f91\u5173\u7cfb\u6838\u67e5\uff08", nrow(rules$rules), " \u6761\u89c4\u5219\uff09")
  pb_path <- if (pointblank && requireNamespace("pointblank", quietly = TRUE))
    file.path(out_dir, "02_pointblank\u6821\u9a8c\u62a5\u544a.html") else NULL
  chk <- qc_rules(raw, rules, engine = engine, pointblank_report = pb_path)
  p_viol <- file.path(out_dir, "02_\u975e\u6cd5\u503c\u4e0e\u903b\u8f91\u5f02\u5e38.csv")
  .write_csv(chk$violations, p_viol)

  # ④ 缺失值
  .msg("\u2463 \u7f3a\u5931\u503c\u6838\u67e5")
  miss <- qc_missing(raw, rules$missing_key)
  p_miss <- file.path(out_dir, "03_\u7f3a\u5931\u503c_\u5217\u6c47\u603b.csv")
  .write_csv(miss$summary, p_miss)
  p_miss_rows <- NULL
  if (length(miss$key_missing_rows)) {
    p_miss_rows <- file.path(out_dir, "03_\u5173\u952e\u5217\u7f3a\u5931\u884c.csv")
    key_df <- data.frame("\u884c\u53f7" = miss$key_missing_rows,
                         check.names = FALSE)
    .write_csv(cbind(key_df, raw[miss$key_missing_rows, , drop = FALSE]),
               p_miss_rows)
  }

  # ⑤ 异常连续变量
  .msg("\u2464 \u8fde\u7eed\u53d8\u91cf\u79bb\u7fa4\u503c\u6838\u67e5")
  oc <- rules$outliers
  o_cols <- if (is.null(oc$columns) || (length(oc$columns) == 1 && is.na(oc$columns[1]))) NULL
            else oc$columns
  o_k <- if (is.null(oc$k) || is.na(oc$k)) NULL else oc$k
  outl <- qc_outliers(raw, o_cols, method = oc$method %||% "iqr", k = o_k)
  p_outl <- file.path(out_dir, "04_\u5f02\u5e38\u8fde\u7eed\u53d8\u91cf.csv")
  .write_csv(outl$outliers, p_outl)

  # ⑥ HTML 汇总报告
  .msg("\u2465 \u751f\u6210\u5f02\u5e38\u6c47\u603b\u62a5\u544a")
  result <- list(
    data_file = data_name,
    rules_file = if (is.character(rules_path)) basename(rules_path)
                 else if (is.null(rules_path)) "" else "\u89c4\u5219\u5217\u8868",
    n_rows = nrow(raw), n_cols = ncol(raw),
    generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    dupes = dupes, violations = chk$violations, rule_summary = chk$summary,
    missing = miss$summary, missing_key_rows = miss$key_missing_rows,
    outlier_bounds = outl$bounds, outliers = outl$outliers,
    paths = list(dupes = p_dupes, violations = p_viol, missing = p_miss,
                 missing_rows = p_miss_rows, outliers = p_outl,
                 pointblank = pb_path))
  p_report <- file.path(out_dir, "\u6570\u636e\u8d28\u63a7\u5f02\u5e38\u62a5\u544a.html")
  build_qc_report(result, p_report)

  # ⑦⑧ 保守清洗 + 日志 + 导出
  clean <- raw
  if (do_clean) {
    .msg("\u2466\u2467 \u4fdd\u5b88\u6e05\u6d17\u5e76\u5bfc\u51fa\uff08\u975e\u6cd5\u503c/\u7f3a\u5931/\u79bb\u7fa4\u4e0d\u81ea\u52a8\u6539\uff0c\u5217\u5728\u62a5\u544a\u4e2d\u5f85\u4eba\u5de5\u5904\u7406\uff09")
    clean <- janitor::clean_names(clean)
    logger$log("\u89c4\u8303\u5217\u540d clean_names", raw, clean)
    before <- clean
    clean <- dplyr::distinct(clean)
    logger$log("\u53bb\u9664\u6574\u884c\u91cd\u590d distinct", before, clean,
               note = paste0("\u5220\u9664 ", nrow(before) - nrow(clean), " \u884c"))
    before <- clean
    clean <- janitor::remove_empty(clean, which = c("rows", "cols"))
    logger$log("\u53bb\u9664\u7a7a\u884c\u7a7a\u5217 remove_empty", before, clean,
               note = paste0("\u5220\u9664 ", nrow(before) - nrow(clean), " \u884c / ",
                             ncol(before) - ncol(clean), " \u5217"))
    if (is.null(clean_path)) {
      clean_path <- file.path(out_dir, paste0(stem, "_clean", ext))
    }
    export_clean(clean, clean_path)
    logger$log("\u5bfc\u51fa clean \u6570\u636e", after = clean, note = basename(clean_path))
    result$clean_path <- clean_path
  }
  logger$write()
  result$log_path <- file.path(out_dir, "\u6e05\u6d17\u65e5\u5fd7.csv")
  result$log_txt <- file.path(out_dir, "\u6e05\u6d17\u65e5\u5fd7.txt")
  result$clean <- clean

  .msg("\u5b8c\u6210\u3002\u62a5\u544a\uff1a", p_report)
  invisible(result)
}

#' 生成 HTML 数据质控报告
#'
#' @param x [run_qc()] 产出的结果列表
#' @param path HTML 输出路径
#' @export
build_qc_report <- function(x, path) {
  n_dupes <- if (is.null(x$dupes)) 0 else nrow(x$dupes)
  n_viol_rows <- if (is.null(x$violations)) 0 else length(unique(x$violations$row))
  n_miss_cells <- sum(x$missing$n_missing, na.rm = TRUE)
  n_miss_cols <- sum(x$missing$n_missing > 0, na.rm = TRUE)
  n_outl <- if (is.null(x$outliers)) 0 else nrow(x$outliers)

  card <- function(num, label, color) paste0(
    "<div style='flex:1 1 130px;background:#fff;border:1px solid #dfe6ef;border-radius:10px;padding:12px;text-align:center;'>",
    "<div style='font-size:26px;font-weight:700;color:", color, ";'>", num, "</div>",
    "<div style='font-size:13px;color:#5b6b7c;margin-top:4px;'>", label, "</div></div>")

  html <- paste0(
    "<html><head><meta charset='utf-8'><title>\u6570\u636e\u8d28\u63a7\u5f02\u5e38\u62a5\u544a</title>",
    "<style>",
    "body{font-family:-apple-system,'PingFang SC','Microsoft YaHei',sans-serif;background:#f6f8fb;color:#1f2d3d;margin:0;padding:20px;}",
    "h2{font-size:17px;margin:22px 0 8px;} table{border-collapse:collapse;width:100%;background:#fff;font-size:13px;}",
    "th,td{border:1px solid #dfe6ef;padding:6px 8px;text-align:left;} th{background:#eef2f7;}",
    "p{font-size:13px;color:#5b6b7c;} .wrap{max-width:1100px;margin:0 auto;}",
    ".cards{display:flex;flex-wrap:wrap;gap:10px;}",
    ".note{background:#fff7e6;border:1px solid #f0d9a8;border-radius:8px;padding:10px 12px;font-size:13px;}",
    "</style></head><body><div class='wrap'>",
    "<h1 style='font-size:21px;'>\u6570\u636e\u8d28\u63a7\u5f02\u5e38\u62a5\u544a</h1>",
    "<p>\u6570\u636e\u6587\u4ef6\uff1a<b>", .html_escape(x$data_file), "</b>\uff1b\u89c4\u5219\u6587\u4ef6\uff1a<b>",
    .html_escape(x$rules_file %||% "\uff08\u672a\u63d0\u4f9b\uff0c\u9ed8\u8ba4\u68c0\u67e5\uff09"), "</b><br>\u6570\u636e\u89c4\u6a21\uff1a",
    x$n_rows, " \u884c \u00d7 ", x$n_cols, " \u5217\uff1b\u751f\u6210\u65f6\u95f4\uff1a", x$generated, "</p>",
    "<div class='cards'>",
    card(n_dupes, "\u91cd\u590d\u8bb0\u5f55\u6761\u6570", "#c0392b"),
    card(n_viol_rows, "\u6d89\u975e\u6cd5\u503c/\u903b\u8f91\u5f02\u5e38\u7684\u884c", "#c0392b"),
    card(paste0(n_miss_cells, " / ", n_miss_cols, " \u5217"), "\u7f3a\u5931\u5355\u5143\u683c / \u542b\u7f3a\u5931\u5217", "#d68910"),
    card(n_outl, "\u8fde\u7eed\u53d8\u91cf\u79bb\u7fa4\u503c\u6570", "#8e44ad"),
    "</div>",
    "<h2>\u2461\u2462 \u89c4\u5219\u6838\u67e5\u6c47\u603b</h2>", .df_to_html(x$rule_summary),
    "<h2>\u2460 \u91cd\u590d\u4e2a\u6848\uff08\u524d 50 \u884c\uff09</h2>", .df_to_html(x$dupes, 50),
    "<h2>\u2461\u2462 \u975e\u6cd5\u503c\u4e0e\u903b\u8f91\u5f02\u5e38\u660e\u7ec6\uff08\u524d 100 \u884c\uff09</h2>", .df_to_html(x$violations, 100),
    "<h2>\u2463 \u7f3a\u5931\u503c\u5217\u6c47\u603b</h2>", .df_to_html(x$missing),
    "<h2>\u2464 \u8fde\u7eed\u53d8\u91cf\u79bb\u7fa4\u754c\u503c</h2>", .df_to_html(x$outlier_bounds),
    "<h2>\u2464 \u79bb\u7fa4\u503c\u660e\u7ec6\uff08\u524d 100 \u884c\uff09</h2>", .df_to_html(x$outliers, 100),
    "<h2 class='note-h'>\u8bf4\u660e</h2>",
    "<div class='note'>\u81ea\u52a8\u6e05\u6d17\u4ec5\u505a\uff1a\u89c4\u8303\u5217\u540d\u3001\u53bb\u9664\u6574\u884c\u91cd\u590d\u3001\u53bb\u9664\u7a7a\u884c\u7a7a\u5217\uff0c\u5168\u90e8\u8bb0\u5f55\u5728\u300a\u6e05\u6d17\u65e5\u5fd7\u300b\u3002",
    "\u975e\u6cd5\u503c\u3001\u5173\u952e\u5217\u7f3a\u5931\u3001\u903b\u8f91\u77db\u76fe\u3001\u79bb\u7fa4\u503c\u9700\u4eba\u5de5\u6838\u5bf9\u540e\u4fee\u6539\uff0c\u672a\u7531\u7a0b\u5e8f\u81ea\u52a8\u66ff\u6362\uff1b\u5404\u95ee\u9898\u5b8c\u6574\u660e\u7ec6\u89c1\u540c\u76ee\u5f55 CSV\u3002</div>",
    "</div></body></html>")

  .ensure_dir(dirname(path))
  writeLines(html, path, useBytes = TRUE)
  invisible(path)
}
