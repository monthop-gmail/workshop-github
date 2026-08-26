#!/usr/bin/env bash
# ตรวจว่าเครื่องพร้อมสำหรับ workshop หรือยัง
# ใช้: ./scripts/check-setup.sh
set -uo pipefail

if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; DIM=''; RESET=''
fi

fail_count=0
warn_count=0

ok()   { printf '%s  ok  %s %s\n' "$GREEN" "$RESET" "$1"; }
bad()  { printf '%s fail %s %s\n' "$RED" "$RESET" "$1"; [ $# -gt 1 ] && printf '        %s→ %s%s\n' "$DIM" "$2" "$RESET"; fail_count=$((fail_count + 1)); }
warn() { printf '%s warn %s %s\n' "$YELLOW" "$RESET" "$1"; [ $# -gt 1 ] && printf '        %s→ %s%s\n' "$DIM" "$2" "$RESET"; warn_count=$((warn_count + 1)); }

echo "== เครื่องมือ =="

check_cmd() {
  local cmd="$1" hint="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd — $("$cmd" --version 2>&1 | head -1)"
  else
    bad "ไม่พบ $cmd" "$hint"
  fi
}

check_cmd git  "apt install git / brew install git"
check_cmd gh   "https://cli.github.com — ดู docs/01-setup.md"
check_cmd jq   "apt install jq / brew install jq"

if command -v claude >/dev/null 2>&1; then
  ok "claude — $(claude --version 2>&1 | head -1)"
else
  warn "ไม่พบ claude" "ติดตั้งจาก https://claude.com/claude-code (ไม่จำเป็นสำหรับ scripts/ แต่จำเป็นสำหรับ workshop)"
fi

echo
echo "== GitHub =="

if ! command -v gh >/dev/null 2>&1; then
  bad "ข้ามการตรวจ GitHub เพราะไม่มี gh"
else
  if gh auth status >/dev/null 2>&1; then
    account=$(gh api user --jq .login 2>/dev/null || echo "?")
    ok "ล็อกอินแล้วในชื่อ $account"

    scopes=$(gh auth status 2>&1 | sed -n 's/.*Token scopes: //p' | tr -d "'" | tr ',' ' ')
    for need in repo read:org workflow; do
      if printf '%s' "$scopes" | grep -qw -- "$need"; then
        ok "scope $need"
      else
        bad "ขาด scope $need" "gh auth refresh -h github.com -s repo,read:org,workflow"
      fi
    done
  else
    bad "ยังไม่ได้ล็อกอิน" "gh auth login"
  fi
fi

echo
echo "== git identity =="

git_name=$(git config user.name  || true)
git_email=$(git config user.email || true)

[ -n "$git_name" ]  && ok "user.name = $git_name"   || bad "ไม่ได้ตั้ง user.name"  "git config --global user.name 'ชื่อของคุณ'"
[ -n "$git_email" ] && ok "user.email = $git_email" || bad "ไม่ได้ตั้ง user.email" "git config --global user.email 'you@company.com'"

if [ -n "$git_email" ] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  login=$(gh api user --jq .login 2>/dev/null || true)

  case "$git_email" in
    *@users.noreply.github.com)
      # อีเมล noreply ของ GitHub นับเป็น contribution ปกติ ถ้าตรงกับบัญชีตัวเอง
      if [ -n "$login" ] && [ "${git_email%@users.noreply.github.com}" != "${git_email}" ] \
         && printf '%s' "$git_email" | grep -qi -- "${login}@users.noreply.github.com"; then
        ok "ใช้อีเมล noreply ของบัญชี $login — นับ contribution ปกติ"
      else
        bad "ใช้อีเมล noreply ของบัญชีอื่น ไม่ใช่ $login" \
            "git config --global user.email '<id>+${login}@users.noreply.github.com' หรือใช้อีเมลจริงที่ verified แล้ว"
      fi
      ;;
    *)
      if verified=$(gh api user/emails --jq '.[] | select(.verified) | .email' 2>/dev/null) && [ -n "$verified" ]; then
        if printf '%s\n' "$verified" | grep -qxF "$git_email"; then
          ok "user.email ตรงกับอีเมลที่ verified บน GitHub"
        else
          bad "user.email ไม่ตรงกับอีเมลที่ผูกกับบัญชี GitHub" \
              "commit จะไม่ขึ้น contribution graph — เลือกจาก: $(printf '%s' "$verified" | tr '\n' ' ')"
        fi
      else
        warn "ตรวจไม่ได้ว่า user.email ผูกกับบัญชี GitHub หรือไม่" \
             "token ไม่มี scope user:email — เพิ่มด้วย: gh auth refresh -h github.com -s user:email"
      fi
      ;;
  esac
fi

echo
if [ "$fail_count" -eq 0 ] && [ "$warn_count" -eq 0 ]; then
  printf '%sพร้อมแล้ว%s\n' "$GREEN" "$RESET"
elif [ "$fail_count" -eq 0 ]; then
  printf '%sพร้อม (มีคำเตือน %d ข้อ)%s\n' "$YELLOW" "$warn_count" "$RESET"
else
  printf '%sยังไม่พร้อม — มี %d ข้อที่ต้องแก้ (ดู docs/01-setup.md)%s\n' "$RED" "$fail_count" "$RESET"
fi

exit $(( fail_count > 0 ? 1 : 0 ))
