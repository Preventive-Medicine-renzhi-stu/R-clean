test_that("qc_dupes finds full-row and key duplicates", {
  df <- data.frame(ID = c(1, 2, 2, 3), x = c("a", "b", "b", "d"))
  d <- qc_dupes(df, key = "ID")
  expect_equal(nrow(d), 2)
  expect_true("dupe_count" %in% names(d))
  expect_equal(nrow(qc_dupes(data.frame(a = 1:3))), 0)
})

test_that("qc_missing counts NAs and flags key rows", {
  df <- data.frame(ID = c(1, NA, 3), v = c(NA, 2, NA))
  m <- qc_missing(df, key = "ID")
  expect_equal(m$summary$n_missing[m$summary$variable == "ID"], 1)
  expect_equal(m$key_missing_rows, 2)
})

test_that("qc_outliers IQR detects planted extremes", {
  df <- data.frame(v = c(rep(10, 20), 100))
  o <- qc_outliers(df, columns = "v", method = "iqr", k = 1.5)
  expect_equal(o$outliers$row, 21)
  expect_equal(o$bounds$n_outlier, 1)
})

test_that("native rule engine catches illegal and out-of-range values", {
  df <- data.frame(ID = 1:4, SEX = c(1, 2, 3, 1), AGE = c(20, 200, -1, 30))
  rules <- Rclean:::.normalize_rules(list(rules = list(
    list(id = "SEX_legal", check = "in_set", column = "SEX", values = c(1, 2)),
    list(id = "AGE_range", check = "between", column = "AGE", min = 0, max = 120),
    list(id = "ID_not_null", check = "not_null", column = "ID")
  )))
  res <- qc_rules(df, rules)
  expect_equal(res$summary$n_fail[res$summary$rule_id == "SEX_legal"], 1)
  expect_equal(res$summary$n_fail[res$summary$rule_id == "AGE_range"], 2)
  expect_equal(res$summary$n_fail[res$summary$rule_id == "ID_not_null"], 0)
  expect_true(3 %in% res$violations$row[res$violations$rule_id == "SEX_legal"])
})

test_that("expr rules evaluate cross-variable logic", {
  df <- data.frame(A = c(5, 1), B = c(2, 9))
  rules <- Rclean:::.normalize_rules(list(rules = list(
    list(id = "A_gt_B", check = "expr", expr = "A >= B")
  )))
  res <- qc_rules(df, rules)
  expect_equal(res$violations$row, 2)
})

test_that("logger records row deltas", {
  lg <- qc_logger(NULL)
  lg$log("step", data.frame(a = 1:3), data.frame(a = 1:2))
  d <- lg$data()
  expect_equal(d$rows_before, 3)
  expect_equal(d$rows_after, 2)
})

test_that("yaml and xlsx rules load to the same structure", {
  y <- system.file("extdata", "rules_demo.yaml", package = "Rclean")
  x <- system.file("extdata", "rules_demo.xlsx", package = "Rclean")
  skip_if(y == "" || x == "", "demo rule files missing")
  ry <- load_rules(y); rx <- load_rules(x)
  expect_equal(nrow(ry$rules), nrow(rx$rules))
  expect_equal(ry$rules$id, rx$rules$id)
  expect_equal(ry$dupes_key, rx$dupes_key)
  expect_equal(ry$missing_key, rx$missing_key)
})
