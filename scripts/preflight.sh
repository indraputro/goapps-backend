#!/bin/bash
# =============================================================================
# preflight.sh — PPC Phase 1 Pre-flight Check
# Jalankan sebelum Claude Code autonomous session
# Usage: bash scripts/preflight.sh
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0; FAIL=0; WARN=0

pass() { echo -e "${GREEN}✅ PASS${NC} — $1"; ((PASS++)); }
fail() { echo -e "${RED}❌ FAIL${NC} — $1"; ((FAIL++)); }
warn() { echo -e "${YELLOW}⚠️  WARN${NC} — $1"; ((WARN++)); }
info() { echo -e "${BLUE}ℹ️  INFO${NC} — $1"; }

echo ""
echo "================================================"
echo "  PPC Phase 1 — Pre-flight Check"
echo "================================================"
echo ""

# ─────────────────────────────────────────────
# GIT CHECKS
# ─────────────────────────────────────────────
echo "🔵 GIT CHECKS"
echo "─────────────────────────────────────────"

# Cek bukan di main
CURRENT_BRANCH=$(git -C /workspace branch --show-current 2>/dev/null)
if [ "$CURRENT_BRANCH" = "main" ]; then
    fail "Di branch main — buat branch baru dulu: git checkout -b feature/ppc-[nama]"
else
    pass "Branch aktif: $CURRENT_BRANCH"
fi

# Cek remote upstream ada
if git -C /workspace remote get-url upstream &>/dev/null; then
    UPSTREAM=$(git -C /workspace remote get-url upstream)
    pass "Upstream: $UPSTREAM"
else
    warn "Remote upstream belum di-set. Jalankan: git remote add upstream https://github.com/mutugading/goapps-backend.git"
fi

echo ""

# ─────────────────────────────────────────────
# BLOCKER CHECKS
# ─────────────────────────────────────────────
echo "🔴 BLOCKER CHECKS"
echo "─────────────────────────────────────────"

# PostgreSQL connection
if pg_isready -h "${DB_HOST:-postgres}" -U "${DB_USER:-goapps}" -d "${DB_NAME:-goapps_dev}" -q 2>/dev/null; then
    pass "PostgreSQL connection ok (${DB_HOST:-postgres}:${DB_PORT:-5432})"
else
    fail "PostgreSQL tidak bisa diconnect — cek DB_HOST, DB_USER, DB_NAME"
fi

# Redis connection
if redis-cli -h "${REDIS_HOST:-redis}" -p "${REDIS_PORT:-6379}" ping 2>/dev/null | grep -q "PONG"; then
    pass "Redis connection ok (${REDIS_HOST:-redis}:${REDIS_PORT:-6379})"
else
    fail "Redis tidak bisa diconnect — cek REDIS_HOST, REDIS_PORT"
fi

# PRD files tersedia
if [ -f "/docs/goapps/production-plan/12-schema.md" ]; then
    pass "PRD files tersedia di /docs/goapps/production-plan/"
else
    fail "PRD files tidak ditemukan — cek volume mount docs-markdown"
fi

# CLAUDE.md tersedia
if [ -f "/workspace/internal/ppc/CLAUDE.md" ]; then
    pass "CLAUDE.md tersedia"
else
    fail "CLAUDE.md tidak ditemukan — copy ke internal/ppc/CLAUDE.md"
fi

# TASKS.md tersedia
if [ -f "/workspace/internal/ppc/TASKS.md" ]; then
    pass "TASKS.md tersedia"
else
    fail "TASKS.md tidak ditemukan — copy ke internal/ppc/TASKS.md"
fi

# Go build
echo -n "  Checking go build... "
if cd /workspace && go build ./... 2>/dev/null; then
    pass "go build ./... OK"
else
    fail "go build gagal — ada compile error"
fi

