#!/usr/bin/env bash
# ตรวจว่า repo ไหนในองค์กร/บัญชี ยังขาดมาตรฐานของทีมบ้าง
#
# ใช้:
#   ./scripts/audit-repos.sh myorg
#   ./scripts/audit-repos.sh myorg --limit 200 > audit.md
#   ./scripts/audit-repos.sh myorg --only-missing
#
# options:
#   --limit N          จำนวน repo สูงสุดที่ดึงมา (ค่าเริ่มต้น: 100)
#   --include-archived รวม repo ที่ archive แล้วด้วย (ค่าเริ่มต้น: ไม่รวม)
#   --only-missing     แสดงเฉพาะ repo ที่ยังขาดอะไรบางอย่าง
#
# ผลลัพธ์เป็นตาราง markdown — เอาไปแปะใน issue ได้เลย
set -euo pipefail

usage() { sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

owner=""
limit=100
include_archived=0
only_missing=0

while [ $# -gt 0 ]; do
  case "$1" in
    --limit)            limit="${2:-}"; shift 2 ;;
    --include-archived) include_archived=1; shift ;;
    --only-missing)     only_missing=1; shift ;;
    -h|--help)          usage 0 ;;
    -*)                 echo "ไม่รู้จัก option: $1" >&2; usage 1 ;;
    *)                  owner="$1"; shift ;;
  esac
done

[ -n "$owner" ] || { echo "ต้องระบุ OWNER (ชื่อ org หรือ user)" >&2; usage 1; }
[[ "$limit" =~ ^[0-9]+$ ]] || { echo "--limit ต้องเป็นตัวเลข" >&2; exit 1; }
command -v gh >/dev/null || { echo "ต้องติดตั้ง gh ก่อน" >&2; exit 1; }
command -v jq >/dev/null || { echo "ต้องติดตั้ง jq ก่อน" >&2; exit 1; }

echo "กำลังดึงรายชื่อ repo ของ $owner ..." >&2

repos=$(gh repo list "$owner" --limit "$limit" --no-archived --json name,defaultBranchRef 2>/dev/null) \
  || { echo "ดึงรายชื่อ repo ไม่ได้ — ตรวจว่าชื่อ $owner ถูกต้องและ token มี scope read:org" >&2; exit 1; }

if [ "$include_archived" -eq 1 ]; then
  repos=$(gh repo list "$owner" --limit "$limit" --json name,defaultBranchRef)
fi

count=$(printf '%s' "$repos" | jq 'length')
[ "$count" -gt 0 ] || { echo "ไม่พบ repo ของ $owner" >&2; exit 0; }

echo "เจอ $count repo — กำลังตรวจทีละอัน (ใช้เวลาประมาณ $((count * 2)) วินาที)" >&2

rows=""
missing_total=0

# ตรวจว่า path หนึ่ง ๆ มีอยู่ใน repo ไหม (ใช้ตอน tree ถูกตัด)
path_exists() {
  gh api "repos/$1/contents/$2" --silent >/dev/null 2>&1
}

mark() {
  case "$1" in
    1)  printf 'yes' ;;
    na) printf '_n/a_' ;;   # ฟีเจอร์ใช้ไม่ได้บนแผนนี้ ไม่ใช่ "ยังไม่ได้ตั้ง"
    *)  printf '**no**' ;;
  esac
}

