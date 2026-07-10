# `.bpuzzles` format version 1

The file is a streaming container, not a ZIP archive. This avoids loading or
recompressing a multi-gigabyte ObjectBox database in memory.

All integer fields use little-endian byte order.

| Offset | Length | Meaning |
|---:|---:|---|
| 0 | 8 | ASCII magic `BPZPKG1\n` |
| 8 | 4 | UTF-8 manifest length (`uint32`) |
| 12 | 8 | ObjectBox database length (`uint64`) |
| 20 | variable | UTF-8 `manifest.json` |
| next | variable | raw ObjectBox `data.mdb` |

No trailing bytes are allowed in version 1.

The manifest includes:

- package format and catalog schema versions;
- stable catalog ID and display name;
- source filename/date/SHA-256 and CC0 license marker;
- ObjectBox model fingerprint;
- `data.mdb` SHA-256, byte size and required `maxDBSizeInKB`;
- puzzle counts and rating range;
- rating bucket configuration;
- versioned 126-bit theme dictionary.

The app reads only the small header and manifest during inspection. During
import, it streams the database section into a staging directory, hashes the
result, opens it once for ObjectBox schema/meta validation, then activates it by
changing `active_catalog.json`.
