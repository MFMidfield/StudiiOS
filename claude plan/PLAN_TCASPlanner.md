# PLAN_TCASPlanner — เขียน TCAS Planner ใหม่

> ร่างวันที่ 2026-08-09 · **ยังไม่ได้เริ่มเขียนโค้ด รอ Few ตัดสินใจ §0.3 และ §5**
> ของเดิม: `Features/TCASPlanner/TCASPlannerView.swift` (142) + `Core/Models/TCASEntry.swift` (50)

---

## 0. หลักการที่ตกลงกันแล้ว

### 0.1 กฎเหล็ก — ไม่เก็บข้อมูลคะแนน/เกณฑ์จริง
**Few ยืนยันแล้ว (2026-08-09):** แอปนี้ **ไม่มี** ฐานข้อมูลคะแนนต่ำสุด ไม่มีรายชื่อมหาลัย/คณะ
ไม่มีเกณฑ์การรับของคณะใดๆ ทั้งสิ้น ทุกจุดที่ผู้ใช้อาจอยากรู้ข้อมูลพวกนี้ → **ปุ่มเปิด mytcas.com**

เหตุผล (ใช้ตอบกรรมการได้):
1. ~90 มหาลัย × ~50 คณะ × 4 รอบ และ**เปลี่ยนทุกปี** — ดูแลไม่ไหวจริง
2. คะแนนต่ำสุดไม่ใช่ค่าคงที่ มันคือผลของจำนวนผู้สมัครปีนั้น → ข้อมูลปีที่แล้วใช้ตัดสินใจไม่ได้
3. แอปเป็น offline-first ไม่มี dependency → ไม่มีทางอัปเดตนอกจาก ship แอปใหม่
4. ถ้าข้อมูลผิด 1 ช่อง นักเรียนยื่นพลาด — **รับผิดชอบไม่ไหว และ mytcas ให้ฟรีอยู่แล้ว**

> **จุดยืนของผลิตภัณฑ์:** Student OS เป็น *ผู้ช่วยวางแผน* ไม่ใช่ *แหล่งข้อมูล*

⚠️ ถ้ารอบไหนในอนาคตมีคนเสนอให้ "ใส่ข้อมูลคณะสัก 20 อันก่อน" → **ต้องถาม Few ก่อนเสมอ** ข้อนี้เป็นการตัดสินใจระดับผลิตภัณฑ์ ไม่ใช่รายละเอียดการทำ

### 0.2 ข้อมูล 3 ชั้น

| ชั้น | คืออะไร | อยู่ที่ไหน | ต้นทุนดูแล |
|---|---|---|---|
| **A** | ปฏิทิน TCAS 4 รอบ · รายชื่อวิชาสอบ TGAT/TPAT/A-Level + คะแนนเต็ม | `Core/TCAS/` เป็น `static let` ในโค้ด | อัปปีละครั้ง ~150 บรรทัด |
| **B** | คณะเป้าหมาย · น้ำหนัก % ที่ผู้ใช้ลอกจากระเบียบการ · คะแนนสอบของตัวเอง | SwiftData | **ศูนย์** |
| **C** | คะแนนต่ำสุด · เกณฑ์จริงของแต่ละคณะ | **ไม่มีในแอป** | — |

ชั้น A ทั้งหมด = ไฟล์ Swift 2 ไฟล์ ไม่มี JSON ไม่มี network ไม่มี asset

### 0.3 ❓ รอ Few ตัดสิน — จะทำรอบไหนก่อน
ดู §6 มี 3 รอบ เรียงตามที่ผมแนะนำ แต่ยังไม่ล็อก

---

## 1. ชั้น A ตัวที่ 1 — `Core/TCAS/TCASExamCatalog.swift` (ใหม่)

รายชื่อวิชาสอบทั้งระบบ = **~24 ตัว จบ** เทียบเคียงกับ `ThaiSubjectCatalog.swift` ที่มีอยู่แล้ว
(logic ล้วน ไม่มี View ไม่มี SwiftData)

