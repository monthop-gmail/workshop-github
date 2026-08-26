#!/usr/bin/env bash
# ตรวจความถูกต้องของ repo นี้ — รันได้ทั้งบนเครื่องและใน CI
#
# ใช้:
#   ./scripts/validate.sh              ตรวจทั้งหมด
#   ./scripts/validate.sh templates    เฉพาะ YAML/JSON ใน templates/
#   ./scripts/validate.sh shell        เฉพาะ script ใน scripts/
#   ./scripts/validate.sh docs         เฉพาะลิงก์และข้อมูลที่ไม่ควรหลุด
#
# CI เรียกทีละส่วนแยก job — บนเครื่องรันรวดเดียวได้
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  GREEN=''; RED=''; DIM=''; RESET=''
fi

fail=0

# บน GitHub Actions ให้ error ไปโผล่ที่ไฟล์จริง บนเครื่องให้อ่านง่าย
err() {
  local file="$1" msg="$2"
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::error file=%s::%s\n' "$file" "$msg"
  else
    printf '%s  fail %s %s: %s\n' "$RED" "$RESET" "$file" "$msg"
  fi
  fail=1
}
ok()   { printf '%s  ok  %s %s\n' "$GREEN" "$RESET" "$1"; }
head_() { printf '\n%s== %s ==%s\n' "$DIM" "$1" "$RESET"; }

need_python() {
  command -v python3 >/dev/null || { echo "ต้องมี python3"; exit 1; }
}

# ---------------------------------------------------------------- templates
check_templates() {
  head_ "templates: YAML / JSON"
  need_python

  if ! python3 -c 'import yaml' 2>/dev/null; then
    echo "ต้องติดตั้ง PyYAML ก่อน: pip install pyyaml" >&2
    fail=1
    return
  fi

  python3 - <<'PY'
import json, pathlib, sys, yaml

status = 0
in_ci = __import__("os").environ.get("GITHUB_ACTIONS")

def report(path, msg):
    global status
    print(f"::error file={path}::{msg}" if in_ci else f"  fail  {path}: {msg}")
    status = 1

for f in sorted(pathlib.Path("templates").rglob("*.yml")):
    try:
        yaml.safe_load(f.read_text(encoding="utf-8"))
        print(f"  ok    {f}")
    except yaml.YAMLError as exc:
        report(f, f"YAML ไม่ถูกต้อง — {exc}")

for f in sorted(pathlib.Path("templates").rglob("*.json")):
    try:
        json.loads(f.read_text(encoding="utf-8"))
        print(f"  ok    {f}")
    except json.JSONDecodeError as exc:
        report(f, f"JSON ไม่ถูกต้อง — {exc}")

sys.exit(status)
PY
  [ $? -eq 0 ] || fail=1

  # handbook สัญญาไว้ว่า required status check ชื่อ "ci" ใช้ได้กับทุก workflow
  # ถ้าไฟล์ไหนไม่มี job ชื่อนี้ คนที่ก๊อปไปใช้จะตั้ง branch protection แล้ว PR ค้าง
  head_ "templates: ทุก ci-*.yml ต้องมี gate job ชื่อ 'ci'"
  python3 - <<'PY'
import pathlib, sys, yaml

status = 0
in_ci = __import__("os").environ.get("GITHUB_ACTIONS")
files = sorted(pathlib.Path("templates/github/workflows").glob("ci-*.yml"))

if not files:
    print("::error::ไม่พบไฟล์ ci-*.yml ใน templates/github/workflows" if in_ci
          else "  fail  ไม่พบไฟล์ ci-*.yml")
    sys.exit(1)

for f in files:
    jobs = (yaml.safe_load(f.read_text(encoding="utf-8")) or {}).get("jobs", {})
    gate = jobs.get("ci")
    if gate is None:
        print(f"::error file={f}::ไม่มี job ชื่อ 'ci'" if in_ci else f"  fail  {f}: ไม่มี job ชื่อ 'ci'")
        status = 1
        continue

    others = [name for name in jobs if name != "ci"]
    needs = gate.get("needs") or []
    needs = [needs] if isinstance(needs, str) else list(needs)
    missing = sorted(set(others) - set(needs))
    if missing:
        msg = f"job 'ci' ไม่ได้รอ job: {', '.join(missing)}"
        print(f"::error file={f}::{msg}" if in_ci else f"  fail  {f}: {msg}")
        status = 1
    elif str(gate.get("if", "")).strip() != "always()":
        msg = "job 'ci' ต้องมี if: always() ไม่งั้นจะถูก skip ตอน job อื่นแดง แล้ว PR จะค้างแทนที่จะแดง"
        print(f"::error file={f}::{msg}" if in_ci else f"  fail  {f}: {msg}")
        status = 1
    else:
        print(f"  ok    {f} (รอ {len(needs)} job)")

sys.exit(status)
PY
  [ $? -eq 0 ] || fail=1
}

