# Live News Aggregator & Verification Prompt Template

## Overview
This prompt template is designed for LLMs with live web-search capabilities. It ensures the model extracts recent, topic-specific news while preventing **URL hallucinations** (404/broken links) and **false positives** (outdated news).

---

## Template

```text
Perform a live web search for the latest news regarding [LOCATION / INDUSTRY / CONTEXT] published strictly within [TIMEFRAME] on the following topics:
1. [TOPIC 1]
2. [TOPIC 2]
3. [TOPIC 3]
4. [TOPIC 4]

### Strict Content & Timeframe Rules
- Timeframe: ONLY include news published within [TIMEFRAME]. Exclude anything older.
- Accuracy over Quantity: Do not invent, extrapolate, or duplicate items to reach a target number. If fewer genuine news updates exist within the specified timeframe, output only the verified items found (up to [MAX BULLET COUNT]).

### Strict URL & Link Rules (CRITICAL)
- Link Accuracy: Every item MUST include a direct HTML hyperlink (<a href="URL" target="_blank">[LINK ANCHOR TEXT]</a>).
- No URL Hallucination: Do NOT guess, alter, shorten, or reconstruct any URLs. Use ONLY exact, complete web addresses retrieved directly from search results.
- Source Requirement: If a verified direct link to the specific article is not found in the search results, exclude that news item entirely.

### Output Requirements
- Language: [TARGET LANGUAGE]
- Output Format: [OUTPUT FORMAT]
- Item Structure: 
  [ITEM FORMAT PATTERN]
```

---

## Placeholder Reference Guide

| Placeholder | Type | Description | Example Values |
| :--- | :--- | :--- | :--- |
| `[LOCATION / INDUSTRY / CONTEXT]` | String | The geographic region, sector, or market context. | `Portugal`, `Global Renewable Energy`, `UK Tech Sector` |
| `[TIMEFRAME]` | String | The exact window of publication relative to execution time. | `the LAST 24 HOURS`, `the PAST 7 DAYS`, `TODAY` |
| `[TOPIC 1..N]` | List | High-priority entities, laws, companies, or subjects. | `AIMA`, `SEF`, `Digital Nomad Visas` |
| `[MAX BULLET COUNT]` | Integer | Cap on total items returned. | `10`, `15`, `20` |
| `[LINK ANCHOR TEXT]` | String | Guidance on what text sits inside the `<a>` tag. | `Source Name`, `Article Title`, `Read Full Story` |
| `[TARGET LANGUAGE]` | String | Desired output language for summaries. | `English`, `Portuguese`, `Spanish` |
| `[OUTPUT FORMAT]` | String | Code structure or structure type required. | `HTML snippet (<ul>/<li>)`, `Markdown List`, `JSON Array` |
| `[ITEM FORMAT PATTERN]` | String | Concrete example pattern for each entry. | `<li>[Summary] — <a href="URL">[Source]</a></li>` |

---

## Critical Execution Requirements

To guarantee success with this prompt, adhere to these operational constraints:

1. **Web Grounding Enabled**: The target platform, API call, or model configuration **must have web search grounding enabled**. Without active search, the model will fail or hallucinate.
2. **Flexible Quantity Constraints**: Do not enforce hard minimums (e.g., "Must be exactly 20 items"). Forcing a minimum count when real news volume is low causes models to pull older articles or manufacture links.

---

## Usage Example

### Configured Input
```text
Perform a live web search for the latest news regarding Portugal immigration published strictly within the LAST 24 HOURS on the following topics:
1. AIMA
2. SEF updates
3. Temporary protection for Ukrainians

### Strict Content & Timeframe Rules
- Timeframe: ONLY include news published within the LAST 24 HOURS. Exclude anything older.
- Accuracy over Quantity: Do not invent, extrapolate, or duplicate items to reach a target number. If fewer genuine news updates exist within the specified timeframe, output only the verified items found (up to 10).

### Strict URL & Link Rules (CRITICAL)
- Link Accuracy: Every item MUST include a direct HTML hyperlink (<a href="URL" target="_blank">Source Name</a>).
- No URL Hallucination: Do NOT guess, alter, shorten, or reconstruct any URLs. Use ONLY exact, complete web addresses retrieved directly from search results.
- Source Requirement: If a verified direct link to the specific article is not found in the search results, exclude that news item entirely.

### Output Requirements
- Language: English
- Output Format: Clean HTML snippet using <ul> and <li>
- Item Structure: 
  <li>[Summary] — <a href="EXACT_URL" target="_blank">[Source Name]</a></li>
```

### Expected Output Structure
```html
<ul>
  <li>AIMA opens a new service desk in Lisbon to clear backlogs — <a href="https://example.com/aima-news" target="_blank">Público</a></li>
  <li>Extension of protection status for Ukrainian refugees published in official journal — <a href="https://example.com/ukraine-status" target="_blank">Diário de Notícias</a></li>
</ul>
```
