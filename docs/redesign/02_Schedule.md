# 02 · Schedule — หน้าตารางเรียน

> โมดูล `StudiiOS/Features/Schedule/` (16 ไฟล์ · 2,461 บรรทัด)
> ✅ ตรวจแล้ว: `ScheduleTodayTasksSection` ถูกใช้ที่เดียวคือ `ScheduleView.swift:71` → ลบได้ปลอดภัย

---

## 1. สภาพปัจจุบัน

```
ScheduleDayPickerBar        จ อ พ พฤ ศ + ขีดใต้เลื่อน + จุดบอกวันนี้
ScrollView
├── PeriodShiftBanner       (เมื่อวันนั้นถูกร่นคาบ)
├── ScheduleTimetableSection
│     headerRow             "คาบ | เวลา | วันจันทร์ | ห้องเรียน"
│     SchedulePeriodRow ×N  เลข|เวลา|จุดสี|ไอคอน|ชื่อ+ครู|ห้อง|chevron
│     ScheduleBreakRow      แถบครีม full-bleed
└── ScheduleTodayTasksSection  การ์ดงานส่งวันนั้น
toolbar: ⚙︎ (ScheduleSettingsSheet) + ＋ (AddScheduleEntrySheet)
```

## 2. ปัญหา UX

| # | ปัญหา | ความหนัก |
|---|---|---|
| 1 | **ปุ่มหลอก** — `ScheduleTodayTasksSection.taskRow` เป็น `Button` มี chevron แต่ action มีแค่ `AppLog.action(...)` กดแล้วไม่เกิดอะไรเลย | **บั๊ก** |
| 2 | สีวิชาโผล่ 4 ครั้งต่อแถว (จุดกลม · พื้นไอคอน · ตัวไอคอน · ป้ายห้อง) เบียดจนชื่อวิชายาวโดน `lineLimit(1)` ตัด | สูง |
| 3 | `headerRow` บอก "วันจันทร์" ซ้ำกับแถบเลือกวันที่เพิ่งกดมา และหัวคอลัมน์ไม่ตรงกับของจริง | กลาง |
| 4 | ไม่มีสัญญาณว่า "ตอนนี้คาบไหน" ทั้งที่เป็นหน้าที่ควรบอกที่สุด | กลาง |
| 5 | การ์ดงานสลับลำดับ — ชื่อวิชาเป็นตัวหนาใหญ่ ชื่องานเป็นตัวเล็กจาง | กลาง |
| 6 | ปุ่ม `+` toolbar ซ้ำกับปุ่ม `+` กลาง tab bar (หลัง §5 ของ `01_Tasks.md`) | ต่ำ |
| 7 | "ร่นคาบวันนี้" เป็นงานรายวัน แต่ซ่อนอยู่ใต้ปุ่มเฟืองซึ่งคนอ่านว่า "ตั้งค่า" | ต่ำ |
| 8 | `PeriodShiftBanner` ใช้ `warning` เป็นทั้งพื้น (15%) และตัวอักษร → คอนทราสต์ต่ำ | ต่ำ |

---

## 3. ตัด / เก็บ / ย้าย

### ✂️ ตัดทิ้ง

| ตัด | เหตุผล |
|---|---|
| `ScheduleTodayTasksSection.swift` **ทั้งไฟล์** | หน้างานจัดกลุ่มตามวันแล้ว การ์ดนี้ซ้ำ · แถบล่างมีแท็บ "งาน" อยู่แล้ว · และเป็นที่อยู่ของบั๊กปุ่มหลอก |
| `ScheduleSettingsSheet.swift` **ทั้งไฟล์** | ของข้างในเหลือ 3 รายการ ย้ายขึ้น Menu บน toolbar ได้หมด ไม่ต้องเปิด sheet |
| `headerRow` ใน `ScheduleTimetableSection` | ซ้ำกับแถบวัน + หัวคอลัมน์ไม่ตรง |
| จุดกลมสีวิชา 8×8 ใน `SchedulePeriodRow` | ซ้ำกับพื้นไอคอน |
| สีวิชาบนป้ายห้อง | เปลี่ยนเป็นสีกลาง — เหลือให้สีวิชาอยู่ที่ไอคอนที่เดียว |
| ปุ่ม `+` บน toolbar | ใช้ปุ่ม `+` กลาง tab bar |
| ขีดใต้แบบเลื่อนใน day picker | เปลี่ยนเป็นแคปซูลเต็ม |

### ✅ เก็บไว้

