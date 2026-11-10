# StickyFilters

**CurseForge:** https://www.curseforge.com/wow/addons/stickyfilters

A quality-of-life addon for **World of Warcraft: Forever** (interface 16001). Trainers and merchants remember what you want to see, and every entry tells you at a glance why you can or cannot use it. Fully available in **English and German**.

![StickyFilters0](https://media.forgecdn.net/attachments/2179/6/0-png.png)
![StickyFilters1](https://media.forgecdn.net/attachments/2179/7/1-png.png)
![StickyFilters2](https://media.forgecdn.net/attachments/2179/8/2-png.png)
![StickyFilters3](https://media.forgecdn.net/attachments/2179/9/3-png.png)
![StickyFilters4](https://media.forgecdn.net/attachments/2179/10/4-png.png)

## Why?

- Trainer filters like "Already known" reset every time you close the window.
- Vendors show recipes you already know, gear your class can never wear and items you cannot afford, all in the same red.

## Features

### Color language (merchants and trainers)

| Color | Meaning | Example |
|---|---|---|
| Gray (desaturated) | Already known | A recipe or tome you learned |
| Dark orange | Recipe for a profession you have not learned | A Blacksmithing plan while you are a Tailor |
| Dark red | Never usable by your character (class, race, armor or weapon type) | Plate armor for a mage |
| Orange | Skill missing, but learnable | A sword before you trained Swords; a recipe that needs a higher profession skill or a previous rank |
| Blue + crossed-out coin | Usable, but you cannot afford it | A 20 silver bag while you have 8 silver |
| Red | Level too low or another requirement not met | Food that requires level 25 |

The **crossed-out coin** appears on everything you cannot afford, in every color, for gold and for every other currency (with that currency's icon). Known trainer entries also get the darker row background.

### Merchants

- **Search box** (fuzzy) and **filter menu** above the window. Search matches get a subtle green animated highlight, even inside dimmed rows.
- **Category filters:** unchecked categories are dimmed, never hidden, so a click always buys the item you clicked.
- **Range filters:** "Only up to +3 levels" and "Only up to +15 profession points"; the numbers are adjustable.
- **Page hint** shows on which pages the search matches are.
- **Green check mark** on items that fit you: made for your class or race, armor and weapon types you can use, recipes for your professions.

### Trainers

- **Remembered Blizzard filters:** "Available", "Unavailable", "Already known" and "Categorize" are saved account-wide and re-applied at every trainer. Changes made by other addons (for example ones that switch all filters on to scan the list) are reverted automatically.
- **Own search box and filter menu** with the same categories and range filters as merchants. Blizzard's own trainer menu stays untouched.

### Search memory and hint

- **Remember search** (on by default): the search text survives closing the window, as a separate search per NPC (default) or one search for all.
- A small **hint** with an arrow points at the search box and filter button the first time; close it with X or turn it off with "Don't show again".

### Tooltips

- "Missing" (when you cannot afford it) or "After buy" (when you can), with gold, silver, copper and currency icons.
- A short gray explanation of why the entry has its color, is dimmed, has a check mark or matches the search.

## Settings

Everything can be configured without commands under **Options > AddOns > StickyFilters** (or `/stickyfilters options`):

- **General:** language, icons, "Reload UI" button, reset
- **Merchant:** color categories, range filters (with sliders), check mark criteria, search memory, hint
- **Trainer:** remembered Blizzard filters, color categories, range filters, search memory, hint

Every setting has a tooltip with an example. The filter menus on the merchant and trainer windows offer the same switches directly.

### Defaults (first run)

- Trainer: Categorize off, Available on, Unavailable on; StickyFilters categories "Already known" and "Skill missing" dimmed, everything else shown
- Merchant: "Already known" and "Never usable" dimmed, everything else shown
- Both: range filters on (+3 levels, +15 profession points), search remembered per NPC, hint shown, icons on

## Commands

Every command works with `/stickyfilters` and with the short form `/sf`.

- `/stickyfilters`: show the saved and current trainer filter state
- `/stickyfilters options`: open the settings page
- `/stickyfilters icons [coin|check|on|off]`: toggle the coin and check mark icons (useful if another addon already draws icons there)
- `/stickyfilters reset`: reset all settings to the defaults
- `/stickyfilters debug`: toggle debug output in chat
- `/stickyfilters dump [note]`: append the current merchant page to the dump log (written on `/reload`)
- `/stickyfilters dump clear`: clear the dump log

## Languages

English and German. By default the client language is used; it can be forced to English or German in the options. A language change takes effect after reloading the UI (button in the options, or `/reload`).

## Compatibility

- Works next to addons that temporarily change trainer filters (for example Warchive): your choice is restored afterwards.
- Warlock tomes: if WhatsTraining is installed, the tomes it remembers as learned are shown as known.

## License

MIT, see [LICENSE](LICENSE).
