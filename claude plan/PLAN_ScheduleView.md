# PLAN — หน้าตารางเรียน (ScheduleView)

> **สถานะ: แผน ยังไม่ได้ลงมือเขียนโค้ด** — รอ Few อ่านแล้ว OK ก่อน
> เขียน: 2026-08-02 · อ้างอิงภาพ mockup ที่ Few ส่งมา + คำตอบจาก 3 รอบคำถาม

---

## 0. สรุปสเปคที่ตกลงกันแล้ว

| # | หัวข้อ | ข้อสรุป |
|---|---|---|
| 1 | เวลาคาบ | **ใส่เวลาเริ่ม/สิ้นสุดเองทีละคาบ** ไม่คำนวณอัตโนมัติ (ตัดเรื่อง "คาบละกี่นาที" ออกจากฟอร์มเพิ่มคาบ) |
| 2 | วิชา | สร้าง `@Model Subject` ใหม่ |
| 3 | สี/ไอคอนวิชา | เลือกเองตอนสร้างวิชา + มีค่า default ให้ |
| 4 | พักกลางวัน | `isBreak` flag ใน Subject → เรนเดอร์เป็นแถบพิเศษ |
| 5 | ร่นคาบ | ลดความยาวคาบ → คาบเรียงติดกันไม่มีพักคั่น (8:30-9:20, 9:20-10:10 …) |
| 6 | ขอบเขตร่นคาบ | เฉพาะวันนั้นวันเดียว มีปุ่มยกเลิก |
| 7 | แถบด้านบน | **ชื่อวัน จันทร์–อาทิตย์ ไม่มีเลขวันที่** (ตัดออกเพื่อลดความซ้ำซ้อน) |
| 8 | งานวันนี้ | เพิ่ม field วิชาใน `Assignment` |
| 9 | Migration | รับได้ — Few จะลบแอปแล้วติดตั้งใหม่ |
| 10 | Tier | **Free ทั้งหมด** ไม่มี paywall |

---

## 1. โครงหน้าจอ (ตามภาพ mockup)

```
┌─────────────────────────────────────────┐
│  จันทร์  อังคาร  พุธ  พฤหัส  ศุกร์  เสาร์  อาทิตย์  │  ← ScheduleDayPickerBar
│    ●                                     │     (ไม่มีเลขวันที่แล้ว)
├─────────────────────────────────────────┤
│ ┌─ CardContainer ─────────────────────┐ │
│ │ คาบ │ เวลา │  วันจันทร์  │ ห้องเรียน │ │  ← header row
│ ├─────────────────────────────────────┤ │
│ │  1  │08:00│ ● 📐 คณิตศาสตร์เพิ่มเติม│5201│ │  ← SchedulePeriodRow
│ │     │08:50│    ครูณัฐวุฒิ อินทร์แก้ว │  › │ │
│ │─────┼─────┼────────────────────────┤ │
│ │  2  │09:00│ ● 📖 ฟิสิกส์            │5304│ │
│ │ …                                    │ │
│ │╔═══ พื้นหลังครีม ═══════════════════╗│ │  ← BreakRow (isBreak)
│ │║ 🍽  พักกลางวัน   12:00 – 13:00     ║│ │
│ │╚════════════════════════════════════╝│ │
│ │  5  │13:00│ ● 🧪 เคมี               │5103│ │
│ │ …                                    │ │
│ └──────────────────────────────────────┘ │
│ ┌─ CardContainer ─────────────────────┐ │
│ │ งาน / การบ้านวันนี้  [3 รายการ]  ดูทั้งหมด › │ ← ScheduleTodayTasksSection
│ │ 📐 คณิตศาสตร์เพิ่มเติม      ส่ง 31 ก.ค. › │ │
│ │    แบบฝึกหัด 2.1 ข้อ 1-20            │ │
│ │ 📖 ฟิสิกส์                 ส่ง 1 ส.ค. › │ │
│ └──────────────────────────────────────┘ │
└─────────────────────────────────────────┘
 Toolbar: [⏱ ร่นคาบ]  [+ เพิ่มคาบ]
```

---

## 2. Models

### 2.1 สร้างใหม่ — `Core/Models/Subject.swift`

