# Claude Code status line

A two-line status line for [Claude Code](https://claude.com/claude-code) on macOS. It shows the
model, context, cache and cost on the left, and your plan end date, 5-hour limit and weekly limit
with progress bars on the right edge of the terminal.

![The status line with normal, high and nearly used up limits](docs/screenshot.png)

## What it shows

| Part | Meaning |
|---|---|
| Model, effort, cost | Current model, effort level and the session cost |
| Context, Cache | Context window used, prompt cache hit ratio |
| Session, API | Time since the session started, time spent waiting for the model |
| Plan ends | Days left and a bar of the month used (optional, see below) |
| 5-Hour, Weekly | Percent used, time until reset and a bar for each limit |

Limits turn yellow at 70%, orange at 80% and red at 90%. The plan turns yellow in the last 7 days
and red in the last 3. Until the first reply of a session, the last saved limits are shown. A limit
whose window is over shows 0% until Claude Code reports the next one.

The block on the right follows the window width. Use a window of about 135 columns or more.

## Requirements

- macOS (the script uses the BSD `date` command)
- `jq`: `brew install jq`
- Claude Code with a Pro or Max plan for the limits; other plans show a dash

## Install

```sh
mkdir -p ~/.claude/state
curl -fsSL https://raw.githubusercontent.com/amirhp-com/claude-code-statusline/main/statusline.sh -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Then add this to `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "$HOME/.claude/statusline.sh",
  "refreshInterval": 60
}
```

## Plan end date

Claude Code does not report when your plan ends, so the script reads it from a file. Put one
Gregorian date in it, and change it after each renewal. Delete the file to hide the block.

```sh
echo 2026-12-20 > ~/.claude/state/subscription-ends
```

The bar covers the month before that date. To show the date in the Jalali calendar, set the command to:

```json
"command": "STATUSLINE_CALENDAR=jalali $HOME/.claude/statusline.sh"
```

## Files and privacy

The script sends nothing anywhere. It reads the JSON that Claude Code passes to it and writes one
file, `~/.claude/state/usage-latest.json`, with the last limits.

## License

MIT © 2026 [AmirhpCom](https://amirhp.com). Not affiliated with Anthropic.
