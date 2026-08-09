# Storage design

`FileTrialStateStore.production()` resolves the existing per-user application-support directory and uses its `trial_runtime` child.

Files:

- `.initialized`: deterministic initialization sentinel.
- `runtime.dat`: JSON envelope containing a Base64URL payload and SHA-256 integrity marker.

The encoded payload contains version, UTC start, last accepted UTC run, sticky tamper, and sticky expiry. The marker detects casual edits and partial corruption; it is explicitly not commercial cryptographic DRM. A missing state/sentinel pair after initialization fails closed. Writes use flushed temporary files and replacement with rollback backup handling.

The store is outside the Drift database, so schema, business backup, restore, accounting, and owner-wipe contracts are unchanged. The governed installer leaves per-user application data intact on uninstall; 107H owns full reinstall acceptance.
