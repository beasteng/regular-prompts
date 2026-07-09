# Environment Context: n8n + LiteLLM Agent Scheduler on AWS EC2

You are developing inside an existing, running environment. Do not re-scaffold it.

## What already exists
- AWS EC2 Linux instance running three Docker services via Docker Compose:
  - **n8n** (port 5678) — open-source scheduler + web UI + pipeline builder
  - **LiteLLM** (port 4000, internal only) — OpenAI-compatible model proxy
  - **Ollama** (port 11434, optional, commented out by default) — local models
- Project dir: `n8n-scheduler/` containing:
  - `docker-compose.yml`
  - `.env` — N8N_HOST, TZ, N8N_USER, N8N_PASSWORD, LITELLM_MASTER_KEY,
             OPENROUTER_API_KEY, ANTHROPIC_API_KEY
  - `litellm_config.yaml` — model routing config
  - `workflow.scheduled-prompt.json` — importable starter workflow

## Architecture
- EC2 [ n8n :5678 ] --> [ LiteLLM :4000 ] --> OpenRouter / Anthropic / Ollama
- Browser/phone --> http://:5678 (Executions tab = every run's output)

## Conventions / constraints
- n8n calls LiteLLM at `http://litellm:4000/v1/chat/completions`
- Auth: `Authorization: Bearer $LITELLM_MASTER_KEY`
- Model name in all workflows: `"default"` (routed by litellm_config.yaml)
- Response format: OpenAI-compatible — `choices[0].message.content`
- Secrets in .env / n8n Credentials, never hardcoded in workflows
- One workflow per logical prompt/pipeline for clean Executions view
- Port 5678 not publicly exposed — SSH tunnel or reverse proxy only
- Port 4000 internal Docker network only — never expose externally
- Swap models: edit litellm_config.yaml + `docker compose restart litellm`
- No workflow changes needed when swapping models

## What you may be asked to build
- New n8n workflows as importable JSON
- Additional LiteLLM model options in litellm_config.yaml
- Agentic pipelines: AI Agent node + Tool nodes + IF/Switch + downstream
  actions (Todoist, Telegram, HTTP webhooks)
- Ollama local model setup on the EC2 instance

## Deliverable format
- New/changed workflows as importable JSON
- Config changes as edits to litellm_config.yaml or docker-compose.yml
- State explicitly if something was not tested