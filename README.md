# dzialaj-mi-tam

Podmienia teksty spinnera w Claude Code na w pelni konfigurowalne wlasne.

Domyslnie dostarcza zestaw polskich slow (kulturalnych i mniej kulturalnych).

![jak tam chlopie](https://i.imgflip.com/2/1bij.jpg)

## Instalacja (jedna linijka)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kamil/dzialaj-mi-tam/master/install.sh)
```

Albo recznie:

```bash
git clone https://github.com/kamil/dzialaj-mi-tam.git
cd dzialaj-mi-tam
python3 patch.py
```

## Przywracanie oryginalu

```bash
python3 patch.py --restore
```

## Wlasne slowa

Edytuj `verbs.json` i odpal ponownie:

```bash
python3 patch.py verbs.json
```

Albo uzyj dowolnego pliku JSON:

```bash
python3 patch.py moje_slowa.json
```

Format: zwykla tablica stringow:

```json
[
  "Ogarnianie",
  "Kombinowanie",
  "Kminienie"
]
```

## Podglad aktualnych slow

```bash
python3 patch.py --list
```

## Jak to dziala

1. Znajduje binarke Claude Code (`~/.local/share/claude/versions/`)
2. Robi backup (`.backup`)
3. Lokalizuje tablice czasownikow w binarce (format Bun SEA)
4. Podmienia stringi z zachowaniem slotow pamieci
5. Na macOS: re-signuje binarke ad-hoc z oryginalnymi entitlements

## Uwagi

- macOS only (na razie)
- Kazdy `claude update` nadpisuje binarke - trzeba odpalic ponownie
- Wymaga Python 3.6+
- Backup zawsze w `<binary>.backup`

## Dzialaj mi tam i zebys mi byl!!!
