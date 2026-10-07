#' 清洗改动日志记录器
#'
#' 记录每一步操作前后的行列数与说明；结束时写出 CSV 与可读的 txt 日志。
#' 交互式使用时可另外 `library(tidylog)`，控制台会实时打印 dplyr/tidyr 的改动。
#'
#' @param csv_path 日志 CSV 路径（NULL 则只保留在内存）
#' @return 记录器对象（环境 + 方法）
#' @export
qc_logger <- function(csv_path = NULL) {
  e <- new.env(parent = emptyenv())
  e$csv_path <- csv_path
  e$txt_path <- if (!is.null(csv_path))
    paste0(tools::file_path_sans_ext(csv_path), ".txt") else NULL
  e$steps <- tibble::tibble(
    time = character(), step = character(),
    rows_before = integer(), rows_after = integer(),
    cols_before = integer(), cols_after = integer(), note = character())
  e$closed <- FALSE

  me <- list(
    # 记录一步改动
    log = function(step, before = NULL, after = NULL, note = "") {
      if (e$closed) warning("\u65e5\u5fd7\u5df2\u5173\u95ed", call. = FALSE)
      rb <- if (!is.null(before)) nrow(before) else NA_integer_
      ra <- if (!is.null(after)) nrow(after) else NA_integer_
      cb <- if (!is.null(before)) ncol(before) else NA_integer_
      ca <- if (!is.null(after)) ncol(after) else NA_integer_
      e$steps <- dplyr::bind_rows(e$steps, tibble::tibble(
        time = format(Sys.time(), "%Y-%m-%d %H:%M:%S"), step = as.character(step),
        rows_before = as.integer(rb), rows_after = as.integer(ra),
        cols_before = as.integer(cb), cols_after = as.integer(ca),
        note = as.character(note)))
      invisible(me)
    },
    # 写出日志文件
    write = function() {
      if (!is.null(e$csv_path)) {
        .ensure_dir(dirname(e$csv_path))
        .write_csv(e$steps, e$csv_path)
      }
      if (!is.null(e$txt_path)) {
        lines <- c(paste("Rclean \u6e05\u6d17\u65e5\u5fd7\uff0c\u751f\u6210\u65f6\u95f4", format(Sys.time())),
                   paste("\u6570\u636e\u6587\u4ef6\uff1a", e$dataset %||% ""),
                   paste(rep("-", 60), collapse = ""))
        for (i in seq_len(nrow(e$steps))) {
          s <- e$steps[i, ]
          f <- function(z) ifelse(is.na(z), "-", as.character(z))
          lines <- c(lines, sprintf("%s | %s | \u884c %s\u2192%s | \u5217 %s\u2192%s | %s",
                                    s$time, s$step, f(s$rows_before), f(s$rows_after),
                                    f(s$cols_before), f(s$cols_after), s$note))
        }
        writeLines(lines, e$txt_path, useBytes = TRUE)
      }
      e$closed <- TRUE
      invisible(me)
    },
    data = function() e$steps,
    set_dataset = function(name) { e$dataset <- name; invisible(me) }
  )
  structure(me, class = "qc_logger")
}
