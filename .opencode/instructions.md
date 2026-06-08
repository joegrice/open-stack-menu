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
| 1 | `planner` | qwen3.7-plus | Architecture & planning |
| 1.5 | `grill-me` skill | — | Interactive plan validation with user |
| 2 | `builder` | deepseek-v4-flash | Code generation (applies SwiftUI best practices, Swift concurrency) |
| 3 | `reviewer` | qwen3.7-plus | Security & architecture audit (audits against skill rules) |
| 4 | `fixer` | deepseek-v4-pro | Apply fixes with CodeGraph |

### Skills

Skills are in `.agents/skills/`:
- `grill-me` — Interactive plan stress-testing and design validation
- `swiftui-expert-skill` — SwiftUI best practices for iOS/macOS (state management, view composition, performance, macOS-specific patterns). Auto-applied in Phases 2-3 for SwiftUI tasks.

### Agent Files

All agent definitions are in `.opencode/agent/`:
- `orchestrator.md` — Primary agent with pipeline instructions
- `planner.md` — Phase 1: Read-only planning
- `builder.md` — Phase 2: Code implementation
- `reviewer.md` — Phase 3: Read-only code audit
- `fixer.md` — Phase 4: Fix application with CodeGraph verification
