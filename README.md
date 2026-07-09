# n8n Agent Scheduler (with LiteLLM middleware)

Run AI prompts on a schedule with an open-source web UI, using **LiteLLM** as
a model-agnostic proxy between n8n and any backend (OpenRouter, Anthropic,
local Ollama, etc.). Swap models by editing one line — n8n workflows never change.

## Architecture

```
        AWS EC2 instance (always-on Linux)
   +---------------------------------------------------+
   |                                                   |
   |   n8n                       LiteLLM proxy         |
   |   (scheduler + UI)  ──────► (port 4000)           |
   |   port 5678                 OpenAI-compatible API |
   |                             litellm_config.yaml   |
   |                                   |               |
   +-----------------------------------|---------------+
                                       | HTTPS
                          ┌────────────┼────────────┐
                          ▼            ▼             ▼
                    OpenRouter    Anthropic      Ollama
                    (default)     (direct)      (local)
```

```
   Browser / phone --> http://<ec2>:5678  (n8n Executions: every run's output)
```

## Vertical pipeline

```
   +----------------------------------------+
   |  Schedule Trigger (n8n)                |
   +--------------------+-------------------+
                        |
                        v
   +----------------------------------------+
   |  Set prompt node (n8n)                 |
   +--------------------+-------------------+
                        |
                        v
   +----------------------------------------+
   |  HTTP Request -> LiteLLM :4000         |
   |  (OpenAI-compatible, model: default)   |
   +--------------------+-------------------+
                        |
                        v  [routed by litellm_config.yaml]
   +----------------------------------------+
   |  OpenRouter / Anthropic / Ollama       |
   +--------------------+-------------------+
                        |
                        v
   +----------------------------------------+
   |  Extract response node (n8n)           |
   +--------------------+-------------------+
                        |
                        v
   +----------------------------------------+
   |  Executions tab (web UI / phone)       |
   +----------------------------------------+
```

## Products used

| Product | Role |
|---|---|
| AWS EC2 | Always-on Linux host |
| Docker + Docker Compose | Runs all services |
| n8n (open source) | Scheduler + web UI + pipeline builder |
| LiteLLM (open source) | Model-agnostic proxy (OpenAI-compatible API) |
| OpenRouter | Default model gateway (one key, many models) |
| Anthropic / Ollama | Alternative backends (swap in litellm_config.yaml) |

## Requirements
- AWS EC2 instance (Linux) with Docker + Docker Compose
- Port 5678 reachable only from you (security group + SSH tunnel)
- At least one backend key: `OPENROUTER_API_KEY` **or** `ANTHROPIC_API_KEY`
  **or** Ollama running locally (no key needed)

## Setup

```bash
# 1. copy files onto EC2, then:
cd n8n-scheduler
cp .env.example .env

# 2. fill in .env:
#    - set N8N_PASSWORD to something strong
#    - generate LITELLM_MASTER_KEY:  openssl rand -hex 32
#    - set OPENROUTER_API_KEY (or ANTHROPIC_API_KEY, or enable Ollama)

# 3. choose your model backend in litellm_config.yaml
#    default is OpenRouter / claude-opus-4-8
#    uncomment Option B for Anthropic direct
#    uncomment Option C + ollama service for local Ollama

# 4. start everything
docker compose up -d

# 5. verify LiteLLM is up
curl http://localhost:4000/health

# 6. reach n8n (SSH tunnel recommended)
ssh -L 5678:localhost:5678 ec2-user@<EC2_PUBLIC_IP>
# open http://localhost:5678
```

## Import and activate the starter workflow
1. n8n UI → **Workflows → Import from File** → `workflow.scheduled-prompt.json`
2. Edit the **Set prompt** node — change the prompt text
3. Edit the **Schedule Trigger** — set your cadence
4. Flip the **Active** toggle (top right)
5. Watch outputs appear in **Executions** (left sidebar)

## Swapping models (the whole point)
Edit `litellm_config.yaml` — change the `model:` line under `Option A`, or
uncomment a different option. Then:
```bash
docker compose restart litellm
```
n8n workflows need **zero changes**. The model name in the workflow is always
`"default"`.

## Ollama (fully local, no external API)
1. Uncomment the `ollama` service in `docker-compose.yml`
2. Uncomment Option C in `litellm_config.yaml`
3. `docker compose up -d`
4. Pull a model: `docker exec ollama ollama pull llama3`
5. `docker compose restart litellm`
EC2 sizing: at minimum a `t3.xlarge` (16 GB RAM) for a 7B model;
`g4dn.xlarge` (GPU) for good performance.

## Adding more prompts
Duplicate the workflow in n8n — one workflow per prompt keeps the
Executions view clean per logical task.

## Scaling to an agentic pipeline
Replace the single LiteLLM HTTP node with an **AI Agent** node in n8n,
add **Tool** nodes (search, HTTP, Todoist, Telegram), and branch with
**IF/Switch** nodes. LiteLLM stays the same; only the n8n workflow grows.

## Security checklist
- [ ] `N8N_PASSWORD` changed from default
- [ ] `LITELLM_MASTER_KEY` is a random string (not the default)
- [ ] `.env` in `.gitignore`, never committed
- [ ] Port 5678 locked to your IP in EC2 security group
- [ ] Port 4000 (LiteLLM) NOT exposed publicly — internal Docker network only
- [ ] Accessing n8n via SSH tunnel or HTTPS reverse proxy

## Caveats
- Not executed by the author. Test with `curl http://localhost:4000/health`
  and one manual workflow run before activating the schedule.
- LiteLLM image tags update frequently; pin to a specific version tag in
  `docker-compose.yml` for production stability.
- n8n node internals evolve across versions; the HTTP Request approach is
  the version-stable path vs. the native AI Agent node.