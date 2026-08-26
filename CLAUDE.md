# workshop-github

handbook + template + script สำหรับทำให้ทุก repo ของทีมเป็นมาตรฐานเดียวกัน
ใช้ในการอบรมทีม และเป็นแหล่งอ้างอิงหลังอบรมจบ

## คำสั่งที่ใช้บ่อย

```bash
./scripts/validate.sh              # ตรวจทั้ง repo — CI เรียกตัวเดียวกันนี้
./scripts/validate.sh templates    # เฉพาะ YAML/JSON และ gate job
./scripts/check-setup.sh           # ตรวจว่าเครื่องพร้อม (ตัวที่ผู้เข้าอบรมรัน)
```

ต้องมี `python3` + `pyyaml`, `shellcheck`, `gh`, `jq`
ถ้าเครื่องไม่มี shellcheck `validate.sh` จะเตือนแล้วข้ามไป — **แต่ CI จะรันให้ ทำให้ PR แดงได้**

## โครงสร้าง

```
docs/         handbook 8 บท เรียงตามลำดับที่ต้องอ่าน (00 = agenda, 99 = cheatsheet)
templates/    ไฟล์ที่ทีมก๊อปไปใช้กับ repo จริง — พังเมื่อไหร่กระทบทุก repo ที่ก๊อปไปแล้ว
scripts/      เครื่องมือติดตั้ง/ตรวจสอบ ต้องรันได้บนเครื่องคนอื่นด้วย
```

## กติกาของ repo นี้

- **ทุกอย่างเข้าผ่าน PR ที่ CI เขียว** main มี branch protection อยู่ push ตรงเข้าไม่ได้
- **แก้ `templates/github/workflows/ci-*.yml` แล้วห้ามทำให้ job ชื่อ `ci` หายหรือรอ job ไม่ครบ**
  handbook สัญญากับทีมไว้ว่า required status check ชื่อ `ci` ใช้ได้กับทุก template —
  ถ้าผิดสัญญา คนที่ก๊อปไปตั้ง branch protection จะเจอ PR ค้างโดยไม่รู้สาเหตุ
  (`validate.sh templates` ตรวจข้อนี้ให้)
- **repo นี้เป็น public** ห้ามมีอีเมลจริง ชื่อ org จริง IP หรือ token
  ตัวอย่างให้ใช้ `myorg`, `you@company.com`, `example.com` เท่านั้น
- **ตัวอย่างคำสั่งในเอกสารต้องรันได้จริง** ก่อนเขียนลงไปให้ลองรันก่อน
  โดยเฉพาะ `gh api` ที่ path เปลี่ยนบ่อย — เอกสารที่คำสั่งพังทำให้คนเลิกเชื่อทั้งเล่ม
- แก้เอกสารแล้วเช็คลิงก์ด้วย `./scripts/validate.sh docs`

## เขียนเอกสารแบบไหน

ผู้อ่านคือคนในทีมที่กำลังรีบ ไม่ใช่คนที่อยากเรียนทฤษฎี

- บอก**ผลจริงที่จะเกิด** ไม่ใช่บอกว่าควรทำเพราะเป็น best practice
- ทุกหัวข้อจบด้วยคำสั่งที่ก๊อปไปวางได้ หรือ checklist ที่ติ๊กได้
- ตารางชนะย่อหน้า เมื่อเนื้อหาเป็นการเทียบหรือแจกแจง
- ภาษาไทย ยกเว้นศัพท์เทคนิคที่แปลแล้วงงกว่าเดิม (PR, branch, commit, merge)

## ข้อตกลงการทำงาน

- งานที่แตะเกิน 2 ไฟล์ → plan mode ก่อน
- ห้าม `git push`, `gh pr merge` — คนกดเอง
- commit ตาม Conventional Commits (`docs:` `ci:` `fix:` `chore:`)
- รัน `./scripts/validate.sh` ให้เขียวก่อนเปิด PR เสมอ

## ที่ยังไม่มี

- `CODEOWNERS` — ยังไม่ใส่เพราะ repo มีคนเดียว ใส่ไปก็ไม่มีผล (approve PR ตัวเองไม่ได้)
  เพิ่มเมื่อมีคนที่สอง พร้อมเปลี่ยน ruleset เป็น `--approvals 1 --checks ci`
