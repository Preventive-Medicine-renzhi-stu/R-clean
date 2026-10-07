# 内部工具函数（不导出）

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0) b else a

.msg <- function(...) {
  message(sprintf("[%s] %s", format(Sys.time(), "%H:%M:%S"), paste0(...)))
}

.need_pkg <- function(pkg, why = "") {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop("\u9700\u8981\u5b89\u88c5 R \u5305 '", pkg, "'", if (nzchar(why)) paste0("\uff08", why, "\uff09"),
         "\u3002\u5b89\u88c5\u547d\u4ee4\uff1ainstall.packages(\"", pkg, "\")", call. = FALSE)
  }
}

.ensure_dir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE)
  invisible(path)
}

# 去掉字符串两端空白
.trim <- function(x) {
  if (is.character(x)) trimws(x) else x
}

# 把 "1, 2，3" / c 形式的单元格解析成向量，并自动推断数值/字符
.parse_cell_values <- function(x) {
  if (is.null(x) || length(x) == 0 || (is.character(x) && is.na(x))) return(NA)
  if (!is.character(x)) return(as.vector(x))
  s <- trimws(x)
  if (is.na(s) || !nzchar(s)) return(NA_character_)
  parts <- strsplit(s, "[,\uff0c;\uff1b\u3001]\\s*")[[1]]
  parts <- trimws(parts)
  parts <- parts[nzchar(parts)]
  # 全可转数值则转数值
  num <- suppressWarnings(as.numeric(parts))
  if (all(!is.na(num))) num else parts
}

# 统一的列存在性检查
.check_columns <- function(df, cols, context = "\u89c4\u5219") {
  miss <- setdiff(cols, names(df))
  if (length(miss)) {
    stop(context, "\u5f15\u7528\u4e86\u6570\u636e\u4e2d\u4e0d\u5b58\u5728\u7684\u5217\uff1a", paste(miss, collapse = ", "), call. = FALSE)
  }
}

# 依赖安全的 CSV 写出（UTF-8 BOM，Excel 直接打开中文不乱码）
.write_csv <- function(df, path) {
  if (nrow(df) == 0) df <- data.frame("\u63d0\u793a" = "\u672a\u53d1\u73b0\u95ee\u9898",
                                      check.names = FALSE)
  # 剥掉 pillar/vctrs 特殊类型，避免 write.csv 的 as.character 报错
  df <- as.data.frame(lapply(as.data.frame(df), function(x) {
    if (is.factor(x)) as.character(x)
    else if (inherits(x, "vctrs_vctr")) as.vector(x)
    else x
  }))
  csv_lines <- character(0)
  tc <- textConnection("csv_lines", "w", local = TRUE)
  write.csv(df, tc, row.names = FALSE, fileEncoding = "UTF-8")
  close(tc)
  csv_lines[1] <- paste0("\ufeff", csv_lines[1])
  writeLines(csv_lines, path, useBytes = TRUE)
  invisible(path)
}

# 简单 HTML 转义
.html_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}

# data.frame 转 HTML 表格（最多展示 n 行）
.df_to_html <- function(df, n = 200) {
  if (is.null(df) || nrow(df) == 0) {
    return("<p style='color:#2f7d5a;'>\u672a\u53d1\u73b0\u95ee\u9898</p>")
  }
  show <- if (nrow(df) > n) df[seq_len(n), , drop = FALSE] else df
  cells <- function(r) paste(vapply(r, function(z) {
    paste0("<td>", .html_escape(format(z, trim = TRUE)), "</td>")
  }, character(1)), collapse = "")
  head_html <- paste0("<tr>", paste0("<th>", .html_escape(names(show)), "</th>",
                                     collapse = ""), "</tr>")
  rows <- apply(show, 1, cells)
  more <- if (nrow(df) > n) paste0("<p>\u4ec5\u5c55\u793a\u524d ", n, " \u884c\uff0c\u5171 ", nrow(df),
                                   " \u884c\uff0c\u5b8c\u6574\u5185\u5bb9\u89c1\u540c\u540d CSV\u3002</p>") else ""
  paste0("<table><thead>", head_html, "</thead><tbody>",
         paste(rows, collapse = ""), "</tbody></table>", more)
}
