# 03 — Branch / PR / Review

เป้าหมาย: ให้ `main` deploy ได้ตลอดเวลา และ PR ถูกรีวิวได้ภายในวันเดียว

---

## 3.1 Branch strategy: trunk-based

ใช้ `main` เดียว + branch อายุสั้น **ไม่เกิน 2–3 วัน**
ไม่ใช้ git-flow (develop/release/hotfix) เว้นแต่มีการ release แบบมีเวอร์ชันจริง ๆ —
สำหรับทีมที่ deploy จาก main อยู่แล้ว git-flow เพิ่มขั้นตอนโดยไม่ได้เพิ่มความปลอดภัย

```
main ──●────●────────●────●──▶  (deploy ได้ทุก commit)
        \        /      \   /
         ●──●──●         ●─●     branch อายุสั้น
```

**ชื่อ branch**

```
<type>/<issue>-<คำอธิบายสั้น>

feat/142-vat-calculation
fix/158-login-uppercase-email
chore/deps-bump-fastapi
```

ทำไมต้องมีเลข issue: เวลาไล่ย้อนหลังว่า "โค้ดนี้มาจากไหน" จะเจอ context ครบใน issue เดียว

**branch ยิ่งอยู่นาน ยิ่งแพง** — conflict เยอะขึ้น, รีวิวยากขึ้น, ความมั่นใจตอน merge ต่ำลง
ถ้างานใหญ่จนทำ 3 วันไม่เสร็จ ให้แตกเป็นหลาย PR ที่ merge ได้ทีละอัน (ซ่อนของที่ยังไม่เสร็จด้วย feature flag)

---

## 3.2 Commit message: Conventional Commits

```
<type>(<scope>): <ผลลัพธ์ที่ระบบ/ผู้ใช้ได้รับ>

[รายละเอียด — ทำไมถึงแก้แบบนี้ ไม่ใช่แก้อะไร]

Refs: #142
```

| type | ใช้เมื่อ |
| --- | --- |
| `feat` | เพิ่มความสามารถที่ผู้ใช้เห็น |
| `fix` | แก้พฤติกรรมที่ผิด |
| `refactor` | เปลี่ยนโครงสร้างโดยพฤติกรรมเหมือนเดิม |
| `perf` | เร็วขึ้น/กินทรัพยากรน้อยลง โดยพฤติกรรมเหมือนเดิม |
| `test` | เพิ่ม/แก้ test อย่างเดียว |
| `docs` | เอกสารอย่างเดียว |
| `chore` | dependency, config, CI |

```
ดี:    fix(auth): ยอมรับอีเมลที่มีตัวพิมพ์ใหญ่ตอน login
ไม่ดี: fix: update auth.py          ← บอกไฟล์ ไม่ได้บอกผลลัพธ์
ไม่ดี: fix: แก้บั๊ก                  ← ไม่บอกอะไรเลย
```

Breaking change ใส่ `!` และอธิบาย: `feat(api)!: เปลี่ยน field 'name' เป็น 'full_name'`
บรรทัดนี้สำคัญมากในบริบทหลาย repo — ดู [05](05-multi-repo.md)

---

## 3.3 ขนาด PR

| บรรทัดที่เปลี่ยน | ผลจริงที่เกิด |
| --- | --- |
| < 200 | รีวิวละเอียดได้ เจอบั๊กจริง |
| 200–400 | ยังไหว แต่คนรีวิวเริ่มอ่านข้าม |
| > 400 | ได้ approve แบบไม่ได้อ่าน — เท่ากับไม่มีรีวิว |

**เพดานของทีม: 400 บรรทัด** (ไม่นับไฟล์ที่ generate เช่น lock file, migration ที่ tool สร้าง)

ถ้าเกิน ให้แตกตามนี้:
1. PR แรก: refactor/เตรียมทาง โดยพฤติกรรมไม่เปลี่ยน
2. PR ที่สอง: ตรรกะใหม่
3. PR ที่สาม: ต่อสายเข้ากับของเดิม

เช็คขนาดก่อนเปิด PR:

```bash
git diff main...HEAD --stat | tail -1
```

---

## 3.4 เปิด PR

```bash
git switch -c feat/142-vat-calculation
# ...ทำงาน, commit...
git push -u origin HEAD
gh pr create --fill --base main
gh pr view --web
```

PR template จะถูกเติมให้อัตโนมัติถ้ามีไฟล์ [`templates/github/PULL_REQUEST_TEMPLATE.md`](../templates/github/PULL_REQUEST_TEMPLATE.md) อยู่ใน repo

เปิดเป็น draft ถ้ายังไม่พร้อมรีวิว: `gh pr create --draft`
**อย่าเปิด PR ทิ้งไว้แล้วบอกทีหลังว่ายังไม่เสร็จ** — คนรีวิวเสียเวลาไปแล้ว

