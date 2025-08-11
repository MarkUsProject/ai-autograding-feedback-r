# Student Submission - Introduction to R Programming
# Name: Student Example
# Assignment: Basic R Operations

# Q1: Calculate the average of a vector
numbers <- c(10, 20, 30, 40, 50)
total <- sum(numbers)
# Missing: average calculation

# Q2: Create a function to check if a number is even
check_even <- function(x) {
  if (x %% 2 == 1) {  # Logic error: should be == 0 for even numbers
    return("even")
  } else {
    return("odd")
  }
}

# Q3: Work with data frame
students <- data.frame(
  name = c("Alice", "Bob", "Charlie"),
  score = c(85, 92, 78)
)

# Find students with score > 80
high_scores <- students[students$score < 80, ]  # Logic error: should be >

# Q4: Plot the data
plot(students$score)
title("Student Scores")  # Missing proper labels and formatting
 
x <- 1:10

# Q1: Sum of positive integers
sum_positive <- function(a, b) {
  if (a < 0 || b < 0) stop("Inputs must be non-negative")
  return(a + b)
}

# Q2: Create a function to check if a number is even
check_even <- function(x) {
  if (x %% 2 == 1) {
    return("even")
  } else {
    return("odd")
  }
}

# Intentional inefficient loop
squared <- c()
for (i in seq_along(x)) {
  squared[i] <- x[i] * x[i]
}
 
