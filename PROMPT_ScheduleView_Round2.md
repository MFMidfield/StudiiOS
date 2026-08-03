# คำสั่งสำหรับ Claude Code (Sonnet, thinking: high) — รอบ 2 · UI ตาราง + ฟอร์ม

> **ห้ามรันรอบนี้ก่อนที่รอบ 1 จะ build เขียวและ Few ยืนยันแล้ว**
> วิธีใช้: copy ทุกอย่างใต้เส้นคั่นไปวางใน Claude Code

---

อ่าน `PROJECT_MAP.md` และ `PLAN_ScheduleView.md` ก่อนเริ่ม รอบ 1 (Models + Schema + Theme + AppLog + ScheduleConstants) เสร็จและ build ผ่านแล้ว รอบนี้ทำ **UI หน้าตารางเรียน + ฟอร์มเพิ่ม/แก้คาบ + ฟอร์มเพิ่มวิชา** เท่านั้น

**ยังไม่ต้องทำในรอบนี้:** section งาน/การบ้านวันนี้ · ระบบร่นคาบ (เก็บไว้รอบ 3)

## ดีไซน์เป้าหมาย

```
┌─────────────────────────────────────────────┐
│  จันทร์  อังคาร   พุธ   พฤหัส   ศุกร์          │ ← 5 วัน (ซ่อน ส-อา)
│   ━━━                                        │   วันที่เลือกมีขีดใต้ + ตัวหนาสีน้ำเงิน
├─────────────────────────────────────────────┤
│ ┌─ CardContainer ─────────────────────────┐ │
│ │ คาบ │ เวลา │    วันจันทร์    │ ห้องเรียน │ │ ← header สีจาง
│ ├──────┼──────┼─────────────────┼──────────┤ │
│ │  1   │08:00 │ ● 📐 คณิตศาสตร์เพิ่มเติม ม.5│5201│›│
│ │      │08:50 │    ครูณัฐวุฒิ อินทร์แก้ว    │    │ │
│ ├──────┼──────┼─────────────────┼──────────┤ │
│ │  2   │09:00 │ ● 📖 ฟิสิกส์              │5304│›│
│ │      │09:50 │    ครูพีรพล โชคชัย         │    │ │
│ ├─────────────────────────────────────────┤ │
│ │╔═══ พื้นหลัง breakBackground ══════════╗│ │ ← แถวพัก
│ │║  🍽   พักกลางวัน                      ║│ │   ไม่มีเลขคาบ ไม่มี chevron
│ │║       12:00 – 13:00                   ║│ │
│ │╚═══════════════════════════════════════╝│ │
│ │  5   │13:00 │ ● 🧪 เคมี                │5103│›│
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
 Toolbar ขวาบน: [ + ]
```

## ไฟล์ที่ต้องสร้าง (แตกไฟล์ตามนี้ ห้ามยัดรวมไฟล์เดียว)

```
Features/Schedule/ScheduleDayPickerBar.swift
Features/Schedule/ScheduleTimetableSection.swift
Features/Schedule/SchedulePeriodRow.swift
Features/Schedule/ScheduleBreakRow.swift
Features/Schedule/AddScheduleEntrySheet.swift
Features/Schedule/AddSubjectSheet.swift
```
และเขียน `Features/Schedule/ScheduleView.swift` ใหม่ (ตอนนี้เป็นหน้าเปล่า)

> **เหตุผลที่ต้องแตกไฟล์:** SwiftUI `body` ยาวๆ ทำให้ compiler ฟ้อง *"unable to type-check this expression in reasonable time"* — เจอ error นี้เมื่อไหร่ให้แตก sub-view เพิ่ม ไม่ใช่ไล่แก้ syntax

---

## 1. `ScheduleDayPickerBar.swift`

- `ForEach(ScheduleConstants.visibleDays)` → ปุ่มชื่อวันสั้น (`dayLabels`)
- วันที่เลือก: ตัวหนา `Theme.Colors.primary` + ขีดใต้หนา 3pt มุมโค้ง · วันอื่น: `Theme.Colors.textSecondary`
- วันที่ตรงกับ **วันนี้จริง** มีจุดเล็กๆ ใต้ชื่อ (ไม่ต้องแสดงเลขวันที่)
- แตะแล้วเปลี่ยน binding + log `AppLog.action("Schedule", "เลือกวัน: <ชื่อวัน>")`
- ใส่ `.animation(.snappy, value: selectedDay)` ให้ขีดใต้เลื่อนนุ่มๆ

