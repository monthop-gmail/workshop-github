#!/usr/bin/env bash
# เปิด branch protection บน default branch ด้วย GitHub Rulesets
#
# ใช้:
#   ./scripts/apply-ruleset.sh myorg/my-service --checks ci
#   ./scripts/apply-ruleset.sh myorg/my-service --checks ci,e2e --approvals 2
#   ./scripts/apply-ruleset.sh myorg/my-service --dry-run
#
# options:
#   --checks a,b       ชื่อ status check ที่ต้องเขียวก่อน merge (ค่าเริ่มต้น: ci)
#   --approvals N      จำนวน approve ที่ต้องมี (ค่าเริ่มต้น: 1)
#   --no-codeowners    ไม่บังคับ code owner review (ใช้เมื่อยังไม่มีไฟล์ CODEOWNERS)
#   --dry-run          แสดง payload อย่างเดียว ไม่ยิงจริง
#   --yes              ไม่ต้องถามยืนยัน
#
# ต้องมีสิทธิ์ admin บน repo
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE="$ROOT/templates/rulesets/main-protection.json"
RULESET_NAME="main-protection"

if [ -t 1 ]; then
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  GREEN=''; YELLOW=''; DIM=''; RESET=''
fi

usage() { sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

nwo=""
checks="ci"
approvals=1
codeowners=true
dry=0
assume_yes=0

while [ $# -gt 0 ]; do
  case "$1" in
    --checks)        checks="${2:-}"; shift 2 ;;
    --approvals)     approvals="${2:-}"; shift 2 ;;
    --no-codeowners) codeowners=false; shift ;;
    --dry-run)       dry=1; shift ;;
    --yes|-y)        assume_yes=1; shift ;;
    -h|--help)       usage 0 ;;
    -*)              echo "ไม่รู้จัก option: $1" >&2; usage 1 ;;
    *)               nwo="$1"; shift ;;
  esac
done

[ -n "$nwo" ] || { echo "ต้องระบุ OWNER/REPO" >&2; usage 1; }
case "$nwo" in */*) ;; *) echo "รูปแบบต้องเป็น OWNER/REPO เช่น myorg/my-service" >&2; exit 1 ;; esac
[[ "$approvals" =~ ^[0-9]+$ ]] || { echo "--approvals ต้องเป็นตัวเลข" >&2; exit 1; }

command -v gh >/dev/null || { echo "ต้องติดตั้ง gh ก่อน" >&2; exit 1; }
command -v jq >/dev/null || { echo "ต้องติดตั้ง jq ก่อน" >&2; exit 1; }
[ -f "$TEMPLATE" ] || { echo "ไม่พบ template: $TEMPLATE" >&2; exit 1; }

# --- ตรวจสิทธิ์และสถานะ repo ก่อน ---
repo_json=$(gh api "repos/$nwo" 2>/dev/null) || { echo "เข้าถึง repo ไม่ได้: $nwo" >&2; exit 1; }
default_branch=$(printf '%s' "$repo_json" | jq -r .default_branch)
is_admin=$(printf '%s' "$repo_json" | jq -r '.permissions.admin // false')

if [ "$is_admin" != "true" ]; then
  echo "ไม่มีสิทธิ์ admin บน $nwo — ตั้ง ruleset ไม่ได้" >&2
  echo "ให้ส่งชื่อ repo นี้ให้ org admin พร้อมคำสั่งนี้" >&2
  exit 1
fi

# --- ประกอบ payload ---
checks_json=$(printf '%s' "$checks" | tr ',' '\n' | sed '/^$/d' | jq -R '{context: .}' | jq -s '.')
[ "$(printf '%s' "$checks_json" | jq 'length')" -gt 0 ] || { echo "--checks ว่าง" >&2; exit 1; }

payload=$(jq \
  --argjson checks "$checks_json" \
  --argjson approvals "$approvals" \
  --argjson codeowners "$codeowners" '
  (.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks) |= $checks
  | (.rules[] | select(.type == "pull_request") | .parameters.required_approving_review_count) |= $approvals
  | (.rules[] | select(.type == "pull_request") | .parameters.require_code_owner_review) |= $codeowners
' "$TEMPLATE")

echo
printf 'repo            %s %s(default branch: %s)%s\n' "$nwo" "$DIM" "$default_branch" "$RESET"
printf 'ruleset         %s\n' "$RULESET_NAME"
printf 'required checks %s\n' "$(printf '%s' "$checks_json" | jq -r '[.[].context] | join(", ")')"
printf 'approvals       %s\n' "$approvals"
printf 'code owner      %s\n' "$codeowners"
echo

if [ "$dry" -eq 1 ]; then
  printf '%s--dry-run — payload ที่จะส่ง:%s\n' "$YELLOW" "$RESET"
  printf '%s\n' "$payload" | jq .
  exit 0
fi

# --- เตือนถ้าเปิด code owner review แต่ยังไม่มีไฟล์ CODEOWNERS ---
if [ "$codeowners" = "true" ]; then
  if ! gh api "repos/$nwo/contents/.github/CODEOWNERS" >/dev/null 2>&1 \
     && ! gh api "repos/$nwo/contents/CODEOWNERS" >/dev/null 2>&1; then
    printf '%sเตือน: ยังไม่มีไฟล์ CODEOWNERS ใน repo นี้ — กฎ require_code_owner_review จะไม่มีผลจนกว่าจะเพิ่มไฟล์%s\n' \
      "$YELLOW" "$RESET"
  fi
fi

if [ "$assume_yes" -eq 0 ]; then
  if [ ! -t 0 ]; then
    echo "ไม่ใช่ terminal — ใส่ --yes ถ้าต้องการรันแบบไม่ถาม" >&2
    exit 1
  fi
  read -r -p "ยืนยันตั้ง ruleset นี้กับ $nwo ? [y/N] " answer
  case "$answer" in [yY]|[yY][eE][sS]) ;; *) echo "ยกเลิก"; exit 0 ;; esac
fi

existing_id=$(gh api "repos/$nwo/rulesets" --jq ".[] | select(.name == \"$RULESET_NAME\") | .id" 2>/dev/null | head -1 || true)

if [ -n "$existing_id" ]; then
  printf '%s\n' "$payload" | gh api -X PUT "repos/$nwo/rulesets/$existing_id" --input - >/dev/null
  printf '%sอัปเดต ruleset เดิม%s (id %s)\n' "$GREEN" "$RESET" "$existing_id"
else
  new_id=$(printf '%s\n' "$payload" | gh api -X POST "repos/$nwo/rulesets" --input - --jq .id)
  printf '%sสร้าง ruleset ใหม่%s (id %s)\n' "$GREEN" "$RESET" "$new_id"
fi

echo
echo "กฎที่มีผลกับ $default_branch ตอนนี้:"
gh api "repos/$nwo/rules/branches/$default_branch" --jq '.[] | "  - \(.type)"' | sort -u

cat <<EOF

ทดสอบว่ากันจริง (ควรถูกปฏิเสธ):
  git switch $default_branch && git commit --allow-empty -m test && git push
  git reset --hard origin/$default_branch
EOF
