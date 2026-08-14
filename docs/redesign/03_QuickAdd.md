# 03 · QuickAdd — เมนู "เพิ่มอะไรดี?"

> โมดูล `PrototypeApp/Features/QuickAdd/` (ไฟล์เดียว 338 บรรทัด)
> **นี่คือโมดูลที่มีบั๊กข้อมูลหายมากที่สุดในแอป** — 3 จุด

---

## 1. สภาพปัจจุบัน

```
QuickAddSheet  (half-sheet, กริด 3 คอลัมน์ 4 ตัวเลือก)
├── งาน        → AddTaskSheet            ← ของจริง
├── ปฏิทิน     → CaptureDetailSheet(.calendar)   ← ฟอร์มซ้ำที่เขียนเอง
├── โน๊ต       → CaptureDetailSheet(.note)       ← ฟอร์มซ้ำที่เขียนเอง
└── Portfolio  → CaptureDetailSheet(.portfolio)  ← ฟอร์มซ้ำที่เขียนเอง
```

## 2. ปัญหา — ตรวจกับโค้ดจริงแล้วทุกข้อ

| # | ปัญหา | ระดับ |
|---|---|---|
| 1 | **โน๊ตหายตลอดกาล** — `QuickAddSheet:293` `context.insert(Note(...))` แต่ `grep` ทั้งแอปแล้วไม่มี `@Query` ตัวไหนอ่าน `Note` เลย ผู้ใช้บันทึกแล้วไม่มีทางเปิดดูอีก | **บั๊กข้อมูลหาย** |
| 2 | **`repeatOption` เป็นของหลอก** — มี Picker 4 ตัวเลือก แต่ `save()` ไม่เคยอ่านค่า | **บั๊กข้อมูลหาย** |
| 3 | **`tags` เป็นของหลอก** — มี TextField แต่ `save()` ไม่เคยอ่านค่า | **บั๊กข้อมูลหาย** |
| 4 | ฟอร์มปฏิทิน**ไม่มีช่องชื่อกิจกรรม** — `detailTitle` เอา `detail` มาเป็นชื่อ ถ้าว่างชื่อกลายเป็นคำว่า "กิจกรรมปฏิทิน" | สูง |
| 5 | `canSave` ของปฏิทินเช็ค `detail` (ช่องล่างสุด) ไม่ใช่ชื่อ → กรอกครบข้างบนแล้วปุ่มยังเทา | สูง |
| 6 | ฟอร์มปฏิทิน**ซ้ำกับ `EventFormSheet`** ที่มีอยู่แล้วและทำได้มากกว่าทุกด้าน (ชื่อ · tag จริง · เลือกสี · custom alert) | สูง |
| 7 | ฟอร์ม Portfolio **ซ้ำกับ `PortfolioItemSheet(mode: .create)`** และ **ใส่รูปไม่ได้** ทั้งที่รูปคือหัวใจของพอร์ต | สูง |
| 8 | ภาษาอังกฤษปนไทยในฟอร์มเดียว — Repeat · Location · Tags · Alert · Note · Detail · All day | กลาง |
| 9 | `colorHex: "E1802F"` hardcode สีในโค้ด (ผิดกฎ Theme) · `customAlertMinutes: 10` ยัดค่าตายตัว | กลาง |
| 10 | DatePicker "วันที่สร้าง" ของ Portfolio ถูก `.disabled(true)` — โชว์ไว้เฉยๆ กดไม่ได้ | ต่ำ |
| 11 | กริด 3 คอลัมน์ แต่มี 4 ตัวเลือก → แถวสองเหลือช่องเดียว เบี้ยว | ต่ำ |
| 12 | sheet ซ้อน sheet — กดยกเลิกในฟอร์มแล้วเจอเมนูค้าง ต้องกดปิดอีกครั้ง | ต่ำ |
| 13 | tile ของ Portfolio ใช้สี `danger` (แดง) — สีแดงในระบบสื่อว่าอันตราย/ลบ | ต่ำ |

> ปัญหา 2 ถึง 11 **หายหมดในทีเดียว**ถ้าลบ `CaptureDetailSheet` แล้วเรียกฟอร์มจริงแทน

---

## 3. ตัด / เก็บ / ย้าย

### ✂️ ตัดทิ้ง

| ตัด | เหตุผล |
|---|---|
| `CaptureDetailSheet` ทั้ง struct (~200 บรรทัด) | ฟอร์มซ้ำที่ทำได้น้อยกว่าของจริง และเป็นที่อยู่ของบั๊ก 2–11 |
| `enum CaptureMode` · `enum RepeatOption` · `enum AlertOption` · `extension AlertOption.toEventAlert()` | ใช้โดย `CaptureDetailSheet` เท่านั้น |
| ตัวเลือก **"โน๊ต"** | สร้างแล้วไม่มีที่ให้ดู — เดโม่ไม่ควรมีทางสร้างของที่เปิดดูไม่ได้ |
| กริด 3 คอลัมน์ | เปลี่ยนเป็น 2×2 |

