#' 加载问卷质控规则（Excel 或 YAML）
#'
#' 规则文件结构：
#' - `rules`：逐行规则，字段 id / check / column / values / min / max / expr / severity；
#'   check 支持 in_set（合法值集合）、between（数值范围）、not_null（不允许缺失）、
#'   regex（正则匹配）、expr（跨变量逻辑表达式）。
#' - `dupes$key`：判定重复个案的关键列（留空 = 整行重复）。
#' - `missing$key`：不允许缺失的关键列。
#' - `outliers`：method（iqr/zscore）、k（倍数，iqr 默认 1.5，zscore 默认 3）、columns（连续变量列）。
#'
#' @param path 规则文件路径（.xlsx/.yaml/.yml），或直接传入规则列表
#' @return 规范化后的规则列表（class = "qc_rules"）
#' @export
load_rules <- function(path) {
  if (is.list(path) && !is.data.frame(path)) return(.normalize_rules(path))
  if (!file.exists(path)) stop("\u89c4\u5219\u6587\u4ef6\u4e0d\u5b58\u5728\uff1a", path, call. = FALSE)
  ext <- tolower(tools::file_ext(path))

  raw <- if (ext %in% c("yaml", "yml")) {
    yaml::yaml.load_file(path)
  } else if (ext %in% c("xlsx", "xls")) {
    .need_pkg("readxl", "\u8bfb\u53d6 Excel \u89c4\u5219\u8868")
    .read_rules_xlsx(path)
  } else {
    stop("\u89c4\u5219\u6587\u4ef6\u4ec5\u652f\u6301 .xlsx / .yaml / .yml\uff0c\u6536\u5230\uff1a.", ext, call. = FALSE)
  }
  .normalize_rules(raw)
}

.read_rules_xlsx <- function(path) {
  sheets <- readxl::excel_sheets(path)
  out <- list()

  if ("rules" %in% sheets) {
    d <- as.data.frame(readxl::read_excel(path, sheet = "rules"))
    d <- d[!is.na(d$id) & nzchar(trimws(as.character(d$id))), , drop = FALSE]
    out$rules <- lapply(seq_len(nrow(d)), function(i) {
      r <- as.list(d[i, , drop = FALSE])
      item <- list(
        id = as.character(r$id),
        check = tolower(trimws(as.character(r$check))),
        column = if (all(is.na(r$column))) NULL else as.character(r$column),
        severity = if (is.null(r$severity) || all(is.na(r$severity))) "error"
                   else tolower(as.character(r$severity))
      )
      if (!is.null(r$values) && !all(is.na(r$values))) item$values <- .parse_cell_values(as.character(r$values))
      if (!is.null(r$min) && !all(is.na(r$min))) item$min <- as.numeric(r$min)
      if (!is.null(r$max) && !all(is.na(r$max))) item$max <- as.numeric(r$max)
      if (!is.null(r$expr) && !all(is.na(r$expr))) item$expr <- as.character(r$expr)
      item
    })
  }
  if ("dupes" %in% sheets) {
    d <- as.data.frame(readxl::read_excel(path, sheet = "dupes"))
    if ("key" %in% names(d)) out$dupes <- list(key = .na_trim(d$key))
  }
  if ("missing" %in% sheets) {
    d <- as.data.frame(readxl::read_excel(path, sheet = "missing"))
    if ("key" %in% names(d)) out$missing <- list(key = .na_trim(d$key))
  }
  if ("outliers" %in% sheets) {
    d <- as.data.frame(readxl::read_excel(path, sheet = "outliers"))
    if (nrow(d) >= 1) {
      r <- d[1, ]
      out$outliers <- list(
        method = if ("method" %in% names(d) && !is.na(r$method)) tolower(as.character(r$method)) else "iqr",
        k = if ("k" %in% names(d) && !is.na(r$k)) as.numeric(r$k) else NA_real_,
        columns = if ("columns" %in% names(d) && !is.na(r$columns))
          .parse_cell_values(as.character(r$columns)) else NA
      )
    }
  }
  out
}

.na_trim <- function(x) {
  x <- trimws(as.character(x))
  x <- x[!is.na(x) & nzchar(x)]
  if (length(x) == 0) NULL else x
}

.normalize_rules <- function(raw) {
  rule_items <- raw$rules %||% list()
  rules <- lapply(rule_items, function(r) {
    tibble::tibble(
      id = as.character(r$id %||% NA_character_),
      check = tolower(as.character(r$check %||% NA_character_)),
      column = if (is.null(r$column)) NA_character_ else as.character(r$column),
      values = list(r$values %||% NA),
      min = if (is.null(r$min)) NA_real_ else as.numeric(r$min),
      max = if (is.null(r$max)) NA_real_ else as.numeric(r$max),
      expr = if (is.null(r$expr)) NA_character_ else as.character(r$expr),
      severity = if (is.null(r$severity)) "error" else tolower(as.character(r$severity))
    )
  })
  rules_tbl <- if (length(rules)) dplyr::bind_rows(rules) else
    tibble::tibble(id = character(), check = character(), column = character(),
                   values = list(), min = numeric(), max = numeric(),
                   expr = character(), severity = character())

  out <- list(
    dataset = as.character(raw$dataset %||% "\u672a\u547d\u540d\u6570\u636e\u96c6"),
    rules = rules_tbl,
    dupes_key = raw$dupes$key %||% NULL,
    missing_key = raw$missing$key %||% NULL,
    outliers = raw$outliers %||% list(method = "iqr", k = NA_real_, columns = NULL)
  )
  if (is.null(out$outliers$method)) out$outliers$method <- "iqr"
  structure(out, class = "qc_rules")
}

# 把单条规则翻译为可对数据框求值的 R 逻辑表达式（字符串）
.rule_to_expr <- function(r) {
  col <- r$column
  switch(r$check,
    in_set = {
      vals <- r$values[[1]]
      if (length(vals) == 1 && is.na(vals[1])) stop("\u89c4\u5219 ", r$id, " \u7f3a\u5c11 values", call. = FALSE)
      dep <- if (is.character(vals)) paste0("c(", paste(vapply(vals, function(v)
        paste0("\"", gsub("\"", "\\\\\"", v), "\""), character(1)), collapse = ","), ")")
             else paste0("c(", paste(vals, collapse = ","), ")")
      paste0(col, " %in% ", dep)
    },
    between = {
      if (is.na(r$min) && is.na(r$max)) stop("\u89c4\u5219 ", r$id, " \u7f3a\u5c11 min/max", call. = FALSE)
      if (is.na(r$min)) paste0(col, " <= ", r$max)
      else if (is.na(r$max)) paste0(col, " >= ", r$min)
      else paste0(col, " >= ", r$min, " & ", col, " <= ", r$max)
    },
    not_null = paste0("!is.na(", col, ")"),
    regex = {
      pat <- r$values[[1]]
      if (length(pat) != 1 || is.na(pat[1])) stop("\u89c4\u5219 ", r$id, " \u7f3a\u5c11\u6b63\u5219 values", call. = FALSE)
      paste0("grepl(\"", gsub("\"", "\\\\\"", pat), "\", as.character(", col, "))")
    },
    expr = if (is.na(r$expr)) stop("\u89c4\u5219 ", r$id, " \u7f3a\u5c11 expr", call. = FALSE) else r$expr,
    stop("\u89c4\u5219 ", r$id, " \u4f7f\u7528\u4e86\u672a\u77e5 check \u7c7b\u578b\uff1a", r$check, call. = FALSE)
  )
}
