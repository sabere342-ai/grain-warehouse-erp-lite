# Pilot Action Matrix

Use this matrix only after a real pilot observation has been reviewed and classified. It is a decision guide, not a record of actual issues.

| Type | Action |
|---|---|
| Accounting Bug | Hotfix |
| Inventory Bug | Hotfix or next patch depending on accounting risk |
| Data Integrity Bug | Hotfix |
| UI Bug | Next patch |
| Report Bug | Hotfix if accounting is misleading; otherwise next patch |
| Backup/Restore Bug | Hotfix if data safety is affected |
| Installation Issue | Support note or next patch depending on reproducibility |
| Environment Issue | Environment guidance |
| Performance Issue | Investigate and schedule if reproducible |
| Training | Update guide or training note |
| Documentation | Update documentation |
| Configuration | Correct configuration or clarify setup |
| Feature Request | Backlog |
| Unsupported Usage | No production change; document usage rule if needed |
| Known Limitation | Won't Fix unless scope changes |
| Not Reproducible | Keep open only if risk justifies more investigation |
| Insufficient Evidence | Request more details |

## Decision Rules
- Accounting bugs block release until resolved or ruled out.
- Data integrity bugs block release until resolved or ruled out.
- Training does not require production code change.
- Documentation issues should be fixed in documentation only.
- Feature requests must not be mixed with bug fixes.
- Unsupported usage should not become a bug unless the product made the unsupported action appear safe.
- Won't Fix requires a documented reason.
- Backlog items require owner or project approval before implementation.
