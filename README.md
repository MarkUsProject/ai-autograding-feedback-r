# ai-autograding-feedback (R Version)

## Overview

This is the R-based implementation of the AI autograding feedback system. It generates structured LLM-powered feedback on student assignment submissions across **code**, **text**, and **image** scopes. The system uses markdown prompts and templates, and supports multiple LLM backends including OpenAI and Claude (via API keys).

The R version is a streamlined and portable rewrite of the original Python implementation and supports OpenAI models using the `openai` R package.

## Features

* Supports **image**, **text**, and **code** scopes
* CLI-based interface using `optparse`
* Uses `.md` prompt templates and markdown output formats
* Modular file structure
* Built-in dependency installer
* LLM support via OpenAI API (Claude, Remote model extendable)

## Argument Details

| Argument             | Description                                                 | Required |
| -------------------- | ----------------------------------------------------------- | -------- |
| `--prompt`           | Name of prompt file in `data/prompts/user/`                 | ❌ \*\*   |
| `--prompt_text`      | Inline string prompt to concatenate or use in place of file | ❌ \*\*   |
| `--prompt_custom`    | Path to a custom prompt file (e.g. `my_prompt.md`)          | ❌ \*\*   |
| `--scope`            | Processing scope (`code`, `text`, `image`)                  | ✅        |
| `--submission`       | Submission file path                                        | ✅        |
| `--solution`         | Solution file path                                          | ❌        |
| `--model`            | Model name: `openai`, `claude`, `remote`                    | ✅        |
| `--remote_model`     | Optional remote model string (used with remote models)      | ❌        |
| `--output`           | Markdown output filepath                                    | ❌        |
| `--submission_image` | Path to image (image scope)                                 | ❌        |
| `--solution_image`   | Path to reference image                                     | ❌        |
| `--output_template`  | Output template name (default: `response_only`)             | ❌        |
| `--system_prompt`    | Name of system prompt in `data/prompts/system/`             | ❌        |

**Note**: You must provide **one** of `--prompt`, `--prompt_text`, or `--prompt_custom`.

## Scope

The script adapts based on the selected `--scope`:

### Code

* Input: student + solution files (e.g., `.py`, `.ipynb`)
* Prompts prefixed with `code_`
* Examples: error analysis, hint generation, annotated feedback

### Text

* Input: student + solution PDFs
* Prompts prefixed with `text_`
* Example: compare student's written answer to rubric

### Image

* Input: submission image + optional solution image
* Prompts prefixed with `image_`
* Example: analyze visual correctness of plots

## Prompts

Prompts are stored in `data/prompts/user/` as `.md` files. They may include placeholders such as:

* `{context}`
* `{file_contents}`
* `{submission_image}`
* `{solution_image}`

Prompt prefix rules:

* Code: starts with `code_`
* Text: starts with `text_`
* Image: starts with `image_`

If your scope and prompt don't match (e.g., `--scope code` with `text_*.md`), execution will halt.

You can also provide your own with `--prompt_custom` or use inline text via `--prompt_text`.

## Output Templates

Stored in `data/output/`. Templates support these placeholders:

* `{model}` – Model name used
* `{request}` – Final constructed prompt
* `{response}` – Model response
* `{timestamp}` – Generation time
* `{submission}` – Path to submission

Default template: `response_only.md`

## File Structure

```
ai-feedback/
├── main.R                  # CLI entry point
├── helpers/
│   └── install_dependencies.R
├── code_processing.R
├── text_processing.R
├── image_processing.R
├── data/
│   ├── prompts/
│   │   ├── user/           # User prompts (.md)
│   │   └── system/         # System prompts (.md)
│   └── output/             # Markdown output templates
```

## Setup Instructions

### 1. Install Dependencies

```bash
Rscript required_packages.R
```

### 2. Set API Key

Create a `.env` file in the project root:

```env
OPENAI_API_KEY=your_openai_key_here
ClAUDE_API_KEY=your_claude_key_here
REMOTE_API_KEY=your_remote_key_here
```

## Example Commands

### Evaluate Text with Inline Prompt

```bash
Rscript ai-feedback/main.R --scope code --model remote --submission "test_submissions/sta130_code_example/fail_submission/fail_submission.R" --solution test_submissions/sta130_code_example/solution.R --prompt code_table --system_prompt student_test_feedback --output_template response_only
```

## Requirements

Ensure the following packages are installed via `install_if_missing()`:

  * `optparse`,
  * `jsonlite`,
  * `magick`,
  * `base64enc`,
  * `jsonlite`,
  * `stringr`,
  * `tools`,
  * `httr`,
  * `dotenv`,
  * `R6`,

Also ensure `.env` is present with your API key.

## License

This project is derived from the original Python version and follows the same academic fair use and research-oriented licensing assumptions.

---
