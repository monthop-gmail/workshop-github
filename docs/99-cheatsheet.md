# 99 — Cheatsheet & แก้ปัญหาเฉพาะหน้า

---

## คำสั่งที่ใช้ทุกวัน

```bash
# เริ่มงานใหม่
git switch main && git pull --prune
git switch -c feat/142-vat-calculation

# ระหว่างทำ
git status
git diff                       # ที่ยังไม่ stage
git diff --staged              # ที่จะ commit
git diff main...HEAD --stat    # ภาพรวมทั้ง branch (จุด 3 จุด = เทียบกับจุดที่แตกออกมา)

# เปิด PR
git push -u origin HEAD
gh pr create --fill --base main
gh pr view --web

# ระหว่างรอรีวิว
gh pr checks                   # CI ผ่านหรือยัง
gh pr view --comments          # อ่านคอมเมนต์
gh pr diff                     # ดู diff ของ PR ใน terminal

# ปิดงาน
gh pr merge --squash --delete-branch
git switch main && git pull --prune
```

## `gh` ที่คนไม่ค่อยรู้

```bash
gh pr list --search "review-requested:@me"    # PR ที่รอเรารีวิว
gh pr list --author "@me" --state open        # PR ของเราที่ยังค้าง
gh pr checks 142 --watch                      # เฝ้า CI จนจบ
gh run view --log-failed                      # ดู log เฉพาะ step ที่แดง
gh run rerun --failed                         # รันซ้ำเฉพาะ job ที่แดง
gh search code 'OrderResponse' --owner myorg  # หาว่าใครใช้โค้ดเราอยู่
gh api repos/O/R/codeowners/errors            # ตรวจ CODEOWNERS ว่า syntax ถูกไหม
gh browse -n .github/workflows/ci.yml         # เปิดไฟล์นี้บนเว็บ
```

---

## แก้ประวัติ commit

**กฎเหล็ก: แก้ประวัติได้เฉพาะ branch ที่ยังไม่มีใครอื่น pull ไป**

```bash
# แก้ข้อความ commit ล่าสุด
git commit --amend -m 'fix(auth): ยอมรับอีเมลตัวพิมพ์ใหญ่'

# ลืมไฟล์ใน commit ล่าสุด
git add ไฟล์ที่ลืม && git commit --amend --no-edit

# commit ขึ้นชื่อ/อีเมลผิด (แก้เฉพาะ commit ล่าสุด)
git config user.email "you@company.com"
git commit --amend --reset-author --no-edit

# หลัง amend ต้อง force push — ใช้ --force-with-lease เสมอ
git push --force-with-lease
```

`--force-with-lease` จะไม่ยอม push ถ้ามีคนอื่น push เข้ามาก่อน ต่างจาก `--force` ที่ทับทิ้งหมด
**อย่าใช้ `--force` เปล่า ๆ กับ branch ที่แชร์กัน**

## ยกเลิกสิ่งที่ทำไปแล้ว

```bash
git restore ไฟล์.py                    # ทิ้งการแก้ที่ยังไม่ stage
git restore --staged ไฟล์.py           # เอาออกจาก stage แต่เก็บการแก้ไว้
git reset --soft HEAD~1                # ยกเลิก commit ล่าสุด เก็บโค้ดไว้
git reset --hard origin/main           # ทิ้งทุกอย่าง กลับไปเท่า remote (โค้ดที่ไม่ commit หายถาวร)

# บน main ที่ push ไปแล้ว: revert เท่านั้น ห้าม reset
git revert <sha>                       # commit ปกติ
git revert -m 1 <merge-sha>            # merge commit (จาก squash merge ก็ใช้อันบน)
```

## กู้ของที่คิดว่าหายแล้ว

```bash
git reflog                             # ทุกจุดที่ HEAD เคยอยู่ 90 วันย้อนหลัง
git switch -c กู้มา <sha-จาก-reflog>
```

reflog กู้ได้เกือบทุกอย่างที่เคย commit — สิ่งที่กู้ไม่ได้คือของที่ไม่เคย commit เลย

