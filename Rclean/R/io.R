#' 读入问卷数据（xlsx / csv / tsv）
#'
#' 优先使用 rio；未安装时按扩展名回退到 readxl / vroom / base R。
#'
#' @param path 数据文件路径（.xlsx/.xls/.csv/.tsv），或直接传入一个 data.frame
#' @param sheet xlsx 的工作表名或序号，默认第 1 个
#' @param ... 传给底层读取函数的额外参数
#' @return tibble
#' @export
read_survey <- function(path, sheet = NULL, ...) {
  if (is.data.frame(path)) return(tibble::as_tibble(path))
  if (!file.exists(path)) stop("\u6587\u4ef6\u4e0d\u5b58\u5728\uff1a", path, call. = FALSE)
  ext <- tolower(tools::file_ext(path))

  if (requireNamespace("rio", quietly = TRUE)) {
    df <- rio::import(path, sheet = sheet, ...)
  } else {
    df <- switch(ext,
      xls = , xlsx = {
        .need_pkg("readxl", "\u8bfb\u53d6 xlsx \u6587\u4ef6")
        readxl::read_excel(path, sheet = sheet %||% 1, ...)
      },
      csv = {
        if (requireNamespace("vroom", quietly = TRUE)) {
          as.data.frame(vroom::vroom(path, show_col_types = FALSE, ...))
        } else {
          utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE,
                          fileEncoding = "UTF-8", ...)
        }
      },
      tsv = utils::read.delim(path, stringsAsFactors = FALSE,
                              check.names = FALSE, fileEncoding = "UTF-8", ...),
      stop("\u6682\u4e0d\u652f\u6301\u7684\u6587\u4ef6\u683c\u5f0f\uff1a.", ext, "\uff1b\u53ef\u5b89\u88c5 rio \u5305\u83b7\u5f97\u66f4\u591a\u683c\u5f0f\u652f\u6301", call. = FALSE)
    )
  }
  tibble::as_tibble(df)
}

#' 导出清洗后的数据（xlsx / csv）
#'
#' 优先使用 rio；xlsx 回退到 openxlsx2 / openxlsx；csv 写出带 UTF-8 BOM。
#'
#' @param df 数据框
#' @param path 输出路径（按扩展名决定格式）
#' @param ... 传给底层写出函数的额外参数
#' @export
export_clean <- function(df, path, ...) {
  ext <- tolower(tools::file_ext(path))
  .ensure_dir(dirname(path))

  if (requireNamespace("rio", quietly = TRUE)) {
    rio::export(as.data.frame(df), path, ...)
    return(invisible(path))
  }

  switch(ext,
    xlsx = {
      if (requireNamespace("openxlsx2", quietly = TRUE)) {
        openxlsx2::write_xlsx(as.data.frame(df), path)
      } else if (requireNamespace("openxlsx", quietly = TRUE)) {
        openxlsx::write.xlsx(as.data.frame(df), path, overwrite = TRUE, ...)
      } else {
        stop("\u5199\u51fa xlsx \u9700\u8981 openxlsx2 \u6216 openxlsx \u5305\uff08\u6216\u5b89\u88c5 rio\uff09", call. = FALSE)
      }
    },
    csv = .write_csv(df, path),
    tsv = utils::write.table(df, path, sep = "\t", row.names = FALSE,
                             fileEncoding = "UTF-8"),
    stop("\u6682\u4e0d\u652f\u6301\u7684\u5bfc\u51fa\u683c\u5f0f\uff1a.", ext, call. = FALSE)
  )
  invisible(path)
}