```swift
@Model final class Subject {
    var name: String            // "ฟิสิกส์"
    var code: String            // "ว31201" — "" = ไม่ใส่รหัส
    var colorHex: String        // "4A7DFF"
    var iconName: String        // SF Symbol เช่น "atom"
    var isBreak: Bool           // true = พักกลางวัน → แถบพิเศษ
    var isBuiltIn: Bool         // true = วิชา seed ห้ามลบ
    var createdAt: Date
}
```

**วิชา seed ตอนเปิดแอปครั้งแรก** (สร้างถ้ายังไม่มีอะไรใน store):

| ชื่อ | isBreak | สี | ไอคอน |
|---|---|---|---|
| ชุมนุม | false | purple | `person.3.fill` |
| กิจกรรมในเครื่องแบบ | false | indigo | `figure.hiking` |
| พักกลางวัน | **true** | warning | `fork.knife` |

### 2.2 แก้ของเดิม — `Core/Models/ScheduleEntry.swift`

| Property | เดิม | ใหม่ | หมายเหตุ |
|---|---|---|---|
| `dayOfWeek` | Int | Int | คงเดิม (1=จันทร์ … 7=อาทิตย์) |
| `startTime` | Date | **ลบ** | → `startMinute` |
| `endTime` | Date | **ลบ** | → `endMinute` |
| `startMinute` | — | **Int ใหม่** | นาทีจากเที่ยงคืน (08:00 = 480) |
| `endMinute` | — | **Int ใหม่** | 08:50 = 530 |
| `periodNumber` | — | **Int ใหม่** | 0-10 หรือกำหนดเอง |
| `teacherName` | — | **String ใหม่** | default "" |
| `subject` | — | **Subject? ใหม่** | relationship |
| `subjectName` | String | String | เก็บไว้เป็น fallback ตอน subject ถูกลบ |
| `location` | String | String | คงเดิม (= ห้องเรียน) |
| `kindRaw` | String | **ลบ** | `ScheduleKind` ไม่ได้ถูกใช้ที่ไหนเลย (grep ยืนยันแล้ว) — บทบาทถูกแทนด้วย Subject |

**ทำไมเปลี่ยน Date → Int:** ค่า `Date` พก "วันที่" ติดมาด้วย ทำให้เรียง/เทียบข้ามวันพลาดง่าย และคำนวณร่นคาบยุ่ง — Int นาทีจากเที่ยงคืนเทียบตรงๆ ได้ ปลอดภัยกว่ามาก

### 2.3 สร้างใหม่ — `Core/Models/DayScheduleOverride.swift` (ร่นคาบ)

```swift
@Model final class DayScheduleOverride {
    var date: Date              // normalize เป็น 00:00 ของวันนั้น
    var startMinute: Int        // คาบแรกเริ่มกี่โมง
    var periodLengthMinutes: Int // คาบละกี่นาที (หลังร่น)
    var createdAt: Date
}
```

ตอนแสดงตาราง: ถ้าวันที่นั้นมี override → **คำนวณเวลาใหม่ทับ** โดยเรียงคาบติดกัน
`คาบ n เริ่ม = startMinute + (index ของคาบใน list) × periodLengthMinutes`
(ไม่แตะข้อมูลจริงใน ScheduleEntry เลย → ลบ override = กลับสภาพเดิม 100%)

### 2.4 แก้ของเดิม — `Core/Models/Assignment.swift`

เพิ่ม `var subjectName: String = ""` ตัวเดียว (มี default → ไม่กระทบ `SmartCaptureView` ที่เรียก init อยู่)
สี/ไอคอนดึงจาก Subject โดย match ชื่อ (ไม่ใช้ relationship → ลดจุดพัง)

---

## 3. ไฟล์ที่จะสร้าง / แก้

### สร้างใหม่

```
Core/Models/Subject.swift
Core/Models/DayScheduleOverride.swift
Core/Logging/AppLog.swift                        ← ระบบ log
Features/Schedule/ScheduleDayPickerBar.swift     ← แถบ จันทร์-อาทิตย์
Features/Schedule/ScheduleTimetableSection.swift ← การ์ดตาราง
Features/Schedule/SchedulePeriodRow.swift        ← แถวคาบ + แถวพัก
Features/Schedule/ScheduleTodayTasksSection.swift← งาน/การบ้านวันนี้
Features/Schedule/AddScheduleEntrySheet.swift    ← ฟอร์มเพิ่ม/แก้คาบ
Features/Schedule/AddSubjectSheet.swift          ← ฟอร์มเพิ่มวิชา
Features/Schedule/PeriodShiftSheet.swift         ← ฟอร์มร่นคาบ
```

