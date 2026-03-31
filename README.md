# dzialaj-mi-tam

Replace Claude Code spinner verbs with your own. Ships with a Polish set by default.

Uses system Ruby (`/usr/bin/ruby`) that comes pre-installed on macOS. No dependencies.

## Install

```bash
git clone https://github.com/kamil/dzialaj-mi-tam.git
cd dzialaj-mi-tam
ruby patch.rb
```

Or one-liner (requires git):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kamil/dzialaj-mi-tam/master/install.sh)
```

## Restore

```bash
ruby patch.rb --restore
```

## Custom verbs

Edit `verbs.json` or point to your own file:

```bash
ruby patch.rb my_verbs.json
```

Format: plain JSON array of strings:

```json
["Thinking", "Pondering", "Vibing"]
```

## List current verbs

```bash
ruby patch.rb --list
```

## How it works

1. Finds the Claude Code binary in `~/.local/share/claude/versions/`
2. Creates a `.backup` next to it
3. Locates the spinner verb arrays inside the Bun executable
4. Replaces strings in-place, respecting memory slot alignment
5. On macOS: re-signs the binary ad-hoc with original entitlements

## Notes

- macOS only (for now)
- `claude update` overwrites the binary, re-run after updating
- Backup is always at `<binary>.backup`

## License

MIT