## 2. `ScheduleView.swift` (root)

```swift
struct ScheduleView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]
    @Query private var allEntries: [ScheduleEntry]
    @State private var selectedDay: Int = <วันนี้ ถ้าเป็นเสาร์/อาทิตย์ให้ fallback เป็น 1>
    @State private var editingEntry: ScheduleEntry?   // nil = ปิด sheet
    @State private var isAddingEntry = false
    ...
}
```
- กรอง entries ของวันที่เลือกแล้ว **sort ด้วย `startMinute`** (ไม่ใช่ `periodNumber` — เผื่อผู้ใช้กรอกเลขคาบสลับ)
- `.toolbar` ปุ่ม `+` → เปิด `AddScheduleEntrySheet` โหมดเพิ่ม
- empty state: ถ้าวันนั้นไม่มีคาบเลย → ไอคอนจางๆ + `"ยังไม่มีคาบเรียนในวัน<ชื่อวัน>"` + ปุ่ม `"+ เพิ่มคาบเรียน"`
- `.background(Theme.Colors.background)` · `.navigationTitle("ตารางเรียน")` · `.navigationBarTitleDisplayMode(.inline)`

## 3. `ScheduleTimetableSection.swift`

- ห่อด้วย `CardContainer` ที่มีอยู่
- **header row**: `คาบ | เวลา | <ชื่อวันเต็ม จาก dayLabelsFull> | ห้องเรียน` — ฟอนต์ `.caption` สี `textSecondary` ชื่อวันตรงกลางสี `primary` ตัวหนา
- วนแถว: `entry.subject?.isBreak == true` → `ScheduleBreakRow` · นอกนั้น → `SchedulePeriodRow`
- คั่นแต่ละแถวด้วยเส้น `Theme.Colors.separator` สูง 1pt (ยกเว้นรอบแถวพัก)

## 4. `SchedulePeriodRow.swift`

layout แนวนอน: `[เลขคาบ] [เวลา 2 บรรทัด] [จุดกลมสี] [ไอคอนกล่อง] [ชื่อวิชา / ชื่อครู] [pill ห้อง] [›]`

| ส่วน | สเปค |
|---|---|
| เลขคาบ | `.title3` ตัวหนา สี `textPrimary` กว้างคงที่ ~28pt |
| เวลา | 2 บรรทัด `.caption` `textSecondary` — `startMinute`/`endMinute` แปลงเป็น `"08:00"` |
| จุดกลมสี | วงกลม 8pt สี `subject.color` |
| ไอคอนกล่อง | สี่เหลี่ยม 36×36 `Radius.control` พื้น `subject.color.opacity(0.12)` ไอคอน `subject.iconName` สี `subject.color` |
| ชื่อวิชา | `.subheadline` ตัวหนา · ถ้ามี `subject.code` ให้โชว์รหัสเป็น `.caption2` ต่อท้ายบรรทัดชื่อครู |
| ชื่อครู | `.caption` `textSecondary` — **ถ้า `teacherName` ว่างให้ซ่อนบรรทัดนี้ไปเลย** ไม่ต้องเว้นที่ |
| pill ห้อง | `location` ในแคปซูลพื้น `subject.color.opacity(0.12)` ตัวอักษรสี `subject.color` — **ว่าง = ซ่อน pill** |
| chevron | `chevron.right` `.caption` `textSecondary` |

ทั้งแถวเป็น `Button` → เปิดฟอร์มแก้ + log `AppLog.action("Schedule", "แตะคาบ <n> · <วิชา> → เปิดฟอร์มแก้")`
ใช้ `.buttonStyle(.plain)` เพื่อไม่ให้ข้อความเป็นสีน้ำเงินหมด

**fallback ตอน `subject == nil`** (เช่นวิชาถูกลบ): ใช้ `subjectName` เป็นชื่อ · สี `textSecondary` · ไอคอน `questionmark.square.dashed`

