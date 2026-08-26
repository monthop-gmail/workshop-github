# 01 — เตรียมเครื่อง

ทำให้เสร็จ **ก่อน** วัน workshop ใช้เวลาประมาณ 20 นาที
จบแล้วรัน `./scripts/check-setup.sh` ต้องขึ้นเขียวทุกบรรทัด

## 1. เครื่องมือพื้นฐาน

```bash
# Debian / Ubuntu
sudo apt update && sudo apt install -y git jq

# GitHub CLI (ไม่มีใน apt เวอร์ชันเก่า ให้ใช้ repo ทางการ)
(type -p wget >/dev/null || sudo apt install wget -y) \
  && sudo mkdir -p -m 755 /etc/apt/keyrings \
  && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
     | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
  && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
     | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
  && sudo apt update && sudo apt install gh -y
```

macOS: `brew install git gh jq`

## 2. ล็อกอิน GitHub

```bash
gh auth login          # เลือก GitHub.com → HTTPS → Login with a web browser
gh auth status         # ต้องเห็นชื่อบัญชีตัวเอง
```

Scope ที่ต้องมีอย่างน้อย: `repo`, `read:org`, `workflow`
ถ้าขาด `workflow` จะ push ไฟล์ใน `.github/workflows/` ไม่ได้ (error `refusing to allow ... without workflow scope`)

```bash
gh auth refresh -h github.com -s repo,read:org,workflow
```

## 3. ตั้ง git identity ให้ตรงกับบัญชี GitHub

**นี่คือจุดที่พลาดกันบ่อยที่สุด** ถ้า `user.email` ไม่ตรงกับอีเมลที่ผูกกับบัญชี GitHub
commit จะไม่ขึ้น contribution graph และ CODEOWNERS/blame จะชี้ผิดคน

```bash
# ดูอีเมลที่ผูกกับบัญชีอยู่จริง
gh api user/emails --jq '.[] | select(.verified) | .email'

# ตั้งแบบ global
git config --global user.name  "ชื่อที่ใช้ใน GitHub"
git config --global user.email "อีเมลที่ verified แล้ว"

# ถ้าเครื่องนี้มีทั้งบัญชีงานและบัญชีส่วนตัว ให้ตั้งเป็นราย repo แทน
cd ~/work/my-service
git config user.email "you@company.com"
```

ตรวจก่อน commit แรกเสมอ:

```bash
git config user.name && git config user.email
```

> ถ้า commit ไปแล้วขึ้นชื่อผิด แก้ย้อนหลังได้ แต่ต้อง force push ซึ่งกระทบคนอื่นที่ pull ไปแล้ว
> อย่าทำกับ branch ที่มีคนอื่นใช้อยู่ — ดู [99-cheatsheet.md](99-cheatsheet.md#แก้ประวัติ-commit)

## 4. Claude Code

```bash
claude --version      # ถ้ายังไม่มี ติดตั้งตาม https://claude.com/claude-code
claude                # เข้าไปแล้วพิมพ์ /login
```

เช็คว่าใช้ model ที่ถูก — พิมพ์ `/model` ใน session
งานเขียนโค้ดจริงใช้ **Opus** (`claude-opus-5`) งานค้นหา/สรุปเบา ๆ ใช้ Sonnet หรือ Haiku ได้

## 5. กันความผิดพลาดที่แพงที่สุด: secret หลุด

ก่อนเริ่มทำงานกับ repo ใด ๆ:

```bash
# ต้องมี .gitignore ที่กัน .env
grep -q '^\.env' .gitignore || echo -e '.env\n.env.*\n!.env.example' >> .gitignore
```

และตั้ง secret scanning ฝั่ง GitHub (ทำครั้งเดียวต่อ repo, ต้องมีสิทธิ์ admin):

```bash
gh api -X PATCH repos/OWNER/REPO \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
```

`push_protection` คือตัวที่จะ **บล็อกไม่ให้ push** ถ้าเจอ token ใน diff — เปิดไว้เถอะ
(repo private ต้องมี GitHub Advanced Security หรือแผนที่รองรับ ถ้า API ตอบ 403 แปลว่าแผนไม่รองรับ ให้ข้ามไปใช้ `.gitignore` + review อย่างเดียว)

## 6. ตรวจว่าพร้อม

```bash
./scripts/check-setup.sh
```

ถ้ามีบรรทัดแดง แก้ให้หมดก่อนเข้า workshop

---

ถัดไป → [02 — ใช้ Claude Code ให้ควบคุมได้](02-claude-code-workflow.md)
