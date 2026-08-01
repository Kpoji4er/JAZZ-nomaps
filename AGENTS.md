# Правила пакета `jazz-nomaps` (display: **JAZZ Vanilla Maps**)

Локальный overlay. Канон комплекта: `../jazz/AGENTS.md`. Спека: `../jazz/docs/specs/active/JAZZ-COMPAT-002.md`.

## Роль

Опциональный профиль **вместо `jazz-maps`**: vanilla HotDiamonds + jazz systems (Legion AI auto-regions, squad remap, loot inject).

В Mod Manager пакет называется **JAZZ Vanilla Maps** (`id` `7MsJ2Eq`). Каталог/репозиторий `jazz-nomaps` — техническое имя.

| С maps | Без maps (Vanilla Maps) |
| --- | --- |
| assets + units + **maps** + jazz | assets + units + **nomaps** + jazz |

При загруженном `FhNNYd` этот пакет **no-op**.

## Ограничения

- Не править `jazz-maps/**`.
- Не копировать UnitData/EnemySquad — читать `jazz-units`.
- Сектора/аванпосты: vanilla `CampaignPreset` (Major HQ `A20`, Ernie fortress `H4`).
- Authored `ErnieIsland` (I7/B28) maps-only — runtime disable в этом пакете.
- ModDef id: `7MsJ2Eq` (не менять после Workshop upload).
