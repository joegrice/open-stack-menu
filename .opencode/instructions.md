## CodeGraph

This project uses CodeGraph for semantic code intelligence.

### Session Start

At the start of every session, check if `.codegraph/` exists and the index is fresh:

1. Run `codegraph status` to check index health
2. If not initialized or stale, run `codegraph init -i` to build the knowledge graph
3. If the index exists but may be outdated, `codegraph sync` can be run on explicit user request to incrementally update — do NOT run it automatically during session startup

### Usage

- Use `codegraph_search` to find symbols by name
- Use `codegraph_context` to build relevant code context for a task
- Use `codegraph_callers` / `codegraph_callees` to trace call flows
- Use `codegraph_impact` to check what's affected before editing
- Use `codegraph_node` to get details about a specific symbol
- Use `codegraph_status` to check index health and statistics
- Use `codegraph_files` to get indexed file structure

## Auto-Orchestration Pipeline

This project uses a 4-phase automated pipeline. The `orchestrator` agent (default) automatically chains through all phases when given a task. See `.opencode/agent/orchestrator.md` for the full pipeline specification.

| Phase | Agent | Model | Role |
|---|---|---|---|
| 1 | `planner` | qwen3.7-max | Architecture & planning |
| 1.5 | `grill-me` skill | — | Interactive plan validation with user |
| 2 | `builder` | deepseek-v4-flash | Code generation (applies React best practices + composition patterns, Go conventions) |
| 3 | `reviewer` | qwen3.7-max | Security & architecture audit (audits against all skill rules) |
| 4 | `fixer` | deepseek-v4-pro | Apply fixes with CodeGraph |

### Skills

Skills are in `.agents/skills/`:
- `grill-me` — Interactive plan stress-testing and design validation
- `vercel-react-best-practices` — 70 React/Next.js performance rules across 8 categories (auto-applied in Phases 2-3 for React/Next.js tasks)
- `vercel-composition-patterns` — 8 React composition rules across 4 categories: compound components, state lifting, variant patterns, React 19 APIs (auto-applied in Phases 2-3 for React/Next.js tasks)

### Agent Files

All agent definitions are in `.opencode/agent/`:
- `orchestrator.md` — Primary agent with pipeline instructions
- `planner.md` — Phase 1: Read-only planning
- `builder.md` — Phase 2: Code implementation
- `reviewer.md` — Phase 3: Read-only code audit
- `fixer.md` — Phase 4: Fix application with CodeGraph verification
