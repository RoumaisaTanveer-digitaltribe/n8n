#!/usr/bin/env bash
# Test script for the AI Task Extraction n8n webhook.
#
# Usage:
#   1. Import workflow/AI_Task_Extraction_Workflow.json into n8n and activate it.
#   2. Set WEBHOOK_URL below to your instance's webhook URL
#      (e.g. http://localhost:5678/webhook/extract-tasks for production,
#      or http://localhost:5678/webhook-test/extract-tasks while testing).
#   3. Run: bash test/sample_request.sh

WEBHOOK_URL="${WEBHOOK_URL:-http://localhost:5678/webhook/extract-tasks}"

TEXT=$(cat "$(dirname "$0")/sample_input.txt")

curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg text "$TEXT" '{text: $text}')" \
  | jq .
