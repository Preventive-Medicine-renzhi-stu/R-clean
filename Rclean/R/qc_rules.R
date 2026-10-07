#' ②③ 非法值与逻辑关系核查
#'
#' 按规则表逐条求值，输出违规明细与汇总。内置 "native" 引擎无需额外依赖；
#' 安装 validate / pointblank 后可切换或追加 HTML 校验报告。
#'
#' @param df 数据框
#' @param rules [load_rules()] 返回的规则对象
#' @param engine "native"（默认）或 "validate"
#' @param pointblank_report 若给文件路径（.html）且已装 pointblank，则额外生成报告
#' @return list(violations 长表, summary 每规则汇总, agent, cf)
#' @export
qc_rules <- function(df, rules, engine = c("native", "validate"),
                     pointblank_report = NULL) {
  engine <- match.arg(engine)
  rt <- rules$rules
  if (nrow(rt) == 0) {
    empty <- tibble::tibble(rule_id = character(), severity = character(),
                           check = character(), column = character(),
                           expr = character(), row = integer(),
                           offending_value = character())
    return(list(violations = empty,
                summary = tibble::tibble(rule_id = character(), check = character(),
                                         column = character(), n_pass = integer(),
                                         n_fail = integer(), n_na = integer()),
                agent = NULL, cf = NULL))
  }

  # 先检查规则引用的列都存在
  cols <- unique(rt$column[!is.na(rt$column)])
  .check_columns(df, cols, "\u8d28\u63a7\u89c4\u5219")

  exprs <- vapply(seq_len(nrow(rt)), function(i) .rule_to_expr(rt[i, ]), character(1))

  native <- .native_eval(df, rt, exprs)
  agent <- NULL; cf <- NULL

  if (engine == "validate") {
    if (requireNamespace("validate", quietly = TRUE)) {
      rule_df <- data.frame(name = rt$id, rule = exprs, stringsAsFactors = FALSE)
      cf <- validate::confront(df, validate::validator(.data = rule_df))
    } else {
      .msg("\u672a\u5b89\u88c5 validate\uff0c\u5df2\u56de\u9000\u5230 native \u5f15\u64ce")
    }
  }

  if (!is.null(pointblank_report)) {
    agent <- tryCatch(.pointblank_run(df, rt, pointblank_report),
                      error = function(e) {
                        .msg("pointblank \u62a5\u544a\u751f\u6210\u5931\u8d25\uff1a", conditionMessage(e))
                        NULL
                      })
  }
  list(violations = native$violations, summary = native$summary,
       agent = agent, cf = cf)
}

.native_eval <- function(df, rt, exprs) {
  viol <- list(); summ <- list()
  for (i in seq_len(nrow(rt))) {
    r <- rt[i, ]
    ok <- tryCatch(eval(parse(text = exprs[i]), envir = as.data.frame(df)),
                   error = function(e) e)
    if (inherits(ok, "error")) {
      stop("\u89c4\u5219 ", r$id, " \u6c42\u503c\u5931\u8d25\uff08", exprs[i], "\uff09\uff1a", conditionMessage(ok),
           call. = FALSE)
    }
    ok <- as.logical(ok)
    if (length(ok) != nrow(df)) {
      stop("\u89c4\u5219 ", r$id, " \u7684\u7ed3\u679c\u957f\u5ea6\uff08", length(ok), "\uff09\u4e0e\u6570\u636e\u884c\u6570\uff08",
           nrow(df), "\uff09\u4e0d\u4e00\u81f4", call. = FALSE)
    }
    n_na <- sum(is.na(ok))
    fail_idx <- if (r$check == "not_null") which(is.na(ok) | ok == FALSE)
                else which(!is.na(ok) & !ok)
    summ[[i]] <- tibble::tibble(
      rule_id = r$id, check = r$check,
      column = ifelse(is.na(r$column), "(\u8868\u8fbe\u5f0f)", r$column),
      n_pass = sum(ok %in% TRUE), n_fail = length(fail_idx), n_na = n_na)

    if (length(fail_idx)) {
      val <- if (!is.na(r$column) && r$check != "expr")
        as.character(df[[r$column]][fail_idx]) else NA_character_
      viol[[i]] <- tibble::tibble(
        rule_id = r$id, severity = r$severity, check = r$check,
        column = ifelse(is.na(r$column), "(\u8868\u8fbe\u5f0f)", r$column),
        expr = exprs[i], row = as.integer(fail_idx), offending_value = val)
    }
  }
  list(violations = dplyr::bind_rows(viol), summary = dplyr::bind_rows(summ))
}

.pointblank_run <- function(df, rt, report_path) {
  .need_pkg("pointblank", "\u751f\u6210 pointblank HTML \u62a5\u544a")
  .need_pkg("rlang", "pointblank \u52a8\u6001\u89c4\u5219")
  agent <- pointblank::create_agent(tbl = df, label = "Rclean \u8d28\u63a7")
  for (i in seq_len(nrow(rt))) {
    r <- rt[i, ]
    col <- if (is.na(r$column)) NULL else rlang::sym(r$column)
    agent <- switch(r$check,
      in_set = pointblank::col_vals_in_set(
        agent, columns = rlang::expr(!!col), set = r$values[[1]]),
      between = pointblank::col_vals_between(
        agent, columns = rlang::expr(!!col),
        left = if (is.na(r$min)) -Inf else r$min,
        right = if (is.na(r$max)) Inf else r$max),
      not_null = pointblank::col_vals_not_null(agent, columns = rlang::expr(!!col)),
      regex = pointblank::col_vals_regex(
        agent, columns = rlang::expr(!!col), regex = r$values[[1]][1]),
      expr = pointblank::col_vals_expr(agent, rlang::parse_expr(r$expr)),
      agent)
  }
  agent <- pointblank::interrogate(agent)
  .ensure_dir(dirname(report_path))
  if ("export_report" %in% getNamespaceExports("pointblank")) {
    pointblank::export_report(agent, filename = basename(report_path),
                              path = normalizePath(dirname(report_path), mustWork = FALSE))
  } else {
    html <- pointblank::get_agent_report(agent)
    writeLines(as.character(html), report_path, useBytes = TRUE)
  }
  agent
}
