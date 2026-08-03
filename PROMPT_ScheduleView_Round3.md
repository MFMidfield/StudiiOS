# คำสั่งสำหรับ Claude Code (Sonnet, thinking: high) — รอบ 3 · งานวันนี้ + ร่นคาบ

> **ห้ามรันรอบนี้ก่อนที่รอบ 2 จะ build เขียวและ Few ยืนยันแล้ว**
> วิธีใช้: copy ทุกอย่างใต้เส้นคั่นไปวางใน Claude Code

---

อ่าน `PROJECT_MAP.md` และ `PLAN_ScheduleView.md` ก่อนเริ่ม รอบ 1-2 เสร็จแล้ว (Models + UI ตาราง + ฟอร์ม) รอบนี้ทำ **section งาน/การบ้านวันนี้ + ระบบร่นคาบ** เป็นรอบสุดท้ายของฟีเจอร์นี้

## ไฟล์ที่ต้องสร้าง

```
Features/Schedule/ScheduleTodayTasksSection.swift
Features/Schedule/PeriodShiftSheet.swift
Features/Schedule/PeriodShiftBanner.swift
Core/Schedule/PeriodShiftCalculator.swift     ← logic ล้วน ไม่มี View
```

---

# ส่วน A · Section งาน/การบ้านวันนี้

## A1. `ScheduleTodayTasksSection.swift`

```
┌─ CardContainer ────────────────────────────┐
│ งาน / การบ้านวันนี้  [3 รายการ]   ดูทั้งหมด › │
├────────────────────────────────────────────┤
│ 📐 คณิตศาสตร์เพิ่มเติม           ส่ง 31 ก.ค. › │
│    แบบฝึกหัด 2.1 ข้อ 1-20                   │
│ 📖 ฟิสิกส์                       ส่ง 1 ส.ค. › │
│    อ่านบทที่ 3 และทำแบบฝึกหัดท้ายบท          │
└────────────────────────────────────────────┘
```

**ข้อมูล:** `@Query` `Assignment` ที่ `isDone == false` แล้วกรองในโค้ดด้วย
`Calendar.current.isDate(dueDate, inSameDayAs: targetDate)`

**`targetDate` คำนวณยังไง** (สำคัญ — ตัดเลขวันที่ออกจาก UI แล้ว แต่ระบบยังต้องรู้):
```
targetDate = วันที่ของ selectedDay ในสัปดาห์ปัจจุบัน
เช่น วันนี้พุธ 5 ส.ค. · selectedDay = ศุกร์ → targetDate = 7 ส.ค.
```
เขียนเป็น `static func date(forDay: Int, in week: Date) -> Date` ไว้ใน `PeriodShiftCalculator.swift` (ใช้ร่วมกับส่วน B)

**รูปแบบแถว:**
- ไอคอนกล่อง 36×36 เหมือน `SchedulePeriodRow` — สี/ไอคอนมาจาก **Subject ที่ชื่อตรงกับ `assignment.subjectName`** (lookup ตามชื่อ ไม่ใช่ relationship) · ไม่เจอ → `textSecondary` + `doc.text.fill`
- บรรทัดบน: ชื่อวิชา `.subheadline` ตัวหนา · ขวาสุด `"ส่ง <วันที่ไทยแบบสั้น>"` `.caption` `textSecondary` + chevron
- บรรทัดล่าง: `assignment.title` `.caption` `textSecondary` — **ตัดที่ 2 บรรทัด** (`.lineLimit(2)`)
- วันที่ใช้ helper จาก `Core/Extensions/Date+Thai.swift` ที่มีอยู่ ถ้ายังไม่มี format สั้นให้เพิ่มเข้าไป

**badge จำนวน:** แคปซูลเล็กสี `primary.opacity(0.12)` ตัวอักษรสี `primary` — ซ่อนถ้า 0

**"ดูทั้งหมด ›"** → push ไป `AssignmentListView` ที่มีอยู่แล้ว
> grep หาก่อนว่า `AssignmentListView` ถูก push ยังไงใน `DashboardView` แล้วทำแบบเดียวกัน อย่าคิดวิธีใหม่

**empty state:** `"ไม่มีงานส่งวัน<ชื่อวัน> 🎉"` จัดกลาง สี `textSecondary` — การ์ดยังอยู่ ไม่ต้องซ่อนทั้งการ์ด

**แตะแถวงาน** → ยังไม่ต้องทำอะไร แค่ log `🔵 [Schedule] แตะงาน: <title>` (ปลายทางไว้ทำทีหลัง)

## A2. เติม `subjectName` ให้ Assignment ที่สร้างจาก SmartCapture