```
TGAT   3 วิชาย่อย (100 คะแนน/วิชา)
       TGAT1 การสื่อสารภาษาอังกฤษ · TGAT2 การคิดอย่างมีเหตุผล · TGAT3 สมรรถนะการทำงาน
TPAT   5 กลุ่ม (300 คะแนน/วิชา)
       TPAT1 แพทย์(กสพท) · TPAT2 ศิลปกรรม(3 ย่อย) · TPAT3 วิทย์-เทคโน-วิศวะ
       TPAT4 สถาปัตย์ · TPAT5 ครุศาสตร์
A-Level ~16 วิชา (100 คะแนน/วิชา)
       61 คณิต1 · 62 คณิต2 · 63 วิทย์ประยุกต์ · 64 ฟิสิกส์ · 65 เคมี · 66 ชีวะ
       70 สังคม · 81 ไทย · 82 อังกฤษ · 83-89 ภาษาที่สาม (ฝรั่งเศส/เยอรมัน/ญี่ปุ่น/เกาหลี/จีน/บาลี/สเปน)
```

โครงสร้าง: `TCASExam` (struct) — `code` · `displayName` · `group` (tgat/tpat/alevel) · `fullScore` · `examMonth`
`TCASExamCatalog.all` · `.grouped` (สำหรับ Picker แบบ 2 ชั้น) · `.exam(code:)`

⚠️ **ต้องให้ Few ตรวจรายชื่อ+รหัสวิชากับ mytcas ก่อน merge** ผมเขียนจากความรู้ทั่วไป ไม่ได้ verify ทีละตัว
ถ้ารหัสวิชาผิดจะไม่ crash แต่ชื่อจะเพี้ยนตอนเดโม่

---

## 2. ชั้น A ตัวที่ 2 — `Core/TCAS/TCASCalendar.swift` (ใหม่)

### ปัญหาที่ต้องออกแบบให้ทน: **TCAS70 ยังประกาศไม่ครบ**
ตอนนี้ ส.ค. 2569 — TCAS69 จบไปแล้ว รอบที่ผู้ใช้จริงต้องใช้คือ TCAS70 (ปีการศึกษา 2570)
ซึ่ง ทปอ. ยังประกาศวันไม่ครบ **ถ้า hardcode วันจริง เดโม่เดือนหน้าก็ผิดแล้ว**

### วิธีแก้: milestone มี 2 สถานะ
```swift
struct TCASMilestone {
    let id: String
    let title: String        // "สอบ TGAT/TPAT"
    let round: TCASRound?    // .portfolio / .quota / .admission / .direct / nil (=วันสอบ)
    let estimatedDate: Date  // จากรูปแบบ TCAS69 เลื่อนไป 1 ปี
    let isConfirmed: Bool    // false = ยังเป็นวันประมาณการ
    let note: String
}
```
UI แสดง milestone ที่ `isConfirmed == false` ด้วยป้าย **"วันโดยประมาณ"** สีเทา + ข้อความ
"ทปอ. ยังไม่ประกาศวันจริง แตะเพื่อแก้เป็นวันจริงเมื่อประกาศแล้ว"

ตอนแตะ "เพิ่มลงปฏิทิน" → **สร้าง `CalendarEvent` ปกติ** ผู้ใช้ไปแก้วัน/ตั้งเตือนเองในแท็บปฏิทินได้เลย
→ **ไม่ต้องมี @Model ใหม่สำหรับปฏิทิน TCAS แม้แต่ตัวเดียว** ใช้ `CalendarEvent` + `NotificationManager` ที่มีอยู่

### ลำดับเหตุการณ์ (โครงตาม TCAS69 เลื่อน 1 ปี)
```
ปลาย ต.ค.  เปิดลงทะเบียน mytcas
ธ.ค.        รอบ 1 Portfolio — ยื่นผลงาน
ธ.ค./ม.ค.   สอบ TGAT/TPAT
ก.พ.        ประกาศผลรอบ 1
ก.พ.–มี.ค.  รอบ 2 Quota
มี.ค.       สอบ A-Level
พ.ค.        รอบ 3 Admission (ประกาศผล 2 ครั้ง)
มิ.ย.       รอบ 4 รับตรงอิสระ
```
⚠️ วัน/เดือนข้างบนมาจากปฏิทิน TCAS69 — **Few ต้องตรวจก่อน** และทุกอันจะถูกตั้ง `isConfirmed = false`

---

## 3. ชั้น B — Models

### 3.1 `TCASEntry` — แก้ของเดิม (เพิ่ม field ทุกตัวมี default)
```swift
// ของเดิม ไม่แตะ: facultyName, universityName, notes, createdAt, checklist[]
var roundRaw: String = "รอบ 1"      // รอบที่ตั้งใจยื่น
var sortOrder: Int = 0              // อันดับความอยาก (1 = อันดับหนึ่ง)
var targetScore: Double = 0         // คะแนนเป้า (0 = ยังไม่ระบุ)
var requiredGPAX: Double = 0        // GPAX ที่คณะต้องการ (0 = ไม่ระบุ)
var admissionURL: String = ""       // ลิงก์ระเบียบการที่ผู้ใช้แปะเอง

@Relationship(deleteRule: .cascade, inverse: \TCASScoreWeight.entry)
var weights: [TCASScoreWeight] = []
```

