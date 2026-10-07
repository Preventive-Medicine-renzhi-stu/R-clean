#' ① 查找重复个案
#'
#' @param df 数据框
#' @param key 关键列名向量；NULL 表示按整行判定重复
#' @return 重复记录（含重复次数列 dupe_count），无重复时返回 0 行 tibble
#' @export
qc_dupes <- function(df, key = NULL) {
  if (!is.null(key) && length(key) > 0) {
    .check_columns(df, key, "\u91cd\u590d\u5224\u5b9a key")
    d <- janitor::get_dupes(df, dplyr::all_of(key))
  } else {
    d <- janitor::get_dupes(df)
  }
  tibble::as_tibble(d)
}

#' ④ 缺失值核查
#'
#' 返回每列缺失统计；若指定关键列，额外返回关键列缺失的行号。
#'
#' @param df 数据框
#' @param key 不允许缺失的关键列
#' @return list(summary, key_missing_rows)
#' @export
qc_missing <- function(df, key = NULL) {
  if (requireNamespace("naniar", quietly = TRUE)) {
    summary <- naniar::miss_var_summary(df)
    summary <- tibble::as_tibble(summary)
    names(summary) <- c("variable", "n_missing", "pct_missing")
  } else {
    n_miss <- vapply(df, function(x) sum(is.na(x)), integer(1))
    summary <- tibble::tibble(
      variable = names(df),
      n_missing = as.integer(n_miss),
      pct_missing = round(100 * n_miss / nrow(df), 2)
    )
  }
  rows <- integer(0)
  if (!is.null(key) && length(key) > 0) {
    .check_columns(df, key, "\u7f3a\u5931\u6838\u67e5 key")
    rows <- which(rowSums(is.na(df[key])) > 0)
  }
  list(summary = summary, key_missing_rows = rows)
}

#' ⑤ 查找连续变量异常值（离群值）
#'
#' @param df 数据框
#' @param columns 连续变量列名；NULL 表示自动选取全部数值列
#' @param method "iqr"（默认，Q1-k*IQR / Q3+k*IQR）或 "zscore"（均值 ± k 个标准差）
#' @param k 倍数；NULL 时 iqr 用 1.5、zscore 用 3
#' @return list(bounds = 各列上下界, outliers = 长表：列/行/值/下界/上界)
#' @export
qc_outliers <- function(df, columns = NULL, method = "iqr", k = NULL) {
  method <- match.arg(tolower(method), c("iqr", "zscore"))
  if (is.null(k)) k <- if (method == "iqr") 1.5 else 3

  if (is.null(columns) || length(columns) == 0) {
    columns <- names(df)[vapply(df, is.numeric, logical(1))]
  } else {
    .check_columns(df, columns, "\u79bb\u7fa4\u503c\u6838\u67e5")
    columns <- columns[vapply(df[columns], is.numeric, logical(1))]
  }

  bounds <- lapply(columns, function(col) {
    x <- df[[col]]
    if (method == "iqr") {
      q <- stats::quantile(x, probs = c(0.25, 0.75), na.rm = TRUE)
      iqr <- unname(q[2] - q[1])
      tibble::tibble(column = col, method = method, k = k,
                     lower = unname(q[1] - k * iqr), upper = unname(q[2] + k * iqr),
                     n_outlier = NA_integer_)
    } else {
      mu <- mean(x, na.rm = TRUE); s <- stats::sd(x, na.rm = TRUE)
      tibble::tibble(column = col, method = method, k = k,
                     lower = mu - k * s, upper = mu + k * s, n_outlier = NA_integer_)
    }
  })
  bounds <- dplyr::bind_rows(bounds)

  out_list <- lapply(seq_len(nrow(bounds)), function(i) {
    col <- bounds$column[i]
    lo <- bounds$lower[i]; up <- bounds$upper[i]
    x <- df[[col]]
    idx <- which(!is.na(x) & (x < lo | x > up))
    if (length(idx) == 0) return(NULL)
    tibble::tibble(column = col, row = idx, value = x[idx],
                   lower = lo, upper = up)
  })
  outliers <- dplyr::bind_rows(out_list)
  if (nrow(bounds) > 0) {
    cnt <- if (nrow(outliers)) dplyr::count(outliers, .data$column, name = "n")
           else tibble::tibble(column = character(), n = integer())
    bounds$n_outlier <- as.integer(cnt$n[match(bounds$column, cnt$column)])
    bounds$n_outlier[is.na(bounds$n_outlier)] <- 0L
  }
  list(bounds = bounds, outliers = outliers)
}