- `PeriodShiftCalculator.apply` และ `[ResolvedPeriod]` — **ห้ามแตะ logic การร่นคาบ**
- `ScheduleBreakRow` เป็นแถบครีม full-bleed ไม่มีเลขคาบ/ห้อง/chevron
- `PeriodShiftBanner` พร้อมปุ่ม "คืนค่าเดิม"
- ไอคอนวิชา (`subject.iconName`) — Few เลือกเก็บไอคอน ตัดขีดสี
- empty state ที่มีปุ่ม "เพิ่มคาบเรียน" ในตัว
- `matchedGeometryEffect` ใน day picker — เป็น local ภายใน view เดียว ไม่ข้ามหน้า ต้นทุนต่ำ ไม่ขัดกับระดับ motion "กลาง"

### ➡️ ย้ายที่

| ของ | จาก | ไป |
|---|---|---|
| ร่นคาบวันนี้ | ปุ่มเฟือง → sheet | Menu จุดไข่บน toolbar → `PeriodShiftSheet` ตรง |
| เปลี่ยนเทอม | ปุ่มเฟือง → sheet → Picker | Menu ย่อยใน Menu จุดไข่ |
| จัดการเทอมทั้งหมด | ปุ่มเฟือง → sheet → NavigationLink | Menu จุดไข่ → push `TermManagementView` |
| เพิ่มคาบ | ปุ่ม `+` toolbar | ปุ่ม `+` กลาง tab bar |

---

## 4. หน้าตาใหม่

```
toolbar:  ตารางเรียน                              ⋯
          ม.5 เทอม 1
──────────────────────────────────────────────
day bar:  ( จ )  อ   พ   พฤ  ศ        ← แคปซูลทึบตัวที่เลือก
──────────────────────────────────────────────
[แถบร่นคาบ ถ้ามี]

┌─────────────────────────────────────────┐  มุมมน 18 ทั้ง 4 มุม
│ 08:00  [🔢]  คณิตศาสตร์เพิ่มเติม    5201 │
│ 08:50        คาบ 1 · ครูณัฐวุฒิ          │
│ ─────────────────────────────────────── │
│ 09:00  [⚛︎]  ฟิสิกส์                5304 │
│ 09:50        คาบ 2 · ครูพีรพล · ว31201   │
│ ─────────────────────────────────────── │
│ ● กำลังเรียน · เหลือ 12 นาที             │  ← พื้น primarySoft
│ 10:00  [🅰]  ภาษาอังกฤษ            5108 │
│ 10:50        คาบ 3 · ครูจริยา            │
│        ▓▓▓▓▓▓▓░░░ progress               │
│ ─────────────────────────────────────── │
│ 12:00        พักกลางวัน                  │  ← แถบครีม full-bleed
└─────────────────────────────────────────┘
```

### 4.1 `SchedulePeriodRow` — เหลือ 4 บล็อก

| ตำแหน่ง | เนื้อหา |
|---|---|
| ซ้าย (กว้างคงที่ 34) | เวลาเริ่ม / เวลาจบ ซ้อน 2 บรรทัด · สี `warning` เมื่อ `period.isShifted` |
| ไอคอน 32×32 | `IconTile` — `subject.iconName` บนพื้น `subject.color.opacity(0.14)` มุม `Radius.icon` |
| กลาง (ยืด) | ชื่อวิชา (**ไม่จำกัดบรรทัด — ให้ตัด 2 บรรทัดได้**) + บรรทัดรอง `"คาบ N · <ครู> · <รหัส>"` |
| ขวา | ห้องเรียน — `PillLabel` สีกลาง (`textSecondary` บน `surfaceRaised`) |

- **ตัด chevron ทิ้ง** — ทั้งแถวกดได้อยู่แล้ว chevron 8 อันเรียงกันเป็นเสียงรบกวน
- เลขคาบย้ายลงบรรทัดรอง แทนที่จะเป็นตัวเลขใหญ่ซ้ายสุด (เวลาสำคัญกว่าเลขคาบ)

### 4.2 สถานะ "กำลังเรียน" — ของใหม่

แสดงเมื่อ **`selectedDay == ScheduleConstants.todayWeekday`** เท่านั้น (ดูวันอื่นไม่ต้องมี)

- พื้นแถว `Theme.Colors.primarySoft`
- บรรทัดบนสุด: จุด 5pt สี `primary` + `"กำลังเรียน · เหลือ N นาที"` สี `primaryDeep`
- progress bar 3pt ใต้บรรทัดรอง — `(now - start) / (end - start)`
- เวลาซ้ายเปลี่ยนเป็นสี `primaryDeep`

รีเฟรชด้วย `TimelineView(.periodic(from: .now, by: 60))` — **แบบเดียวกับ `DashboardNextClassCard`** ห้ามตั้ง `Timer` เอง