while IFS=$'\t' read -r name branch; do
  [ -n "$name" ] || continue
  nwo="$owner/$name"
  printf '  %s\r' "$nwo" >&2

  has_claude=0; has_owners=0; has_prtpl=0; has_ci=0; has_rules=0

  if [ -z "$branch" ] || [ "$branch" = "null" ]; then
    rows+="| \`$name\` | _repo ว่าง_ | | | | |"$'\n'
    missing_total=$((missing_total + 1))
    continue
  fi

  tree=$(gh api "repos/$nwo/git/trees/$branch?recursive=1" 2>/dev/null || true)

  if [ -n "$tree" ] && printf '%s' "$tree" | jq -e 'has("tree") and (.truncated // false | not)' >/dev/null 2>&1; then
    paths=$(printf '%s' "$tree" | jq -r '.tree[].path')
    printf '%s\n' "$paths" | grep -qx 'CLAUDE.md' && has_claude=1
    printf '%s\n' "$paths" | grep -qxE '(\.github/|docs/)?CODEOWNERS' && has_owners=1
    printf '%s\n' "$paths" | grep -qiE '^(\.github/)?(PULL_REQUEST_TEMPLATE\.md|\.github/PULL_REQUEST_TEMPLATE/)' && has_prtpl=1
    printf '%s\n' "$paths" | grep -qE '^\.github/workflows/.+\.(yml|yaml)$' && has_ci=1
  else
    # repo ใหญ่เกินจน tree ถูกตัด หรือดึงไม่ได้ — ตรวจทีละ path แทน
    path_exists "$nwo" "CLAUDE.md" && has_claude=1
    { path_exists "$nwo" ".github/CODEOWNERS" || path_exists "$nwo" "CODEOWNERS"; } && has_owners=1
    path_exists "$nwo" ".github/PULL_REQUEST_TEMPLATE.md" && has_prtpl=1
    [ -n "$(gh api "repos/$nwo/contents/.github/workflows" --jq 'length' 2>/dev/null || true)" ] && has_ci=1
  fi

  # ระวัง: บน private repo ของแผนฟรี API ตอบ 403 พร้อม body เป็น JSON object
  # ถ้าเอา body มานับตรง ๆ จะกลายเป็น "มี protection" ทั้งที่ตั้งไม่ได้เลย
  # เก็บทั้ง stdout และ stderr ไว้ก่อน อย่าต่อ pipe ตรงจาก gh —
  # pipefail จะทำให้ pipeline ล้มตาม exit code ของ gh ก่อนที่ grep จะได้ทำงาน
  rules_out=$(gh api "repos/$nwo/rules/branches/$branch" 2>&1 || true)
  if printf '%s' "$rules_out" | jq -e 'type == "array"' >/dev/null 2>&1; then
    [ "$(printf '%s' "$rules_out" | jq 'length')" -gt 0 ] && has_rules=1
  elif printf '%s' "$rules_out" | grep -q 'Upgrade to GitHub'; then
    # แผนไม่รองรับ — ต่างจาก "ยังไม่ได้ตั้ง" อย่างสิ้นเชิง
    has_rules=na
  fi

  rules_missing=0
  [ "$has_rules" = "0" ] && rules_missing=1
  total_missing=$(( (1 - has_claude) + (1 - has_owners) + (1 - has_prtpl) + (1 - has_ci) + rules_missing ))
  [ "$total_missing" -gt 0 ] && missing_total=$((missing_total + 1))

  if [ "$only_missing" -eq 1 ] && [ "$total_missing" -eq 0 ]; then
    continue
  fi

  rows+="| \`$name\` | $(mark $has_claude) | $(mark $has_owners) | $(mark $has_prtpl) | $(mark $has_ci) | $(mark $has_rules) |"$'\n'
done < <(printf '%s' "$repos" | jq -r '.[] | [.name, (.defaultBranchRef.name // "")] | @tsv')

printf '%*s\r' 60 '' >&2

cat <<EOF

# มาตรฐาน repo ของ $owner

ตรวจ $count repo — มี $missing_total repo ที่ยังขาดอย่างน้อย 1 อย่าง

| repo | CLAUDE.md | CODEOWNERS | PR template | CI workflow | branch protection |
| --- | --- | --- | --- | --- | --- |
EOF

printf '%s' "$rows"

cat <<EOF

_n/a_ = ฟีเจอร์ใช้ไม่ได้บนแผนปัจจุบัน ไม่ใช่ "ยังไม่ได้ตั้ง"
branch protection ของ private repo ต้องใช้ GitHub Pro/Team ขึ้นไป — บนแผนฟรีใช้ได้เฉพาะ public repo

## เติมส่วนที่ขาด

\`\`\`bash
git clone https://github.com/$owner/<repo> && cd <repo>
git switch -c chore/adopt-team-standards
<path-to>/scripts/bootstrap-repo.sh --repo . --stack <python|odoo|node|docker>
# แก้ CLAUDE.md และ CODEOWNERS ให้เป็นของจริงก่อน commit
git add -A && git commit -m 'chore: adopt team GitHub standards'
gh pr create --fill

# หลัง CI เขียวแล้วค่อยเปิด branch protection
<path-to>/scripts/apply-ruleset.sh $owner/<repo> --checks ci
\`\`\`
EOF