⚠️ **ห้ามลบ `Note` model และห้ามแตะ `Schema([...])` ใน `PrototypeAppApp.swift`**
ลบ `@Model` ออกจาก schema ที่มีฐานข้อมูลเดิมอยู่ = เสี่ยง crash ตอนเปิดแอป
`SettingsView.resetAllData()` ที่มี `deleteAll(Note.self)` ก็ปล่อยไว้เหมือนเดิม — แค่ตัดทางสร้างออกจาก UI

### ✅ เก็บไว้

- `QuickAddSheet` เป็น half-sheet `.presentationDetents([.medium])` + drag indicator
- โครง `options: [QuickAddOption]` — เพิ่มทางใหม่ = เพิ่ม 1 บรรทัดในอาเรย์ (ข้อดีเดิมของไฟล์นี้ รักษาไว้)

### ➡️ ย้ายที่

| ของ | จาก | ไป |
|---|---|---|
| ฟอร์มปฏิทิน | `CaptureDetailSheet(.calendar)` | `EventFormSheet(initialDate: .now)` ที่มีอยู่แล้ว |
| ฟอร์มผลงาน | `CaptureDetailSheet(.portfolio)` | `PortfolioItemSheet(mode: .create)` ที่มีอยู่แล้ว |
| การเปิดฟอร์ม | sheet ซ้อน sheet ใน `QuickAddSheet` | sheet ชั้นเดียวที่ `RootTabView` |

---

## 4. เมนูใหม่ — 4 ทาง กริด 2×2

| ทาง | เปิดอะไร | สี tile |
|---|---|---|
| งาน | `AddTaskSheet()` | `Theme.Colors.primary` |
| กิจกรรมปฏิทิน | `EventFormSheet(initialDate: .now)` | `subjectPalette[3]` (น้ำเงินหม่น) |
| คาบเรียน | `AddScheduleEntrySheet(editing: nil, defaultDay: …)` | `subjectPalette[1]` (เขียวมะกอก) |
| ผลงาน | `PortfolioItemSheet(mode: .create)` | `subjectPalette[4]` (ม่วงหม่น) |

⚠️ **ห้ามใช้ `danger` / `warning` / `success` เป็นสีตกแต่ง** — สามตัวนี้มีความหมายในระบบ (อันตราย · เตือน · สำเร็จ) เอามาใช้เป็นสีไอคอนเมนูทำให้ความหมายเจือจาง

⚠️ `defaultDay` ของคาบเรียน: `ScheduleConstants.todayWeekday` **อาจเป็น 6 หรือ 7 (เสาร์–อาทิตย์)** ซึ่งไม่มีใน `visibleDays`
→ ต้อง `ScheduleConstants.visibleDays.contains(d) ? d : 1`

tile: ใช้ `IconTile` จาก DesignSystem (พื้น `color.opacity(0.14)` มุม `Radius.icon`) ขนาดใหญ่ 64pt + ป้ายชื่อใต้ · ทั้งใบใช้ `PressScaleButtonStyle`

---

## 5. sheet ชั้นเดียว — โครงที่ `RootTabView` ถือ

> ⚠️ **`RootTabView.swift` เป็นไฟล์ของ agent โมดูล Tasks** (สเปค `01_Tasks.md` §5)
> agent โมดูล QuickAdd **ห้ามแก้ไฟล์นี้** — ให้ทำเฉพาะ `QuickAddSheet.swift`
> ถ้าทำโดย agent ตัวเดียวทั้งหมด ให้ทำ §5 ของ `01_Tasks.md` กับ §5 นี้พร้อมกันในก้อนเดียว

ประกาศ enum ไว้ใน `RootTabView.swift`:

```swift
enum QuickAddTarget: String, Identifiable, CaseIterable {
    case menu, task, event, scheduleEntry, portfolio
    var id: String { rawValue }
}
```

`RootTabView` ถือ sheet **ใบเดียว** และให้เนื้อข้างในสลับตาม `@State` ที่อยู่ในตัว flow view —
**ไม่ใช่** `.sheet(item:)` ที่เปลี่ยน identity (การเปลี่ยน identity ระหว่างที่ sheet เปิดอยู่ทำให้ SwiftUI ปิดแล้วเปิดใหม่ เห็นกระพริบ):

```swift
@State private var showQuickAdd = false
@State private var quickAddStart: QuickAddTarget = .menu

// กด + กลาง tab bar
quickAddStart = defaultTarget(for: previousTab)   // ตาราง §5 ของ 01_Tasks
showQuickAdd = true

.sheet(isPresented: $showQuickAdd) {
    QuickAddFlow(start: quickAddStart)
}
```

