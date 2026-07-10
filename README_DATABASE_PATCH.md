# Better Puzzles database preparation patch

This patch prepares the database architecture without changing the existing
screens or widget layout.

## What changes

### Separate ObjectBox models

- `packages/puzzle_catalog_store`
  - large replaceable puzzle catalog;
  - `PuzzleEntity`;
  - `CatalogMetaEntity`;
  - stable theme dictionary and model fingerprint.

- `packages/user_store`
  - persistent user data;
  - settings, progress and runs;
  - no ObjectBox relation to the replaceable catalog.

Because each package owns its own `objectbox-model.json`, changing user
entities does not silently change the catalog model used by the PC builder.

### App storage

```text
ApplicationSupport/
  better_puzzles/
    catalogs/
      installed/
        <catalogId>/
          manifest.json
          objectbox/
            data.mdb
      staging/
      active_catalog.json
    user/
      objectbox/
        data.mdb
```

### `.bpuzzles`

Version 1 is a streaming binary container:

```text
header + manifest JSON + raw ObjectBox data.mdb
```

It is deliberately not a ZIP file. The full Lichess catalog may be several
gigabytes; the custom container can be inspected and extracted without loading
the database into RAM.

See `docs/bpuzzles_format_v1.md`.

## Apply the patch

Extract the patch ZIP into the root of `C:\dev\essentials\better_puzzles` and
allow existing files to be replaced.

Then run:

```powershell
cd C:\dev\essentials\better_puzzles
Set-ExecutionPolicy -Scope Process Bypass
.\tool\setup_database_patch.ps1
```

The script:

1. installs package dependencies;
2. generates the catalog ObjectBox model and code;
3. generates the user ObjectBox model and code;
4. stores the SHA-256 of the catalog model as a shared compatibility value;
5. downloads the matching ObjectBox 5.3.2 native DLL for the PC builder;
6. prepares Flutter dependencies;
7. runs formatting.

The native DLL is downloaded from the matching official ObjectBox C 5.3.2
release into `tools\puzzle_catalog_builder\lib\objectbox.dll`. It is a local
runtime dependency of the Dart PC builder and is ignored by Git.

Commit both generated `objectbox-model.json` files. Never delete or recreate
them after distributing a catalog.

Recommended check:

```powershell
.\tool\test_database_patch.ps1
```

## Install `zstd` on Windows

The builder expects `zstd.exe` either in `PATH` or supplied with `-Zstd`.

With Winget:

```powershell
winget install -e --id Meta.Zstandard
```

Verify:

```powershell
zstd --version
```

## First small test catalog

Use a small `-Limit` first:

```powershell
cd C:\dev\essentials\better_puzzles

.\tool\build_lichess_catalog.ps1 `
  -InputFile "D:\lichess\lichess_db_puzzle.csv.zst" `
  -OutputFile "D:\lichess\lichess_puzzles_test.bpuzzles" `
  -SourceDate "2026-07-05" `
  -Limit 10000 `
  -Overwrite `
  -KeepWork
```

The builder streams `zstd -dc`, validates the CSV header, applies the first UCI
move to the source FEN, checks the remaining sequence for consistent side to
move, occupied source squares and special-move state, and inserts batches into
ObjectBox. It deliberately does not run a chess engine evaluation.

## Full catalog

After the test succeeds:

```powershell
.\tool\build_lichess_catalog.ps1 `
  -InputFile "D:\lichess\lichess_db_puzzle.csv.zst" `
  -OutputFile "D:\lichess\lichess_puzzles_2026_07.bpuzzles" `
  -SourceDate "2026-07-05" `
  -Overwrite
```

Defaults:

- ObjectBox batch size: `10000`;
- rating bucket size: `50`;
- ObjectBox maximum size: `8388608 KB` (8 GiB ceiling);
- invalid rows are written to `<output>.errors.tsv`;
- invalid rows do not stop the build unless `-Strict` is used.

The working ObjectBox directory is deleted after a successful package build
unless `-KeepWork` is supplied.

## App integration prepared by this patch

`PuzzleDatabaseImportService` now supports:

- package inspection before import, including a conservative staging-space estimate;
- format/schema/model compatibility checks;
- streaming extraction into staging;
- SHA-256 verification;
- optional ObjectBox schema and metadata validation;
- activation through `active_catalog.json`;
- cleanup of a failed candidate and rollback to the previous active catalog if opening the new one fails.

`PuzzleCatalogStoreManager` and `UserStoreManager` open different directories
and different generated ObjectBox models.

`ObjectBoxPuzzleCatalogRepository` implements:

- rating range filtering;
- deterministic pivot-based random selection without a huge random offset;
- ascending selection by `(rating, id)`.

It is included but deliberately not wired into the current controller yet.
That wiring should happen together with app startup initialization and the
future file-picker action, not by rebuilding the existing UI.

## Later startup flow

1. Open `UserStoreManager` at `layout.userObjectBox`.
2. Create one long-lived `PuzzleCatalogStoreManager`.
3. Create `PuzzleDatabaseImportService(catalogStoreManager: manager)`.
4. Call `openActiveCatalog()`.
5. If a catalog is active, inject
   `ObjectBoxPuzzleCatalogRepository(storeManager: manager)` into the existing
   `PuzzleAppController`.
6. Keep both stores open for the app session.
7. Close only the catalog store during catalog replacement; user data remains
   open and untouched.

## Theme masks

Version 1 uses two positive 63-bit integers, for 126 stable theme bits. The sign
bit is intentionally unused because ObjectBox stores Dart integers as signed
64-bit values.

Unknown future Lichess themes remain in the original `themes` string and are
counted in the manifest. They can be assigned bits in a future dictionary
version without corrupting version-1 masks.
