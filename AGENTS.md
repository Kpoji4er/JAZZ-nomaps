# Правила пакета `jazz-nomaps` (display: **JAZZ Vanilla Maps**)

Локальный overlay. Канон комплекта: `../jazz/AGENTS.md`. Навигация: `../jazz/.agents/docs/index.md`. Спеки: `../jazz/docs/specs/active/`. Совместимость: `../jazz/docs/specs/active/JAZZ-COMPAT-002.md`. При противоречии действует центральный контракт.

## Роль

Опциональный профиль **вместо `jazz-maps`**: vanilla HotDiamonds + jazz systems (Legion AI auto-regions, squad remap, loot inject).

В Mod Manager пакет называется **JAZZ Vanilla Maps** (`id` `7MsJ2Eq`). Каталог/репозиторий `jazz-nomaps` — техническое имя.

| С maps | Без maps (Vanilla Maps) |
| --- | --- |
| assets + units + **maps** + jazz | assets + units + **nomaps** + jazz |

При загруженном `FhNNYd` этот пакет **no-op**.

## Когда что читать

Не открывать все skills. Только совпавшая строка:

| Задача | Открыть |
| --- | --- |
| Поведение, public ID, generated data, межпакетный контракт | spec в `../jazz/docs/specs/active/` + `$specify-jazz-change` |
| Несколько пакетов / ownership | `../jazz/.agents/skills/work-on-jazz-mod/SKILL.md` |
| Editor-generated / `items.lua` / `metadata.lua` | `$sync-jazz-generated-data` |
| Player-facing эффект / drift technical | `../jazz/.cursor/rules/jazz-docs-sync.mdc` + `$document-jazz-systems` |

## Ограничения

- Не править `jazz-maps/**`.
- Не копировать UnitData/EnemySquad — читать `jazz-units`.
- Сектора/аванпосты: vanilla `CampaignPreset` (Major HQ `A20`, Ernie fortress `H4`).
- Authored maps Regions (`ErnieIsland`, `PortCacaoEnvirons`, `GreatDesert`, `MountainSteppe`, `FleatownEnvirons`, `LaBarrier`, `GreatForest`, …) — runtime disable managed maps-only AI в этом пакете.
- ModDef id: `7MsJ2Eq` (не менять после Workshop upload).
