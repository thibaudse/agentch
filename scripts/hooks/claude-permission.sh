#!/bin/bash
# Claude Code PermissionRequest hook.
# - For AskUserQuestion: shows the question and options in the notch, returns the user's selection
# - For other tools: shows approve/deny buttons in the notch
# Blocks until the user decides, then returns the decision to Claude Code.

LOG="/tmp/agent-island-hook.log"
ISLAND="${AGENT_ISLAND_HOME:-$HOME/.agent-island}/scripts/island.sh"
INPUT=$(cat)
CWD=$(printf '%s' "$INPUT" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('cwd',''))" 2>/dev/null || true)

resolve_branch_label() {
    local cwd="$1"
    [ -n "$cwd" ] || return 0

    local label
    label="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    if [ -z "$label" ] || [ "$label" = "HEAD" ]; then
        label="$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null || true)"
    fi

    if [ -n "$label" ]; then
        printf '%s' "$label"
    fi
}

BRANCH_LABEL="$(resolve_branch_label "$CWD")"

echo "$(date '+%H:%M:%S') PERMISSION INPUT(${#INPUT}b): $(echo "$INPUT" | head -c 1000)" >> "$LOG"

# Extract tool name, command, suggestions, and elicitation data
EXTRACTED=$(printf '%s' "$INPUT" | python3 -c "
import json, sys, difflib, re

d = json.loads(sys.stdin.read())
tool = d.get('tool_name', 'Unknown')
session_id = d.get('session_id', '')

inp = d.get('tool_input', {})

# Check if this is an AskUserQuestion (elicitation)
is_elicitation = (tool == 'AskUserQuestion')

if is_elicitation:
    questions = inp.get('questions', [])
    if questions:
        q = questions[0]
        elicitation = {
            'question': q.get('question', ''),
            'options': q.get('options', [])
        }
    else:
        elicitation = {'question': '', 'options': []}
    command = ''
else:
    elicitation = None

    def truncate(value, limit=1200):
        if isinstance(value, str):
            text = value
        else:
            try:
                text = json.dumps(value, indent=2)
            except Exception:
                text = str(value)

        if len(text) <= limit:
            return text
        return text[:limit] + '\n... [truncated]'

    def truncate_line(text, limit=280):
        if len(text) <= limit:
            return text
        return text[:limit] + ' ...'

    def read_file_text(path):
        if not path:
            return None
        try:
            with open(path, 'r', errors='ignore') as fh:
                return fh.read()
        except Exception:
            return None

    def locate_old_start_line(file_text, old_text, search_from=0):
        if file_text is None or not old_text:
            return None, search_from

        idx = file_text.find(old_text, search_from)
        if idx == -1:
            return None, search_from

        line = file_text.count('\n', 0, idx) + 1
        return line, idx + max(len(old_text), 1)

    def shift_hunk_header(line, base_old_line=None, base_new_line=None):
        if base_old_line is None and base_new_line is None:
            return line

        m = re.search(r'@@\s*-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s*@@', line)
        if not m:
            return line

        old_start = int(m.group(1))
        old_count = m.group(2)
        new_start = int(m.group(3))
        new_count = m.group(4)

        if base_old_line is not None:
            old_start = old_start + base_old_line - 1
        if base_new_line is None:
            base_new_line = base_old_line
        if base_new_line is not None:
            new_start = new_start + base_new_line - 1

        old_suffix = (',' + old_count) if old_count else ''
        new_suffix = (',' + new_count) if new_count else ''
        return '@@ -{}{} +{}{} @@'.format(old_start, old_suffix, new_start, new_suffix)

    def inline_diff_block(old_text, new_text, context=3, max_lines=220, base_old_line=None, base_new_line=None):
        old_lines = old_text.splitlines()
        new_lines = new_text.splitlines()

        diff_lines = list(difflib.unified_diff(
            old_lines,
            new_lines,
            fromfile='current',
            tofile='proposed',
            lineterm='',
            n=context,
        ))

        formatted = []
        for line in diff_lines:
            if line.startswith('--- ') or line.startswith('+++ '):
                continue
            if line.startswith('@@'):
                shifted = shift_hunk_header(line, base_old_line=base_old_line, base_new_line=base_new_line)
                formatted.append('... {}'.format(truncate_line(shifted, 120)))
                continue
            if line.startswith('+'):
                formatted.append('+ {}'.format(truncate_line(line[1:])))
                continue
            if line.startswith('-'):
                formatted.append('- {}'.format(truncate_line(line[1:])))
                continue
            if line.startswith(' '):
                formatted.append('  {}'.format(truncate_line(line[1:])))
                continue
            formatted.append(truncate_line(line))

        if not formatted:
            formatted = ['  (no textual diff)']

        if len(formatted) > max_lines:
            hidden = len(formatted) - max_lines
            formatted = formatted[:max_lines] + ['... [truncated {} lines]'.format(hidden)]

        return '\n'.join(formatted)

    def shell_block(command_text):
        lines = command_text.splitlines()
        if not lines:
            return '$ (empty)'
        first = '$ {}'.format(lines[0])
        rest = ['  {}'.format(line) for line in lines[1:]]
        return '\n'.join([first] + rest)

    if isinstance(inp, dict):
        file_path = inp.get('file_path', '(unknown file)')
        file_text = read_file_text(file_path)

        if tool == 'Edit':
            old_text = inp.get('old_string', '')
            new_text = inp.get('new_string', '')
            replace_all = inp.get('replace_all')
            replace_info = ('\nreplace_all: {}'.format(replace_all)) if replace_all is not None else ''
            base_line = inp.get('line_start')
            if not isinstance(base_line, int):
                base_line, _ = locate_old_start_line(file_text, old_text, search_from=0)

            diff_block = inline_diff_block(
                old_text,
                new_text,
                context=3,
                max_lines=220,
                base_old_line=base_line,
                base_new_line=base_line,
            )
            command = (
                'File: {}{}\n\n'.format(file_path, replace_info)
                + diff_block
            )
        elif tool == 'Write':
            content = inp.get('content', inp.get('text', ''))
            if file_text is not None:
                content_block = inline_diff_block(
                    file_text,
                    content,
                    context=2,
                    max_lines=240,
                    base_old_line=1,
                    base_new_line=1,
                )
            else:
                preview = truncate(content, 1600)
                content_lines = preview.splitlines() if preview else []
                if not content_lines:
                    content_lines = ['(empty)']
                content_block = '\n'.join(['+ {}'.format(truncate_line(line)) for line in content_lines])
            command = (
                'File: {}\n\n'.format(file_path)
                + '+++ proposed\n{}'.format(content_block)
            )
        elif tool == 'MultiEdit':
            edits = inp.get('edits', [])
            parts = ['File: {}'.format(file_path)]
            search_from = 0
            for idx, edit in enumerate(edits[:4], start=1):
                old_text = edit.get('old_string', '')
                new_text = edit.get('new_string', '')
                base_line = edit.get('line_start')
                if not isinstance(base_line, int):
                    base_line, search_from = locate_old_start_line(file_text, old_text, search_from=search_from)

                diff_block = inline_diff_block(
                    old_text,
                    new_text,
                    context=2,
                    max_lines=80,
                    base_old_line=base_line,
                    base_new_line=base_line,
                )
                parts.append(
                    '\nEdit {}\n{}'.format(idx, diff_block)
                )
            extra = len(edits) - 4
            if extra > 0:
                parts.append('\n... {} more edits'.format(extra))
            command = '\n'.join(parts)
        elif tool == 'Bash':
            cmd = truncate(inp.get('command', ''), 2400)
            desc = truncate(inp.get('description', ''), 600)
            desc_block = ('\ndescription: {}'.format(desc)) if desc else ''
            command = 'Command{}\n{}'.format(desc_block, shell_block(cmd))
        elif 'command' in inp:
            command = inp['command']
        elif 'file_path' in inp:
            command = inp['file_path']
        else:
            command = json.dumps(inp, indent=2)
    else:
        command = str(inp)

    command = truncate(command, 3200)

suggestions = d.get('permission_suggestions', [])

print(json.dumps({
    'tool': tool,
    'command': command,
    'suggestions': suggestions,
    'is_elicitation': is_elicitation,
    'elicitation': elicitation,
    'session_id': session_id
}))
" 2>>"$LOG") || true

TOOL=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('tool','Unknown'))" 2>/dev/null) || true
IS_ELICITATION=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print('1' if json.loads(sys.stdin.read()).get('is_elicitation') else '0')" 2>/dev/null) || true
SESSION_ID=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('session_id',''))" 2>/dev/null) || true

