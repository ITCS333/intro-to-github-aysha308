#!/bin/bash

# ============================================================
# validate_studentinfo.sh
# Validates a student information file for required fields
# and checks if the GitHub username exists.
# ============================================================

set -euo pipefail

# --- Configuration ---
FILE="${1:-studentinfo.txt}"
EXIT_CODE=0

# --- Color codes for output (compatible with GitHub Actions) ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Helper Functions ---
log_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
    # GitHub Actions annotation
    echo "::error::$1"
    EXIT_CODE=1
}

log_success() {
    echo -e "${GREEN}✅ PASS: $1${NC}"
}

log_info() {
    echo -e "${YELLOW}ℹ️  INFO: $1${NC}"
}

# --- Step 1: Check if file exists ---
echo "========================================"
echo " Student Info File Validator"
echo "========================================"
echo ""

log_info "Checking file: ${FILE}"

if [[ ! -f "$FILE" ]]; then
    log_error "File '${FILE}' not found!"
    exit 1
fi

echo ""
echo "--- File Contents ---"
cat "$FILE"
echo ""
echo "---------------------"
echo ""

# --- Step 2: Extract and validate Name ---
NAME=$(grep -i "^Name:" "$FILE" | head -n 1 | sed 's/^[Nn]ame:\s*//' | xargs || true)

if [[ -z "$NAME" ]]; then
    log_error "'Name' field is missing or empty."
else
    # Check that name contains only letters, spaces, hyphens, or apostrophes
    if [[ "$NAME" =~ ^[a-zA-Z][a-zA-Z\ \'\-]+$ ]]; then
        log_success "Name is valid: '${NAME}'"
    else
        log_error "Name '${NAME}' contains invalid characters. Only letters, spaces, hyphens, and apostrophes are allowed."
    fi
fi

# --- Step 3: Extract and validate UOB ID ---
UOB_ID=$(grep -i "^UOB ID:" "$FILE" | head -n 1 | sed 's/^[Uu][Oo][Bb] [Ii][Dd]:\s*//' | xargs || true)

if [[ -z "$UOB_ID" ]]; then
    log_error "'UOB ID' field is missing or empty."
else
    # Check that UOB ID is exactly 8 or 9 digits
    if [[ "$UOB_ID" =~ ^[0-9]{8,9}$ ]]; then
        log_success "UOB ID is valid: '${UOB_ID}' (${#UOB_ID} digits)"
    else
        log_error "UOB ID '${UOB_ID}' is invalid. It must be exactly 8 or 9 digits (0-9 only)."
    fi
fi

# --- Step 4: Extract and validate GitHub Username ---
GITHUB_USER=$(grep -i "^GitHub Username:" "$FILE" | head -n 1 | sed 's/^[Gg]it[Hh]ub [Uu]sername:\s*//' | xargs || true)

if [[ -z "$GITHUB_USER" ]]; then
    log_error "'GitHub Username' field is missing or empty."
else
    # Validate GitHub username format (alphanumeric and hyphens, 1-39 chars)
    if [[ ! "$GITHUB_USER" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?$ ]] || [[ ${#GITHUB_USER} -gt 39 ]]; then
        log_error "GitHub Username '${GITHUB_USER}' has an invalid format."
    else
        log_success "GitHub Username format is valid: '${GITHUB_USER}'"

        # Check if the GitHub user actually exists via the GitHub API
        log_info "Verifying GitHub user '${GITHUB_USER}' exists..."

        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Accept: application/vnd.github+json" \
            "https://api.github.com/users/${GITHUB_USER}")

        if [[ "$HTTP_STATUS" -eq 200 ]]; then
            log_success "GitHub user '${GITHUB_USER}' exists."
        elif [[ "$HTTP_STATUS" -eq 404 ]]; then
            log_error "GitHub user '${GITHUB_USER}' does NOT exist (HTTP 404)."
        elif [[ "$HTTP_STATUS" -eq 403 ]]; then
            log_error "GitHub API rate limit exceeded (HTTP 403). Unable to verify user."
        else
            log_error "GitHub API returned unexpected status code: ${HTTP_STATUS} for user '${GITHUB_USER}'."
        fi
    fi
fi

# --- Final Result ---
echo ""
echo "========================================"
if [[ $EXIT_CODE -ne 0 ]]; then
    echo -e "${RED}  VALIDATION FAILED${NC}"
    echo "========================================"
    exit 1
else
    echo -e "${GREEN}  ALL CHECKS PASSED${NC}"
    echo "========================================"
    exit 0
fi