เปิด `Features/SmartCapture/SmartCaptureView.swift:257` — ตอนนี้เรียก `Assignment(title:detail:dueDate:)` ไม่ส่งวิชา
**ถ้าในฟอร์ม SmartCapture มีที่ให้เลือกวิชาอยู่แล้ว** → ส่งค่าเข้าไป
**ถ้าไม่มี** → เพิ่ม Picker เลือกวิชา (ไม่บังคับ มีตัวเลือก "ไม่ระบุ") ในฟอร์มนั้น แล้วส่งเข้า init
อ่านไฟล์ก่อนตัดสินใจ แล้วบอกผมว่าเลือกทางไหนเพราะอะไร

---

# ส่วน B · ระบบร่นคาบ

## B1. `PeriodShiftCalculator.swift` — logic ล้วน แยกจาก View

```swift
enum PeriodShiftCalculator {
    static func date(forDay: Int, in week: Date) -> Date
    static func apply(override: DayScheduleOverride?, to entries: [ScheduleEntry]) -> [ResolvedPeriod]
}

struct ResolvedPeriod: Identifiable {
    let entry: ScheduleEntry
    let startMinute: Int   // หลังร่นแล้ว
    let endMinute: Int
    let isShifted: Bool    // true = เวลาถูกเปลี่ยนจากค่าจริง
}
```

**กติกาการคำนวณ — อ่านให้ครบก่อนเขียน:**

1. `entries` เรียงตาม `startMinute` ก่อนเสมอ
2. `override == nil` → คืนค่าเดิมทุกตัว `isShifted = false`
3. มี override → เดินไล่ทีละแถว มี cursor เวลาเริ่มต้นที่ `override.startMinute`
4. แถวปกติ: `start = cursor` · `end = cursor + periodLengthMinutes` · `cursor = end` · `isShifted = true`
5. **แถวที่ `subject?.isBreak == true` ไม่ถูกร่น** → คงเวลาเดิมของมันไว้เป๊ะ `isShifted = false` แล้ว **ตั้ง `cursor = endMinute เดิมของแถวพัก`** (คาบหลังพักเริ่มนับต่อจากเวลาจบพักจริง)
6. ถ้าคำนวณแล้วคาบล้นเกิน 23:59 (1439) → หยุดร่นแถวที่เหลือ คงเวลาเดิม + `AppLog.warn("Shift", "เวลาล้นเกินเที่ยงคืน หยุดร่นที่คาบ <n>")`
7. **ห้ามแก้ค่าใน `ScheduleEntry` จริง** — override เป็น layer คำนวณทับตอนแสดงผลเท่านั้น ลบ override = กลับสภาพเดิม 100%

## B2. ให้ `ScheduleTimetableSection` ใช้ `ResolvedPeriod` แทน `ScheduleEntry` ตรงๆ

- `ScheduleView` `@Query` `DayScheduleOverride` แล้วหาตัวที่ `date == PeriodShiftCalculator.date(forDay:in:)` ของวันที่เลือก
- ส่ง `[ResolvedPeriod]` ลงไปแทน
- แถวที่ `isShifted == true` → เวลาแสดงด้วยสี `Theme.Colors.warning` (ให้เห็นชัดว่าไม่ใช่เวลาปกติ)

## B3. `PeriodShiftBanner.swift`

โผล่เหนือการ์ดตาราง **เฉพาะเมื่อวันที่เลือกมี override**:
```
┌────────────────────────────────────────────┐
│ ⏱  วันนี้ร่นคาบ · คาบละ 50 นาที   [คืนค่าเดิม] │  ← พื้น warning.opacity(0.15)
└────────────────────────────────────────────┘
```
ปุ่ม "คืนค่าเดิม" → `.confirmationDialog` ยืนยัน → ลบ override + log

## B4. `PeriodShiftSheet.swift`

เปิดจากปุ่มนาฬิกาใน toolbar (ซ้ายของปุ่ม `+`) — icon `clock.arrow.trianglehead.counterclockwise.rotate.90` หรือ `clock.badge.exclamationmark`

```
┌─ ร่นคาบ ─────────────────────────────┐
│ วันที่ร่น    จันทร์ 3 สิงหาคม 2569      │ ← อ่านอย่างเดียว
│ คาบแรกเริ่ม  [ 08:30 ]                │ ← DatePicker .hourAndMinute
│ คาบละ       [ 50 นาที ▾ ]             │ ← Picker 5,10,…,60 + "กำหนดเอง"
│              └ กำหนดเอง → TextField    │
├──────────────────────────────────────┤
│ ตัวอย่างผลลัพธ์                        │ ← live preview อัปเดตตามที่ปรับ
│   คาบ 1   08:30 – 09:20               │
│   คาบ 2   09:20 – 10:10               │
│   พักกลางวัน  12:00 – 13:00  (ไม่ร่น)   │ ← ตัวเทา ระบุชัดว่าไม่ถูกร่น
│   คาบ 5   13:00 – 13:50               │
├──────────────────────────────────────┤
│        [ ยืนยันร่นคาบ ]                │
│        [ ยกเลิกการร่นคาบ ]  ← ถ้ามีอยู่แล้ว│
└──────────────────────────────────────┘
```