> แตกไฟล์เยอะเพราะ SwiftUI `body` ยาวๆ ทำให้ compiler ฟ้อง
> *"unable to type-check this expression in reasonable time"* — กันไว้ก่อน

### แก้ไฟล์เดิม

| ไฟล์ | แก้อะไร | ความเสี่ยง |
|---|---|---|
| `Features/Schedule/ScheduleView.swift` | เขียนใหม่ทั้งไฟล์ (ตอนนี้เป็นหน้าเปล่า) | ต่ำ |
| `Core/Models/ScheduleEntry.swift` | เปลี่ยน property ตาม §2.2 | **สูง — breaking** |
| `Core/Models/Assignment.swift` | +`subjectName` | ต่ำ (มี default) |
| `App/PrototypeAppApp.swift` | เพิ่ม `Subject.self`, `DayScheduleOverride.self` ใน Schema | ลืม = crash ทันที |
| `Features/Settings/SettingsView.swift` | เพิ่ม 2 model ใน `resetAllData()` | ต่ำ |
| `Core/DesignSystem/Theme.swift` | +tokens ใหม่ (§5) | ต่ำ |
| `Features/Onboarding/ScheduleSetupView.swift` | init ScheduleEntry เปลี่ยน signature | **ปานกลาง** |
| `Core/OCR/ScheduleOCRParser.swift` | `ScheduleDraftEntry` มี `startTime: Date` → แปลงเป็นนาที | **ปานกลาง** |
| `Features/Onboarding/SetupSummaryView.swift` | อ่านแค่ `.subjectName` + `.count` → **ไม่ต้องแก้** | — |
| `Features/SmartCapture/SmartCaptureView.swift` | เรียก `Assignment(title:detail:dueDate:)` → **ไม่ต้องแก้** | — |
| `PROJECT_MAP.md` | อัปเดต §2 §3 §5 §8 | — |

---

## 4. ฟอร์มต่างๆ

### 4.1 `AddScheduleEntrySheet` — เพิ่ม/แก้คาบ

| ฟิลด์ | ชนิด | บังคับ | รายละเอียด |
|---|---|:---:|---|
| วัน | Picker จันทร์–อาทิตย์ | ✅ | default = วันที่เลือกอยู่บนแถบ |
| คาบที่ | Picker 0–10 + "กำหนดเอง" | ✅ | เลือก "กำหนดเอง" → เผย TextField ตัวเลข |
| เวลาเริ่ม | DatePicker `.hourAndMinute` | ✅ | |
| เวลาสิ้นสุด | DatePicker `.hourAndMinute` | ✅ | validate ต้อง > เวลาเริ่ม |
| วิชา | Picker จาก Subject + ปุ่ม **"+ เพิ่มวิชา"** | ✅ | ปุ่มเปิด `AddSubjectSheet` เป็น sheet ซ้อน |
| ชื่อครู | TextField | ❌ | |
| ห้องเรียน | TextField | ❌ | |

ปุ่ม "บันทึก" `.disabled` จนกว่า 4 ฟิลด์บังคับจะครบ + เวลาสิ้นสุด > เวลาเริ่ม

### 4.2 `AddSubjectSheet` — เพิ่มวิชา

| ฟิลด์ | ชนิด | บังคับ |
|---|---|:---:|
| ชื่อวิชา | TextField | ✅ |
| ใส่รหัสวิชา | Toggle → เผย TextField | ❌ |
| สี | แถบ 8 สีจาก `Theme.Colors.subjectPalette` | มี default |
| ไอคอน | กริด SF Symbols ~16 ตัว | มี default |
| เป็นช่วงพัก | Toggle | ❌ (default off) |

### 4.3 `PeriodShiftSheet` — ร่นคาบ

