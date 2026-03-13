# AGENTS Guide

This repository builds `agentch`: a macOS notch-style assistant surface for Claude sessions.

Scope rules:
- Claude-only integration.
- Do not add references to other agent CLIs.
- Keep docs and UX naming as `agentch`.

## Canonical Skills

All skill docs live in `.agents/`:
- `.agents/README.md`
- `.agents/01-product-and-constraints.md`
- `.agents/02-runtime-architecture.md`
- `.agents/03-hooks-and-session-routing.md`
- `.agents/04-notch-shape-and-animation.md`
- `.agents/05-design-system-buttons-colors.md`
- `.agents/06-ops-build-debug.md`

Use these as source of truth before changing behavior.

## Non-Negotiable Product Constraints

- Island shell fill stays pure black.
- Window background stays clear.
- Button system has exactly 2 variants: `primary` and `secondary`.
- Accent palette is Claude brand palette (`#C15F3C`, `#B1ADA1`, plus neutral support).
- Header status dot always uses the session primary color.
- Conversation sender colors: `Claude` = primary, `You` = secondary.
- For blocking prompts, sessions must be isolated and queue safely.

## Fast Local Workflow

Build + install:
```bash
bash scripts/build.sh
```

Restart daemon:
```bash
~/.agent-island/scripts/island.sh stop
sleep 0.5
~/.agent-island/scripts/island.sh start
```

Manual prompt test:
```bash
~/.agent-island/scripts/island.sh prompt "Test" "Claude" 0 "" "" "" "**Claude:** Hello" "" "test-session"
```

## Session-Safe Behavior

- Always propagate `session_id` through socket command payloads.
- `dismiss` must be session-scoped.
- Queued commands for a specific session should be replaceable by newer commands from the same session.

## Validation Checklist Before Commit

- `swift build` passes.
- Shell hooks pass `bash -n`.
- No forbidden agent-name references in repo.
- Interactive prompt still submits and dismisses correctly.
- Multi-session queue behavior still isolates active vs queued sessions.
