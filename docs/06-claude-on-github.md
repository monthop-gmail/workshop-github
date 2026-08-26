# 06 — ให้ Claude ทำงานบน GitHub

บทนี้เป็น **ของเสริม** ไม่ใช่ของจำเป็น ทำ [02](02-claude-code-workflow.md)–[05](05-multi-repo.md) ให้อยู่ตัวก่อน

สิ่งที่ได้: เรียก `@claude` ใน PR/issue ได้ และให้มันรีวิว PR ให้อัตโนมัติ

---

## 6.1 เตรียม

ต้องมี API key จาก [console.anthropic.com](https://console.anthropic.com) แล้วตั้งเป็น secret

```bash
# ระดับ org — ทำครั้งเดียว ใช้ได้ทุก repo (แนะนำ)
gh secret set ANTHROPIC_API_KEY --org myorg --visibility selected --repos my-service

# หรือระดับ repo
gh secret set ANTHROPIC_API_KEY --repo myorg/my-service
```

> ค่าใช้จ่ายคิดตาม token ที่ใช้จริง เปิดกับทุก PR ของทุก repo แล้วบิลจะโตเร็วกว่าที่คิด
> เริ่มจาก repo เดียวก่อน ดูตัวเลขหนึ่งสัปดาห์ แล้วค่อยขยาย

---

## 6.2 เรียก `@claude` ใน PR / issue

ก๊อป [`templates/github/workflows/claude.yml`](../templates/github/workflows/claude.yml) ไปที่ `.github/workflows/`

หลังจากนั้นพิมพ์ในคอมเมนต์ของ issue หรือ PR ได้เลย:

```
@claude อธิบายหน่อยว่าฟังก์ชัน calculate_vat ตรงนี้จัดการเศษสตางค์ยังไง

@claude PR นี้ทำ test ตกที่ test_order_total ช่วยดูให้หน่อยว่าเพราะอะไร
```

มันจะอ่าน context ของ PR/issue นั้น ทำงาน แล้วตอบกลับในคอมเมนต์
ถ้าให้แก้โค้ด มันจะ push ขึ้น branch ของ PR นั้น — **ยังต้องผ่านรีวิวและ CI ตามปกติ**

---

## 6.3 รีวิว PR อัตโนมัติ

ก๊อป [`templates/github/workflows/claude-pr-review.yml`](../templates/github/workflows/claude-pr-review.yml)

มันจะรีวิวทุก PR ที่เปิดใหม่หรือ push เพิ่ม แล้วคอมเมนต์แบบ inline

**ปรับให้เข้ากับทีมก่อนใช้:**

- แก้ `prompt:` ให้ตรงกับสิ่งที่ทีมสนใจจริง ๆ (default ในไฟล์เน้น correctness + security + ผลกระทบข้าม repo)
- ถ้า PR เยอะ ให้จำกัดด้วย `paths:` เฉพาะโฟลเดอร์สำคัญ เช่น `api/**`, `migrations/**`
- ข้าม PR ของ bot ด้วย `if: github.event.pull_request.user.type != 'Bot'` (ไม่งั้นเสียเงินรีวิว dependabot ทุกอัน)

**สิ่งที่ต้องบอกทีมให้ชัดตั้งแต่วันแรก:**

> คอมเมนต์จาก Claude ไม่ใช่ approval และไม่ใช่ตัวแทนคนรีวิว
> มันช่วยกวาดของง่าย ๆ ออกก่อน เพื่อให้คนไปโฟกัสเรื่องที่ต้องใช้ context ของธุรกิจ

ถ้าทีมเริ่มกด approve เพราะ "Claude บอกว่าโอเค" ให้ปิดทิ้งทันที — มันกำลังทำให้แย่ลง ไม่ใช่ดีขึ้น

---

## 6.4 ความปลอดภัย

1. **repo private เท่านั้น** สำหรับตอนเริ่ม — บน public repo ใครก็ได้เปิด issue ที่มีคำสั่งหลอกให้ agent ทำตาม (prompt injection)
2. **อย่าตั้ง `allowed_bots: "*"`** — เท่ากับให้ App ภายนอกสั่ง agent ของคุณได้
3. **ให้ `permissions:` เท่าที่จำเป็น** — workflow รีวิวไม่ต้องมี `contents: write`
4. **ห้ามใช้ `pull_request_target`** กับ workflow ที่รัน Claude
5. **จำกัดเครื่องมือ** ด้วย `claude_args: --allowedTools "..."` — workflow รีวิวไม่ควรรันอะไรได้นอกจากอ่าน diff และคอมเมนต์
6. ทบทวน log ใน Actions ช่วงสัปดาห์แรก ดูว่ามันรันคำสั่งอะไรบ้างจริง ๆ

---

## 6.5 เมื่อไหร่ที่ไม่ควรใช้

- repo ที่มีข้อมูลลูกค้าใน fixture/seed — diff จะถูกส่งออกไปประมวลผล
- repo ที่ CI ยังไม่นิ่ง — แก้ CI ให้เขียวก่อน อย่าเพิ่มตัวแปร
- ทีมที่ยังไม่มีวินัยรีวิว — เครื่องมือจะกลายเป็นข้ออ้างไม่รีวิว

---

ถัดไป → [99 — Cheatsheet](99-cheatsheet.md)
