# PPC Phase 1 — Task Queue for Claude Code

> **PENTING:** Jalankan `bash scripts/preflight.sh` DULU sebelum mulai.
> Kalau ada BLOCKER yang FAIL, STOP dan jangan kerjakan task apapun.
>
> Setelah task selesai:
> 1. Update status di file ini: [TODO] → [DONE]
> 2. Commit dengan pesan yang jelas
> 3. Update status ClickUp task ke DONE
>
> ClickUp List Phase 1 ID: 901818891955
> Refer ke: /docs/goapps/production-plan/ untuk semua keputusan desain

---

## PROGRESS

```
[DONE] 0 / 18 tasks
```

---

## GROUP 1 — Infrastructure & Setup

### [TODO] T001 — PostgreSQL Migrations: Core Tables

**ClickUp task:** cari di list Phase 1 dengan judul "Database Migrations"
**Refer ke:** `/docs/goapps/production-plan/12-schema.md`

Buat migration files untuk semua tabel PPC core:
```
migrations/ppc/
  000001_create_sales_order_staging.up.sql
  000001_create_sales_order_staging.down.sql
  000002_create_production_demand.up.sql
  000002_create_production_demand.down.sql
  000003_create_production_plan_item.up.sql
  000003_create_production_plan_item.down.sql
  000004_create_work_order_tables.up.sql     ← WO + WO_PARAMETER + WO_EXECUTION
  000004_create_work_order_tables.down.sql
  000005_create_wo_production_actual.up.sql
  000005_create_wo_production_actual.down.sql
  000006_create_wo_grade_actual.up.sql
  000006_create_wo_grade_actual.down.sql
  000007_create_master_tables.up.sql         ← LOT_MASTER + MACHINE_MASTER + MACHINE_GROUP
  000007_create_master_tables.down.sql
  000008_create_config_tables.up.sql         ← PRODUCT_PPC_CONFIG + OVERRUN_THRESHOLD_CONFIG
  000008_create_config_tables.down.sql
  000009_create_changeover_tables.up.sql
  000009_create_changeover_tables.down.sql
```

**⚠️ Catatan penting dari schema:**
- `wo_production_actual`: UNIQUE (wpa_wo_id, wpa_date, wpa_shift)
- `wo_grade_actual`: UNIQUE (wga_wo_id, wga_lot_no, wga_grade)
- `wo_plan_item_link`: UNIQUE (wpl_wo_id, wpl_plan_item_id)
- TRN_STS TXT/TWT: 0=Full, 1=Unfull — catat di comment kolom

**Acceptance criteria:**
- [ ] Semua migration file dibuat sesuai schema di 12-schema.md
- [ ] `migrate up` berhasil tanpa error
- [ ] `migrate down` berhasil rollback
- [ ] Semua constraint dan index sesuai schema

---

### [TODO] T002 — PPC Service Structure Setup

**Refer ke:** `/workspace/internal/ppc/CLAUDE.md` section Architecture Pattern

Buat struktur folder Clean Architecture untuk PPC service:
```
internal/ppc/
  domain/
    entity/          ← WorkOrder, ProductionDemand, PlanItem, dll
    repository/      ← interface definitions
    valueobject/     ← status enums, area codes, dll
  application/
    usecase/         ← CreateWO, UpdateDemand, ETLSync, dll
    dto/             ← request/response DTOs
  infrastructure/
    postgres/        ← repository implementations
    oracle/          ← ETL Oracle client
    grpc/            ← gRPC server implementation
  delivery/
    grpc/            ← gRPC handlers
    rest/            ← REST gateway handlers
```

**Acceptance criteria:**
- [ ] Folder structure sesuai Clean Architecture pattern
- [ ] `go build ./internal/ppc/...` berhasil
- [ ] Ikuti pattern yang ada di `internal/finance/`

---

### [TODO] T003 — Proto Definition: PPC Service

**Refer ke:** `/docs/goapps/production-plan/05-layer3-work-order.md`

Buat proto file:
```
proto/ppc/v1/
  ppc.proto           ← service definition
  demand.proto        ← ProductionDemand messages
  plan_item.proto     ← PlanItem messages
  work_order.proto    ← WorkOrder messages
  master.proto        ← LotMaster, MachineMaster messages
```

**Acceptance criteria:**
- [ ] Proto sesuai dengan schema di PRD
- [ ] `protoc` generate berhasil tanpa error
- [ ] gRPC service methods sesuai use cases Layer 1, 2, 3

---

## GROUP 2 — ETL Oracle → PostgreSQL

### [TODO] T004 — Oracle ETL Client

**Refer ke:** `/docs/goapps/production-plan/08-integrasi-etl.md`
**⚠️ Blocker:** Oracle summary tables harus sudah ada (T001 Oracle, bukan PostgreSQL)

Buat Oracle ETL client:
```
internal/ppc/infrastructure/oracle/
  client.go           ← Oracle connection via go-oracle driver
  watermark.go        ← simpan/baca last ETL run timestamp di PostgreSQL
  etl_txt.go          ← SELECT dari PPC_TXT_PRODUCTION WHERE LAST_UPDATED > watermark
  etl_spg.go          ← SELECT dari PPC_SPG_PRODUCTION (Phase 2, stub dulu)
  etl_grade.go        ← SELECT dari PPC_GRADE_ACTUAL (Phase 3, stub dulu)
  etl_so.go           ← SELECT dari MGT_SO_PENDING_WEB (full replace)
```

