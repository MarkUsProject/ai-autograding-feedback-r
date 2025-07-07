# 4_student_submission.R
students <- data.frame(
  name = c("Alice", "Bob", "Charlie", "Diana", "Eli"),
  math = c(88, 74, 90, 66, 92),
  science = c(91, 83, 89, 70, 95),
  english = c(85, 79, 87, 72, 88)
)
# Q1 - Average Math Score
total_math <- sum(students$math)

# Q2 - Science scores
top_sci_students <- students[students$science < 90, ]

# Q3 - Add average column
average_all <- mean(students)

# Q4 - Pass/Fail function
pass_fail_check <- function(x) {
  if (x > 80) "Pass" else "Fail"
}

students$status_check <- sapply(students$average_score, pass_fail_check)
