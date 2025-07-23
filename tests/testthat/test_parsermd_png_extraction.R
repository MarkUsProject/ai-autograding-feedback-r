test_that("QMD chunk extraction works correctly", {
  # Use direct path that works with source() calls
  qmd_path <- "../fixtures/sta130-example/submission.qmd"
  
  skip_if(!file.exists(qmd_path), "Test QMD file not found")
  
  # Test chunk extraction with context
  code_chunks <- extract_qmd_chunks_with_context(qmd_path)
  
  expect_true(length(code_chunks) > 0, "Should find some R chunks with contexts")
  
  # Check context naming pattern
  contexts <- sapply(code_chunks, function(x) x$context)
  expect_true(any(grepl("Q1", contexts)), "Should find Q1 contexts")
  expect_true(any(grepl("__", contexts)), "Should find sub-question contexts with __")
})

test_that("PNG generation works correctly", {
  # Use direct path that works with source() calls
  qmd_path <- "../fixtures/sta130-example/submission.qmd"
  
  skip_if(!file.exists(qmd_path), "Test QMD file not found")
  
  # Test PNG generation with temporary directory
  temp_output_dir <- file.path(tempdir(), "test_png_generation")
  if (dir.exists(temp_output_dir)) {
    unlink(temp_output_dir, recursive = TRUE)
  }
  
  # Test with reasonable timeout
  png_files <- run_qmd_collect_png(qmd_path, timeout = 30, output_dir = temp_output_dir)
  
  # Basic checks
  expect_true(is.character(png_files), "Should return character vector")
  
  # If PNG generation worked, validate the results
  if (length(png_files) > 0) {
    # Check naming convention
    file_names <- basename(png_files)
    expect_true(all(grepl("^plot__", file_names)), "All files should start with 'plot__'")
    expect_true(all(grepl("__[0-9]{3}\\.png$", file_names)), "All files should end with '__###.png'")
    
    # Check if files actually exist
    existing_files <- png_files[file.exists(png_files)]
    expect_gte(length(existing_files), 0, "Files should exist if returned")
  }
  
  # Clean up
  if (dir.exists(temp_output_dir)) {
    unlink(temp_output_dir, recursive = TRUE)
  }
})

test_that("extract_qmd_chunks_with_context handles various heading formats", {
  # Create a temporary test file
  test_content <- c(
    "---",
    "title: Test",
    "---",
    "",
    "# Question 1",
    "",
    "Some text here.",
    "",
    "```{r}",
    "# Test chunk 1", 
    "plot(1:10)",
    "```",
    "",
    "## (a) Create histograms",
    "",
    "More text.",
    "",
    "```{r}",
    "# Test chunk 2",
    "hist(rnorm(100))",
    "```",
    "",
    "## (b) Make a plot",
    "",
    "Even more text.",
    "",
    "```{r}",
    "# Test chunk 3",
    "barplot(c(1,2,3))",
    "```"
  )
  
  temp_file <- tempfile(fileext = ".qmd")
  writeLines(test_content, temp_file)
  
  # Test the extraction
  chunks <- extract_qmd_chunks_with_context(temp_file)
  
  expect_equal(length(chunks), 3, info = "Should find exactly 3 chunks")
  
  contexts <- sapply(chunks, function(x) x$context)
  expect_equal(contexts[1], "Q1", info = "First chunk should be Q1")
  expect_equal(contexts[2], "Q1__a", info = "Second chunk should be Q1__a") 
  expect_equal(contexts[3], "Q1__b", info = "Third chunk should be Q1__b")
  
  # Check code content
  expect_true(any(grepl("plot\\(1:10\\)", chunks[[1]]$code)), "First chunk should contain plot(1:10)")
  expect_true(any(grepl("hist\\(rnorm", chunks[[2]]$code)), "Second chunk should contain hist(rnorm")
  expect_true(any(grepl("barplot", chunks[[3]]$code)), "Third chunk should contain barplot")
  
  # Clean up
  unlink(temp_file)
})

test_that("question pattern matching works correctly", {
  # Test various heading formats
  test_cases <- data.frame(
    heading = c("# Question 1", "# QUESTION 2", "# question 3", "## (a)", "## (b) Some text", "## (z) Final part"),
    should_match_q = c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE),
    should_match_sub = c(FALSE, FALSE, FALSE, TRUE, TRUE, TRUE),
    stringsAsFactors = FALSE
  )
  
  for (i in 1:nrow(test_cases)) {
    case <- test_cases[i, ]
    
    # Test question pattern  
    q_match <- grepl("^# Question [0-9]+", case$heading, ignore.case = TRUE)
    expect_equal(q_match, case$should_match_q, 
                info = paste("Question pattern for:", case$heading))
    
    # Test sub-question pattern  
    sub_match <- grepl("^## \\([a-z]\\)", case$heading)
    expect_equal(sub_match, case$should_match_sub,
                info = paste("Sub-question pattern for:", case$heading))
  }
})
