# dzialaj-mi-tam

Replace Claude Code spinner verbs with your own.

Uses system Ruby (`/usr/bin/ruby`) that comes pre-installed on macOS. No dependencies.

## Install

```bash
git clone https://github.com/kamil/dzialaj-mi-tam.git
cd dzialaj-mi-tam
ruby patch.rb
```

Running without arguments shows an interactive picker:

```
Available packs:
  1) chef (30 verbs: Chopping, Dicing, Simmering...)
  2) corporate (30 verbs: Synergizing, Leveraging, Disrupting...)
  3) cursed (40 verbs: Procrastinating, Overthinking, Panicking...)
  4) gym (30 verbs: Repping, Curling, Squatting...)
  5) pl (70 verbs: Ogarnianie, Kminienie, Opieprzanie...)

Pick a pack [1-5]:
```

Or pass a pack directly:

```bash
ruby patch.rb verbs/cursed.json
```

## Verb packs

| Pack | Vibe |
|------|------|
| `pl` | Ogarnianie, Pierdolenie, Kombinowanie... |
| `cursed` | Procrastinating, Hallucinating, Doom-scrolling... |
| `chef` | Chopping, Deglazing, Sous-viding... |
| `corporate` | Synergizing, Circling-back, Solutioning... |
| `gym` | Squatting, Deadlifting, Maxing-out... |

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