---

## เจอปัญหานี้ ทำแบบนี้

| อาการ | สาเหตุ | ทางแก้ |
| --- | --- | --- |
| `refusing to allow an OAuth App to create or update workflow` | token ไม่มี scope `workflow` | `gh auth refresh -h github.com -s workflow` |
| push แล้วขึ้น `protected branch hook declined` | กำลัง push ตรงเข้า main | ถูกแล้ว — เปิด branch + PR |
| PR merge ไม่ได้ ปุ่มเทา ทั้งที่ CI เขียว | มี review thread ที่ยังไม่ resolve / branch ไม่ up-to-date | resolve ให้หมด แล้ว `gh pr update-branch 142` |
| เปิด PR แล้วไม่มี check ขึ้นเลย (repo เพิ่งสร้าง) | GitHub ยังไม่ register workflow เพราะยังไม่เคยมีบน default branch | merge workflow เข้า main รอบแรกก่อน แล้วค่อยตั้ง required check — ดู [04](04-ci-branch-protection.md) |
| required check ค้าง "Expected — Waiting for status" | ชื่อ check ใน ruleset ไม่ตรงกับชื่อ job จริง | เทียบชื่อกับ `gh pr checks` แล้วแก้ ruleset — ดู [04](04-ci-branch-protection.md) |
| CI ผ่านบนเครื่อง แต่แดงบน GitHub | เวอร์ชัน runtime / env var ต่างกัน | pin เวอร์ชันใน workflow ให้ตรงกับ local แล้วดู `gh run view --log-failed` |
| commit ไม่ขึ้น contribution graph | `user.email` ไม่ตรงกับอีเมลที่ verified บน GitHub | ดู [01](01-setup.md) |
| CODEOWNERS ตั้งแล้วไม่มีผล | syntax ผิด / team ไม่มีสิทธิ์บน repo | `gh api repos/O/R/codeowners/errors` |
| merge conflict ใน lock file | ทั้งสอง branch เพิ่ม dependency | `git checkout --theirs package-lock.json` แล้ว **รัน install ใหม่** อย่าแก้ lock file ด้วยมือ |
| Claude แก้ไฟล์ที่ไม่เกี่ยว | context เก่าค้าง / ไม่มี CLAUDE.md | `/clear` แล้วสั่งใหม่พร้อมระบุไฟล์ด้วย `@path` |
| Claude ลืมสิ่งที่ตกลงกันไปเมื่อกี้ | context ยาวเกิน | `/compact` หรือ `/clear` แล้วเริ่มใหม่ — และเขียนกติกาลง `CLAUDE.md` |

---

## Claude Code ที่ใช้บ่อย

| คำสั่ง | ทำอะไร |
| --- | --- |
| `Shift+Tab` | สลับโหมด → plan mode |
| `/clear` | ล้าง context เริ่มงานใหม่ |
| `/compact` | ย่อ context เก็บบทสรุป |
| `/context` | ดูว่าอะไรกิน context อยู่ |
| `/init` | สร้างร่าง `CLAUDE.md` |
| `#` | เพิ่มกติกาลง memory |
| `@path/to/file` | ใส่ไฟล์เข้า context |
| `!command` | รันคำสั่ง shell แล้วเอา output เข้า context |
| `/model` | ดู/เปลี่ยน model |
| `/permissions` | ดู/แก้ allowlist |
| `/code-review` | รีวิว diff ปัจจุบัน |
| `/security-review` | ตรวจช่องโหว่ใน diff |
| `Esc` | หยุดกลางคัน |
| `Esc Esc` | ย้อนกลับไปแก้ prompt ก่อนหน้า |

---

## เมื่อไม่แน่ใจ

1. `git status` ก่อนเสมอ
2. ถ้าจะทำอะไรที่ย้อนยาก — สร้าง branch สำรองไว้ก่อน: `git branch backup/$(date +%F)`
3. ถามในแชททีม ดีกว่า force push ทับงานคนอื่น
