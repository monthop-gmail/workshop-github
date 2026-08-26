# 05 — หลาย repo หลายทีม

ปัญหาที่บทนี้แก้: **repo A แก้แล้ว repo B พัง โดยไม่มีใครรู้จนกว่าลูกค้าจะโทรมา**

---

## 5.1 วาดแผนที่ก่อน

ก่อนจะแก้อะไร ต้องรู้ว่าตอนนี้ repo ไหนพึ่งพาใครอยู่ ทำครั้งเดียวแล้วเก็บไว้ที่เดียว

สร้าง `docs/dependencies.md` ใน repo กลางของทีม (repo นี้ก็ได้) หน้าตาแบบนี้:

```markdown
| repo | เรียกใคร | ถูกใครเรียก | ช่องทาง | เจ้าของ |
| --- | --- | --- | --- | --- |
| api-gateway | auth-service, order-service | web-app, mobile | HTTP | @team-platform |
| order-service | odoo-connector | api-gateway | HTTP + DB ร่วม | @team-backend |
| odoo-connector | — | order-service | XML-RPC | @team-erp |
```

คอลัมน์ **"ถูกใครเรียก"** คือคอลัมน์ที่สำคัญที่สุด — มันตอบคำถาม
"ถ้าฉันเปลี่ยนตรงนี้ ต้องไปบอกใครบ้าง" ซึ่งเป็นคำถามที่ทุกคนถามสาย

แล้วเขียนลงใน `CLAUDE.md` ของแต่ละ repo เป็นบรรทัดเดียว:

```markdown
## ความสัมพันธ์กับ repo อื่น
- service นี้ถูกเรียกโดย `api-gateway` ผ่าน HTTP — เปลี่ยน response schema = breaking change
- เรียก `odoo-connector` ผ่าน XML-RPC — ถ้า field ฝั่งนั้นเปลี่ยน ต้องแก้ `adapters/odoo.py`
```

บรรทัดนี้ทำให้ Claude เตือนคุณเองตอนที่คุณกำลังจะเปลี่ยน contract โดยไม่ทันคิด

---

## 5.2 CODEOWNERS — ให้คนที่ต้องรู้ ได้รู้

วางที่ `.github/CODEOWNERS` แล้วเปิด `require_code_owner_review` ใน ruleset ([04](04-ci-branch-protection.md))
คนใน CODEOWNERS จะถูกใส่เป็น reviewer อัตโนมัติทุกครั้งที่ไฟล์ในความดูแลถูกแตะ

```
# บรรทัดล่างชนะบรรทัดบน — ตัวที่เจาะจงที่สุดต้องอยู่ล่างสุด
*                       @myorg/team-backend

/.github/               @myorg/team-platform
/infra/                 @myorg/team-platform
/migrations/            @myorg/team-backend @myorg/team-data
/api/schemas/           @myorg/team-backend @myorg/team-frontend
/addons/account_*/      @myorg/team-erp
```

หลักการตั้ง:
- ใช้ **team** ไม่ใช่ชื่อคน — คนลาออก/ลาพักได้ ทีมไม่หายไป
- ใส่เจ้าของให้ **จุดที่เป็น contract ระหว่างทีม** (schema, API, migration, infra) ไม่ต้องใส่ทุกโฟลเดอร์
- ถ้าใส่แล้วทีมหนึ่งกลายเป็นคอขวดของทุก PR แปลว่าเจาะจงเกินไป ถอยออกมาหนึ่งชั้น

ตรวจว่าไฟล์ถูกต้อง (syntax ผิดจะเงียบ ไม่มี error):

```bash
gh api repos/myorg/my-service/codeowners/errors --jq '.errors'
```

---

## 5.3 เปลี่ยน contract โดยไม่ทำใครพัง

ห้ามเปลี่ยนแล้วปล่อย ให้ทำเป็นสามจังหวะเสมอ:

```
จังหวะ 1 (PR ใน repo ผู้ให้บริการ)
  เพิ่มของใหม่ ให้ของเก่ายังทำงานได้เหมือนเดิม
  → deploy ได้ทันที ไม่มีใครพัง

จังหวะ 2 (PR ในทุก repo ผู้เรียก)
  ย้ายไปใช้ของใหม่ทีละ repo
  → เปิด issue ค้างไว้ในแต่ละ repo ผู้เรียก ให้เห็นว่าใครยังไม่ย้าย

จังหวะ 3 (PR ใน repo ผู้ให้บริการ)
  ลบของเก่า — หลังจากยืนยันแล้วว่าไม่มีใครเรียกแล้ว
  → เว้นอย่างน้อย 2 สัปดาห์ หรือ 1 sprint
```

ตัวอย่างจังหวะ 1 ที่ทำถูก:

```python
class OrderResponse(BaseModel):
    name: str | None = Field(None, deprecated=True)  # ลบได้หลัง 2026-09-15 — ดู #241
    full_name: str

    @model_validator(mode="after")
    def _mirror_legacy_name(self) -> "OrderResponse":
        if self.name is None:
            self.name = self.full_name
        return self
```

**ใส่วันที่ลบจริงใน comment เสมอ** ไม่ใช่ `# TODO: remove later` — คำว่า later ไม่เคยมาถึง

### ผูก PR ข้าม repo ให้ตามกันเจอ

