test_that("this test illustrates MarkUs metadata attributes", {
  expect_equal(1, 1)
  
  # Following the pattern from the Python tester PR
  # This demonstrates how R unit tests can store MarkUs-related metadata
  exp_signal(new_expectation(
    type = "success",
    message = "",
    markus_overall_comments = "This is an overall comment. Great job!",
    markus_tag = "good",
    markus_annotation = list(
      filename = "submission.R",
      content = "This function should not be used",
      line_start = 5,
      line_end = 5,
      column_start = 2,
      column_end = 6
    )
  ))
})

test_that("MarkUs metadata can include multiple annotations", {
  expect_true(TRUE)
  
  # Example with multiple annotations
  exp_signal(new_expectation(
    type = "success", 
    message = "",
    markus_overall_comments = "Code analysis completed with multiple issues found",
    markus_tag = "needs_improvement",
    markus_annotation = list(
      list(
        filename = "submission.R",
        content = "Variable naming could be improved",
        line_start = 3,
        line_end = 3,
        column_start = 1,
        column_end = 10
      ),
      list(
        filename = "submission.R", 
        content = "Missing error handling",
        line_start = 8,
        line_end = 10,
        column_start = 1,
        column_end = 20
      )
    )
  ))
})

test_that("MarkUs metadata for image analysis", {
  expect_equal(2, 2)
  
  # Example for image/plot analysis
  exp_signal(new_expectation(
    type = "success",
    message = "",
    markus_overall_comments = "Visualization shows good understanding of data relationships",
    markus_tag = "excellent",
    markus_annotation = list(
      filename = "plots.png",
      content = "Axis labels are clear and informative",
      line_start = 1,
      line_end = 1,
      column_start = 1,
      column_end = 1
    )
  ))
})
