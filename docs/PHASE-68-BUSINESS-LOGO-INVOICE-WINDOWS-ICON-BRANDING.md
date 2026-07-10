# Phase 68 - Business Logo, Invoice Branding & Windows Icon Tool

## Summary
Added business name and logo branding to the ERP application, enabling the owner to set a company name and upload a logo (PNG/JPEG) that appears on the dashboard and printed invoices.

## Changes

### Business Identity Logo
- `LogoMetadata` model: stores logo file path, SHA-256 hash, MIME type, byte length
- `BusinessIdentity` extended with optional `logo` field
- `LocalBusinessIdentityRepository`: atomic logo storage in `$APPDATA/GrainWarehouseErpLite/logos/` with SHA-256 prefixed filenames
- `BusinessIdentityController`: save/remove logo operations
- Settings UI: logo picker (file_dialog), preview, remove button
- Dashboard AppBar: shows logo when available
- PDF builders: accept and render logo on sales/purchase invoices

### Backup v3 with Logo
- `BackupExportService`: `backupVersion = 3`, includes optional `logo` object with base64-encoded data
- `BackupRestorePreviewService`: `supportedBackupVersions = {1, 2, 3}`
- v1/v2 backup restore continues to work without logo
- Corrupted logo during restore produces warning but does not block data restoration

### Windows ICO Generation Tool
- `tool/create_windows_app_icon.ps1`: PS 5.1 compatible ICO generation from PNG/JPEG source
- Produces multi-size ICO (16/32/48/64/128/256)
- Build-time only tool, not included in delivery package

## Tests
- 40 Phase 68 tests covering logo model, repository storage, controller operations, backup v3, PDF builders, ICO tool, Settings UI scope
- All 586 full suite tests pass
- Flutter analyze: 0 issues

## Tags
- `phase-68-business-logo-invoice-windows-icon-branding` -> commit `601629a`
