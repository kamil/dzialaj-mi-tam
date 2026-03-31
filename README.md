# dzialaj-mi-tam

Replace Claude Code spinner verbs with your own.

Uses system Ruby (`/usr/bin/ruby`) pre-installed on macOS. No dependencies.

## One-liner install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kamil/dzialaj-mi-tam/master/install.sh)
```

Pick a pack from the interactive menu:

```
Available packs:
  1) chef (30 verbs: Chopping, Dicing, Simmering...)
  2) corporate (30 verbs: Synergizing, Leveraging, Disrupting...)
  3) cursed (40 verbs: Procrastinating, Overthinking, Panicking...)
  4) gym (30 verbs: Repping, Curling, Squatting...)
  5) pl (70 verbs: Ogarnianie, Kminienie, Opieprzanie...)

Pick a pack [1-5]:
```

## Restore

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kamil/dzialaj-mi-tam/master/install.sh) --restore
```

## Verb packs

| Pack | Vibe |
|------|------|
| `pl` | Ogarnianie, Pierdolenie, Kombinowanie... |
| `cursed` | Procrastinating, Hallucinating, Doom-scrolling... |
| `chef` | Chopping, Deglazing, Sous-viding... |
| `corporate` | Synergizing, Circling-back, Solutioning... |
| `gym` | Squatting, Deadlifting, Maxing-out... |

## Custom verbs

Clone the repo, add a JSON file to `verbs/`, run:

```bash
ruby patch.rb verbs/my_pack.json
```

Format: plain JSON array of strings:

```json
["Thinking", "Pondering", "Vibing"]
```

## How it works

1. Finds the Claude Code binary in `~/.local/share/claude/versions/`
2. Creates a `.backup` next to it
3. Locates the spinner verb arrays inside the Bun executable
4. Replaces strings in-place, respecting memory slot alignment
5. Re-signs the binary ad-hoc with original entitlements

## Notes

- macOS only (for now)
- `claude update` overwrites the binary, re-run after updating
- Backup is always at `<binary>.backup`

## License

MIT
