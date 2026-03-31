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

To undo, just run `claude update`.

## Custom verbs

Pass any JSON file with an array of strings:

```bash
ruby patch.rb my_verbs.json
```

```json
["Thinking", "Pondering", "Vibing"]
```

## License

MIT
