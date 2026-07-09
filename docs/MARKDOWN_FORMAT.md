# `workflow.scheduled-prompt.json` — Plain Language Guide

> **Who this is for:** Someone who has never opened n8n or read a workflow JSON file before. No technical background assumed.

---

## Start here: what is this file, in one sentence?

It is a **save file for an automated task** — like exporting a recipe from one kitchen so you can cook the same dish in another. You import it into n8n once, and n8n sets everything up from it.

---

## What does the workflow actually do?

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│   Every 6 hours, automatically:                             │
│                                                             │
│   1. Wake up                                                │
│   2. Take a saved question (the prompt)                     │
│   3. Send it to the AI                                      │
│   4. Receive the answer                                     │
│   5. Store the answer so you can read it in the browser     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

That is the entire job. Nothing more happens unless you add more steps later.

---

## Key concept: what is a "node"?

Every step in an n8n workflow is called a **node**. Think of nodes as stations on an assembly line — each one does exactly one job, then passes its result to the next station.

This workflow has four nodes:

```
  [1]                [2]              [3]             [4]
  Schedule     →   Set prompt   →   LiteLLM    →   Extract
  Trigger                            (AI call)       response
  "when"           "what to ask"     "ask it"        "read answer"
```

The arrows show the direction data flows. Node 1 triggers Node 2, which feeds Node 3, which feeds Node 4. Nothing runs in parallel; it is a straight chain.

---

## Node 1 — Schedule Trigger

### What it does
This is the alarm clock. It starts the whole chain automatically at regular intervals, without anyone pressing a button.

### The key setting
```
every 6 hours
```
You can change this to anything — once a day, every Monday at 9 am, every 30 minutes — by clicking this node in the n8n UI after importing.

### What it produces
A timestamp. It passes the current date and time to Node 2, which Node 2 ignores — it just needs the nudge to start.

### Analogy
A recurring alarm on your phone. It does not do the task itself; it just wakes up the rest of the chain.

---

## Node 2 — Set Prompt

### What it does
This node holds the question or instruction you want to send to the AI. It stores it in a variable called `prompt` so the next node can use it.

### The default value
```
Summarize the most important technology news from the last 24 hours
in 5 bullet points, each with a source link.
```

### How to change it
After importing, click this node in the n8n canvas. Find the value field and type whatever you want to ask. Examples:

- *"What are the top 3 risks in my industry this week?"*
- *"Draft a brief status update for a software project that is on track."*
- *"List five ideas for improving customer onboarding."*

### Why a separate node just for the prompt?
It keeps the question in one obvious place. You never have to dig into technical settings to change what you are asking — this node is the only thing you edit day to day.

### Analogy
Writing your question on a card before handing it to a researcher. The card travels through the rest of the process unchanged.

---

## Node 3 — LiteLLM (the AI call)

### What it does
This is the worker. It picks up the prompt from Node 2, packages it into a standard message format, sends it to the LiteLLM proxy running on your server, and waits for the AI's response.

### Where it sends the request
```
http://litellm:4000/v1/chat/completions
```
This address looks unusual because it is **internal to your server** — `litellm` is the name of the LiteLLM container on the same machine. The request never travels across the public internet to reach LiteLLM; it stays inside your EC2 instance. LiteLLM then forwards it outward to whichever AI model you have configured.

### The message it sends
```
You (role: user) say:  "<your prompt text>"
```
The `role: user` label tells the AI this message is coming from a human, as opposed to the AI itself. This follows the standard format all major AI APIs use.

### The response limit
```
max_tokens: 1024
```
This caps the AI's reply at roughly 750 words. Raise it if you need longer answers; lower it to reduce API cost.

### The model name
```
model: "default"
```
This does not mean a generic model — it means *whatever model you have configured in `litellm_config.yaml`*. The word `default` is just the internal label LiteLLM uses to look up your choice. You never need to change this value in the workflow. To switch from Claude to Mistral or Llama, you edit `litellm_config.yaml` and restart LiteLLM — this node stays exactly as is.

### Authentication
```
Authorization: Bearer <your LITELLM_MASTER_KEY>
```
This is the password that proves n8n is allowed to talk to LiteLLM. It is pulled automatically from the `LITELLM_MASTER_KEY` value you set in your `.env` file — you do not type it into the workflow manually.

