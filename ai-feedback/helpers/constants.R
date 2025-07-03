source("ai-feedback/models/OpenAIModel.R")
source("ai-feedback/models/ClaudeModel.R")
source("ai-feedback/models/RemoteModel.R")

model_mapping <- list(
  "openai" = OpenAIModel,
  "claude" = ClaudeModel,
  "remote" = RemoteModel
)