# Oracle tables check (via sqlplus kalau tersedia)
echo ""
info "Oracle checks (skip kalau sqlplus tidak tersedia)..."
if command -v sqlplus &>/dev/null && [ -n "${ORACLE_DSN}" ]; then
    ORACLE_CHECK=$(sqlplus -S "${ORACLE_DSN}" << 'SQLEOF'
SET HEADING OFF FEEDBACK OFF PAGESIZE 0
SELECT 'PPC_TXT_PRODUCTION:' || CASE WHEN COUNT(*)>0 THEN 'EXISTS' ELSE 'MISSING' END FROM ALL_TABLES WHERE TABLE_NAME='PPC_TXT_PRODUCTION' AND OWNER='MGTDAT';
SELECT 'PPC_SPG_PRODUCTION:' || CASE WHEN COUNT(*)>0 THEN 'EXISTS' ELSE 'MISSING' END FROM ALL_TABLES WHERE TABLE_NAME='PPC_SPG_PRODUCTION' AND OWNER='MGTDAT';
SELECT 'PPC_GRADE_ACTUAL:' || CASE WHEN COUNT(*)>0 THEN 'EXISTS' ELSE 'MISSING' END FROM ALL_TABLES WHERE TABLE_NAME='PPC_GRADE_ACTUAL' AND OWNER='MGTDAT';
SELECT 'MGT_SO_PENDING_WEB:' || CASE WHEN COUNT(*)>0 THEN 'EXISTS' ELSE 'MISSING' END FROM ALL_TABLES WHERE TABLE_NAME='MGT_SO_PENDING_WEB' AND OWNER='MGTDAT';
SELECT 'PRC_TXT_PROD:' || CASE WHEN COUNT(*)>0 THEN 'EXISTS' ELSE 'MISSING' END FROM ALL_OBJECTS WHERE OBJECT_NAME='PRC_PPC_TXT_PRODUCTION' AND OWNER='MGTDAT';
SELECT 'PRC_SPG_PROD:' || CASE WHEN COUNT(*)>0 THEN 'EXISTS' ELSE 'MISSING' END FROM ALL_OBJECTS WHERE OBJECT_NAME='PRC_PPC_SPG_PRODUCTION' AND OWNER='MGTDAT';
SELECT 'PRC_GRADE:' || CASE WHEN COUNT(*)>0 THEN 'EXISTS' ELSE 'MISSING' END FROM ALL_OBJECTS WHERE OBJECT_NAME='PRC_PPC_GRADE_ACTUAL' AND OWNER='MGTDAT';
EXIT;
SQLEOF
)
    for ITEM in PPC_TXT_PRODUCTION PPC_SPG_PRODUCTION PPC_GRADE_ACTUAL MGT_SO_PENDING_WEB; do
        if echo "$ORACLE_CHECK" | grep -q "${ITEM}:EXISTS"; then
            pass "Oracle: ${ITEM} exists"
        else
            fail "Oracle: ${ITEM} TIDAK ADA — run PPC_ORACLE_DDL.sql dulu"
        fi
    done
    for ITEM in PRC_TXT_PROD PRC_SPG_PROD PRC_GRADE; do
        if echo "$ORACLE_CHECK" | grep -q "${ITEM}:EXISTS"; then
            pass "Oracle procedure: ${ITEM} exists"
        else
            fail "Oracle procedure: ${ITEM} TIDAK ADA — run PPC_ORACLE_PROCEDURES.sql dulu"
        fi
    done
else
    warn "sqlplus tidak tersedia atau ORACLE_DSN tidak di-set — Oracle checks diskip"
    warn "Verifikasi Oracle tables manual sebelum mulai ETL development"
fi

echo ""

# ─────────────────────────────────────────────
# WARNING CHECKS
# ─────────────────────────────────────────────
echo "🟡 WARNING CHECKS"
echo "─────────────────────────────────────────"

# Git working tree
if cd /workspace && [ -z "$(git status --porcelain)" ]; then
    pass "Git working tree bersih"
else
    warn "Ada uncommitted changes — commit atau stash dulu"
fi

# Sync dengan upstream
if cd /workspace && git fetch upstream main -q 2>/dev/null; then
    LOCAL=$(git rev-parse HEAD)
    UPSTREAM_HEAD=$(git rev-parse upstream/main 2>/dev/null)
    if [ "$LOCAL" = "$UPSTREAM_HEAD" ] || git merge-base --is-ancestor upstream/main HEAD 2>/dev/null; then
        pass "Branch sudah include latest dari upstream/main"
    else
        warn "Ada update baru di upstream/main — pertimbangkan: git merge upstream/main"
    fi
else
    warn "Tidak bisa fetch upstream — cek network atau remote upstream"
fi

# golangci-lint
if cd /workspace && golangci-lint run ./... 2>/dev/null; then
    pass "golangci-lint: 0 errors"
else
    warn "golangci-lint: ada errors — fix sebelum commit"
fi

# ─────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────
echo ""
echo "================================================"
echo "  SUMMARY"
echo "================================================"
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}✅ READY TO RUN${NC}"
    echo ""
    echo "  Jalankan Claude Code autonomous:"
    echo "  claude --dangerously-skip-permissions \\"
    echo "    'baca internal/ppc/TASKS.md, kerjakan semua task [TODO]'"
    exit 0
else
    echo -e "  ${RED}❌ NOT READY — $FAIL blocker harus difix dulu${NC}"
    echo ""
    echo "  Fix semua ❌ FAIL di atas sebelum mulai."
    exit 1
fi
