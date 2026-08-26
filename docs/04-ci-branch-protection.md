# 04 — CI + Branch Protection

เป้าหมาย: ทำให้ "โค้ดพังเข้า main" เป็นสิ่งที่**ทำไม่ได้** ไม่ใช่สิ่งที่ขอความร่วมมือกันไม่ให้ทำ

ต้องมีสิทธิ์ **admin** บน repo ถ้าไม่มี ให้จดชื่อ repo ไว้ไปคุยกับ org admin

---

## 4.1 ลำดับที่ถูกต้อง

```
1. เขียน CI ให้เขียวบน branch ก่อน
2. ค่อยตั้ง required check
```

ถ้าตั้ง required check ก่อนที่ CI จะเสถียร ทีมจะติดแหง็ก merge อะไรไม่ได้เลย
แล้วคนจะขอปิด protection ทิ้ง — จบเห่

---

## 4.2 ปัญหาที่ทุกคนเจอ: ชื่อ check ไม่นิ่ง

Branch protection อ้างอิง check ด้วย**ชื่อ** ถ้า workflow ใช้ matrix ชื่อจะกลายเป็น
`test (3.10)`, `test (3.12)` — พอเพิ่ม/ลด version ในอนาคต ชื่อเปลี่ยน required check ก็พัง

**วิธีแก้: gate job** — มี job สุดท้ายชื่อ `ci` ที่รอทุก job แล้วสรุปผล
required check มีอันเดียวชื่อ `ci` ตลอดไป ไม่ว่าข้างในจะเปลี่ยนกี่รอบ

```yaml
  ci:
    if: always()
    needs: [lint, test]
    runs-on: ubuntu-latest
    steps:
      - name: Gate
        run: |
          if ${{ contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled') }}; then
            echo "::error::มี job ก่อนหน้าไม่ผ่าน"
            exit 1
          fi
```

`if: always()` จำเป็น — ไม่งั้น job นี้จะถูก skip เมื่อ job ก่อนหน้าแดง
และ check ที่ถูก skip จะถูกนับว่า "รอผลอยู่" ทำให้ PR ค้างแทนที่จะแดง

---

## 4.3 Workflow ตาม stack

ก๊อปไฟล์ที่ตรงกับ repo ไปวางที่ `.github/workflows/ci.yml` (หรือใช้ `scripts/bootstrap-repo.sh`)

| Stack | ไฟล์ | ทำอะไร |
| --- | --- | --- |
| Python / FastAPI / script | [`ci-python.yml`](../templates/github/workflows/ci-python.yml) | ruff check + format check, pytest หลาย version |
| Node / TypeScript | [`ci-node.yml`](../templates/github/workflows/ci-node.yml) | `npm ci` + lint + typecheck + test + build |
| Docker / infra / config | [`ci-docker.yml`](../templates/github/workflows/ci-docker.yml) | hadolint, `docker compose config`, build image |

ทุกไฟล์มีร่วมกัน:

```yaml
permissions:
  contents: read            # ให้สิทธิ์น้อยที่สุด แล้วค่อยเพิ่มเมื่อจำเป็น
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true  # push ซ้ำแล้วยกเลิกรอบเก่า ประหยัด runner
```

### กรณี Odoo

Odoo module test ต้องมี Odoo + PostgreSQL จริง ๆ รันด้วย `odoo -d test --test-enable -i <module> --stop-after-init`
ซึ่งขึ้นกับเวอร์ชัน Odoo และ addons path ของแต่ละ repo — `ci-python.yml` เลย**ไม่รวม**ส่วนนี้ไว้

สิ่งที่ทำได้เลยโดยไม่ต้องยก Odoo ขึ้นมา และคุ้มที่สุด:
- `ruff check` — จับ import ที่ไม่ได้ใช้, ตัวแปรที่พิมพ์ผิด, syntax error
- ตรวจว่า `__manifest__.py` parse ได้และ `depends` ไม่ว่าง (มีใน `ci-python.yml` เป็น step แยก)
- ตรวจว่าไฟล์ XML ทุกไฟล์ well-formed

ถ้าจะรัน Odoo test จริงใน CI ให้เพิ่ม `services: postgres:` แล้วรัน Odoo จาก image ที่ทีมใช้อยู่จริง
อย่าลอกจากตัวอย่างบนอินเทอร์เน็ตที่ pin Odoo คนละเวอร์ชันกับ production

---

## 4.4 ตั้ง branch protection

ใช้ **Rulesets** (ของใหม่) ไม่ใช่ branch protection แบบเดิม — เพราะ ruleset ตั้งระดับ org ได้
และเห็นชัดว่ากฎไหนมาจากไหน

