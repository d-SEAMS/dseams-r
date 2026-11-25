test_that("an unknown sprintf object size is clamped to INT_MAX", {
  expect_identical(dseams:::sprintf_capacity_(-1), 2147483647)
  expect_identical(dseams:::sprintf_capacity_(64), 64)
  # Darwin's (size_t)-1: vsnprintf writes the text instead of failing.
  expect_identical(dseams:::sprintf_chk_("abc 42", -1), "abc 42")
})

test_that("checked sprintf stops when the text does not fit", {
  expect_identical(dseams:::sprintf_chk_("abc", 4), "abc")
  expect_error(dseams:::sprintf_chk_("abcd", 4), "exceeds its buffer")
})

test_that("checked sprintf stops on a negative vsnprintf count", {
  expect_identical(dseams:::sprintf_result_(3L, 16), 3L)
  expect_error(dseams:::sprintf_result_(-1L, 16), "could not be formatted")
  expect_error(dseams:::sprintf_result_(-1L, -1), "could not be formatted")
})
