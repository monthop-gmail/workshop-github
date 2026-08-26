# Workshop: Claude Code + GitHub

คู่มือ + ชุด template สำหรับทีม เพื่อให้ทุก repo ทำงานด้วยมาตรฐานเดียวกัน และใช้ Claude Code
อย่างที่ควบคุมผลลัพธ์ได้จริง ไม่ใช่ "สั่งแล้วหวังว่ามันจะถูก"

## ปัญหาที่ repo นี้แก้

| อาการที่เจอ | สาเหตุจริง | แก้ที่ |
| --- | --- | --- |
| Claude แก้โค้ดเกินที่สั่ง / ผิด convention ของ repo | ไม่มี `CLAUDE.md` ให้มันอ่าน | [docs/02](docs/02-claude-code-workflow.md) |
| PR ใหญ่จนไม่มีใครกล้ารีวิว | ไม่มีข้อตกลงเรื่องขนาด PR | [docs/03](docs/03-branch-pr-review.md) |
| โค้ดพังบน main แต่บนเครื่องผ่าน | ไม่มี CI เป็น required check | [docs/04](docs/04-ci-branch-protection.md) |
| repo A แก้แล้ว repo B พังโดยไม่มีใครรู้ | ไม่มี CODEOWNERS / ไม่มี contract | [docs/05](docs/05-multi-repo.md) |
| แต่ละ repo ตั้งค่าไม่เหมือนกัน | ตั้งค่าด้วยมือทีละ repo | [scripts/](scripts/) |

## เริ่มยังไง

**ถ้าคุณเป็นผู้เข้าร่วม workshop** — อ่าน [docs/01-setup.md](docs/01-setup.md) ให้เครื่องพร้อมก่อนวันงาน
แล้วค่อยไล่ `docs/02` → `docs/05` ตามลำดับ

**ถ้าคุณเป็นคนจัด** — เริ่มที่ [docs/00-agenda.md](docs/00-agenda.md)

**ถ้าคุณจะเอาไปใช้กับ repo จริงเลย**

```bash
# 1. ติดตั้ง template ลง repo เป้าหมาย
./scripts/bootstrap-repo.sh --repo ~/work/my-service --stack python

# 2. เปิด branch protection บน main
./scripts/apply-ruleset.sh myorg/my-service --checks ci

# 3. ตรวจว่า repo ไหนในองค์กรยังขาดอะไร
./scripts/audit-repos.sh myorg
```

## สารบัญ

| | เอกสาร | เนื้อหา |
| --- | --- | --- |
| 00 | [Agenda](docs/00-agenda.md) | ตาราง half-day + วิธีคุมแต่ละช่วง (สำหรับคนจัด) |
| 01 | [เตรียมเครื่อง](docs/01-setup.md) | gh, git identity, Claude Code, secret scanning |
| 02 | [ใช้ Claude Code ให้ควบคุมได้](docs/02-claude-code-workflow.md) | CLAUDE.md, plan mode, permission, การจัด context |
| 03 | [Branch / PR / Review](docs/03-branch-pr-review.md) | trunk-based, Conventional Commits, ขนาด PR, วิธีรีวิว |
| 04 | [CI + branch protection](docs/04-ci-branch-protection.md) | gate job, workflow ต่อ stack, rulesets, secrets |
| 05 | [หลาย repo หลายทีม](docs/05-multi-repo.md) | CODEOWNERS, เปลี่ยน contract 3 จังหวะ, audit ทั้ง org |
| 06 | [Claude บน GitHub](docs/06-claude-on-github.md) | `@claude` ใน PR, auto review, ความปลอดภัย (ของเสริม) |
| 99 | [Cheatsheet](docs/99-cheatsheet.md) | คำสั่งที่ใช้ทุกวัน, กู้ของที่พัง, ตารางแก้ปัญหา |

## โครงสร้าง

```
docs/         handbook อ่านเรียงตามลำดับ
templates/    ไฟล์ที่ก๊อปไปวางใน repo จริงได้เลย — ดู templates/README.md
scripts/      เครื่องมือติดตั้ง/ตรวจสอบมาตรฐาน (ต้องมี gh + jq)
              check-setup.sh     ตรวจว่าเครื่องพร้อมไหม
              bootstrap-repo.sh  ติดตั้ง template ลง repo
              apply-ruleset.sh   เปิด branch protection
              audit-repos.sh     สแกนทั้ง org ว่าขาดอะไร
```

## สิ่งที่ต้องมีก่อน

- `git` >= 2.34, [`gh`](https://cli.github.com/) >= 2.40 (login แล้ว), `jq` >= 1.6
- [Claude Code](https://claude.com/claude-code) และ login แล้ว (`claude` แล้วพิมพ์ `/login`)
- สิทธิ์ **admin** บน repo ที่จะตั้ง branch protection (ถ้าไม่มี ให้ข้ามไปหา org admin)

## ข้อตกลงที่ repo นี้ยึด

1. `main` ต้อง deploy ได้ตลอดเวลา — ทุกอย่างเข้าผ่าน PR ที่ CI เขียว
2. PR หนึ่งอัน = การเปลี่ยนแปลงหนึ่งเรื่อง — ไม่เกิน ~400 บรรทัดที่เปลี่ยนจริง
3. Claude เขียนได้ แต่ **คนเป็นคนรับผิดชอบ diff** — ห้าม merge สิ่งที่ตัวเองอ่านไม่รู้เรื่อง
4. Secret ไม่เคยอยู่ในโค้ด — อยู่ใน GitHub Secrets หรือ `.env` ที่ถูก gitignore