```bash
./scripts/apply-ruleset.sh myorg/my-service --checks ci
```

กฎที่ script ตั้งให้ ([`templates/rulesets/main-protection.json`](../templates/rulesets/main-protection.json)):

| กฎ | ผลจริง |
| --- | --- |
| `deletion` | ลบ `main` ไม่ได้ |
| `non_fast_forward` | force push ทับ `main` ไม่ได้ |
| `pull_request` (approve 1 คน) | push ตรงเข้า main ไม่ได้ ต้องผ่าน PR |
| `dismiss_stale_reviews_on_push` | push เพิ่มหลัง approve แล้ว → approve เดิมถูกยกเลิก |
| `require_code_owner_review` | ไฟล์ที่มีเจ้าของใน CODEOWNERS ต้องให้เจ้าของ approve |
| `required_review_thread_resolution` | คอมเมนต์ที่ยังไม่ resolve ค้างอยู่ merge ไม่ได้ |
| `required_status_checks: ci` | CI ต้องเขียว |
| `strict_required_status_checks_policy` | branch ต้อง up-to-date กับ main ก่อน merge |
| `allowed_merge_methods: squash` | เหลือแค่ squash |

ตรวจผล:

```bash
gh api repos/myorg/my-service/rulesets --jq '.[] | {id, name, enforcement}'
gh api "repos/myorg/my-service/rules/branches/main" --jq '[.[].type]'
```

ทดสอบว่ามันกันจริง (ควรถูกปฏิเสธ):

```bash
git switch main && echo x >> README.md && git commit -am 'test' && git push
# → remote: error: ... protected branch
git reset --hard origin/main
```

### ระวังตอนเริ่มใช้

- ถ้ามี bot/CI ที่ push ตรงเข้า main อยู่ ต้องใส่ bypass ให้มันก่อน ไม่งั้น pipeline พัง
  (`bypass_actors` ใน ruleset — ใส่เท่าที่จำเป็นจริง ๆ และทบทวนทุกไตรมาส)
- `require_code_owner_review` จะไม่มีผลถ้ายังไม่มีไฟล์ `CODEOWNERS` — ดู [05](05-multi-repo.md)
- ทีมเล็ก 2 คนแล้วบังคับ approve 1 คน = ติดกันเองตอนอีกคนลา
  ทางออกคือใส่คนจากทีมข้าง ๆ เป็น reviewer สำรอง **ไม่ใช่**ปิด protection

---

## 4.5 Secrets และสิทธิ์ของ workflow

```bash
gh secret set DATABASE_URL --repo myorg/my-service          # ค่าลับ
gh variable set DEPLOY_ENV --repo myorg/my-service -b staging  # ค่าไม่ลับ
```

กฎที่ต้องยึด:

1. `permissions:` ตั้งเป็น `contents: read` เป็นค่าเริ่มต้น เพิ่มเฉพาะ job ที่ต้องใช้จริง
2. **ห้ามใช้ `pull_request_target`** เว้นแต่รู้ว่ากำลังทำอะไร — มันรันด้วยสิทธิ์เต็มบนโค้ดจาก fork
3. pin third-party action ด้วย SHA ไม่ใช่ tag (tag ถูกย้ายได้)
   `uses: some/action@a1b2c3d...  # v1.2.3`
   action ของ `actions/*` ใช้ major tag ได้
4. secret จะไม่ถูกส่งให้ workflow ที่รันจาก fork PR — เป็นค่าเริ่มต้นที่ถูกแล้ว อย่าไปปิด
5. ใช้ **environment** สำหรับ deploy ที่ต้องมีคนกดอนุมัติ:
   ```bash
   gh api -X PUT repos/myorg/my-service/environments/production \
     -f 'reviewers[][type]=User' -F 'reviewers[][id]=<user id>'
   ```

---

## แบบฝึกหัด (40 นาที)

1. ก๊อป workflow ที่ตรง stack เข้า playground → เปิด PR → ดูจนเขียว
2. ทำให้ test แดงตั้งใจ → ยืนยันว่า check `ci` แดงด้วย
3. `./scripts/apply-ruleset.sh <org>/<playground> --checks ci`
4. ลอง push ตรงเข้า main → ต้องถูกปฏิเสธ
5. ลอง merge PR ที่ CI แดง → ปุ่ม merge ต้องกดไม่ได้
6. ใครมีสิทธิ์ admin บน repo จริง ลองทำซ้ำกับ repo นั้น 1 อัน

---

ถัดไป → [05 — หลาย repo หลายทีม](05-multi-repo.md)
