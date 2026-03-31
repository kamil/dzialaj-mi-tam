# dzialaj-mi-tam

Replace Claude Code spinner verbs with your own.

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

## Verb packs

| Pack | File | Vibe |
|------|------|------|
| Polish | `verbs/pl.json` | Ogarnianie, Pierdolenie, Kombinowanie... (default) |
| Original | `verbs/original.json` | The stock Claude Code verbs |
| Cursed | `verbs/cursed.json` | Procrastinating, Hallucinating, Doom-scrolling... |
| Chef | `verbs/chef.json` | Chopping, Deglazing, Sous-viding... |
| Corporate | `verbs/corporate.json` | Synergizing, Circling-back, Solutioning... |
| Gym | `verbs/gym.json` | Squatting, Deadlifting, Maxing-out... |

Use a specific pack:

```bash
ruby patch.rb verbs/cursed.json
```

## Restore

```bash
ruby patch.rb --restore
```

## Custom verbs

Create your own JSON file:

```json
["Thinking", "Pondering", "Vibing"]
```

```bash
ruby patch.rb my_verbs.json
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