## 5. `ScheduleBreakRow.swift`

- พื้นหลัง `Theme.Colors.breakBackground` เต็มความกว้างการ์ด
- ไอคอนในวงกลมสีขาวขอบ `warning` · ชื่อ `.subheadline` ตัวหนา · เวลา `"12:00 – 13:00"` บรรทัดล่าง `.caption`
- **ไม่มี** เลขคาบ · ห้อง · ครู · chevron — แต่ยังกดเพื่อแก้ได้ (แตะทั้งแถว)

## 6. `AddScheduleEntrySheet.swift` — ใช้ทั้งโหมดเพิ่มและแก้

```swift
struct AddScheduleEntrySheet: View {
    let editing: ScheduleEntry?      // nil = โหมดเพิ่ม
    let defaultDay: Int
    ...
}
```

| ฟิลด์ | ชนิด | บังคับ |
|---|---|:---:|
| วัน | Picker `ScheduleConstants.visibleDays` | ✅ default = `defaultDay` |
| คาบที่ | Picker 0–10 + ตัวเลือกท้าย `"กำหนดเอง"` → เผย TextField `.keyboardType(.numberPad)` | ✅ |
| เวลาเริ่ม | DatePicker `.hourAndMinute` | ✅ |
| เวลาสิ้นสุด | DatePicker `.hourAndMinute` | ✅ |
| วิชา | Picker จาก `subjects` + แถวท้าย **"+ เพิ่มวิชาใหม่"** เปิด `AddSubjectSheet` ซ้อน | ✅ |
| ชื่อครู | TextField | ❌ |
| ห้องเรียน | TextField | ❌ |

- DatePicker ใช้ `Date` ภายใน แต่ **แปลงเป็น `Int` นาที** ก่อนเซฟเสมอ
- ปุ่ม "บันทึก" `.disabled` เมื่อ: ยังไม่เลือกวิชา · เลขคาบว่าง/ไม่ใช่ตัวเลข · `endMinute <= startMinute`
- ถ้าเวลาซ้อนทับคาบอื่นในวันเดียวกัน → **ไม่บล็อก** แต่โชว์ข้อความเตือนสีส้มใต้ฟิลด์เวลา + `AppLog.warn`
- **โหมดแก้**: มีปุ่ม `"ลบคาบเรียนนี้"` สีแดงใน Section ล่างสุด → `.confirmationDialog("ลบคาบนี้?")` ยืนยันก่อนลบจริง (ไม่มี swipe-to-delete)
- เซฟแล้ว `dismiss()`

**log ที่ต้องมี:**
```
🔵 [Schedule] เปิดฟอร์มเพิ่มคาบ (วัน=จันทร์)
🔵 [Schedule] เปิดฟอร์มแก้คาบ: คาบ 2 · ฟิสิกส์
🔵 [Schedule] เพิ่มคาบสำเร็จ: คาบ 2 · ฟิสิกส์ · 09:00-09:50 · ห้อง 5304 · ครูพีรพล
🔵 [Schedule] แก้คาบสำเร็จ: คาบ 2 · ห้อง 5304 → 5305
🔵 [Schedule] ลบคาบ: คาบ 2 · ฟิสิกส์ · วันจันทร์
🟠 [Schedule] เวลาซ้อนทับกับ คาบ 1 (08:00-08:50)
🟠 [Schedule] บันทึกไม่ได้: เวลาสิ้นสุดต้องมากกว่าเวลาเริ่ม
🔴 [Schedule] save ล้มเหลว: <error>
```

## 7. `AddSubjectSheet.swift`

| ฟิลด์ | ชนิด | บังคับ |
|---|---|:---:|
| ชื่อวิชา | TextField | ✅ |
| ใส่รหัสวิชา | Toggle → เผย TextField | ❌ |
| สี | `LazyVGrid` วงกลม 8 สีจาก `subjectPaletteHex` มี ✓ บนตัวที่เลือก | default = สีถัดไปตามจำนวนวิชา |
| ไอคอน | `LazyVGrid` SF Symbols 16 ตัว | default `book.closed.fill` |
| เป็นช่วงพัก | Toggle + คำอธิบาย `"จะแสดงเป็นแถบพิเศษ ไม่มีเลขคาบ"` | default off |

