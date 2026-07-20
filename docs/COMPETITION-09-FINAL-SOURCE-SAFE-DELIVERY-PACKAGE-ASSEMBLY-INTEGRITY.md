# COMPETITION-09 — Final Source-Safe Delivery Package Assembly and Integrity

## A. Outcome

**Outcome A — GO: Final Source-Safe Package Verified**

The frozen Windows executable and its required runtime were copied without a
build, source and private-data scans passed, the final ZIP was independently
extracted with exact file/hash continuity, and the extracted executable reached
input-idle and remained running and responsive for the full isolated smoke
window. No qualifying package blocker was found.

## B. Frozen baseline

| Item | Observed value |
| --- | --- |
| Branch | `phase9e-expense-analysis-report` |
| Starting HEAD | `6202b33b551f8eacc0015571151306da60f27dcb` |
| Final evidence HEAD before this documentation-only closure commit | `6202b33b551f8eacc0015571151306da60f27dcb` |
| Frozen executable path | `C:\dev\multi-pos\grain-warehouse-erp-lite\build\windows\x64\runner\Release\grain_warehouse_erp_lite.exe` |
| Frozen executable size | `785408` bytes |
| Frozen executable timestamp | `2026-07-20 14:37:19.2700115 +03:00` (`2026-07-20T11:37:19.2700115Z`) |
| Frozen executable SHA-256 | `CC24816F7E88F12C3DAEED322027EC022A0799EBD0E7DF88C15B591968CA7792` |

The source Release file and direct external package copy retained the exact
timestamp. PowerShell ZIP extraction represented the executable timestamp as
`2026-07-20 14:37:18 +03:00` because of ZIP timestamp granularity; size,
content, filename, relative location, and SHA-256 remained exact. The original
frozen file was not changed, replaced, moved, or rebuilt.

## C. Package identity