### 3.2 `TCASScoreWeight` — @Model ใหม่
น้ำหนัก % ของวิชาหนึ่งในคณะหนึ่ง — **ผู้ใช้กรอกเองจากระเบียบการ**
`examCode: String` · `percent: Double` · `entry: TCASEntry?`

### 3.3 `TCASScoreRecord` — @Model ใหม่
คะแนนของผู้ใช้เอง แยกจากคณะ (ใช้ร่วมทุกคณะ)
`examCode: String` · `score: Double` · `kindRaw: String` (สอบจริง/ลองทำ) · `takenAt: Date`

**ไม่ผูก relationship กับ TCASEntry** เพราะคะแนน 1 ตัวใช้กับหลายคณะ — ค้นด้วย `examCode` เอา

### 3.4 ต้องแก้ 3 ที่ตามกฎเหล็ก
1. `App/PrototypeAppApp.swift` `Schema([...])` — เพิ่ม 2 model
2. `SettingsView.resetAllData()` — เพิ่ม 2 model
3. `PROJECT_MAP.md` §3 — เพิ่มแถว (คอมมิตเดียวกัน)

---

## 4. Logic — `Core/TCAS/TCASScoreEngine.swift` (ใหม่, ไม่มี View)

เทียบเคียง `AssignmentPriorityEngine` — สูตรอยู่ที่เดียว ห้ามซ้ำใน View

```
totalPercent(entry)          → รวม % ครบ 100 มั้ย (ไม่ครบ = เตือนผู้ใช้ ไม่ใช่ error)
currentScore(entry, records) → Σ (คะแนน/เต็ม × percent)
gap(entry, records)          → เป้า − ปัจจุบัน
leverage(entry, records)     → เรียงวิชาตาม "ดัน 1 คะแนนที่นี่ได้กี่คะแนนรวม"
                               = จุดที่ตอบว่า "ควรทุ่มวิชาไหน"
missingExams(entry, records) → วิชาที่มีน้ำหนักแต่ยังไม่เคยบันทึกคะแนน
```

**นี่คือฟีเจอร์ที่ mytcas ไม่มี และไม่ต้องใช้ข้อมูลภายนอกเลย** — จุดขายหลักตอนนำเสนอ

---

## 5. ❓ รอ Few ตัดสิน — เรื่อง schema

### ข่าวดี: **น่าจะไม่ต้องลบแอป**
ทุกอย่างใน §3 เป็น (ก) `@Model` ใหม่ล้วน หรือ (ข) property ใหม่ที่มี default ครบ
ทั้งสองแบบ SwiftData ทำ lightweight migration ให้เอง **ไม่ลบข้อมูลเดิม**

### ข่าวที่ต้องระวัง
จุดเดียวที่ผมไม่กล้าการันตี 100% คือ **`weights` ที่เป็น relationship ใหม่บน model เดิม**
SwiftData ปกติรับได้ แต่ผมคอมไพล์/รันเองไม่ได้ → verify ไม่ได้จนกว่า Few จะกดรัน

**แผนสำรองถ้า crash ตอนเปิดแอป:** ลบแอปออกแล้วติดตั้งใหม่ — เสียแค่ข้อมูลทดสอบ
**ทางเลี่ยงถ้าไม่อยากเสี่ยงเลย:** ให้ `TCASScoreWeight` เก็บ `entryID: UUID` แทน relationship
แล้วค้นเอาด้วย predicate — ปลอดภัย 100% แต่โค้ดขี้เหร่กว่าและไม่มี cascade delete ให้อัตโนมัติ

> **คำถามถึง Few:** เอาแบบ relationship (สวย เสี่ยงนิดเดียว) หรือ entryID (ปลอดภัย โค้ดขี้เหร่)?

---

## 6. แบ่ง 3 รอบ — ❓ รอ Few เลือกว่าเอาถึงรอบไหน

