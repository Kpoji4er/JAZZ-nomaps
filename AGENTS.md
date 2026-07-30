# Правила пакета `jazz-nomaps`

Локальный overlay. Канон комплекта: `../jazz/AGENTS.md`. Спека: `../jazz/docs/specs/active/JAZZ-COMPAT-002.md`.

## Роль

Опциональный профиль **вместо `jazz-maps`**: vanilla HotDiamonds + jazz systems (Legion AI auto-regions, squad remap, loot inject).

| С maps | Без maps |
| --- | --- |
| assets + units + **maps** + jazz | assets + units + **nomaps** + jazz |

При загруженном `FhNNYd` этот пакет **no-op**.

## Ограничения

- Не править `jazz-maps/**`.
- Не копировать UnitData/EnemySquad — читать `jazz-units`.
- Сектора/аванпосты: vanilla `CampaignPreset` (Major HQ `A20`, Ernie fortress `H4`).
- Authored `ErnieIsland` (I7/B28) maps-only — runtime disable в этом пакете.
- ModDef id: `7MsJ2Eq` (не менять после Workshop upload).