**⚠️ TRN_STS TXT/TWT: 0=Full, 1=Unfull (KEBALIKAN dari SPG)**

**Acceptance criteria:**
- [ ] Koneksi Oracle berhasil (pakai ORACLE_DSN dari env)
- [ ] Watermark tersimpan di PostgreSQL tabel `etl_watermark`
- [ ] Query incremental: `WHERE LAST_UPDATED > :watermark`
- [ ] Error handling: kalau Oracle tidak bisa diconnect, log warning tapi tidak crash

---

### [TODO] T005 — ETL Worker: TXT/TWT Production

**Refer ke:** `/docs/goapps/production-plan/08-integrasi-etl.md` section 8.3
**⚠️ Blocker:** T004 harus selesai, Oracle PPC_TXT_PRODUCTION harus ada data

Buat ETL worker untuk TXT/TWT:
```
internal/ppc/infrastructure/oracle/worker/
  txt_worker.go       ← periodic ETL dari PPC_TXT_PRODUCTION
```

**Logic:**
```
1. SELECT dari MGTDAT.PPC_TXT_PRODUCTION WHERE LAST_UPDATED > watermark
2. Untuk setiap row: match ke WO berdasarkan lot_no + machine_no
3. UPSERT ke wo_production_actual by (wo_id, wpa_date, wpa_shift)
4. wpa_qty_source = 'ETL_SUGGEST'
5. Kalkulasi wpa_calculated_qty_kg:
   (full_bobbins × lm_std_weight_full) + (unfull_bobbins × lm_std_weight_unfull)
6. Update watermark
```

**Acceptance criteria:**
- [ ] Worker jalan setiap ETL_INTERVAL_MINUTES
- [ ] UPSERT benar — tidak duplicate, update kalau sudah ada
- [ ] Kalkulasi qty benar (0=Full, 1=Unfull)
- [ ] Unit test dengan mock Oracle data

---

### [TODO] T006 — ETL Worker: SO Orion Staging

**Refer ke:** `/docs/goapps/production-plan/08-integrasi-etl.md` section 8.2

Buat ETL worker untuk SO Orion:
```
internal/ppc/infrastructure/oracle/worker/
  so_worker.go        ← periodic ETL dari MGT_SO_PENDING_WEB
```

**Logic:**
```
1. SELECT semua dari MGTDAT.MGT_SO_PENDING_WEB
2. TRUNCATE sales_order_staging di PostgreSQL
3. INSERT semua rows
4. Mode: full replace setiap run
```

**Acceptance criteria:**
- [ ] Full replace berjalan benar
- [ ] Field mapping sesuai 08-integrasi-etl.md tabel mapping
- [ ] sos_pulled_to_demand_id dipreserve (tidak di-reset saat full replace)

---

## GROUP 3 — Layer 1: Production Demand

### [TODO] T007 — Repository: ProductionDemand + SalesOrderStaging

**Refer ke:** `/docs/goapps/production-plan/03-layer1-demand.md`

```
internal/ppc/
  domain/repository/
    demand_repository.go        ← interface
    so_staging_repository.go    ← interface
  infrastructure/postgres/
    demand_repository.go        ← pgx implementation
    so_staging_repository.go    ← pgx implementation
```

**Acceptance criteria:**
- [ ] CRUD lengkap untuk production_demand
- [ ] Query: list by month, filter by status, filter by customer
- [ ] Query: list SO staging yang belum di-pull (sos_pulled_to_demand_id IS NULL)
- [ ] Table-driven tests

---

### [TODO] T008 — Use Case: Demand Management

**Refer ke:** `/docs/goapps/production-plan/03-layer1-demand.md`

```
internal/ppc/application/usecase/
  create_demand.go          ← pull from SO staging atau manual input
  carry_forward.go          ← 5 aksi: CARRY_AS_IS, SPLIT, DEFER, PARTIAL_CARRY, CANCEL
  update_demand_status.go   ← update pd_qty_remaining dari WO actual
```

**Acceptance criteria:**
- [ ] Pull from Orion: mark sos_pulled_to_demand_id setelah di-pull
- [ ] Carry-forward: validasi SUM(qty baru) ≤ pd_qty_remaining untuk SPLIT
- [ ] Unit tests untuk semua use cases

---

## GROUP 4 — Layer 2: Production Plan Item

### [TODO] T009 — Repository + Use Case: PlanItem

**Refer ke:** `/docs/goapps/production-plan/04-layer2-plan-item.md`

```
internal/ppc/
  domain/repository/plan_item_repository.go
  infrastructure/postgres/plan_item_repository.go
  application/usecase/
    create_plan_item.go     ← buat plan item + cascade intermediate
    update_plan_item.go
```

**Acceptance criteria:**
- [ ] Constraint: ppi_demand_id OR ppi_parent_item_id harus diisi
- [ ] Cascade create intermediate plan item saat FG plan dibuat
- [ ] Plan log dicatat setiap perubahan

