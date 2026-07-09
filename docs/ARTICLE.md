## Self-Hosted AI Prompt Scheduling with n8n, LiteLLM, and AWS EC2

The dependency on a single model provider's API key is a real constraint: rotate
the key, the service breaks; the provider changes pricing, you're stuck; you want
to try a different model, you rewrite your integration. The fix is a
**model-agnostic proxy** sitting between your scheduler and any backend. Here's
how to build the whole thing — scheduler, web UI, model proxy — on a single AWS
EC2 instance using open-source tools.

### The three-layer stack

**n8n** is the scheduler and web UI. Every prompt runs as a workflow with a
Schedule Trigger; every run's output is stored and viewable in the Executions
tab — in a browser or on your phone. It also handles the future: when "run a
prompt" grows into "run a multi-step agentic pipeline with tools and branching,"
the platform doesn't change, you just add nodes.

**LiteLLM** is the model proxy. It exposes a single OpenAI-compatible endpoint
(`/v1/chat/completions`) and routes requests to whichever backend you configure:
OpenRouter, Anthropic, a local Ollama instance, or anything else. n8n always
calls the same URL with the same format; the model is swapped by editing one
line in a config file and restarting one container.

**OpenRouter** (default backend) is a single API key that gives access to
dozens of models — Claude, GPT-4, Mistral, Llama, and more. Switch models
without touching n8n.

### Why this is better than a direct API key

With a direct `ANTHROPIC_API_KEY` in n8n, every workflow hardcodes an assumption
about the provider. With LiteLLM in the middle:

- Swap from Claude to Mistral: one line in `litellm_config.yaml`
- Run a local model via Ollama (zero external API cost): one line + one container
- Rotate API keys: change `.env`, restart LiteLLM — n8n untouched
- Add rate limiting, logging, or cost tracking: configure LiteLLM, not every workflow

### The shape of it

```
EC2 [ n8n :5678 ] --> [ LiteLLM :4000 ] --> OpenRouter / Anthropic / Ollama
         |
         v
   Executions tab (browser / phone)
```

### Going local with Ollama

Uncomment the Ollama service in `docker-compose.yml` and the Ollama option in
`litellm_config.yaml`, pull a model (`ollama pull llama3`), and restart LiteLLM.
Now every prompt runs on-instance with no external API call. The catch: you need
a beefy EC2 instance (16+ GB RAM for a 7B model; a GPU instance for real
performance). For most scheduled prompt workloads, OpenRouter is the better
cost/performance trade-off; Ollama makes sense for high-volume or privacy-sensitive runs.

### Scaling to an agentic pipeline

The scheduler, proxy, and UI are already in place. When you're ready to go
beyond one-shot prompts, replace the single LiteLLM HTTP node in the workflow
with n8n's AI Agent node, add Tool nodes (web search, HTTP calls, Todoist,
Telegram), and use IF/Switch nodes for branching logic. Every run of that
pipeline also appears in the Executions tab. Same infrastructure, more nodes.

### Takeaway

Three open-source tools, one EC2 instance, one `docker compose up -d`. You get
a scheduled AI prompt runner with a web UI today, and a flexible agentic pipeline
platform tomorrow — without being locked to a single model provider.