### รอบ 1 — ปฏิทิน + โครงข้อมูล *(แนะนำทำก่อน)*
- `TCASExamCatalog` + `TCASCalendar` (ชั้น A ทั้งหมด)
- เขียน `TCASPlannerView` ใหม่: การ์ดนับถอยหลังบนสุด + ไทม์ไลน์ 4 รอบ + รายการคณะเป้าหมายเดิม
- ปุ่ม "เพิ่มลงปฏิทิน" → สร้าง `CalendarEvent`
- ปุ่ม "เปิด mytcas" ตามกฎ §0.1
- **ยังไม่แตะ schema เลย** ← ทำรอบนี้อย่างเดียวก็ไม่มีความเสี่ยงเรื่องข้อมูลหาย

**เช็คยังไง:** Dashboard → TCAS Planner → เห็นนับถอยหลัง → กดเพิ่มลงปฏิทิน → ไปแท็บปฏิทินแล้วเห็นรายการนั้น

### รอบ 2 — เครื่องคิดคะแนนย้อนกลับ *(จุดขายหลัก)*
- Model §3 ทั้งหมด (**จุดที่แตะ schema**)
- หน้ากรอกน้ำหนัก % (Picker วิชาจาก catalog) + หน้าบันทึกคะแนนตัวเอง
- `TCASScoreEngine` + การ์ดผลลัพธ์ "ขาดอีก X · ควรทุ่ม TPAT3"

**เช็คยังไง:** สร้างคณะ 1 อัน → ใส่น้ำหนัก 4 วิชารวม 100% → ใส่คะแนน → เห็นตัวเลข gap และวิชาที่ควรทุ่ม

### รอบ 3 — เชื่อมของเดิม *(ถ้าเวลาเหลือ)*
- ดึง `SemesterRecord` มาคำนวณ GPAX ปัจจุบัน + ทำนายว่าเทอมที่เหลือต้องได้เท่าไร
- ผูก `PortfolioItem` เข้ากับคณะเป้าหมาย (เลือกผลงานที่จะใช้ยื่นรอบ 1)

⚠️ รอบ 3 สวยที่สุดตอนเล่าเรื่อง แต่**แตะโค้ดที่ใช้งานได้อยู่แล้ว** — เสี่ยงพัง GradeCenter/Portfolio
ตามลำดับความสำคัญ §6 ของสกิล (แอปต้องไม่ crash ตอนเดโม่) → **ไม่ควรทำถ้าเหลือน้อยกว่า 1 สัปดาห์**

---

## 7. ไฟล์ที่กระทบ (รวมทุกรอบ)

| ไฟล์ | รอบ | ทำอะไร |
|---|---|---|
| `Core/TCAS/TCASExamCatalog.swift` | 1 | ใหม่ |
| `Core/TCAS/TCASCalendar.swift` | 1 | ใหม่ |
| `Features/TCASPlanner/TCASPlannerView.swift` | 1 | เขียนใหม่เกือบหมด (142 บรรทัดเดิม) |
| `Features/TCASPlanner/TCASCountdownCard.swift` | 1 | ใหม่ |
| `Features/TCASPlanner/TCASTimelineSection.swift` | 1 | ใหม่ |
| `Core/Models/TCASEntry.swift` | 2 | เพิ่ม field + `TCASScoreWeight` |
| `Core/Models/TCASScoreRecord.swift` | 2 | ใหม่ |
| `Core/TCAS/TCASScoreEngine.swift` | 2 | ใหม่ |
| `Features/TCASPlanner/TCASWeightSheet.swift` | 2 | ใหม่ |
| `Features/TCASPlanner/TCASScoreEntrySheet.swift` | 2 | ใหม่ |
| `App/PrototypeAppApp.swift` | 2 | Schema |
| `Features/Settings/SettingsView.swift` | 2 | `resetAllData()` |
| `PROJECT_MAP.md` | 1,2 | §2 §3 |

**ไม่มีไฟล์อื่นเรียก `TCASPlannerView`** นอกจาก `DashboardDestination.tcasPlanner` ทางเดียว
→ เขียนใหม่ทั้งหน้าความเสี่ยงต่ำมาก (ยืนยันด้วย grep แล้ว ดูบล็อกท้าย)

---

## 8. หมายเหตุ Pro-gating
PROJECT_MAP §6 บอกว่า `TCASPlannerView` gated เป็น Pro อยู่ แต่โค้ดจริงในไฟล์ **ไม่มี gate เลย**
(คอมเมนต์หัวไฟล์เขียนว่า "Free feature" ด้วย) — ❓ Few อยากให้เป็น Free หรือ Pro?
ถ้าเดโม่ให้กรรมการดู แนะนำ **Free** จะได้ไม่ต้องกดเปิด toggle ใน Settings ก่อน