---

## GROUP 5 — Layer 3: Work Order

### [TODO] T010 — Repository: WorkOrder

**Refer ke:** `/docs/goapps/production-plan/05-layer3-work-order.md`

```
internal/ppc/
  domain/repository/wo_repository.go
  infrastructure/postgres/wo_repository.go
```

**Acceptance criteria:**
- [ ] CRUD wo, wo_parameter, wo_execution, wo_production_actual, wo_grade_actual
- [ ] Query: list WO by status, by machine, by lot
- [ ] Query: wo_production_actual by (wo_id, date, shift)

---

### [TODO] T011 — Use Case: WO Lifecycle

**Refer ke:** `/docs/goapps/production-plan/05-layer3-work-order.md`

```
internal/ppc/application/usecase/
  create_wo.go            ← generate WO dari plan item
  submit_wo.go            ← submit → trigger approval
  approve_wo.go           ← PC approve parameter, PM approve overall
  auto_approve_worker.go  ← background worker: auto-approve setelah 4 jam
```

**Acceptance criteria:**
- [ ] Dual approval: PC dan PM paralel
- [ ] Auto-approve setelah 4 jam (background goroutine)
- [ ] WO status machine sesuai lifecycle di PRD
- [ ] Revision: wo_ref_id + wo_revision_no

---

### [TODO] T012 — Use Case: WO Production Actual Suggest

**Refer ke:** `/docs/goapps/production-plan/05-layer3-work-order.md` section Suggest Logic

```
internal/ppc/application/usecase/
  suggest_wo_actual.go    ← suggest qty berdasarkan priority chain
  override_wo_actual.go   ← manual override dengan reason
```

**Priority chain:**
```
P1: wo_grade_actual ada → qty dari packing
P2: normal_bobs dari ETL TXT → QC released
P3: transferred_bobs dari ETL SPG (Phase 2)
P4: total_bobbins dari ETL TXT
P5: SPG doff estimate (Phase 2)
```

**Acceptance criteria:**
- [ ] Suggest logic priority chain benar
- [ ] Override menyimpan reason di wpa_manual_reason
- [ ] Log setiap perubahan di wo_actual_log

---

### [TODO] T013 — Use Case: RM Allocation

**Refer ke:** `/docs/goapps/production-plan/05-layer3-work-order.md` section RM Allocation

```
internal/ppc/application/usecase/
  set_rm_allocation.go    ← PPC input RM manual per WO
  check_rm_fence.go       ← warning/block kalau melebihi alokasi
```

**Acceptance criteria:**
- [ ] Multiple RM baris per WO
- [ ] Warning threshold 85%
- [ ] Block + PM approval untuk override

---

## GROUP 6 — gRPC Service

### [TODO] T014 — gRPC Handler: PPC Service

```
internal/ppc/delivery/grpc/
  ppc_handler.go          ← implement semua RPC methods
  interceptor.go          ← auth interceptor (IAM integration)
```

**Acceptance criteria:**
- [ ] Semua RPC methods dari proto terbuat
- [ ] IAM integration: check role PPC/PC/PM/Marketing per endpoint
- [ ] Error handling sesuai gRPC status codes

---

### [TODO] T015 — gRPC Gateway: REST API

```
internal/ppc/delivery/rest/
  gateway.go              ← register REST endpoints
```

**Acceptance criteria:**
- [ ] REST endpoints bisa diakses via HTTP
- [ ] OpenAPI spec ter-generate

---

## GROUP 7 — Dashboard & Monitoring

### [TODO] T016 — Use Case: Morning Review Data

**Refer ke:** `/docs/goapps/production-plan/10-balance-for-sale.md`

```
internal/ppc/application/usecase/
  morning_review.go       ← actual vs plan kemarin per mesin
  balance_for_sale.go     ← kalkulasi BFS untuk commodity products
```

**Acceptance criteria:**
- [ ] Morning review: actual vs target per mesin per shift
- [ ] BFS formula: stok + running + MTS - committed

---

## GROUP 8 — Testing & Quality

### [TODO] T017 — Integration Tests

```
internal/ppc/test/
  integration/
    etl_test.go           ← test ETL flow end-to-end
    demand_test.go        ← test demand lifecycle
    wo_test.go            ← test WO lifecycle + approval
```

**Acceptance criteria:**
- [ ] Test pakai PostgreSQL test container
- [ ] Mock Oracle dengan data sample dari ETL Spec
- [ ] Coverage > 70% untuk use cases

---

### [TODO] T018 — golangci-lint Clean

```
Pastikan semua code PPC bersih dari lint errors:
golangci-lint run ./internal/ppc/...
```

**Acceptance criteria:**
- [ ] 0 lint errors
- [ ] 0 lint warnings yang kritikal
- [ ] Ikuti golangci-lint config yang sudah ada di repo

---

## COMPLETION CRITERIA PHASE 1

Semua task [DONE] + semua tests passing + lint clean = Phase 1 selesai.
Setelah itu: update ClickUp semua tasks ke DONE, buat PR ke main branch.
