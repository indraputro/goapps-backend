# Dev Environment Setup — goapps-backend

## Prerequisites di Windows 11

- Docker Desktop (sudah ada)
- Git (sudah ada)
- VS Code (opsional tapi recommended)

---

## Setup

### 1. Build image

```powershell
cd "D:\IT Project\goapps-backend"
docker build -t goapps-dev -f Dockerfile.dev .
```

Build pertama kali ~5-10 menit (download Go tools dan protoc).

### 2. Jalankan semua services

```powershell
docker compose -f docker-compose.dev.yml up -d
```

Services yang jalan:
- `goapps-dev` — main dev container (Go + Claude Code)
- `goapps-postgres` — PostgreSQL 18 di port 5432
- `goapps-redis` — Redis 7 di port 6379

### 3. Masuk ke container

```powershell
docker compose -f docker-compose.dev.yml exec app bash
```

### 4. Login Claude Code (sekali saja, tersimpan di volume)

```bash
# Di dalam container
claude login
```

Browser akan terbuka di Windows untuk auth. Setelah login, config tersimpan
di Docker volume `goapps-claude-config` — tidak perlu login lagi meski container di-restart.

### 5. Mulai Claude Code

```bash
# Di dalam container, di /workspace
claude

# Atau langsung dengan task
claude "baca CLAUDE.md dan bantu saya setup PPC service"
```

---

## Oracle Instant Client

Oracle Instant Client tidak bisa di-download otomatis (perlu Oracle account).

**Opsi A — Mount dari host (recommended jika sudah install):**

Edit `docker-compose.dev.yml`, uncomment bagian ini:
```yaml
- type: bind
  source: C:/oracle/instantclient_21_10
  target: /opt/oracle/instantclient_21_10
  read_only: true
```

Sesuaikan path `source` dengan lokasi Instant Client di Windows Anda.

**Opsi B — Copy ke dalam image:**

```dockerfile
# Tambah di Dockerfile.dev setelah baris Oracle section
COPY oracle/instantclient_21_10/ /opt/oracle/instantclient_21_10/
```

Lalu taruh folder Instant Client di `oracle/` dalam repo (add ke .gitignore).

**Verifikasi Oracle:**
```bash
# Di dalam container
ls /opt/oracle/instantclient_21_10/
# Harus ada: libclntsh.so, libnnz21.so, dll

# Test koneksi Oracle
# (setelah Go app di-run)
```

---

## tnsnames.ora

File ini perlu ada di `/etc/oracle/tnsnames.ora` di dalam container.

```bash
# Di dalam container
cat > /etc/oracle/tnsnames.ora << 'EOF'
ALTHARA =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 192.168.0.7)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = althara)
    )
  )
EOF
```

Atau mount dari host:
```yaml
# Tambah di volumes docker-compose.dev.yml
- type: bind
  source: ./config/tnsnames.ora
  target: /etc/oracle/tnsnames.ora
  read_only: true
```

---

## Database Migration

```bash
# Di dalam container
cd /workspace

# Jalankan semua migration PPC
migrate -path migrations/ppc \
        -database "postgres://goapps:goapps_dev@postgres:5432/goapps_dev?sslmode=disable" \
        up

# Rollback 1 step
migrate -path migrations/ppc \
        -database "postgres://goapps:goapps_dev@postgres:5432/goapps_dev?sslmode=disable" \
        down 1
```

---

## Generate Proto

```bash
# Di dalam container
cd /workspace

# Generate dari shared proto
./scripts/gen-proto.sh

# Atau manual
protoc --go_out=. --go_opt=paths=source_relative \
       --go-grpc_out=. --go-grpc_opt=paths=source_relative \
       --grpc-gateway_out=. --grpc-gateway_opt=paths=source_relative \
       proto/ppc/v1/ppc.proto
```

---

## Run Tests

```bash
# Di dalam container
cd /workspace

# Semua tests
gotestsum ./...

# Hanya PPC
gotestsum ./internal/ppc/...

# Dengan coverage
go test -coverprofile=coverage.out ./internal/ppc/...
go tool cover -html=coverage.out
```

---

## Lint

```bash
# Di dalam container
cd /workspace

golangci-lint run ./internal/ppc/...
```

---

## Jaeger (Tracing UI)

```powershell
# Jalankan dengan profile tracing
docker compose -f docker-compose.dev.yml --profile tracing up -d jaeger
```

Buka http://localhost:16686 di browser Windows.

---

## Useful Commands

```bash
# Lihat semua containers
docker compose -f docker-compose.dev.yml ps

# Stop semua
docker compose -f docker-compose.dev.yml down

# Stop + hapus volume (reset DB)
docker compose -f docker-compose.dev.yml down -v

# Rebuild image (setelah update Dockerfile.dev)
docker compose -f docker-compose.dev.yml build --no-cache app

# Lihat logs
docker compose -f docker-compose.dev.yml logs -f app
```

---

## Connect dari Windows

- **PostgreSQL:** `localhost:5432` user: `goapps` password: `goapps_dev` db: `goapps_dev`
- **gRPC:** `localhost:50051`
- **REST:** `http://localhost:8080`
- **Jaeger UI:** `http://localhost:16686`

Tools Windows yang bisa connect langsung:
- DBeaver / pgAdmin → PostgreSQL
- Postman / grpcurl → gRPC + REST
- Browser → Jaeger UI
