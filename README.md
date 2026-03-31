# dzialaj-mi-tam

Custom spinner verbs for Claude Code.

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kamil/dzialaj-mi-tam/master/install.sh)
```

Pick a pack:

```
Available packs:
  1) chef - Chopping, Dicing, Simmering...
  2) corporate - Synergizing, Leveraging, Disrupting...
  3) cursed - Procrastinating, Overthinking, Panicking...
  4) gym - Repping, Curling, Squatting...
  5) pl - Ogarnianie, Kminienie, Rzępolenie...
  6) skrzypas - Ogarnianie, Zwoływanie, Czynienie...

Pick [1-6]:
```

## Restore

Re-run the installer with `--restore`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kamil/dzialaj-mi-tam/master/install.sh) --restore
```

Or just update Claude Code, which replaces the binary:

```bash
claude update
```

## Packs

| Pack | Vibe |
|------|------|
| **skrzypas** | Jeremiaszenie, Wołanie Brygidy, Ty szmato, Jak tam chłopie... |
| **pl** | Pierdolenie, Gównoburzenie, Rzyganie, Bekanie... |
| **cursed** | Procrastinating, Hallucinating, Doom-scrolling... |
| **corporate** | Synergizing, Circling-back, Solutioning... |
| **chef** | Chopping, Deglazing, Sous-viding... |
| **gym** | Squatting, Deadlifting, Maxing-out... |

## Custom verbs

Pass any JSON file with an array of strings:

```bash
ruby patch.rb my_verbs.json
```

```json
["Thinking", "Pondering", "Vibing"]
```

## Notes

- `claude update` overwrites the binary, re-run after updating
- Backup at `<binary>.backup`

## License

MIT