```
วันที่ร่น: จันทร์ 3 ส.ค. 2569        ← วันจริงของ "วันจันทร์" ในสัปดาห์นี้
คาบแรกเริ่ม:  [08:30]               ← DatePicker
คาบละ:        [50 นาที ▾]           ← Picker 5,10,…,60 + "กำหนดเอง" (TextField)
─────────────────────────────
ตัวอย่างผลลัพธ์:
  คาบ 1  08:30 – 09:20
  คาบ 2  09:20 – 10:10
  คาบ 3  10:10 – 11:00  …
─────────────────────────────
[ ยืนยันร่นคาบ ]
[ ยกเลิกการร่นคาบ ]   ← โชว์เฉพาะเมื่อวันนั้นมี override อยู่แล้ว
```

เมื่อร่นแล้ว → หัวการ์ดตารางโชว์ป้าย **"วันนี้ร่นคาบ 50 นาที"** สีส้ม + ปุ่มคืนค่าเดิม

---

## 5. Design tokens ที่ต้องเพิ่มใน `Theme.swift`

```swift
Theme.Colors.breakBackground  = #FFF8E7   // พื้นแถวพักกลางวัน
Theme.Colors.separator        = #E8EAF0   // เส้นคั่นแถว
Theme.Colors.textSecondary    = #6B7280   // ชื่อครู / เวลา
Theme.Colors.subjectPalette   = [primary, success, warning, danger,
                                 purple, pink, indigo, info]   // 8 สีให้เลือก
```

> ตามกฎ §4 ของสกิล — เพิ่มแล้วต้องไปเพิ่ม Figma variable `color/breakBackground` ฯลฯ ให้ตรงกันด้วย (ทำทีหลังได้ ไม่บล็อกงานโค้ด)

---

## 6. ระบบ log — `Core/Logging/AppLog.swift`

```swift
enum AppLog {
    static func action(_ category: String, _ message: String) {
        print("🔵 [\(category)] \(message)")
    }
    static func warn(_ category: String, _ message: String) {
        print("🟠 [\(category)] \(message)")
    }
    static func error(_ category: String, _ message: String) {
        print("🔴 [\(category)] \(message)")
    }
}
```

**จุดที่จะใส่ log ทั้งหมด:**

| การกระทำ | ตัวอย่างบรรทัดที่จะเห็นใน Xcode console |
|---|---|
| กดเลือกวัน | `🔵 [Schedule] เลือกวัน: อังคาร` |
| กด + เพิ่มคาบ | `🔵 [Schedule] เปิดฟอร์มเพิ่มคาบ (วัน=จันทร์)` |
| บันทึกคาบ | `🔵 [Schedule] เพิ่มคาบสำเร็จ: คาบ 2 · ฟิสิกส์ · 09:00-09:50 · ห้อง 5304` |
| บันทึกไม่ผ่าน validate | `🟠 [Schedule] บันทึกไม่ได้: เวลาสิ้นสุดต้องมากกว่าเวลาเริ่ม` |
| แก้คาบ | `🔵 [Schedule] แก้คาบ id=… : ห้อง 5304 → 5305` |
| ลบคาบ | `🔵 [Schedule] ลบคาบ: คาบ 2 · ฟิสิกส์ · วันจันทร์` |
| เพิ่มวิชา | `🔵 [Subject] เพิ่มวิชา: เคมี (ว31221) สี=#E91E63 ไอคอน=flask` |
| seed วิชาเริ่มต้น | `🔵 [Subject] seed วิชาเริ่มต้น 3 รายการ` |
| ร่นคาบ | `🔵 [Shift] ร่นคาบ 3 ส.ค. 2569 · เริ่ม 08:30 · คาบละ 50 นาที · กระทบ 8 คาบ` |
| ยกเลิกร่น | `🔵 [Shift] ยกเลิกร่นคาบ 3 ส.ค. 2569` |
| SwiftData save fail | `🔴 [Schedule] save ล้มเหลว: <error>` |

---

## 7. ลำดับการทำงาน (แนะนำแบ่ง 3 รอบ build)