# Create a FIFO for the island to write the decision back
PIPE="/tmp/agent-island-perm-$$"
mkfifo "$PIPE" 2>/dev/null || true

PERMISSION_TIMEOUT_SECS="${AGENTCH_PERMISSION_TIMEOUT_SECS:-110}"
if ! [[ "$PERMISSION_TIMEOUT_SECS" =~ ^[0-9]+$ ]]; then
    PERMISSION_TIMEOUT_SECS=110
fi

dismiss_notch_on_signal() {
    echo "$(date '+%H:%M:%S') PERMISSION: received termination signal, dismissing session '$SESSION_ID'" >> "$LOG"
    "$ISLAND" dismiss "$SESSION_ID" >/dev/null 2>&1 || true
    exit 0
}

trap 'rm -f "$PIPE"' EXIT
trap dismiss_notch_on_signal TERM INT HUP

if [ "$IS_ELICITATION" = "1" ]; then
    # Elicitation: show the question and options
    ELICITATION_JSON=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print(json.dumps(json.loads(sys.stdin.read()).get('elicitation',{})))" 2>/dev/null) || true
    echo "$(date '+%H:%M:%S') ELICITATION: question=$(printf '%s' "$ELICITATION_JSON" | head -c 200) pipe=$PIPE" >> "$LOG"

    "$ISLAND" elicitation "$ELICITATION_JSON" "Claude" "$PPID" "$PIPE" "$SESSION_ID" "$BRANCH_LABEL"

    # Block reading from the FIFO — the island writes "answer:<selection>" or "deny"
    if IFS= read -r -t "$PERMISSION_TIMEOUT_SECS" DECISION < "$PIPE"; then
        DECISION=$(printf '%s' "$DECISION" | tr -d '\n')
    else
        DECISION="deny"
        echo "$(date '+%H:%M:%S') ELICITATION: timed out after ${PERMISSION_TIMEOUT_SECS}s, dismissing session '$SESSION_ID'" >> "$LOG"
        "$ISLAND" dismiss "$SESSION_ID" >/dev/null 2>&1 || true
    fi
    rm -f "$PIPE"

    echo "$(date '+%H:%M:%S') ELICITATION DECISION: $DECISION" >> "$LOG"

    if echo "$DECISION" | grep -q '^answer:'; then
        ANSWER="${DECISION#answer:}"
        echo "$(date '+%H:%M:%S') ELICITATION: user answered '$ANSWER'" >> "$LOG"
        # Deny the AskUserQuestion tool but give Claude the user's answer in the message.
        # Claude will see this and know the user's selection without the TUI dialog showing.
        OUTPUT=$(python3 -c "
import json, sys
answer = sys.argv[1]
output = {
    'hookSpecificOutput': {
        'hookEventName': 'PermissionRequest',
        'decision': {
            'behavior': 'deny',
            'message': 'The user answered via agentch notch UI. Their selection: ' + answer
        }
    }
}
print(json.dumps(output))
" "$ANSWER" 2>>"$LOG") || true
        echo "$OUTPUT"
        echo "$(date '+%H:%M:%S') ELICITATION: output deny-with-answer JSON, exiting 0" >> "$LOG"
        exit 0
    else
        echo "Elicitation dismissed by user via agentch" >&2
        echo "$(date '+%H:%M:%S') ELICITATION: dismissed via exit 2" >> "$LOG"
        exit 2
    fi
else
    # Regular permission: show approve/deny
    COMMAND=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('command',''))" 2>/dev/null) || true
    SUGGESTIONS=$(printf '%s' "$EXTRACTED" | python3 -c "import json,sys; print(json.dumps(json.loads(sys.stdin.read()).get('suggestions',[])))" 2>/dev/null) || true

    if [ -z "$TOOL" ]; then TOOL="Unknown"; fi
    if [ -z "$COMMAND" ]; then COMMAND="(no details)"; fi
    if [ -z "$SUGGESTIONS" ]; then SUGGESTIONS="[]"; fi

    echo "$(date '+%H:%M:%S') PERMISSION: tool=$TOOL command=$(echo "$COMMAND" | head -c 100) suggestions=$SUGGESTIONS pipe=$PIPE" >> "$LOG"

    "$ISLAND" permission "$TOOL" "$COMMAND" "Claude" "$PPID" "$PIPE" "$SUGGESTIONS" "$SESSION_ID" "$BRANCH_LABEL"

    # Block reading from the FIFO — the island writes "allow", "deny", or "allow_always:<json>"
    if IFS= read -r -t "$PERMISSION_TIMEOUT_SECS" DECISION < "$PIPE"; then
        DECISION=$(printf '%s' "$DECISION" | tr -d '\n')
    else
        DECISION="deny"
        echo "$(date '+%H:%M:%S') PERMISSION: timed out after ${PERMISSION_TIMEOUT_SECS}s, dismissing session '$SESSION_ID'" >> "$LOG"
        "$ISLAND" dismiss "$SESSION_ID" >/dev/null 2>&1 || true
    fi
    rm -f "$PIPE"

    echo "$(date '+%H:%M:%S') PERMISSION DECISION: $DECISION" >> "$LOG"

    if [ "$DECISION" = "allow" ]; then
        echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
        echo "$(date '+%H:%M:%S') PERMISSION: output allow JSON, exiting 0" >> "$LOG"
        exit 0
    elif echo "$DECISION" | grep -q '^allow_always:'; then
        SUGGESTION_JSON="${DECISION#allow_always:}"
        echo "$(date '+%H:%M:%S') PERMISSION: always allow with suggestion=$SUGGESTION_JSON" >> "$LOG"
        OUTPUT=$(python3 -c "
import json, sys
suggestion = json.loads(sys.argv[1])
output = {
    'hookSpecificOutput': {
        'hookEventName': 'PermissionRequest',
        'decision': {
            'behavior': 'allow',
            'updatedPermissions': [suggestion]
        }
    }
}
print(json.dumps(output))
" "$SUGGESTION_JSON" 2>>"$LOG") || true
        if [ -n "$OUTPUT" ]; then
            echo "$OUTPUT"
            echo "$(date '+%H:%M:%S') PERMISSION: output allow_always JSON, exiting 0" >> "$LOG"
            exit 0
        else
            echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
            echo "$(date '+%H:%M:%S') PERMISSION: fallback allow, exiting 0" >> "$LOG"
            exit 0
        fi
    else
        echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Permission denied by user via agentch"}}}'
        echo "$(date '+%H:%M:%S') PERMISSION: output deny JSON, exiting 0" >> "$LOG"
        exit 0
    fi
fi