- ตัวเลือก "คาบละ" = `stride(from: 5, through: 60, by: 5)` + `"กำหนดเอง"`
- ค่าเริ่มต้นตอนเปิด: ถ้ามี override อยู่แล้วใช้ค่านั้น · ถ้ายังไม่มีใช้ `startMinute` ของคาบแรกจริง + ความยาวคาบแรกจริง
- **preview ต้องเรียก `PeriodShiftCalculator.apply` ตัวเดียวกับที่หน้าจริงใช้** ห้ามเขียนสูตรซ้ำ (ไม่งั้น preview กับผลจริงจะไม่ตรงกัน)
- ยืนยันแล้ว: หา override เดิมของวันนั้น → ถ้ามีให้อัปเดต ถ้าไม่มีให้ insert ใหม่ (**ห้ามมี override ซ้ำวันเดียวกัน 2 ตัว**)
- validate: `periodLengthMinutes` ต้องอยู่ระหว่าง 1–240 ไม่งั้นปิดปุ่ม + `AppLog.warn`

**log ที่ต้องมี:**
```
🔵 [Shift] เปิดฟอร์มร่นคาบ · วันจันทร์ 3 ส.ค. 2569 · มี override เดิม: ไม่มี
🔵 [Shift] ร่นคาบ 3 ส.ค. 2569 · เริ่ม 08:30 · คาบละ 50 นาที · กระทบ 8 คาบ (ข้ามพัก 1)
🔵 [Shift] ยกเลิกร่นคาบ 3 ส.ค. 2569
🟠 [Shift] เวลาล้นเกินเที่ยงคืน หยุดร่นที่คาบ 9
🔴 [Shift] save ล้มเหลว: <error>
```

## B5. อัปเดต `PROJECT_MAP.md` และ §8 (หนี้ทางเทคนิค)

- เพิ่มไฟล์ใหม่ทั้ง 4 ใน §2
- §8: ลบข้อ "SettingsView.resetAllData() เคยลืม" ถ้าจัดการครบแล้ว · เพิ่มข้อใหม่ถ้ามีอะไรค้าง

---

## กฎที่ต้องทำตาม

1. **ห้ามบอกว่า build ผ่าน**
2. **ห้ามแตะ `.pbxproj`**
3. **ห้าม hardcode สี/ระยะห่าง** — ต้องมาจาก `Theme`
4. **ห้ามเพิ่ม SPM package**
5. iOS 26.5 → **ห้ามเขียน `if #available`**
6. **ห้ามแก้ค่าจริงใน `ScheduleEntry` ตอนร่นคาบ** — ข้อนี้สำคัญที่สุดในรอบนี้
7. logic การคำนวณต้องอยู่ใน `PeriodShiftCalculator` ที่เดียว **ห้ามเขียนสูตรซ้ำใน View**
8. ก่อนแตะ `SmartCaptureView` หรือ `AssignmentListView` → อ่านไฟล์ก่อน แล้วบอกผมว่าจะแก้อะไรบ้าง
9. **ยังไม่ commit** จนกว่าผมยืนยัน

## ปิดท้ายด้วยบล็อกนี้เสมอ

```
เช็คแล้ว:
- <verify ได้จริง>

ยังไม่ได้เช็ค:
- ยังไม่ได้คอมไพล์ (รัน xcodebuild ไม่ได้)
- <อื่นๆ>

รบกวน Few:
1. กด ⌘B — ถ้าแดง copy error ทั้งก้อนมาวาง
2. สร้างงานใน SmartCapture ที่ครบกำหนดวันนี้ 2 ชิ้น → เห็นใน section งานพร้อมไอคอนวิชา
3. กด "ดูทั้งหมด" → ต้อง push ไปหน้ารายการงานได้
4. กดปุ่มนาฬิกาบน toolbar → ตั้งเริ่ม 08:30 คาบละ 50 → เช็คว่า preview คำนวณถูก
5. กดยืนยัน → เวลาทุกคาบเปลี่ยน (สีส้ม) แต่ **พักกลางวันต้องเวลาเดิม** และคาบหลังพักเริ่มตรงเวลาจบพัก
6. เลื่อนไปวันอังคาร → ต้องเป็นเวลาปกติ (ร่นเฉพาะวันเดียว)
7. กลับมาวันจันทร์ → กด "คืนค่าเดิม" → เวลากลับเป็นเดิมเป๊ะ
8. ปิดเปิดแอป → ทั้ง override และงาน ยังอยู่
9. ส่ง screenshot ทั้งก่อนร่นและหลังร่นมาให้ดู
```
