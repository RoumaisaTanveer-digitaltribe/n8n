# AI Workflow Automation with n8n — Task Extraction

**Task:** Build a workflow where a webhook receives messy text, an AI model extracts
structured tasks (task, owner, deadline, priority), the result is stored, and a
structured JSON response is returned to the caller.

## Flow

```
Webhook (POST /extract-tasks)
   -> Normalize Input (Set)
   -> Validate Input (Code)
   -> AI Extract Tasks (HTTP Request -> OpenAI chat/completions, JSON mode)
   -> Parse & Validate JSON (Code)
   -> Read Existing tasks.json (Read/Write File)
   -> Extract Existing Data (Extract From File)
   -> Merge With Existing (Code)
   -> Convert To File (Convert To File)
   -> Save to tasks.json (Read/Write File)
   -> Respond to Webhook (JSON)
```

## Files

```
ai-task-extraction-n8n/
├── README.md
├── workflow/
│   └── AI_Task_Extraction_Workflow.json   # importable n8n workflow export
├── data/
│   └── tasks.json                          # local JSON store, starts empty
└── test/
    ├── sample_input.txt                    # messy meeting-style sample text
    └── sample_request.sh                   # curl test script
```
<img width="943" height="619" alt="Screenshot 2026-07-06 132925" src="https://github.com/user-attachments/assets/e34c102b-8a0b-4afd-9e7f-5a136fd61878" />


## Setup

1. **Import the workflow**
   In n8n: `Workflows -> Import from File` -> select
   `workflow/AI_Task_Extraction_Workflow.json`.

2. **Add credentials**
   The `AI Extract Tasks (OpenRouter)` node calls OpenRouter and expects a
   **Header Auth** credential:
   - In n8n: **Credentials -> New -> Header Auth**
   - Name: `Authorization`
   - Value: `Bearer sk-or-v1-YOUR_OPENROUTER_KEY`
   - Save it, then select it on the node's Credential field.

   The model used is `mistralai/mistral-7b-instruct`. Swap it in the node's
   JSON body if you want a different OpenRouter model (use OpenRouter's
   `provider/model-name` format, e.g. `openai/gpt-4o-mini`,
   `anthropic/claude-3.5-haiku`).

3. **Set the storage path**
   `Read Existing tasks.json` and `Save to tasks.json` read/write
   `/data/tasks.json` by default (override with the `TASKS_FILE_PATH`
   environment variable on the n8n instance). Point this at the `data/`
   folder in this repo, or swap in a database/Google Sheets node instead
   (see "Swapping storage" below).

4. **Activate the workflow** and copy the webhook URL from the Webhook node.

## Testing

```bash
chmod +x test/sample_request.sh
WEBHOOK_URL="http://localhost:5678/webhook/extract-tasks" bash test/sample_request.sh
```

Or with plain curl:

```bash
curl -X POST http://localhost:5678/webhook/extract-tasks \
  -H "Content-Type: application/json" \
  -d '{"text": "sara needs to send the client update today, high priority. ahmed will fix the login bug by friday."}'
```

### Expected response shape

```json
{
  "tasks": [
    { "task": "Send client update", "owner": "Sara", "deadline": "Today", "priority": "High" },
    { "task": "Fix the login bug", "owner": "Ahmed", "deadline": "Friday", "priority": "Medium" }
  ]
}
```

Each run also appends the extracted tasks to `data/tasks.json`, so the file
accumulates a running log across requests.

## Swapping storage (Google Sheets / a real database)

The `Read Existing tasks.json` -> `Extract Existing Data` -> `Merge With
Existing` -> `Convert To File` -> `Save to tasks.json` chain is a drop-in
local-file replacement for a database. To use Google Sheets instead:

1. Delete the file read/write and convert nodes.
2. Add a **Google Sheets** node (`Append`) after `Parse & Validate JSON`,
   mapped to columns `task`, `owner`, `deadline`, `priority`.
3. Wire its output straight into `Respond to Webhook`.

For Postgres/MySQL, swap in the corresponding database node with an `INSERT`
per task instead.

## Error handling notes

- `Validate Input` throws (and n8n returns a 500) if the webhook is called
  with no `text` field.
- `Parse & Validate JSON` guards against the AI returning malformed JSON and
  fills in sensible defaults (`Unassigned` owner, `Not specified` deadline,
  `Medium` priority) if a field is missing.
- `Read Existing tasks.json` has `Continue On Fail` enabled so the very first
  run (before `tasks.json` exists) doesn't break the workflow.