# -------------------------------------------------------------------- shell
check_shell() {
  head_ "scripts: syntax"
  for f in scripts/*.sh; do
    if bash -n "$f" 2>/dev/null; then ok "$f"; else
      err "$f" "$(bash -n "$f" 2>&1 | head -3)"
    fi
  done

  head_ "scripts: shellcheck"
  if command -v shellcheck >/dev/null; then
    for f in scripts/*.sh; do
      if shellcheck -S warning -f gcc "$f"; then ok "$f"; else fail=1; fi
    done
  else
    echo "  ${DIM}(ไม่มี shellcheck บนเครื่องนี้ — ข้าม ติดตั้ง: apt install shellcheck)${RESET}"
  fi

  head_ "scripts: ต้องรันได้ (mode 100755)"
  # ถ้า executable bit หาย คนที่ clone ไปจะเจอ Permission denied
  while read -r mode _ _ path; do
    [ "$mode" = "100755" ] && ok "$path" || err "$path" "ไม่มี executable bit (mode $mode) — แก้ด้วย: git update-index --chmod=+x $path"
  done < <(git ls-files -s scripts/ 2>/dev/null)
}

# --------------------------------------------------------------------- docs
check_docs() {
  head_ "docs: ลิงก์ภายใน"
  need_python
  python3 - <<'PY'
import pathlib, re, sys

status = 0
in_ci = __import__("os").environ.get("GITHUB_ACTIONS")
pattern = re.compile(r'\[[^\]]*\]\(([^)#\s]+)(?:#[^)]*)?\)')

for md in sorted(pathlib.Path(".").rglob("*.md")):
    if ".git" in md.parts:
        continue
    for link in pattern.findall(md.read_text(encoding="utf-8")):
        if link.startswith(("http://", "https://", "mailto:")):
            continue
        if not (md.parent / link).exists():
            msg = f"ลิงก์ชี้ไปไฟล์ที่ไม่มีอยู่: {link}"
            print(f"::error file={md}::{msg}" if in_ci else f"  fail  {md}: {msg}")
            status = 1

print("  ok    ลิงก์ภายในทุกอันชี้ไปยังไฟล์ที่มีอยู่จริง" if status == 0 else "")
sys.exit(status)
PY
  [ $? -eq 0 ] || fail=1

  # repo นี้เป็น public — กันไม่ให้ค่าจริงหลุดปนมากับตัวอย่าง
  head_ "docs: ไม่มีข้อมูลที่ไม่ควรอยู่ใน repo สาธารณะ"

  if git grep -InE '(gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' -- . ; then
    err "repo" "พบสิ่งที่ดูเหมือน token หรือ private key"
  else
    ok "ไม่พบ token / private key"
  fi

  # อีเมลที่ไม่ใช่ placeholder ที่ตั้งใจใช้เป็นตัวอย่าง
  if git grep -InE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' -- . \
     | grep -vE 'company\.com|users\.noreply\.github\.com|example\.(com|org)|myorg|@[a-zA-Z0-9.-]*anthropic' ; then
    err "repo" "พบอีเมลที่อาจเป็นของจริง — ใช้ you@company.com หรือ example.com แทน"
  else
    ok "ไม่พบอีเมลที่อาจเป็นของจริง"
  fi
}

case "${1:-all}" in
  templates) check_templates ;;
  shell)     check_shell ;;
  docs)      check_docs ;;
  all)       check_templates; check_shell; check_docs ;;
  -h|--help) sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *)         echo "ไม่รู้จัก: $1 (ต้องเป็น all|templates|shell|docs)" >&2; exit 1 ;;
esac

echo
if [ "$fail" -eq 0 ]; then
  printf '%sผ่านทั้งหมด%s\n' "$GREEN" "$RESET"
else
  printf '%sไม่ผ่าน — แก้ตามรายการข้างบน%s\n' "$RED" "$RESET"
fi
exit "$fail"