`QuickAddFlow` (struct ใหม่ใน `QuickAddSheet.swift`) ถือ `@State private var target` แล้ว `switch`:

```swift
switch target {
case .menu:          QuickAddSheet(onSelect: { target = $0 })
case .task:          AddTaskSheet()
case .event:         EventFormSheet(initialDate: .now)
case .scheduleEntry: AddScheduleEntrySheet(editing: nil, defaultDay: safeDefaultDay)
case .portfolio:     PortfolioItemSheet(mode: .create)
}
```

- ฟอร์มทุกตัวใช้ `@Environment(\.dismiss)` อยู่แล้ว → กดยกเลิก/บันทึกจะปิด sheet ทั้งใบทันที **ครั้งเดียวจบ**
- ไม่มีการ present ซ้อน ไม่มีปัญหาจังหวะ
- detent: `.presentationDetents(target == .menu ? [.medium] : [.large])`
  ถ้าเปลี่ยน detent กลางคันแล้วเด้งแปลก → **ให้ใช้ `.large` ทั้งหมด** อย่าดันต่อ

---

## 6. ไฟล์ที่แตะ

| ไฟล์ | ทำอะไร |
|---|---|
| `Features/QuickAdd/QuickAddSheet.swift` | ลบ `CaptureDetailSheet` + 3 enum + extension · เหลือ 4 ตัวเลือก กริด 2×2 · เพิ่ม `QuickAddFlow` · รับ `onSelect` |
| `App/RootTabView.swift` | **เจ้าของคือ agent โมดูล Tasks** — `QuickAddTarget` + sheet ชั้นเดียว (§5) |

ไฟล์ที่**ไม่แตะ**แต่ถูกเรียกใช้: `EventFormSheet.swift` · `PortfolioItemSheet.swift` · `AddScheduleEntrySheet.swift` · `AddTaskSheet.swift`
→ ห้ามแก้ signature ของทั้งสี่ตัว ยกเว้น `presetKind:` ของ `AddTaskSheet` ที่ `01_Tasks.md` §2.2 สั่งไว้

ประมาณการ: `QuickAddSheet.swift` 338 → **~120 บรรทัด**

---

## 7. ความเสี่ยง

| เสี่ยง | กัน |
|---|---|
| ลบ `Note` model แล้วแอป crash ตอนเปิด | **ไม่ลบ model** ตัดแค่ทางสร้างใน UI |
| `EventFormSheet(initialDate:)` signature ไม่ตรง | ✅ ตรวจแล้ว — มีจริง ใช้อยู่ที่ `CalendarView.swift:232` |
| `PortfolioItemSheet(mode: .create)` signature ไม่ตรง | ✅ ตรวจแล้ว — มีจริง ใช้อยู่ที่ `PortfolioView.swift:34` |
| `defaultDay` เป็นเสาร์/อาทิตย์แล้ว picker แสดงไม่ได้ | guard ด้วย `visibleDays.contains` (§4) |
| agent 2 ตัวแก้ `RootTabView.swift` ชนกัน | ระบุเจ้าของชัดใน §5 และใน `00_INDEX.md` |
| เปลี่ยน detent กลางคันแล้ว sheet เด้ง | fallback เป็น `.large` ทั้งหมด (§5) |

---

## 8. เกณฑ์เสร็จ

อยู่หน้าแรก กดปุ่ม `+` กลางแถบล่าง:

1. เมนูเด้งขึ้นครึ่งจอ มี **4 ช่อง กริด 2×2 ลงตัว** ไม่มี "โน๊ต" แล้ว
2. กด "กิจกรรมปฏิทิน" → **เมนูหายไป ฟอร์มปฏิทินตัวจริงขึ้นมาแทน** (มีช่องชื่อกิจกรรม · เลือก tag ได้ · เลือกสีได้)
3. กด "ยกเลิก" → **ออกกลับหน้าแรกทันที ครั้งเดียว** ไม่มีเมนูค้าง
4. กด "ผลงาน" → ฟอร์มพอร์ตตัวจริง **เพิ่มรูปได้**
5. กด "คาบเรียน" → ฟอร์มเพิ่มคาบตัวจริง (มีปุ่มสแกนจากรูปในนั้น)
6. บันทึกกิจกรรมปฏิทิน → ไปเปิดหน้าปฏิทิน **เห็นกิจกรรมนั้นจริง**
7. ไม่มีช่องไหนในเมนู/ฟอร์มที่เลือกแล้วค่าหาย
8. อยู่แท็บงานแล้วกด `+` → ได้ฟอร์มงานตรง ไม่ผ่านเมนู (จาก `01_Tasks.md` §5)
