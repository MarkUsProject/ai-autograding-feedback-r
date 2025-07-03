
# Incorrect Submission Scoring Analysis

## Student Submission Summary

The following R implementation contains several fundamental mistakes in data manipulation and function design:

```r
# Q1 - Average Math Score
total_math <- sum(students$math)

# Q2 - Science scores (incorrect comparison)
top_sci_students <- students[students$science < 90, ]

# Q3 - Add average column incorrectly
average_all <- mean(students)

# Q4 - Pass/Fail function (unclear logic)
pass_fail_check <- function(x) {
  if (x > 80) "Pass" else "Fail"
}

students$status_check <- sapply(students$average_score, pass_fail_check)
```

## Issues Identified

1. **Incorrect Aggregation**: Used `sum()` instead of `mean()` in Q1, which gives the total rather than the average math score.
2. **Wrong Filter Condition**: Q2 uses `<` instead of `>`, which selects students below 90 in science rather than above.
3. **Misuse of `mean()`**: In Q3, `mean()` was incorrectly applied to the entire data frame instead of computing row-wise averages.
4. **Non-idiomatic Function Return**: Q4 lacks an explicit `return()` and uses unclear naming, which makes the logic harder to read and debug.

## Expected AI Response

The AI should identify and comment on:

- **Incorrect use of `sum()`**: Suggest replacing with `mean()` for averaging.
- **Improper filtering logic**: Recommend fixing comparison operator.
- **Invalid row-wise operation**: Guide the use of `rowMeans()` for adding a column.
- **Function definition style**: Encourage explicit `return()` and better naming for readability.