**เพิ่มใน `ScheduleConstants`** (จุดเดียวที่รู้จักการแปลงวัน — ตอนนี้สูตรนี้ถูกเขียนซ้ำ 2 ที่ ทั้งใน `ScheduleView.init` และ `ScheduleDayPickerBar.todayWeekday`):

```swift
/// 1=จันทร์ ... 7=อาทิตย์ (Calendar.weekday คือ 1=อาทิตย์)
static var todayWeekday: Int {
    let raw = Calendar.current.component(.weekday, from: .now)
    return raw == 1 ? 7 : raw - 1
}
```
แล้วให้ทั้ง `ScheduleView.init` และ `ScheduleDayPickerBar` เรียกตัวนี้แทนสูตรของตัวเอง

### 4.3 `ScheduleDayPickerBar`

- ตัวที่เลือก = แคปซูลทึบ `primary` ตัวอักษร `onPrimary`
- ตัวอื่น = ไม่มีพื้น ตัวอักษร `textSecondary`
- **จุดบอกวันนี้ย้ายไปอยู่ในแคปซูล** — วันนี้แต่ไม่ได้เลือก: ตัวอักษรเป็น `primaryDeep` (ไม่ต้องมีจุดแยก)
- พื้นแถบ: เปลี่ยนจาก `cardBackground` เป็น `background` — แถบนี้ไม่ใช่การ์ด ไม่ควรมีพื้นของตัวเอง
- คง `matchedGeometryEffect` ไว้ แค่ย้ายจากขีดใต้ไปเป็นแคปซูล

### 4.4 `ScheduleBreakRow`

- ตัดวงกลมมีขอบ 36×36 ทิ้ง — แถบครีมบอกอยู่แล้วว่าเป็นช่วงพัก
- เหลือ: เวลา (ตำแหน่งเดียวกับแถวคาบ) + ชื่อช่วงพัก
- สีตัวอักษรเปลี่ยนจาก `textPrimary`/`warning` เป็นโทนอ่อนลง — ช่วงพักไม่ควรเด่นกว่าคาบเรียน

### 4.5 `PeriodShiftBanner`

- พื้น `warning.opacity(0.15)` คงเดิม แต่**ตัวอักษรเปลี่ยนเป็น `textPrimary`** ไอคอนเท่านั้นที่เป็น `warning`
- radius → `Theme.Radius.card`

### 4.6 toolbar Menu จุดไข่

```swift
Menu {
    Button("ร่นคาบวันนี้", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90") { … }
    Menu("เปลี่ยนเทอม") {
        ForEach(SchoolBand.upper.gradeLevels …) { … }   // ยกโค้ดจาก ScheduleSettingsSheet มาตรงๆ
    }
    Divider()
    NavigationLink("จัดการเทอมทั้งหมด") { TermManagementView() }
} label: {
    Image(systemName: "ellipsis")
}
```

⚠️ `TermManagementView` ยังถูกเปิดจาก `SettingsView` อีกทางหนึ่ง — **ห้ามแก้ไฟล์นั้น** แค่เพิ่มทางเข้าที่สอง
⚠️ ตรรกะ `termSelection` binding (สร้างเทอม + `setActive` + `syncTermSubjects`) ให้**ยกมาทั้งก้อน ห้ามเขียนใหม่** — มันเรียก `TermStore` ซึ่งเป็น logic ที่ห้ามแตะ

---

## 5. ผลกระทบข้ามโมดูล — ต้องบอก 05_Settings

ลบ `ScheduleTodayTasksSection` แล้ว `@AppStorage("scheduleShowsPersonalTasks")` เหลือผู้ใช้เพียงที่เดียวคือ Toggle ใน `SettingsView.swift:167` ("แสดงงานส่วนตัวในตารางเรียน") — **กลายเป็นสวิตช์ที่ไม่ควบคุมอะไรเลย**

→ `05_Settings.md` ต้องลบ Toggle ตัวนั้น **ห้ามให้ agent โมดูล Schedule ไปแก้ `SettingsView.swift` เอง**

---

## 6. ไฟล์ที่แตะ