ในทุก PR ที่เกี่ยวข้อง เขียนอ้างถึงกันด้วย full path:

```markdown
## Related
- ต้อง merge หลัง myorg/order-service#241
- ผู้เรียกที่ต้องย้าย: myorg/api-gateway#88, myorg/web-app#132
```

GitHub จะสร้างลิงก์ให้อัตโนมัติทั้งสองฝั่ง — เปิดอันไหนก็เห็นอันที่เหลือ

หา repo ที่เรียกโค้ดของเราอยู่:

```bash
gh search code 'OrderResponse' --owner myorg --limit 50 --json repository,path \
  --jq '.[] | "\(.repository.nameWithOwner)  \(.path)"' | sort -u
```

---

## 5.4 ทำให้ทุก repo ตั้งค่าเหมือนกัน

ปัญหาไม่ใช่ "ไม่รู้ว่าต้องตั้งอะไร" แต่คือ "ตั้งด้วยมือ 14 repo แล้วมันเพี้ยน"

**ตรวจว่าตอนนี้ขาดอะไรบ้าง:**

```bash
./scripts/audit-repos.sh myorg
```

ได้ตารางแบบนี้ออกมา (เอาไปแปะใน issue ได้เลย):

```
| repo            | CLAUDE.md | CODEOWNERS | PR tmpl | CI | ruleset |
| --------------- | --------- | ---------- | ------- | -- | ------- |
| api-gateway     | yes       | yes        | yes     | yes| yes     |
| order-service   | yes       | no         | yes     | yes| no      |
| odoo-connector  | no        | no         | no      | no | no      |
```

**เติมส่วนที่ขาด:**

```bash
./scripts/bootstrap-repo.sh --repo ~/work/odoo-connector --stack python
cd ~/work/odoo-connector
git switch -c chore/adopt-team-standards
git add -A && git commit -m 'chore: adopt team GitHub standards'
gh pr create --fill
```

### ตั้ง ruleset ระดับ org (ถ้ามีสิทธิ์)

ถ้าเป็น org (ไม่ใช่บัญชีส่วนตัว) ตั้งครั้งเดียวครอบทุก repo ได้ ไม่ต้องไล่ทีละอัน:

```bash
gh api -X POST orgs/myorg/rulesets --input templates/rulesets/org-main-protection.json
```

ข้อควรรู้: กฎระดับ org **บวกเพิ่ม**กับกฎระดับ repo ไม่ได้ทับกัน — repo เข้มกว่าได้ แต่หย่อนกว่าไม่ได้
เริ่มด้วย `"enforcement": "evaluate"` เพื่อดูผลก่อนบังคับจริง แล้วค่อยเปลี่ยนเป็น `"active"`

> ⚠️ **บนแผนฟรี กฎจะมีผลกับ public repo เท่านั้น** — private repo ต้องมีแผน Team ขึ้นไป
> ดูตารางเต็มว่าอะไรใช้ได้บ้างตาม visibility และประเภทบัญชีที่
> [04 — ข้อจำกัดตามแผนและ visibility](04-ci-branch-protection.md)

---

## 5.5 ใช้ Claude Code กับหลาย repo

**หนึ่ง session ต่อหนึ่ง repo** อย่าเปิด session เดียวแล้วให้มันเดินข้ามหลาย repo
context จะปนกัน แล้วมันจะเอา pattern ของ repo หนึ่งไปใส่อีก repo หนึ่ง

วิธีที่ใช้ได้จริงเมื่อต้องแก้พร้อมกันหลาย repo:

1. **repo ผู้ให้บริการก่อน** — session แรก ทำจังหวะ 1 ให้จบ เปิด PR
2. **สรุป contract ใหม่เป็นข้อความ** ให้ Claude เขียนสรุปสั้น ๆ ว่า field ไหนเปลี่ยนเป็นอะไร
3. **repo ผู้เรียกแต่ละอัน** — เปิด session ใหม่ต่อ repo วางสรุปจากข้อ 2 ลงไปเป็น context

ข้อ 2 คือขั้นที่คนข้าม แล้วต้องมาเล่าเรื่องเดิมซ้ำทุก session

ถ้าอยากให้ agent มองเห็นหลาย repo จริง ๆ ให้ clone มาไว้โฟลเดอร์เดียวกันแล้วเปิด session ที่โฟลเดอร์แม่
— แต่ยอมรับว่ามันจะช้าและเปลืองกว่ามาก ใช้เฉพาะตอนสำรวจ ไม่ใช่ตอนแก้

---

## แบบฝึกหัด (40 นาที)

1. รัน `./scripts/audit-repos.sh <org ของทีม>` — ดูตารางร่วมกัน
2. เลือก repo ที่ "โล่งที่สุด" 1 อัน แล้ว bootstrap + เปิด PR สด
3. เขียน `.github/CODEOWNERS` ให้ repo นั้น โดยตกลงกันในห้องว่าใครดูแลอะไร
4. วาด `docs/dependencies.md` ของทีมให้ได้อย่างน้อย 5 แถว
5. เอาตาราง audit ไปเปิดเป็น issue พร้อมชื่อคนรับผิดชอบต่อบรรทัด

---

ถัดไป → [06 — ให้ Claude ทำงานบน GitHub](06-claude-on-github.md)
