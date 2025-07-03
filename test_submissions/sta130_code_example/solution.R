# 1_dataset.R
# Load dataset

students <- data.frame(
  name = c("Alice", "Bob", "Charlie", "Diana", "Eli"),
  math = c(88, 74, 90, 66, 92),
  science = c(91, 83, 89, 70, 95),
  english = c(85, 79, 87, 72, 88)
)

print("Dataset Loaded:")

# 3_solutions.R
# Worksheet Solutions

# Q1
avg_math <- mean(students$math)
cat("Q1: Average Math Score =", avg_math, "\n")

# Q2
high_science <- students[students$science > 90, ]
cat("Q2: Students with Science > 90\n")
print(high_science)

# Q3
students$average_score <- rowMeans(students[, c("math", "science", "english")])
cat("Q3: Students with average_score column:\n")
print(students)

# Q4
get_status <- function(avg) {
  if (avg > 80) return("Pass") else return("Fail")
}
students$status <- sapply(students$average_score, get_status)
cat("Q4: Students with status column:\n")
