#!/usr/bin/env bash
# ติดตั้ง template มาตรฐานของทีมลง repo ที่มีอยู่แล้ว
#
# ใช้:
#   ./scripts/bootstrap-repo.sh --repo ~/work/my-service --stack python
#   ./scripts/bootstrap-repo.sh --repo ~/work/erp-addons --stack odoo --force
#
# stack: python | odoo | node | docker
# ค่าเริ่มต้นคือ "ไม่ทับไฟล์ที่มีอยู่แล้ว" — ใช้ --force ถ้าต้องการทับ
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
TPL="$ROOT/templates"

if [ -t 1 ]; then
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  GREEN=''; YELLOW=''; DIM=''; RESET=''
fi

repo=""
stack=""
force=0
dry=0

usage() {
  sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)    repo="${2:-}"; shift 2 ;;
    --stack)   stack="${2:-}"; shift 2 ;;
    --force)   force=1; shift ;;
    --dry-run) dry=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "ไม่รู้จัก option: $1" >&2; usage 1 ;;
  esac
done

[ -n "$repo" ]  || { echo "ต้องระบุ --repo" >&2; usage 1; }
[ -n "$stack" ] || { echo "ต้องระบุ --stack (python|odoo|node|docker)" >&2; usage 1; }
[ -d "$repo" ]  || { echo "ไม่พบโฟลเดอร์: $repo" >&2; exit 1; }

repo="$(cd "$repo" && pwd)"

if [ ! -d "$repo/.git" ]; then
  echo "เตือน: $repo ไม่ใช่ git repository — จะยังก๊อปไฟล์ให้ แต่ตรวจให้แน่ใจว่าถูกที่" >&2
fi

case "$stack" in
  python) ci_src="ci-python.yml"; claude_src="CLAUDE.md.base" ;;
  odoo)   ci_src="ci-python.yml"; claude_src="CLAUDE.md.python-odoo" ;;
  node)   ci_src="ci-node.yml";   claude_src="CLAUDE.md.node-ts" ;;
  docker) ci_src="ci-docker.yml"; claude_src="CLAUDE.md.docker-infra" ;;
  *) echo "stack ไม่ถูกต้อง: $stack (ต้องเป็น python|odoo|node|docker)" >&2; exit 1 ;;
esac

copied=(); skipped=()

place() {
  local src="$1" dest="$2"
  [ -f "$src" ] || { echo "ไม่พบ template: $src" >&2; exit 1; }

  if [ -e "$dest" ] && [ "$force" -eq 0 ]; then
    skipped+=("${dest#"$repo"/}")
    return
  fi

  if [ "$dry" -eq 1 ]; then
    copied+=("${dest#"$repo"/}")
    return
  fi

  mkdir -p "$(dirname "$dest")"
  cp "$src" "$dest"
  copied+=("${dest#"$repo"/}")
}

place "$TPL/github/PULL_REQUEST_TEMPLATE.md"        "$repo/.github/PULL_REQUEST_TEMPLATE.md"
place "$TPL/github/CODEOWNERS"                      "$repo/.github/CODEOWNERS"
place "$TPL/github/ISSUE_TEMPLATE/bug_report.yml"   "$repo/.github/ISSUE_TEMPLATE/bug_report.yml"
place "$TPL/github/ISSUE_TEMPLATE/feature_request.yml" "$repo/.github/ISSUE_TEMPLATE/feature_request.yml"
place "$TPL/github/workflows/$ci_src"               "$repo/.github/workflows/ci.yml"
place "$TPL/claude/settings.json"                   "$repo/.claude/settings.json"
place "$TPL/$claude_src"                            "$repo/CLAUDE.md"

# .gitignore — เพิ่มเฉพาะบรรทัดที่ยังไม่มี ไม่ทับของเดิม
gitignore_added=()
if [ "$dry" -eq 0 ]; then
  gi="$repo/.gitignore"
  touch "$gi"
  for line in '.env' '.env.*' '!.env.example' '.claude/settings.local.json'; do
    if ! grep -qxF "$line" "$gi"; then
      printf '%s\n' "$line" >> "$gi"
      gitignore_added+=("$line")
    fi
  done
fi

echo
printf '%sติดตั้งลง%s %s %s(stack: %s)%s\n' "$GREEN" "$RESET" "$repo" "$DIM" "$stack" "$RESET"
[ "$dry" -eq 1 ] && printf '%s(dry-run — ยังไม่ได้เขียนไฟล์จริง)%s\n' "$YELLOW" "$RESET"
echo

if [ ${#copied[@]} -gt 0 ]; then
  echo "เพิ่ม/ทับ:"
  printf '  + %s\n' "${copied[@]}"
fi

if [ ${#skipped[@]} -gt 0 ]; then
  echo
  printf '%sข้าม (มีอยู่แล้ว — ใช้ --force ถ้าต้องการทับ):%s\n' "$YELLOW" "$RESET"
  printf '  . %s\n' "${skipped[@]}"
fi

if [ ${#gitignore_added[@]} -gt 0 ]; then
  echo
  echo "เพิ่มลง .gitignore:"
  printf '  + %s\n' "${gitignore_added[@]}"
fi

cat <<EOF

ต่อไปต้องทำด้วยมือ:
  1. แก้ CLAUDE.md — แทนที่ทุก <...> ด้วยของจริงของ repo นี้
  2. แก้ .github/CODEOWNERS — เปลี่ยน @myorg/team-* เป็นทีมจริง
     ตรวจ syntax: gh api repos/<owner>/<repo>/codeowners/errors --jq '.errors'
  3. เปิด PR แล้วดูให้ CI เขียวก่อน
  4. ค่อยเปิด branch protection:
     $ROOT/scripts/apply-ruleset.sh <owner>/<repo> --checks ci
EOF
