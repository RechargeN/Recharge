# NOTICE — сторонние компоненты с условиями лицензии

Recharge использует сторонние пакеты из npm и pub.dev; их лицензии и уведомления
поставляются внутри самих пакетов и не удаляются. Полный состав зависимостей
закреплён lock-файлами (`apps/backend/functions/package-lock.json`, lock-файлы
runtime-пакетов в `apps/backend/*-runtime/`, `pubspec.lock`); их SHA-256
записываются в манифест release candidate (`docs/release/rc/`).

Ниже — компоненты, для которых решение владельца требует отдельного учёта.

## libvips (LGPL-3.0-or-later) в составе sharp

| Пакет | Версия | Лицензия | Где используется | Решение владельца |
|---|---|---|---|---|
| `@img/sharp-libvips-linux-x64` | 1.3.4 | LGPL-3.0-or-later | образ media-tools (Cloud Run, Debian glibc), CI и локальный стенд | 2026-10-09 |
| `@img/sharp-libvips-linuxmusl-x64` | 1.3.4 | LGPL-3.0-or-later | только Linux-раннер CI (npm ставит рядом с glibc-сборкой); в образ не входит | 2026-11-13 |
| `@img/sharp-win32-x64` | 0.35.5 | Apache-2.0 AND LGPL-3.0-or-later | локальный стенд Windows | 2026-10-09 |
| `@img/sharp-wasm32` | 0.35.5 | Apache-2.0 AND LGPL-3.0-or-later AND MIT | ставится npm как optional; processor его не использует | 2026-10-09 |

Условия (MEDIA_D1_REAL_TOOLS_AMENDMENT §3.6):

- лицензия и уведомления пакетов сохраняются в том виде, в каком их публикует
  автор (пакеты ставятся из реестра npm по SRI, без изменений);
- библиотека не модифицируется; если это когда-нибудь понадобится, изменения
  публикуются, а не скрываются;
- `apps/backend/scripts/verify-toolchain.mjs` разрешает эти пакеты поштучно, по
  имени и версии: другая версия или другой пакет с такой лицензией требует
  нового решения.

Исходный код libvips: https://github.com/libvips/libvips ; сборки sharp:
https://github.com/lovell/sharp-libvips .
