
# Assignment: R Data Manipulation and Function Writing

## Problem Description

Write a series of R expressions and functions to analyze a dataset containing student scores in math, science, and English.

You will compute averages, filter data, and define a grading function using basic R skills.

## Requirements

Given the following `students` data frame:

```r
students <- data.frame(
  name = c("Alice", "Bob", "Charlie", "Diana", "Eli"),
  math = c(88, 74, 90, 66, 92),
  science = c(91, 83, 89, 70, 95),
  english = c(85, 79, 87, 72, 88)
)
```

Complete the following tasks:

1. Compute the **average math score** using the correct summary function.
2. Filter and return the students who scored **above 90 in science**.
3. Add a new column named `average_score` which contains the **mean of math, science, and English** for each student.
4. Write a function `get_status` that returns `"Pass"` if the average score is above 80, otherwise `"Fail"`. Use this to add a new column `status`.

## Function Signature

```r
get_status <- function(avg) {
  # Returns "Pass" if avg > 80, else "Fail"
}
```

## Submission Instructions

1. Write your code in a single R script file.
2. Use clear and consistent variable names.
3. Include comments or short docstrings for any custom functions.
4. Test your script by running it end-to-end and printing key outputs.
5. Ensure your code is properly formatted and readable.
