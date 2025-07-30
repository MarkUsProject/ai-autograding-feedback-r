# ai-autograding-feedback (R Version)

## Overview

This is the R-based implementation of the AI autograding feedback system. It generates structured LLM-powered feedback on student assignment submissions across **code**, **text**, and **image** scopes. The system uses markdown prompts and templates, and supports multiple LLM backends including OpenAI and Claude (via API keys).

This version exposes a direct `main()` function instead of using a CLI, making it easier to call programmatically or from within R scripts, notebooks, or services.

## Features

* Supports **image**, **text**, and **code** scopes
* Function-based interface (no CLI)
* Uses `.md` prompt templates and markdown output formats
* Modular file structure
* Built-in dependency installer
* LLM support via OpenAI API (Claude and remote extensible)

## Main Function Parameters

| Parameter            | Description                                                 | Required |
| -------------------- | ----------------------------------------------------------- | -------- |
| `prompt`             | Name of prompt file in `data/prompts/user/`                 | ❌ **    |
| `prompt_text`        | Inline string prompt to concatenate or use in place of file | ❌ **    |
| `prompt_custom`      | Path to a custom prompt file (e.g. `my_prompt.md`)          | ❌ **    |
| `scope`              | Processing scope (`code`, `text`, `image`)                  | ✅        |
| `submission`         | Submission file path                                        | ✅        |
| `solution`           | Solution file path                                          | ❌        |
| `model`              | Model name: `openai`, `claude`, `remote`                    | ✅        |
| `remote_model`       | Optional remote model string (used with remote models)      | ❌        |
| `output`             | Markdown output filepath                                    | ❌        |
| `submission_image`   | Path to image (image scope)                                 | ❌        |
| `solution_image`     | Path to reference image                                     | ❌        |
| `output_template`    | Output template name (default: `response_only`)             | ❌        |
| `system_prompt`      | Name of system prompt in `data/prompts/system/`             | ❌        |
| `question`           | Exact question/subquestion to test                          | ❌        |
| `marking_instructions` | Marking instructions/rubric file path                     | ❌        |

**Note**: You must provide **one** of `prompt`, `prompt_text`, or `prompt_custom`.

---

## Scope

The behavior of `main()` adapts based on the selected `scope`:

### Code
* Input: student + solution code files (e.g., `.R`, `.py`)
* Prompts prefixed with `code_`
* Use case: error analysis, hint generation, annotated feedback

### Text
* Input: student + solution PDFs or text files
* Prompts prefixed with `text_`
* Use case: compare student writing to rubric

### Image
* Input: submission image + optional reference image
* Prompts prefixed with `image_`
* Use case: plot evaluation, visual structure checking

---

## Example Usage

In R (script or console):

```r
source("main.R")

main(
  prompt = "code_table",
  scope = "code",
  model = "remote",
  submission = "test_submissions/code_example/fail_submission/fail_submission.R",
  solution = "test_submissions/code_example/solution.R",
  system_prompt = "student_test_feedback",
  output_template = "response_only",
  output = "output/q1.md"
)
```

---

## Prompts

Prompts may include placeholders such as:

* `{context}`
* `{file_contents}`
* `{file_references}`
* `{submission_image}`
* `{solution_image}`
* `{marking_instructions}`

If your scope and prompt don't match (e.g., `scope = "code"` with a `text_*.md`), the function will stop with an error.

---

## Output Templates

Templates are stored in `data/output/`. They support the following placeholders:

* `{model}` – Model name used
* `{request}` – Final constructed prompt
* `{response}` – Model response
* `{timestamp}` – Generation time
* `{submission}` – Path to submission

Default template: `response_only.md`

---

## File Structure

```
ai-feedback/
├── R/
│   └── code_processing.R
│   └── text_processing.R
│   └── image_processing.R
│   └── main.R 
│   └── template_utils.R
│   └── constants.R
│   └── ClaudeModel.R
│   └── OpenAIModel.R
│   └── RemoteModel.R
├── man/
├── tests/
│   ├── fixtures/
│   ├── testthat/
│   ├── testthat.R
```

---

## Setup Instructions

### 1. Install Dependencies

Imports:
- `base64enc`
- `callr`
- `dotenv`
- `ggplot2`
- `httr`
- `jsonlite`
- `magick`
- `optparse`
- `pdftools`
- `R6`
- `readr`
- `stringr`
- `tools`
- `withr`

Suggests:
- `testthat` (>= 3.0.0)
- `here`

### 2. Set API Key

Create a `.env` file in the project root:

```env
OPENAI_API_KEY=your_openai_key_here
CLAUDE_API_KEY=your_claude_key_here
REMOTE_API_KEY=your_remote_key_here
```

---

## License

This project is derived from the original Python version and follows the same academic fair use and research-oriented licensing assumptions.
