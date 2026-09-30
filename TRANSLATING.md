# Translating Levelbound

Translations are contributed by pull request. Every language has one file in `Locale/`:

| Client language | File |
|---|---|
| Deutsch | `deDE.lua` |
| Español (España) | `esES.lua` |
| Español (México) | `esMX.lua` |
| Français | `frFR.lua` |
| Italiano | `itIT.lua` |
| 한국어 | `koKR.lua` |
| Português (Brasil) | `ptBR.lua` |
| Русский | `ruRU.lua` |
| 简体中文 | `zhCN.lua` |
| 繁體中文 | `zhTW.lua` |

## How to translate

Each file lists every English string, in the same groups as `enUS.lua`. An untranslated string is a commented line:

```lua
-- L["Hide in Combat"] = "Hide in Combat"
```

To translate it, remove the leading `-- ` and replace the text on the right. Leave the key on the left exactly as it is:

```lua
L["Hide in Combat"] = "Im Kampf ausblenden"
```

Anything left commented shows in English, so a partial translation is welcome.

## Rules

- **Keep the placeholders.** `%s`, `%d` and `%q` are filled in by the addon. Keep every one, in the same order. A missing or extra placeholder breaks the message in game.
- **Keep color codes.** Text such as `|cff7a63ff…|r` is a color; keep both ends.
- **Keep the capitalization style.** Settings labels are written like titles in English ("Show Party Markers"); use whatever your language's own WoW settings panel uses. Chat messages and tooltips are sentences.
- **Strings starting with `tag.` or `slot.`** describe the text editor's tags and positions; translate the description, not the tag.
- **One language per pull request**, please.

## Checking your work

If you have Python, run this from the repository root before opening the pull request:

```
python Tools/sync-locales.py --check
```

It reports any placeholder, color code or key mistakes. The same check runs automatically on every pull request.

In game, switch the client to your language, `/reload`, and look through the settings window (`/lb`).

## For maintainers

After adding, changing or removing an English string in `enUS.lua`, run `python Tools/sync-locales.py`. It adds new strings to every language as commented English lines, drops removed ones and keeps every existing translation.