| Item | Verified value |
| --- | --- |
| External package path | `C:\dev\multi-pos\deliveries\grain-warehouse-erp-lite\competition-final-6202b33-CC24816F\` |
| ZIP path | `C:\dev\multi-pos\deliveries\grain-warehouse-erp-lite\competition-final-6202b33-CC24816F.zip` |
| Package file count | `22` |
| Total uncompressed size | `40346801` bytes |
| ZIP size | `17625858` bytes |
| ZIP SHA-256 | `C0DAD6FA349177CB909CC161198ED4BEFB31A136952959CF58AF290C09DA0820` |
| `PACKAGE-MANIFEST.txt` SHA-256 | `F88A3969B75181C4E2E4404A0DC2F558D01E12EA11F6DF4582477921F9B244A5` |
| `SHA256SUMS.txt` SHA-256 | `1C0F9E1E1BF1CC744BC88ACD6A8ACB7F729C7DC49055C4982179CC4B0028EDEF` |

The ZIP contains exactly one top-level directory named
`competition-final-6202b33-CC24816F`. The final ZIP and checksum-inventory
hashes are recorded here rather than embedded as self-referential values: a ZIP
cannot contain its own final hash, and changing the manifest to embed the
inventory hash would change the manifest hash recorded by that inventory.

## D. Runtime contents

The package contains:

- `grain_warehouse_erp_lite.exe`.
- Six required DLLs: Flutter, PDFium/printing, SQLite runtime/plugin, and URL
  launcher runtime libraries.
- The complete required `data\` tree: AOT application, ICU data, compiled
  Flutter manifests/assets, Arabic and icon fonts, notices, and shader.
- Runtime-required `native_assets.yaml`.
- Recipient-facing `README-AR.txt`, written from the approved Windows,
  first-run, backup/restore, data-wipe, PDF-export, and handoff evidence.
- `PACKAGE-MANIFEST.txt` and `SHA256SUMS.txt`.

No repository document was copied merely because it existed under `docs\`.
Existing owner/client-facing Arabic guidance was used as evidence for the
concise README; no internal phase, governance, developer, or audit record was
added to the recipient package. Link-time `.lib` and `.exp` artifacts were
excluded. Repository evidence identifies `native_assets.yaml` as a required
runtime artifact, so it was retained.

## E. Source-safe audit

| Audit | Final extracted-package result |
| --- | --- |
| Prohibited path/directory scan | Pass: `0` prohibited directories |
| Prohibited extension/file scan | Pass: `0` prohibited files |
| Secret-marker scan | Pass: `0` matches for the required private-key, client-secret, service-account, access/refresh-token, password-assignment, and secret-assignment markers |
| Database and backup scan | Pass: no `.db`, `.sqlite`, `.sqlite3`, `.bak`, or `.backup` data files; `sqlite3.dll` and `sqlite3_flutter_libs_plugin.dll` are required compiled runtime libraries, not databases |
| Source-code scan | Pass: no Dart source, tests, repository metadata, development directory, debug symbol, or link-time artifact |
| `.build-diagnostics/` scan | Pass: absent; the one textual occurrence is the required manifest confirmation that it is excluded |
| Private user-data scan | Pass: no database, backup archive, credentials, environment file, private key/certificate, log, temporary file, screenshot, or user data |
| Runtime repository dependency scan | Pass: no runtime file outside the provenance manifest/checksum files contains the repository path |

All 19 copied runtime files were SHA-256 compared with their Release-source
counterparts before archiving; mismatches were `0`. The executable entry in
`SHA256SUMS.txt` is exactly the frozen hash.

## F. Extraction verification

| Item | Observed result |
| --- | --- |
| Extraction path | `C:\dev\multi-pos\deliveries\grain-warehouse-erp-lite\verification-6202b33-CC24816F\competition-final-6202b33-CC24816F\` |
| Package/extracted file counts | `22` / `22` |
| Package/extracted byte totals | `40346801` / `40346801` |
| Per-file package/extraction hashes | `22` compared, `0` changed |
| `SHA256SUMS.txt` verification | `21` entries checked (every packaged file except `SHA256SUMS.txt` itself), `0` errors |
| Extracted executable SHA-256 | `CC24816F7E88F12C3DAEED322027EC022A0799EBD0E7DF88C15B591968CA7792` |
| Missing/extra result | `0` missing, `0` extra |
| Repeated prohibited/secret scan | Pass, `0` findings |

Validation was performed against the independently extracted final ZIP, not
only against the source package directory.

## G. Smoke launch

| Item | Observed value |
| --- | --- |
| Extracted executable | `C:\dev\multi-pos\deliveries\grain-warehouse-erp-lite\verification-6202b33-CC24816F\competition-final-6202b33-CC24816F\grain_warehouse_erp_lite.exe` |
| Isolated profile | `C:\dev\multi-pos\deliveries\grain-warehouse-erp-lite\smoke-profile-6202b33-CC24816F\` |
| Observation duration | `15` seconds |
| Environment isolation | `APPDATA`, `LOCALAPPDATA`, `USERPROFILE`, `TEMP`, and `TMP` redirected before process start and restored immediately after launch |
| Process behavior | Reached Windows input-idle; remained running and responsive for the full observation; no immediate exit, missing-DLL error, missing-asset error, or other startup/runtime error was observed |
| Exit code | Not applicable; process had not exited |
| Window observation | The automation session exposed no main-window handle/title, so visual Arabic/RTL content was not directly inspected in this phase |
| Termination | `CloseMainWindow` was unavailable without an observable handle; only the recorded smoke process was terminated directly |
| Isolated writes | `0` files; only isolated profile/cache directories were created |
| Real profile | No real profile was supplied to the process; all required profile variables were redirected |
| Cleanup | Environment variables restored and the isolated smoke profile removed; final existence check was `False` |

The same behavior was observed on the finalized extracted candidate before
promotion and once more from the exact final extraction path. Remaining
running, responsive, and input-idle without a startup failure satisfies the
specified package-startup criterion. The unavailable GUI handle and direct
test-process termination are recorded limitations, not hidden as a visual
verification claim.

## H. Repository integrity

| Gate | Observed result |
| --- | --- |
| Initial Git status | `?? .build-diagnostics/` |
| Initial branch / HEAD | `phase9e-expense-analysis-report` / `6202b33b551f8eacc0015571151306da60f27dcb` |
| Initial staged-file list | Empty |
| Pre-document Git status | `?? .build-diagnostics/` |
| Pre-document `git diff --check` | Exit `0`, no output |
| COMPETITION-08 comparison | No diff; unchanged |
| Authorized tracked change | Only `docs/COMPETITION-09-FINAL-SOURCE-SAFE-DELIVERY-PACKAGE-ASSEMBLY-INTEGRITY.md` |
| Expected final staged list before commit | Only the authorized COMPETITION-09 document |
| Expected post-commit status | `?? .build-diagnostics/` only |

No production code, tests, dependencies, schemas, Windows runner files,
generated Release files, permissions, accounting/inventory behavior, backup
contracts, or AI actions changed. `.build-diagnostics/` was never targeted by a
copy, write, stage, cleanup, or packaging command and remained untouched,
untracked, unstaged, and excluded. No tag or push was created.

The closure commit message is
`COMPETITION-09: assemble and verify final delivery package`. Its commit hash
is necessarily reported by the final Git log and operator response because a
commit cannot embed its own hash.

## I. Final operator instruction

The verified ZIP at
`C:\dev\multi-pos\deliveries\grain-warehouse-erp-lite\competition-final-6202b33-CC24816F.zip`
is the approved delivery package. Verify its SHA-256 as
`C0DAD6FA349177CB909CC161198ED4BEFB31A136952959CF58AF290C09DA0820`
before handoff. Do not edit, rebuild, replace, or recompress it. Any such change
requires the entire package verification to be repeated and a new archive hash
and delivery decision to be assigned.
