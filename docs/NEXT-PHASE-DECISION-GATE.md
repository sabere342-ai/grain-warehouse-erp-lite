# Next Phase Decision Gate

Use this gate before opening any new phase. Do not start a new implementation phase without real evidence.

| Evidence                      | Next Phase                                   |
| ----------------------------- | -------------------------------------------- |
| No customer feedback          | Stay frozen / continue observation           |
| Customer accepted pilot       | First delivery confirmation                  |
| Blocker bug recorded          | Dedicated blocker fix phase                  |
| Non-blocking bugs recorded    | Non-blocking bug batch phase                 |
| Documentation confusion only  | Documentation clarification phase            |
| Feature requests only         | Future backlog planning                      |
| Backup/restore issue recorded | Dedicated backup/restore investigation phase |

## Rules

- Do not start a code phase without evidence.
- Do not treat feature requests as bugs.
- Do not fix from memory or assumptions.
- Always require backup before troubleshooting.
- Keep generated outputs ignored.
- Use `docs/PILOT-ISSUE-LOG.md` for actual customer issues only.