ไอคอนที่ให้เลือก: `function` `atom` `book.closed.fill` `textformat.abc` `globe.asia.australia.fill` `flask.fill` `leaf.fill` `paintpalette.fill` `figure.run` `music.note` `hammer.fill` `desktopcomputer` `person.3.fill` `flag.fill` `fork.knife` `star.fill`

- กันชื่อซ้ำ: ถ้ามีวิชาชื่อนี้แล้ว (case-insensitive) → เตือน `"มีวิชานี้อยู่แล้ว"` + ปิดปุ่มบันทึก
- สร้างเสร็จ → **เลือกวิชานั้นให้อัตโนมัติ** ในฟอร์มที่เปิดมันมา
- log: `🔵 [Subject] เพิ่มวิชา: เคมี (ว31221) สี=#E91E63 ไอคอน=flask.fill isBreak=false`

## 8. อัปเดต `PROJECT_MAP.md`

เพิ่มไฟล์ใหม่ทั้ง 6 + ScheduleView ใน §2 · เพิ่มบรรทัดใน §4 (navigation) ว่าหน้า Schedule มี sheet ย่อย 2 ตัว

---

## กฎที่ต้องทำตาม

1. **ห้ามบอกว่า build ผ่าน** — คุณคอมไพล์ไม่ได้
2. **ห้ามแตะ `.pbxproj`** — ไฟล์ใหม่เข้า target อัตโนมัติ
3. **ห้าม hardcode สี/ระยะห่าง/มุมโค้ง** — ต้องมาจาก `Theme` เท่านั้น ถ้าต้องการโทเคนใหม่ให้เพิ่มใน `Theme.swift` ก่อนแล้วบอกผม
4. **ห้ามเพิ่ม SPM package**
5. iOS 26.5 → **ห้ามเขียน `if #available`**
6. ข้อความ UI ภาษาไทยทั้งหมด
7. **ห้ามแตะ `Assignment` / DashboardView / CalendarView** ในรอบนี้
8. ทุก View ต้องมี `#Preview` ที่ใช้ `.modelContainer(for: [...], inMemory: true)` และ seed ข้อมูลตัวอย่าง 2-3 คาบ + พักกลางวัน จะได้ดูใน canvas ได้
9. **ยังไม่ commit** จนกว่าผมยืนยัน build ผ่าน — ถ้าจะ commit ขึ้นต้น `wip:`

## ปิดท้ายด้วยบล็อกนี้เสมอ

```
เช็คแล้ว:
- <verify ได้จริง>

ยังไม่ได้เช็ค:
- ยังไม่ได้คอมไพล์ (รัน xcodebuild ไม่ได้)
- <อื่นๆ>

รบกวน Few:
1. กด ⌘B — ถ้าแดง copy error ทั้งก้อนมาวาง
2. ถ้าเขียว: แท็บ "ตารางเรียน" → กด + → เพิ่มคาบ 1 คณิต 08:00-08:50 ห้อง 5201 ครูณัฐวุฒิ
3. กด + อีกครั้ง → เลือก "+ เพิ่มวิชาใหม่" → สร้าง "ฟิสิกส์" สีเขียว → เพิ่มเป็นคาบ 2
4. เพิ่มคาบพักกลางวัน (เลือกวิชา "พักกลางวัน") 12:00-13:00 → ต้องขึ้นเป็นแถบสีครีม
5. แตะแถวคาบ 2 → ฟอร์มแก้ต้องเปิดพร้อมข้อมูลเดิม → เปลี่ยนห้อง → บันทึก → เห็นเปลี่ยนทันที
6. แตะแถวคาบ 2 อีกรอบ → กดลบ → ยืนยัน → หายไป
7. เลื่อนไปวันอังคาร → ต้องเป็น empty state
8. ปิดแอปแล้วเปิดใหม่ → ข้อมูลยังอยู่ครบ
9. ส่ง screenshot มาให้ดูด้วยว่าหน้าตาตรงกับ mockup แค่ไหน
```