### สิ่งที่ PR description ต้องตอบให้ได้

1. **ทำไม** ต้องมีการเปลี่ยนแปลงนี้ (ลิงก์ issue)
2. **ทำอะไร** ในระดับที่คนไม่ได้อยู่ในหัวคุณเข้าใจ
3. **ทดสอบยังไง** — คนรีวิวต้องทำตามได้
4. **มีอะไรที่คนอื่นต้องรู้** — ต้องรัน migration ไหม, ต้องเพิ่ม env var ไหม, กระทบ repo อื่นไหม

---

## 3.5 รีวิว

### คนเขียนต้องทำก่อนขอรีวิว

- [ ] อ่าน diff ของตัวเองใน GitHub (คนละสายตากับตอนอ่านใน editor)
- [ ] CI เขียว
- [ ] ไม่มี debug log / commented-out code / `TODO` ค้าง
- [ ] PR description ตอบครบ 4 ข้อข้างบน

ให้ Claude ช่วยรอบแรกได้:

```bash
claude
> /code-review          # หาบั๊กใน diff ปัจจุบัน
> /security-review      # ตรวจช่องโหว่
```

มันจะเจอของง่าย ๆ ที่ทำให้คนรีวิวต้องเสียเวลาคอมเมนต์ — **แต่ไม่ใช่ตัวแทนคนรีวิว**

### คนรีวิวดูอะไร

เรียงตามลำดับความสำคัญ อย่าเริ่มจากล่าง:

1. **ถูกต้องไหม** — edge case: null, empty, ค่าติดลบ, ข้อมูลใหญ่, เรียกซ้อน
2. **ปลอดภัยไหม** — input จากภายนอกถูก validate, ไม่มี SQL ต่อ string, ไม่มี secret
3. **พังของเดิมไหม** — เปลี่ยน API/schema/พฤติกรรมที่ repo อื่นใช้อยู่หรือเปล่า
4. **แก้ต่อได้ไหม** — คนที่ไม่ได้เขียนจะเข้าใจใน 6 เดือนไหม
5. **สไตล์** — ให้ linter ตรวจ อย่าเสียเวลาคนคอมเมนต์เรื่อง format

### เขียนคอมเมนต์ยังไงให้ไม่เสียเวลาทั้งสองฝ่าย

ติดป้ายระดับความสำคัญเสมอ:

```
blocking: ตรงนี้ถ้า orders ว่างจะ IndexError — เพิ่ม guard ก่อน
suggestion: ใช้ dict comprehension จะสั้นกว่า แต่ไม่ merge ก็ได้
question: ทำไมต้อง retry 5 รอบ มีเหตุผลอะไรเป็นพิเศษไหม
nit: ชื่อ `d` อ่านยาก
```

คนเขียนจะได้รู้ว่าอันไหนต้องแก้ อันไหนคุยได้ — ไม่ต้องเดา

### ตอบคอมเมนต์

```bash
gh pr view 142 --comments        # อ่านคอมเมนต์ทั้งหมดจาก terminal
```

แก้แล้ว push ตามปกติ แล้ว **ตอบทุกคอมเมนต์** ว่าแก้ยังไง หรือทำไมไม่แก้
กด resolve ได้เฉพาะเมื่อจัดการเรียบร้อยแล้ว

---

## 3.6 Merge

**ใช้ squash merge อย่างเดียว** — ประวัติบน main สะอาด 1 PR = 1 commit ย้อนกลับง่าย

```bash
gh pr merge 142 --squash --delete-branch
```

ตรวจ commit message ตอน squash ด้วย — GitHub จะเอา PR title มาใช้ ต้องอยู่ในรูป Conventional Commits

หลัง merge:
```bash
git switch main && git pull --prune
```

ถ้า merge แล้วพัง: **revert ก่อน แก้ทีหลัง**

```bash
gh pr view 142 --json mergeCommit --jq .mergeCommit.oid
git revert -m 1 <sha> && git push
```

อย่าพยายาม hotfix บน main ตอนที่ยังไม่รู้สาเหตุ

---

## แบบฝึกหัด (จับคู่, 30 นาที)

1. แต่ละคนเปิด PR ใน repo playground — เปลี่ยนจริงไม่เกิน 30 บรรทัด ใช้ PR template
2. สลับกันรีวิว **ต้องมีอย่างน้อย 1 คอมเมนต์ `blocking:`**
3. คนเขียนแก้ตามคอมเมนต์ แล้วตอบทุกอัน
4. squash merge แล้วลบ branch
5. คุยกันว่ารอบนี้ใช้เวลาเท่าไหร่ ติดตรงไหน

---

ถัดไป → [04 — CI + branch protection](04-ci-branch-protection.md)
