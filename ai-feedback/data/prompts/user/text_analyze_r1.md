## Primary tasks
1. Derive a list of grading criteria by extracting every distinct claim, requirement, or step that appears in the Instructor Solution.

2. Judge whether the Student Response satisfies each criterion.

**Present your evaluation as a single Markdown table—nothing else.

##Required output format
Criterion	Meets? (✅ / Partially / ❌)	Explanation

- List criteria in the same order they appear in the Instructor Solution.
- In the Explanation cell, state why the student falls short and quote one or two short phrases from the Student Response for evidence.
- Wrap quotes in “...”, limit them to 50 words, and use an ellipsis (…) to truncate if necessary.
- If—and only if—the Student Response meets every criterion, output the compressed table below instead of the detailed one:

| ✅ Excellent – the response meets every inferred criterion | | |

**No other text, JSON, or emojis may appear before or after the table.

## Reasoning workflow (internal)
1. Parse the Instructor Solution and list its discrete requirements.

2. Compare the Student Response against each requirement in sequence.

3. Decide on ✅, Partially, or ❌ for each.

4. Draft concise explanations with supporting quotes.

5. Render the final table exactly as specified.

File References:
{file_references}

{file_contents}