| ไฟล์ | ทำอะไร |
|---|---|
| `Features/Schedule/ScheduleView.swift` | ตัด TodayTasks · ตัดปุ่ม `+` · toolbar Menu จุดไข่ · ส่ง `isToday` ลงไป |
| `Features/Schedule/ScheduleConstants.swift` | เพิ่ม `todayWeekday` |
| `Features/Schedule/ScheduleDayPickerBar.swift` | แคปซูล (§4.3) |
| `Features/Schedule/ScheduleTimetableSection.swift` | ตัด `headerRow` |
| `Features/Schedule/SchedulePeriodRow.swift` | layout ใหม่ + สถานะกำลังเรียน (§4.1–4.2) |
| `Features/Schedule/ScheduleBreakRow.swift` | เบาลง (§4.4) |
| `Features/Schedule/PeriodShiftBanner.swift` | คอนทราสต์ (§4.5) |
| `Features/Schedule/AddScheduleEntrySheet.swift` | **ทาสีอย่างเดียว** — เป็น `Form` มาตรฐาน โครงไม่แตะ |
| `Features/Schedule/AddSubjectSheet.swift` · `SubjectPickerFields.swift` · `PeriodNumberField.swift` · `PeriodShiftSheet.swift` · `ScheduleImportReviewSheet.swift` · `ScheduleImportRowEditSheet.swift` | **ทาสีอย่างเดียว** |
| ~~`Features/Schedule/ScheduleTodayTasksSection.swift`~~ | **ลบไฟล์** |
| ~~`Features/Schedule/ScheduleSettingsSheet.swift`~~ | **ลบไฟล์** |

---

## 7. ความเสี่ยง

| เสี่ยง | กัน |
|---|---|
| แตะ `PeriodShiftCalculator` แล้วการร่นคาบพัง | ไฟล์นั้นอยู่ใน `Core/Schedule/` — **ไม่อยู่ในรายการไฟล์ที่แตะ** |
| ลบ `ScheduleSettingsSheet` แล้วสลับเทอมไม่ได้ | ยกโค้ด `termSelection` binding มาทั้งก้อน แล้วทดสอบว่ายังสลับได้จริง |
| `AddScheduleEntrySheet` 381 บรรทัด แก้แล้ว type-check ไม่ผ่าน | ทาสีอย่างเดียว ไม่เพิ่มโครง |
| `SchedulePeriodRow` ยาวขึ้นจากสถานะกำลังเรียน | ตอนนี้ 114 บรรทัด · ถ้าเกิน 200 ให้แยก `SchedulePeriodRow+Now.swift` |
| Toggle ที่ Settings กลายเป็นปุ่มตาย | §5 — ส่งต่อให้ `05_Settings.md` |

---

## 8. เกณฑ์เสร็จ

เข้าแท็บตารางเรียน:

1. แถวคาบมีไอคอนวิชา มุมการ์ดมนครบ 4 มุม · ชื่อวิชายาวๆ ไม่โดนตัดกลางคำ
2. **คาบที่กำลังเรียนอยู่ตอนนี้เรืองขึ้นมาเอง** พร้อม progress bar และนับถอยหลังเป็นนาที
3. เปลี่ยนไปดูวันอื่น → ไม่มีแถวไหนเรือง (เพราะไม่ใช่วันนี้)
4. ไม่มีหัวตาราง "คาบ/เวลา/วันจันทร์/ห้องเรียน" แล้ว
5. ไม่มีการ์ด "งาน/การบ้านวันนี้" แล้ว
6. ไม่มีปุ่ม `+` และปุ่มเฟืองบน toolbar — เหลือจุดไข่อันเดียว
7. กดจุดไข่ → ร่นคาบวันนี้ / เปลี่ยนเทอม / จัดการเทอมทั้งหมด ครบ 3 อย่าง และ **สลับเทอมแล้วตารางเปลี่ยนจริง**
8. กดปุ่ม `+` กลางแถบล่างขณะอยู่แท็บนี้ → `AddScheduleEntrySheet` เด้งตรง
9. สลับ dark mode แล้วแถวกำลังเรียนยังอ่านออก

---

## 9. ข้อที่ยังไม่ตัดสิน

**ชื่อแท็บ "ตารางสอน" หรือ "ตารางเรียน"?**
Few เขียนลำดับแท็บว่า `หน้าแรก · งาน · เพิ่ม · ตารางสอน · การตั้งค่า` แต่โค้ดปัจจุบันและ UI ทั้งหมดใช้คำว่า **"ตารางเรียน"**
ในภาษาไทย *ตารางสอน* คือของครู · *ตารางเรียน* คือของนักเรียน — แอปนี้เป็นของนักเรียน
สเปคนี้เขียนโดยใช้ **"ตารางเรียน"** ไว้ก่อน ถ้า Few ยืนยันว่าจะใช้ "ตารางสอน" ต้องไล่แก้ทุกที่ที่มีคำนี้ (label แท็บ · navigationTitle · empty state · ข้อความใน `01_Tasks.md` §4.4)
