# CLAUDE.md — PPC Production Planning System (Phase 1)

> Context file untuk Claude Code. Baca ini sebelum mengerjakan task apapun di service PPC.
> Letakkan di: `goapps-backend/internal/ppc/CLAUDE.md`

---

## Project Context

**Service:** PPC Production Planning System
**Repo upstream:** `mutugading/goapps-backend`
**Repo fork:** `[personal-github]/goapps-backend`
**Phase:** 1 — Foundation + TXT (Bulan 1–4)
**Stack:** Go 1.24, PostgreSQL 18, gRPC + gRPC-Gateway

**PRD:** `docs-markdown/goapps/production-plan/` (GitHub: mutugading/docs-markdown)
**ETL Spec:** ClickUp Doc `2kzmeddw-2758`
**Design Decisions:** ClickUp Doc `2kzmeddw-2138`

---

## Git Workflow — Fork & Pull Request

```
Repo lokal clone dari fork personal:
  origin   → [personal-github]/goapps-backend  (push ke sini)
  upstream → mutugading/goapps-backend          (pull dari sini)

Sebelum mulai task baru — sync fork dengan upstream:
  git fetch upstream
  git checkout main
  git merge upstream/main
  git push origin main

Buat branch per task/feature:
  git checkout -b feature/ppc-[nama-task]

Setelah selesai → push ke fork + buat PR:
  git push origin feature/ppc-[nama-task]
  → Pull Request: [personal]/feature/ppc-[nama] → mutugading/main

JANGAN push langsung ke mutugading/main.
```

**Branch naming convention:**
```
feature/ppc-[nama]    → fitur baru PPC
fix/ppc-[nama]        → bug fix PPC
refactor/ppc-[nama]   → refactor
docs/ppc-[nama]       → dokumentasi
chore/[nama]          → setup, tooling
```

---

## Architecture Pattern (WAJIB IKUTI)

```
Clean Architecture + DDD:
  domain/        → entities, value objects, repository interfaces
  application/   → use cases, DTOs
  infrastructure/→ PostgreSQL impl, Oracle ETL client, gRPC server
  delivery/      → gRPC handlers, REST gateway handlers
```

Ikuti pattern yang sudah ada di `internal/finance/` dan `internal/iam/`.

---

## Database

**PostgreSQL 18** via `pgx/v5`

Prefix kolom sesuai tabel:
- `production_demand`      → prefix `pd_`
- `production_plan_item`   → prefix `ppi_`
- `work_order`             → prefix `wo_`
- `wo_parameter`           → prefix `wop_`
- `wo_execution`           → prefix `woe_`
- `wo_production_actual`   → prefix `wpa_`
- `wo_grade_actual`        → prefix `wga_`
- `sales_order_staging`    → prefix `sos_`
- `lot_master`             → prefix `lm_`
- `machine_master`         → prefix `machine_`

**Migration:** pakai `golang-migrate`. File di `migrations/ppc/`.
Cek nomor terakhir sebelum buat: `ls migrations/ | sort | tail -3`

---

## Oracle ETL

**Pattern:** Oracle summary tables → ETL Go → PostgreSQL UPSERT

Oracle summary tables di `MGTDAT` schema:
- `PPC_TXT_PRODUCTION`  — TXT/TWT bobbin production, watermark: `LAST_UPDATED`
- `PPC_SPG_PRODUCTION`  — SPG production + TQM (Phase 2)
- `PPC_GRADE_ACTUAL`    — packing grade per lot (Phase 3)
- `MGT_SO_PENDING_WEB`  — SO Orion staging, full replace

**⚠️ KRITIS — TRN_STS TXT/TWT:**
```
TRN_STS = 0 → FULL bobbin   (bukan 1)
TRN_STS = 1 → UNFULL bobbin (bukan 0)
Ini KEBALIKAN dari SPG DOFF_OPTION (1=Full, 2=Unfull)
```

---

## Phase 1 Scope — Yang Dikerjakan

- Infrastructure setup (migrations, service structure, proto)
- ETL TXT/TWT dari `PPC_TXT_PRODUCTION`
- ETL SO Orion dari `MGT_SO_PENDING_WEB`
- Layer 1: Production Demand
- Layer 2: Plan Item TXT
- Layer 3: Work Order TXT + dual approval
- Dashboard morning review

**Phase 1 TIDAK include:**
SPG/TWT integration, packing sync, BOM Phase B, changeover

---

## Suggest Logic Priority (WO_PRODUCTION_ACTUAL)

```
P1: wo_grade_actual ada (packing selesai)
P2: wpa_normal_bobs dari ETL TXT (QC released)
P3: wpa_transferred_bobs dari ETL SPG (Phase 2)
P4: wpa_total_bobbins dari ETL TXT (semua transferred)
P5: SPG doff estimate (Phase 2)

Kalkulasi qty TXT/TWT:
  full_bobbins (TRN_STS=0) * lm_std_weight_full
  + unfull_bobbins (TRN_STS=1) * lm_std_weight_unfull
```

---

## Coding Standards

- golangci-lint v2 — 0 lint errors wajib
- Table-driven tests dengan testify
- Error wrapping: `fmt.Errorf("ppc.CreateWO: %w", err)`
- Context propagation di semua function
- Tidak ada hardcoded config — semua di `config/`

---

## Task Tracking

ClickUp: Space **IT Project** → Folder **PPC — Production Planning System**
- List: `🏗️ Phase 1 — Foundation + TXT` (ID: `901818891955`)
- Update status task setelah selesai mengerjakan setiap task

---

## References

| Dokumen | Lokasi |
|---|---|
| PRD Lengkap | `/docs/goapps/production-plan/` (mount di container) |
| Oracle DDL | `/docs/goapps/production-plan/oracle/PPC_ORACLE_DDL.sql` |
| Oracle Procedures | `/docs/goapps/production-plan/oracle/PPC_ORACLE_PROCEDURES.sql` |
| ETL Spec | ClickUp `2kzmeddw-2758` |
| Design Decisions | ClickUp `2kzmeddw-2138` |
| Schema Lengkap | `/docs/goapps/production-plan/12-schema.md` |
| TASKS.md | `/workspace/internal/ppc/TASKS.md` |
| PREFLIGHT.md | `/workspace/internal/ppc/PREFLIGHT.md` |
