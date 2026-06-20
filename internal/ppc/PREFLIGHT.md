# PPC Phase 1 — Pre-flight Checklist

> Claude Code harus run file ini PERTAMA sebelum mengerjakan task apapun.
> Kalau ada item yang FAIL, STOP dan report ke Indra. Jangan lanjut.
> Script check: `bash scripts/preflight.sh`

---

## CHECKLIST

### 🔴 BLOCKER — Harus semua PASS sebelum mulai

| # | Check | Status | Cara Verifikasi |
|---|---|---|---|
| 1 | Oracle: `MGTDAT.PPC_TXT_PRODUCTION` exists | ❌ PENDING | `SELECT COUNT(*) FROM MGTDAT.PPC_TXT_PRODUCTION` |
| 2 | Oracle: `MGTDAT.PPC_SPG_PRODUCTION` exists | ❌ PENDING | `SELECT COUNT(*) FROM MGTDAT.PPC_SPG_PRODUCTION` |
| 3 | Oracle: `MGTDAT.PPC_GRADE_ACTUAL` exists | ❌ PENDING | `SELECT COUNT(*) FROM MGTDAT.PPC_GRADE_ACTUAL` |
| 4 | Oracle: `MGTDAT.MGT_SO_PENDING_WEB` exists | ❌ PENDING | `SELECT COUNT(*) FROM MGTDAT.MGT_SO_PENDING_WEB` |
| 5 | Oracle: `PRC_PPC_TXT_PRODUCTION` procedure exists | ❌ PENDING | `SELECT OBJECT_NAME FROM USER_OBJECTS WHERE OBJECT_NAME='PRC_PPC_TXT_PRODUCTION'` |
| 6 | Oracle: `PRC_PPC_SPG_PRODUCTION` procedure exists | ❌ PENDING | `SELECT OBJECT_NAME FROM USER_OBJECTS WHERE OBJECT_NAME='PRC_PPC_SPG_PRODUCTION'` |
| 7 | Oracle: `PRC_PPC_GRADE_ACTUAL` procedure exists | ❌ PENDING | `SELECT OBJECT_NAME FROM USER_OBJECTS WHERE OBJECT_NAME='PRC_PPC_GRADE_ACTUAL'` |
| 8 | PostgreSQL: connection ok | ❌ PENDING | `pg_isready -h postgres -U goapps -d goapps_dev` |
| 9 | PostgreSQL: database `goapps_dev` exists | ❌ PENDING | `psql -h postgres -U goapps -c "\l"` |
| 10 | Redis: connection ok | ❌ PENDING | `redis-cli -h redis ping` |
| 11 | Go: build ok (no compile errors) | ❌ PENDING | `go build ./...` |
| 12 | PRD files: tersedia di /docs | ❌ PENDING | `ls /docs/goapps/production-plan/12-schema.md` |
| 13 | CLAUDE.md: tersedia di /workspace | ❌ PENDING | `ls /workspace/internal/ppc/CLAUDE.md` |

### 🟡 WARNING — Tidak blocking tapi perlu dicatat

| # | Check | Status | Keterangan |
|---|---|---|---|
| 14 | Oracle: data di PPC_TXT_PRODUCTION > 0 | ⚠️ PENDING | Procedure perlu dirun dulu |
| 15 | golangci-lint: no existing lint errors | ⚠️ PENDING | `golangci-lint run ./...` |
| 16 | Git: working tree clean | ⚠️ PENDING | `git status --porcelain` |
| 17 | Git: up to date dengan origin/main | ⚠️ PENDING | `git fetch && git status` |

---

## STATUS KESELURUHAN

```
BLOCKERS:  0/13 PASS  ← semua harus PASS
WARNINGS:  0/4  PASS  ← ideally semua PASS
READY TO RUN: ❌ NO
```

---

## Cara Update Checklist

Setelah Oracle tables dibuat (next session), update status di atas:
- ❌ PENDING → ✅ PASS (kalau check berhasil)
- ❌ PENDING → ❌ FAIL (kalau check gagal, dengan keterangan error)

---

## Kapan Bisa Mulai?

```
Semua 13 BLOCKER = ✅ PASS → Claude Code boleh mulai eksekusi tasks
Ada 1+ BLOCKER = ❌ FAIL  → STOP, report ke Indra, tunggu fix
```