### Analogy
A courier who picks up your letter (the prompt), addresses the envelope correctly, delivers it to a post office (LiteLLM), which sends it on to the right destination (the AI model), then brings the reply back.

---

## Node 4 — Extract Response

### What it does
The AI's raw reply is a large technical package containing the answer text plus a lot of metadata — token counts, timing, model name, finish reason, and more. This node opens that package and pulls out **just the text of the answer**, nothing else.

### The expression it uses
```
$json.choices[0].message.content
```

Reading this left to right:

| Part | Meaning |
|---|---|
| `$json` | The full raw response that came back from Node 3 |
| `.choices` | A list of possible answers (AI APIs can return more than one; we always get one here) |
| `[0]` | Take the first item in that list |
| `.message` | The message object inside that item |
| `.content` | The actual text string — the AI's answer |

### What `={{ ... }}` means
In n8n, wrapping something in `={{ }}` tells n8n to **evaluate it as code** rather than treat it as plain text. Without those brackets, n8n would store the literal string `$json.choices[0].message.content` instead of the value it points to.

### What it stores
A variable called `response` containing the clean answer text. This is what you read in the Executions tab.

### Analogy
Tearing open an envelope and pulling out the letter inside. The envelope, stamp, and postmark (the metadata) are discarded. You keep only the letter (the answer).

---

## The connections — how nodes are wired together

```json
"Schedule Trigger"  →  "Set prompt"
"Set prompt"        →  "LiteLLM"
"LiteLLM"           →  "Extract response"
```

This section is the wiring diagram. Each line means: *when this node finishes, pass its output to this next node.* In the n8n visual editor these appear as drawn arrows between boxes. You never edit this section by hand — drag a new connection in the UI and n8n updates the JSON automatically.

---

## The `active: false` field

The workflow is deliberately imported in a **paused state**. The schedule is not running yet. This gives you a chance to:

1. Read and understand what will happen
2. Change the prompt to what you actually want
3. Adjust the schedule interval
4. Confirm LiteLLM is running and healthy

When you are ready, flip the **Active** toggle in the top-right corner of the n8n workflow editor. From that moment, the schedule is live.

---

## The `position` values

```json
"position": [ 240, 300 ]
```

These are purely visual — the X and Y coordinates of each node box on the canvas. They have no effect on how the workflow runs. Move nodes around in the UI and these numbers update automatically.

---

## What you see after the first run

Click **Executions** in the n8n left sidebar. One row appears for this workflow. Click it to inspect each node:

```
Schedule Trigger   →   timestamp of when it fired
Set prompt         →   the exact prompt text that was sent
LiteLLM            →   the full raw JSON response (useful if something breaks)
Extract response   →   the clean answer text   ← this is what you read
```

The `response` value in the last node is the AI's answer to your question.

---

## The one thing to check before activating

Open the **LiteLLM** node after importing. Confirm the `Authorization` header references `$env.LITELLM_MASTER_KEY`. If n8n was started with that environment variable set (via your `.env` file), it will resolve automatically. If it is blank, the AI call will fail with a `401 Unauthorized` error.

---

## Everything in one table

| Node | What it is | One job |
|---|---|---|
| **Schedule Trigger** | Built-in timer | Wake the workflow every 6 hours |
| **Set prompt** | Variable setter | Hold the question to ask the AI |
| **LiteLLM** | HTTP Request | Send the question, receive the answer |
| **Extract response** | Variable setter | Pull the answer text out of the raw response |

---

## Visual summary of the full flow

```
  Every 6 hours
       │
       ▼
  ┌────────────┐
  │  Set your  │   ← edit this node to change what you ask
  │  question  │
  └─────┬──────┘
        │
        ▼
  ┌────────────┐
  │  Send to   │   ← calls LiteLLM on your server (internal, never public)
  │  AI model  │     LiteLLM forwards to OpenRouter / Anthropic / Ollama
  └─────┬──────┘
        │
        ▼
  ┌────────────┐
  │  Read the  │   ← this is what appears in the Executions tab
  │  answer    │
  └────────────┘
```

---

> **Bottom line:** four nodes, one chain, one timer. The only thing you need to
> change before activating is the prompt text in Node 2 and the interval in
> Node 1. Everything else is pre-wired and ready to run.