| รอบ | ทำอะไร | Few เช็คยังไง |
|:---:|---|---|
| **1** | Models ทั้งหมด + Schema + resetAllData + AppLog + Theme tokens + seed วิชา | ลบแอป → เปิดใหม่ → ไม่ crash · console ขึ้น `🔵 [Subject] seed วิชาเริ่มต้น 3 รายการ` |
| **2** | ScheduleView + แถบวัน + การ์ดตาราง + ฟอร์มเพิ่มคาบ/เพิ่มวิชา | เพิ่ม 3 คาบ + พักกลางวัน → เห็นตารางตามรูป · ปิดเปิดแอปแล้วข้อมูลยังอยู่ |
| **3** | Section งานวันนี้ + ระบบร่นคาบ | สร้างงานใน SmartCapture ที่ครบกำหนดวันนี้ → เห็นใน section · กดร่นคาบ 50 นาที → เวลาเปลี่ยนหมด · กดยกเลิก → กลับเดิม |

**หยุดรอ Few ยืนยัน build ผ่านทุกรอบก่อนไปรอบถัดไป**

---

## 8. ⚠️ จุดที่ผมตัดสินใจแทน — ถ้าไม่ตรงใจบอกได้

1. **ตัดตัวเลือก "คาบละกี่นาที" ออกจากฟอร์มเพิ่มคาบ** — เพราะ Few เลือกว่าให้ใส่เวลาเริ่ม/จบเองทีละคาบ ตัวเลือก 5–60 นาทีจึงย้ายไปอยู่ในฟอร์ม *ร่นคาบ* ซึ่งเป็นที่ที่ใช้จริง

2. **แถบบนไม่มีเลขวันที่ แต่ระบบยังต้องรู้วันที่จริงอยู่ดี** — สำหรับ "งานที่ต้องส่งวันนี้" และ "ร่นคาบเฉพาะวันนั้น" ผมจะ map ชื่อวัน → วันที่ของวันนั้น **ในสัปดาห์ปัจจุบัน** เงียบๆ ข้างหลัง
   ผลคือ: เลือก "พฤหัส" ตอนวันจันทร์ → section งานจะโชว์งานที่ครบกำหนด *วันพฤหัสของสัปดาห์นี้*
   ถ้าอยากให้ section งานล็อกที่ "วันนี้จริงๆ" เสมอไม่ว่าเลือกวันไหน → บอกได้ แก้ง่าย

3. **`ScheduleKind` จะถูกลบทิ้ง** — grep แล้วยืนยันว่าไม่มีไฟล์ไหนใช้เลยนอกจากตัวมันเอง บทบาท (ชุมนุม/ลูกเสือ/แนะแนว) ถูกแทนด้วย Subject ที่สร้างเองได้ ยืดหยุ่นกว่า

4. **`startTime`/`endTime` เปลี่ยนจาก `Date` เป็น `Int` (นาที)** — นี่คือสาเหตุหลักที่ข้อมูลเดิมอ่านไม่ได้ ถ้าอยากเลี่ยงต้องยอมเก็บเป็น Date ต่อ แต่โค้ดร่นคาบจะซับซ้อนและเสี่ยงบั๊กเรื่อง timezone

5. **สีวิชาใช้ palette 8 สีจาก Theme** ไม่ใช้ ColorPicker อิสระ — เพื่อให้ UI ดูเป็นชุดเดียวกัน ไม่มีสีหลุดโทน (ถ้าอยากได้ ColorPicker เต็มบอกได้)

---

## 9. 🔺 ความเสี่ยงที่อยากให้รู้ก่อนเริ่ม

| ความเสี่ยง | ผลกระทบ | วิธีคุม |
|---|---|---|
| เปลี่ยน `ScheduleEntry` schema | **ข้อมูลตารางเรียนเดิมหายหมด · แอป crash ถ้าไม่ลบก่อน** | Few ลบแอปจาก simulator ก่อนรันรอบแรก (ยืนยันแล้ว) |
| `ScheduleOCRParser` ผูกกับ Date | OCR onboarding อาจพังถ้าแปลงไม่ครบ | รอบ 1 แก้ไฟล์นี้ด้วย + Few ลองเดิน onboarding ใหม่ 1 รอบ |
| `body` ยาว → compiler timeout | build ไม่ผ่าน error ประหลาด | แตกเป็น 8 ไฟล์ตั้งแต่แรก (§3) |
| Relationship `ScheduleEntry.subject` | ลบวิชาที่มีคาบใช้อยู่ → คาบกำพร้า | ก่อนลบวิชาเช็คว่ามีคาบใช้ไหม → เตือน + เก็บ `subjectName` เป็น fallback |
| ร่นคาบทับเวลาพักกลางวัน | พักกลางวันโดนคำนวณใหม่ด้วย เวลาเพี้ยน | **แถวที่ `isBreak == true` จะไม่ถูกร่น** คงเวลาเดิมไว้ แล้วคาบหลังพักเริ่มนับต่อจากเวลาจบพัก |

