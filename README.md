# mc-packs

Дополнительные моды («extras») к сборкам Minecraft для нашей компании. Только ссылки на Modrinth — ни базовых сборок, ни их конфигов, ни jar-файлов здесь нет.

- `packs/prominence2-extras/` — доп. моды к Prominence II: Hasturian Era (Fabric 1.20.1).
- `tools/packgen.mjs` — генератор packwiz-совместимых файлов (`node tools/packgen.mjs add <dir> <modrinth-slug>`).

Формат — packwiz (`pack.toml`, `index.toml`, `mods/*.pw.toml`), клиенты обновляются через packwiz-installer.

## Credits / licenses

- **Prominence 2 RPG — Russian Localization** (MIT) by Synessful and d0ukesh1: files under `packs/prominence2-extras/config/prominence_localization`, `.../resources` and `.../mods/prominence-localization-1.0.0.jar`. Source: https://github.com/d0ukesh1/Prominence-2-RPG-Russian-Localization (CurseForge project 1355158, release 4.1.6-beta3).
- **VaultPatcher** (GPL-3.0) by FengMing3093: `packs/prominence2-extras/mods/vaultpatcher-all-1.4.4.jar`, unmodified build 1.4.4+1. Source code: https://github.com/3093FengMing/VaultPatcher
- Prominence II itself is © its author and is **not** distributed here; players get it from Modrinth.
