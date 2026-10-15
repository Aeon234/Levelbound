# Levelbound

## Unreleased

Settings:

- The settings window and edit mode are rebuilt on the settings library Aeon's addons share, with search across
  every page and Undo.
- The Bars settings are now five pages: Layout, Appearance (with the bar preview), Text, Visibility and Gain
  Indicator. Gain Indicator, Party Progress and Level-Ups no longer have tabs; Party Progress shows the sections
  for markers or for standalone bars, as Display is set. `/lb appearance`, `/lb text` and `/lb visibility` open
  their own pages.
- Settings no longer have a Defaults button per page. A setting that follows a shared value goes back to it with
  its reset arrow, and the profile's Reset still restores everything.
- In edit mode, each frame has a menu with its position and a shortcut to its settings. Your snap, grid and
  toolbar choices carry over.

## 1.2.1

Fixes:

- Leveling up outside a group no longer raises an "AddOn tried to call the protected function" error. The
  game blocks addons from sending emotes on their own, so Emote Level-Up Message is now Print Level-Up Message and
  shows the line in your own chat instead.

## 1.2.0

Gain indicator:

- The gain indicator can sit to the right or left of its bar, centered on it. Where there is no room beside the
  bar, such as in fullscreen, it sits above that end of the bar instead.
- With segmented bars, gains beside the bar gather in one stack next to the whole row, labeled by type as when
  detached, and grow in the chosen direction.
- A new Animate switch, on by default. Turned off, the indicator and the detached stack appear in place and fade
  without moving.
- A new Animation Style for indicators beside the bar or detached: Rise, as before, or Slide Outward, away from
  the bar. With Slide Outward, the segmented and detached stacks line up side by side instead of on top of each
  other, and the detached stack can grow left or right.
- The Gain Indicator and progress type previews show the indicator beside the bar when it is set there.

Party level-up notices:

- Two new anchors, Right of Bar and Left of Bar, place the notices beside the bar, the first one centered on it.
  Where there is no room beside the bar, they sit above that end of the bar instead.
- The same Animation Style as the gain indicator, for notices beside the bar or detached: Rise, as before, or Slide
  Outward, with the notices side by side growing away from the bar. Detached, they can grow left or right.

Fixes:

- When a type gains again while its line is still in the detached stack, that line moves to the front, so the
  stack's lines fade from the oldest first instead of an older line sliding back before it fades.
- All new text is translated into German, Spanish, French, Italian, Korean, Brazilian Portuguese, Russian and
  Chinese.

## 1.1.0

New looks:

- A first-time install now asks you to choose a style: Blizzard or Modern, each with a preview of the experience bar.
- Blizzard border: the default experience bar's own frame, with beveled ends, Blizzard's dividers and the bar at
  Blizzard's height. Text inside the bar is turned off, since there is no room for it.
- Levelbound Blizzard bar texture: the default experience bar's two-tone fill, in any bar color.
- Pip party markers: Blizzard's rested-experience tick, in each member's class color. On the Blizzard border they
  start at Blizzard's own size and place.
- The 1 Pixel and 2 Pixel borders are now one Pixel border with a Border Width from 1 to 10. Your saved border is
  kept.

More control:

- XP dividers can mark every 10% or every 5% of a level.
- Party markers can sit on the bar's center, top or bottom edge, with a vertical offset. Top-Edge Notch is now
  Notch and points into the bar from either edge.
- Bar width moves in 1-pixel steps and can go up to your screen's width.
- Text shown on hover now fades in and out.
- Your level-ups are announced as an emote to players nearby while you are not in a group, so others see
  Levelbound in action. It is on by default and can be turned off on the Level-Ups page's Announcements tab.
- Level-up messages in emote, party and guild chat now start with a star icon.

A tidier settings window:

- Settings are split into tabs. Layout, Appearance, Text and Visibility share one Layout page; the Gain
  Indicator, each progress type, Markers and Level-Ups have tabs of their own.
- Every page has a short description under its title.
- A bar's own size and each text slot's style show whether they follow the shared setting, with a button to go
  back to it.
- Previews keep the same size as you change settings, and draw bars at a steady width.
- The Appearance preview replays the gain effect while Gain Shimmer is on; hovering the Markers preview fades the
  markers in as on the real bar.
- More of each preview can be clicked to find its setting: the ring around a bar finds Border Style even with no
  border, the end of the fill finds the spark, the space above a bar on the Gain Indicator page finds that bar's
  arrow tint, and a text slot finds its Text row.
- The Markers and Level-Ups previews show the bar without its text.
- Progress types with a single Bar Color show it beside the bar's on/off switch.
- The Post-Dungeon Summary has its own section, Dungeon Summary, beside Level-Ups.
- On the Profiles page, Active Profile and Use a Character Specific Profile share a row.
- The settings window's content areas are lighter.

Fixes:

- Text above and below a bar, and the gain indicator, no longer overlap the border.
- Toggle switches respond to clicks on their knob.
- A whole dropdown row can be clicked, not just its text.
- Border Color is turned off when there is no border, except in Segmented layout, where it colors the
  separators.
- Growth Direction and Gap Between Bars are only offered in Connected layout, where they apply.
- The preview's "Click an element" hint no longer runs into the preview.
- All new text is translated into German, Spanish, French, Italian, Korean, Brazilian Portuguese, Russian and
  Chinese.

## 1.0.1

- The settings window is narrower, so it fits better on smaller screens.

## 1.0.0

First release, for Retail and WoW: Forever.

- Experience bar with rested and quest turn-in overlays, XP per hour, time to level and session totals.
- Pet experience, reputation, honor, House Favor, Neighborhood Endeavors and Trading Post bars.
- Three layouts: one segmented bar, connected stacked bars, or independent bars placed one by one in edit mode;
  any of them can stretch across the top or bottom of the screen.
- Editable text on every bar, with live tags such as [percent] and [remaining]; the experience bar has nine text
  places, inside, above and below it.
- Shift-click a bar, or use /lb share, to post its progress in chat.
- Gain indicator: an arrow and the amount gained on each bar, or gathered in one stack away from the bars.
- Party XP markers on your experience bar for group members running Levelbound.
- Party level-up notices on screen and in chat, with a sound; your own level-ups posted to party or guild; a
  summary of the experience and time each dungeon or scenario took.
- Borders (1 Pixel, 2 Pixel, Simple, Simple Thick, Bronze, Metallic), bar textures, fonts, spark, gain shimmer
  and XP dividers, with LibSharedMedia support.
- Fading, focus dimming and combat visibility options.
- A settings window with a live preview on every page; click part of the preview to find its setting.
- Profiles: per-character or shared, with copy, rename, reset, export and import.
- Translated into German, Spanish (Spain and Mexico), French, Italian, Korean, Brazilian Portuguese, Russian and
  Chinese (Simplified and Traditional).
