# Templates

ไฟล์ในโฟลเดอร์นี้เอาไปวางใน repo จริงได้เลย
วิธีที่แนะนำคือใช้ `../scripts/bootstrap-repo.sh` แทนการก๊อปเอง — จะได้ไม่ตกหล่นและเหมือนกันทุก repo

```bash
../scripts/bootstrap-repo.sh --repo ~/work/my-service --stack python
```

## ไฟล์ไหนไปไหน

| template | ปลายทางใน repo | หมายเหตุ |
| --- | --- | --- |
| `CLAUDE.md.base` | `CLAUDE.md` | ใช้กับ repo ทั่วไป (`--stack python`) |
| `CLAUDE.md.python-odoo` | `CLAUDE.md` | Odoo addons (`--stack odoo`) |
| `CLAUDE.md.node-ts` | `CLAUDE.md` | Node/TypeScript (`--stack node`) |
| `CLAUDE.md.docker-infra` | `CLAUDE.md` | infra/config repo (`--stack docker`) |
| `claude/settings.json` | `.claude/settings.json` | permission ของ Claude Code — commit ลง git |
| `github/PULL_REQUEST_TEMPLATE.md` | `.github/PULL_REQUEST_TEMPLATE.md` | |
| `github/CODEOWNERS` | `.github/CODEOWNERS` | **ต้องแก้ชื่อทีมก่อนใช้** |
| `github/ISSUE_TEMPLATE/*.yml` | `.github/ISSUE_TEMPLATE/` | |
| `github/workflows/ci-*.yml` | `.github/workflows/ci.yml` | เลือกอันเดียวตาม stack |
| `github/workflows/claude*.yml` | `.github/workflows/` | ของเสริม — อ่าน `docs/06` ก่อน |
| `rulesets/main-protection.json` | ไม่ต้องก๊อป | ใช้ผ่าน `scripts/apply-ruleset.sh` |
| `rulesets/org-main-protection.json` | ไม่ต้องก๊อป | ตั้งระดับ org: `gh api -X POST orgs/<org>/rulesets --input <ไฟล์นี้>` |

## ต้องแก้ก่อนใช้

**`CLAUDE.md.*`** — ทุกจุดที่เป็น `<...>` คือช่องที่ต้องเติมของจริง
ถ้าเติมไม่ได้แปลว่ายังไม่รู้จัก repo ดีพอ ให้ไปหาคำตอบก่อน อย่าปล่อยไว้

**`github/CODEOWNERS`** — `@myorg/team-*` เป็นชื่อสมมติทั้งหมด
team ที่ใส่ต้องมีสิทธิ์ write บน repo ไม่งั้นบรรทัดนั้นจะเงียบไม่มีผลและไม่มี error
ตรวจด้วย `gh api repos/<owner>/<repo>/codeowners/errors --jq '.errors'`

**`github/ISSUE_TEMPLATE/config.yml`** — แก้ URL ให้ชี้ discussions ของ repo จริง
(`bootstrap-repo.sh` ไม่ก๊อปไฟล์นี้ให้ เพราะถ้า URL ผิด GitHub จะขึ้น error ให้ผู้ใช้เห็น)

## ข้อควรรู้ของแต่ละ CI workflow

**ทั้งสามไฟล์** จบด้วย job ชื่อ `ci` ที่รอทุก job ก่อนหน้า —
ตั้ง required status check ใน branch protection เป็น `ci` อันเดียวพอ
ต่อให้เพิ่ม/ลด job ข้างในทีหลัง ก็ไม่ต้องกลับมาแก้ branch protection

**`ci-python.yml`**
- ต้องมี `ruff` ผ่าน ถ้า repo ยังไม่เคยจัด format มาก่อน ให้รัน `ruff format .` แล้ว commit เป็น PR แยกก่อน
  ไม่งั้น PR แรกจะบวมจนรีวิวไม่ได้
- matrix ตั้งไว้ที่ Python 3.10 กับ 3.12 — แก้ให้ตรงกับที่ใช้จริงบน production
- step "ตรวจ Odoo manifest และ XML" ทำงานกับทุก repo Python ถ้าไม่มี `__manifest__.py` มันจะข้ามไปเอง

**`ci-node.yml`**
- ใช้ `npm ci` ซึ่งต้องมี `package-lock.json` — ถ้า repo ใช้ pnpm/yarn ต้องแก้ทั้ง 3 จุด
  (`cache:`, คำสั่ง install, และคำสั่ง run)
- อ่านเวอร์ชัน Node จาก `.nvmrc` ถ้าไม่มีจะเตือนแล้วใช้ 22 — ควรเพิ่ม `.nvmrc` ลง repo
- script ที่ยังไม่มีใน `package.json` จะถูกข้ามด้วย `--if-present` ไม่ทำให้ CI แดง

**`ci-docker.yml`**
- job `compose` จะแดงถ้าเจอ `image: xxx:latest` — pin เวอร์ชันให้ชัด
- job `build` ทำงานเฉพาะเมื่อมี `Dockerfile` ที่ราก repo
- ไม่ push image — การ push ควรอยู่ใน workflow แยกที่ผูกกับ tag ไม่ใช่ทุก PR

**`claude*.yml`** — ต้องมี secret `ANTHROPIC_API_KEY` และมีค่าใช้จ่ายตาม token ที่ใช้
อ่าน [`docs/06-claude-on-github.md`](../docs/06-claude-on-github.md) ให้จบก่อนเปิดใช้ โดยเฉพาะหัวข้อความปลอดภัย

## `claude/settings.json`

`deny` ชนะ `allow` เสมอ ลิสต์ `deny` ตั้งไว้กันสิ่งที่ย้อนไม่ได้หรือกระทบคนอื่น
(`git push`, `gh pr merge`, `rm -rf`, `docker compose down`, `kubectl`, `ssh`, อ่าน `.env` และ private key)

ปรับให้เข้ากับ repo ได้ตามสบาย แต่**อย่าลบ `deny` ทิ้งทั้งก้อนเพื่อความสะดวก** —
ถ้าโดนถามบ่อยเกินไป ให้เพิ่มคำสั่งที่ปลอดภัยเข้า `allow` แทน
หรือรัน `/fewer-permission-prompts` ใน Claude Code ให้มันเสนอ allowlist จากสิ่งที่คุณกดอนุญาตไปแล้วจริง ๆ

ของส่วนตัวที่ไม่อยากให้ทีมเห็น ใส่ `.claude/settings.local.json` (`bootstrap-repo.sh` เพิ่มลง `.gitignore` ให้แล้ว)