---

## 10. ✅ คำตอบจาก Few (2026-08-02) — ตัดสินครบแล้ว

1. **กดแถวคาบ (chevron `›`)** → **เปิดฟอร์มแก้คาบนั้น** (`AddScheduleEntrySheet` ในโหมด edit)

2. **ลบคาบ** → **ปุ่มลบในฟอร์มแก้เท่านั้น** ไม่มี swipe-to-delete
   (มี confirmation dialog ก่อนลบจริง — กันกดพลาดตอนเดโม่)

3. **Onboarding สร้าง Subject อัตโนมัติ** → ใช่ ตอน `ScheduleSetupView.saveAndContinue()`
   ให้ไล่ชื่อวิชาจากที่กรอก/OCR แล้ว **สร้าง Subject ตัวใหม่ถ้ายังไม่มีชื่อนั้น** (สีหมุนตาม `subjectPaletteHex` ไอคอน default `book.closed.fill`) แล้วผูก relationship ให้ ScheduleEntry

4. **วันเสาร์–อาทิตย์** → **ซ่อนไปเลย** แถบวันเหลือ **จันทร์–ศุกร์ 5 วัน** (`dayOfWeek` 1–5)
   → Picker "วัน" ในทุกฟอร์มก็เหลือ 5 ตัวเลือกด้วย รวมถึง `ManualScheduleEntrySheet` ใน onboarding
   → ถ้าในอนาคตอยากได้เสาร์-อาทิตย์กลับมา แก้ที่ค่าคงที่ `Schedule.visibleDays` ที่เดียว (ให้ประกาศไว้ตั้งแต่แรก)

---

## เช็คแล้ว / ยังไม่ได้เช็ค

**เช็คแล้ว:**
- `ScheduleView.swift` ปัจจุบันเป็นหน้าเปล่าจริง (มีแค่ `Spacer()`) — เขียนใหม่ได้ไม่ทับของใคร
- grep ยืนยัน `ScheduleKind` ไม่ถูกใช้นอกไฟล์ `ScheduleEntry.swift` เลย → ลบได้
- grep หา `ScheduleEntry` ครบ: กระทบ 4 ไฟล์ (`PrototypeAppApp`, `SettingsView`, `SetupSummaryView`, `ScheduleSetupView`) + `ScheduleOCRParser`
- `SetupSummaryView` อ่านแค่ `.subjectName` และ `.count` → ไม่ต้องแก้
- `Assignment(...)` ถูกเรียกที่เดียวคือ `SmartCaptureView.swift:257` และไม่ส่ง `subjectName` → เพิ่ม field พร้อม default = ไม่พัง
- `Theme.swift` ยังไม่มี `textSecondary` / `separator` / `breakBackground` จริง

**ยังไม่ได้เช็ค:**
- ยังไม่ได้คอมไพล์ (ผมรัน `xcodebuild` ไม่ได้ — sandbox เป็น Linux)
- ยังไม่ได้อ่าน `ScheduleOCRParser.swift` ทั้งไฟล์ ว่าแปลง Date → นาที ต้องแก้กี่จุด (จะดูตอนลงมือรอบ 1)
- ยังไม่ได้เช็คว่า `DashboardView` โชว์ Assignment แบบไหน — อาจอยากโชว์ชื่อวิชาด้วยหลังเพิ่ม field

**รบกวน Few:**
1. อ่านแผนนี้ โดยเฉพาะ **§8 (จุดที่ผมตัดสินใจแทน)** และ **§9 (ความเสี่ยง)**
2. ตอบคำถาม 4 ข้อใน **§10**
3. ถ้าโอเคทั้งหมด บอก "เริ่มรอบ 1" ได้เลย — ผมจะทำแค่ Models + Schema + Theme + log ก่อน ยังไม่แตะ UI
