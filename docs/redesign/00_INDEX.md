# สเปค redesign รายโมดูล — สารบัญ

> แกนกลางอยู่ที่ `PLAN_Redesign.md` (design token · wave · กฎที่ห้ามลืม)
> ไฟล์ในโฟลเดอร์นี้คือสเปคระดับหน้าจอ **หนึ่งไฟล์ต่อหนึ่งโมดูล**
> agent ที่ทำโมดูลไหน อ่านแค่ไฟล์ของโมดูลนั้น + `PLAN_Redesign.md` พอ — ไม่ต้องอ่านไฟล์อื่น

---

## 🔖 สถานะปัจจุบัน — อ่านก่อนเริ่มทุก session

**branch `redesign`** (แตกจาก `dev` · `dev`/`master` ยังเป็นของเดิม ไม่ถูกแตะ)

| Wave | สถานะ |
|---|---|
| **W0** เตรียม | ✅ เสร็จ — commit rename PrototypeApp→StudiiOS, ตัด branch `redesign` |
| **W1** Theme + Dashboard + tab bar | ✅ **จบแล้ว — Few ยืนยัน ⌘B เขียว 14 ส.ค.** |
| **W2** หน้าที่เหลือ (ไฟล์ 01–08 ในโฟลเดอร์นี้) | 🔄 **ก้อน A–F จบแล้ว build เขียวทั้งหมด** (C 🟡 หน้าตายังไม่ผ่าน ดูตารางหนี้ · F เขียวรอบเดียวผ่าน 15 ส.ค. **แต่ยังไม่ได้ลองด้วยตา**) · **G ยังไม่เริ่ม** |

| **W3** custom nav · แตก CalendarView · onboarding | ⬜ ยังไม่เริ่ม |

**W2 เหลือ 1 ก้อน** — G `08_Calendar` (ทำท้ายสุดเป็นก้อนเดี่ยว งานใหญ่สุดในแผน)

### 🔄 ก้อน G — ความคืบหน้ารายขั้น (`08_Calendar` §8)

| ขั้น | งาน | สถานะ |
|---|---|---|
| 1 | แตกไฟล์ตาม §6 ย้ายโค้ดเดิมเข้าไปโดยไม่เปลี่ยนพฤติกรรม | ✅ **`xcodebuild` เขียว 15 ส.ค.** — ยังไม่ได้ลองด้วยตา |
| 2 | `MonthLayoutEngine` + เทสต์ | ✅ **เทสต์ผ่าน 10/10 บน simulator 15 ส.ค.** |
| 3 | `CalendarWeekRow` + `CalendarEventBar` วาดจาก layout | ✅ **`xcodebuild` เขียว 15 ส.ค.** — 🔴 **ยังไม่ได้ดูด้วยตา** |
| 4 | `ScrollView` 12 เดือน + หัวเดือน/ปี + ปุ่มวันนี้ | ✅ **`xcodebuild` เขียว** — 🔴 ยังไม่ได้ดูด้วยตา |
| 5 | `CalendarDaySheet` + การแตะ | ✅ **`xcodebuild` เขียว** — 🔴 ยังไม่ได้ดูด้วยตา |
| 6 | ghost drag → `CalendarDragController` (เฟส 1) | ⬜ |
| 7 | ลบ `eventsCard` · `fabButton` | ⬜ |
| 8 | auto-scroll เฟส 2 (ตัดได้) | ⬜ |

**ขั้นที่ 1 ทำอะไรจริง** — `CalendarView.swift` 963 → 291 บรรทัด · ไฟล์ใหม่ 7 ไฟล์
`CalendarMonthSection` (แถวชื่อวัน + ตาราง + `CalendarDay` + `CalendarStrings`) ·
`CalendarWeekRow` (+ `CalendarDayCell`) · `CalendarEventBar` (ชิปเดิม `dayPill`) ·
`CalendarDaySheet` (`CalendarDayItemsCard` + `CalendarItemRow` + `CalendarItemRowContent`) ·
`CalendarSearchView` · `CalendarDragController` · `CalendarItemBuilder` (ไฟล์นอกตาราง §6)

- `CalendarItemBuilder` เพิ่มมาเพราะโค้ดสร้าง `CalendarItem` เดิม**ซ้ำสองที่** (ตาราง + ค้นหา) และไม่ยกออกแล้ว root จะ 370 บรรทัด เกินแนว ~250 ของ `PLAN_Redesign` §5 ข้อ 5
- `CalendarDragController.swift` ยังเป็น **`extension CalendarView`** ไม่ใช่คลาสของตัวเอง — ขั้นนี้ห้ามเปลี่ยนพฤติกรรม · **ขั้นที่ 6 ค่อยแปลง**
  ผลข้างเคียง: สถานะ ghost/toast + `cal` + `itemsFor` + `subjectColor` + `CalendarSheet` เปลี่ยนจาก `private` เป็น `internal` (มีคอมเมนต์กำกับไว้ในโค้ดแล้ว) ขั้นที่ 6 ปิดกลับ
- ค่า hardcode (`.font(.system(size:))` · `cornerRadius: 16` · `.padding(16)`) **ยังอยู่ครบตามของเดิม** — ขั้น 3–5 ค่อยเปลี่ยนเป็น `Theme` ตอนเขียน UI ใหม่ ยังไม่ต้องรันสคริปต์ตรวจ hardcode กับโมดูลนี้

**ขั้นที่ 2 ทำอะไรจริง** — `Core/Calendar/MonthLayoutEngine.swift` (161) + `StudiiOSTests/MonthLayoutEngineTests.swift` (144)
เทสต์ 5 ข้อที่สเปคสั่ง + เคสขอบอีก 5 (นอกสัปดาห์ · ลำดับ input ไม่มีผล · เวลาในวันไม่มีผล · ช่วงกลับหัว · `maxLanes` 1) **ผ่านครบ 10**

> ⚠️ **เบี่ยงจากสเปค §4: `layout(items:)` รับ `[MonthLayoutItem]` ไม่ใช่ `[CalendarItem]`**
> `CalendarItem` ถือ `Color` (SwiftUI) + `sourceEvent`/`sourceTask` (SwiftData) — รับตรงๆ จะขัดข้อบังคับ "ฟังก์ชันบริสุทธิ์ ไม่ import SwiftUI" ของสเปคเอง
> `MonthLayoutItem` มีแค่ `id` · `startDay` · `endDay` · `sortRank` · `createdAt` (Foundation ล้วน)
>
> **ขั้นที่ 3 ต้องทำต่อ:** เขียนตัวแปลงใน `CalendarItemBuilder`
> — `CalendarItem` **ไม่มีวันสิ้นสุด** (มีแค่ `date`) แถบหลายวันจึงต้องอ่าน `CalendarEvent.endDate` ตรงๆ ตอนสร้าง `MonthLayoutItem`
> — กิจกรรมทั้งวันเก็บ `endDate` แบบ**ไม่รวมปลาย** (เที่ยงคืนวันถัดไป) ต้อง −1 วันก่อนส่งเข้า engine ไม่งั้นแถบยาวเกินไปหนึ่งช่อง
> — `CalendarWeekRow` รับ `WeekLayout` + ตาราง `[id: CalendarItem]` คู่กัน ไม่ต้องแตะ `CalendarItem.swift` ตาม §6

**ขั้นที่ 3 ทำอะไรจริง** — แถวสัปดาห์วาดจาก `WeekLayout` แล้ว (`ZStack` + `.offset` ตาม §4.1)

- `CalendarGeometry` (ใน `CalendarWeekRow.swift`) เป็น**จุดเดียว**ที่รู้ขนาดแถว — 4 เลน · แถบสูง 17 · ห่าง 3 · แถวสูง 132
  ของเดิมแถวสูง 76 โชว์ 2 ชิป · **หนึ่งเดือนสูงกว่าหนึ่งจอแล้ว ต้องเลื่อน** (Few รับทราบไว้ใน §3.1)
- `CalendarEventBar` เป็นชิป 3 แบบตาม §3.3 · ข้อความ = **ชื่อเต็ม** ไม่ใช่ชื่อวิชาแบบเดิม · ท่อนต่อเติม " (ต่อ)"
- ช่องวันไม่วาดชิปของตัวเองแล้ว เหลือแค่เลขวัน + พื้นที่แตะ · เสาร์/อาทิตย์จางลงตาม §3.2
- `+N` วางต่อท้ายเลนที่ 4 **เฉพาะคอลัมน์ที่มีของซ่อนจริง**
- `MonthLayoutEngine` ถูกเรียกที่ `CalendarView.weekLayout(row:)` **จุดเดียว** แล้วส่งผลชุดเดียวกันให้ทั้งการวาดและ ghost drag
- `hitTestItem` เลิกเดาจากลำดับ pill ในช่อง เปลี่ยนเป็นหาแถบจาก `(lane, column)` ใน `WeekLayout`
- **ชั้นแถบยัง `.allowsHitTesting(false)`** — แตะชิปเปิดฟอร์มเป็นงานขั้นที่ 5 ตอนนี้แตะตรงไหนก็เลือกวันเหมือนเดิม
- `barRadius` 5 (§3.1) เป็นค่าประจำโมดูล **ไม่มี token ขนาดนี้ใน `Theme.Radius`** — ถ้า Few อยากได้เป็น token ต้องเพิ่มใน `Theme.swift` เอง (agent ห้ามแตะ `Core/DesignSystem/`)
- วัดเวลา type-check ทั้งโมดูลแล้ว ไม่มีไฟล์ไหนเกิน 400ms (`PortfolioItemSheet.body` 1401ms เป็นหนี้เก่าของก้อน F)

**บัคที่แก้ระหว่างทาง (ก่อนขั้นที่ 4)** — เลื่อนหน้าบนตารางไม่ได้
`LongPressGesture.sequenced(before: DragGesture)` ของ SwiftUI จับนิ้วตั้งแต่แตะแรก ScrollView เลย pan ไม่ได้ (บัคมีมาก่อน ขั้นที่ 3 ทำให้ตารางเต็มจอจึงโผล่ชัด)
→ ไฟล์ใหม่ `CalendarPressDragGesture.swift` ห่อ `UILongPressGestureRecognizer` ผ่าน `UIGestureRecognizerRepresentable`
→ **ห้ามใช้ `recognizer.location(in: recognizer.view)`** — view ที่ SwiftUI แปะไว้เป็น host ก้อนใหญ่ ghost จะลงต่ำกว่านิ้วหนึ่งแถว ต้องใช้ `context.converter.location(in:)` กับ coordinate space ที่ตั้งชื่อไว้
✅ Few ยืนยันแล้ว: ลากตรง · เลื่อนได้

**ขั้นที่ 4 ทำอะไรจริง**

- `CalendarView` เป็น `VStack`: header ในหน้า → แถวชื่อวันปักหมุด → `ScrollView` + `LazyVStack` 12 เดือน
  `.scrollPosition(id:anchor:.top)` ทำให้หัวเดือนเปลี่ยนตามที่เลื่อน **ไม่ได้ใช้ `GeometryReader` ต่อแถว** ตามที่ §3.2 ห้าม
- ปี = `Menu` ปีปัจจุบัน −1…+2 (พ.ศ.) · เปลี่ยนปีแล้วเด้งไปมกราคม · ปุ่ม "วันนี้" สลับปีให้ด้วย
- **`.navigationTitle("")` + `.inline`** ห้ามใช้ `.navigationBarHidden(true)` — ปุ่มย้อนกลับจะหาย เข้าปฏิทินแล้วออกไม่ได้
- ค้นหาเป็น **sheet ของตัวเอง** (`CalendarSearchSheet`) เพราะไม่มี nav bar ให้แปะ `.searchable` แล้ว
- ghost drag เลิกใช้ `gridSize` ก้อนเดียว เปลี่ยนเป็น `monthFrames: [String: CGRect]` (12 รายการ ตาม §5.1)
  `hit(at:)` หาเดือนที่ครอบจุดนั้นก่อน แล้วค่อยหารเป็นแถว/คอลัมน์ · `CalendarGeometry.monthLabelHeight` ต้องตรงกับป้ายชื่อเดือนจริง
- เดือนที่ `LazyVStack` ยังไม่ render จะไม่มี frame → ลากไปปล่อยตรงนั้นไม่ได้ (flyBack) ตามที่สเปคเตือน

> ⚠️ **สลับลำดับกับสเปคหนึ่งข้อ:** `CalendarDayItemsCard` (การ์ดรายการใต้ตาราง) ย้ายไปเป็น **sheet ตอนแตะวัน** แล้วในขั้นนี้
> เพราะสายเลื่อน 12 เดือนกินทั้งจอ ถ้าไม่ย้ายตอนนี้ แตะวันแล้วจะไม่มีอะไรเกิดขึ้นเลยจนถึงขั้นที่ 5
> **ขั้นที่ 5 ยังต้องทำต่อ:** หัว sheet เป็น "พฤหัสบดี 13 สิงหาคม" (ต้องเพิ่ม `thaiWeekdayFull` ใน `Date+Thai.swift`) · "N รายการ" · ปุ่ม "เพิ่มกิจกรรมวันนี้" · แตะชิปในตารางเปิดฟอร์มตรงๆ (ตอนนี้ชั้นแถบยัง `allowsHitTesting(false)`)

**ขั้นที่ 5 ทำอะไรจริง**

- `CalendarDayItemsCard` → `CalendarDaySheet` — หัว "พฤหัสบดี 13 สิงหาคม" + ป้าย "วันนี้" + "N รายการ" ขวา · ปุ่ม "เพิ่มกิจกรรมวันนี้" ท้าย sheet
- `Date+Thai.swift` เพิ่ม `thaiWeekdayFull` + `thaiWeekdayFullString` (สเปค §3.5 สั่งไว้ · `01_Tasks` เติม `thaiWeekdayShort` ไปแล้ว ไม่ทับกัน)
- ชั้นแถบเลิก `allowsHitTesting(false)` — ชิปเป็น `Button` แตะแล้วเปิด `EventFormSheet(event:)` / `AddTaskSheet(editing:)` ตรงๆ · `+N` เป็นปุ่มเปิด sheet รายวันของวันนั้น
- **เปิด sheet ทับ sheet ไม่ได้** — แตะแถวใน sheet รายวันต้องปิดตัวเดิมก่อน ใช้ `pendingSheet` + `onDismiss` (แบบเดียวกับที่ก้อน A ทำใน `QuickAddSheet`)

> 📌 **หนี้เอกสาร:** `PROJECT_MAP.md` §Calendar (บรรทัด 184–185 · 541–550) ยังเขียนว่า `CalendarView` 963 บรรทัดไฟล์เดียว · ghost ใช้ `LongPressGesture` ของ SwiftUI · ค่าคงที่ 27/16 — **ผิดหมดแล้ว** ต้องเขียนใหม่ตอนปิดก้อน G

**🔴 เจอของเสียที่ไม่เกี่ยวกับก้อน G:** `GPAXCalculatorTests/achievedWhenRequiredIsZeroOrBelow()` **แดงอยู่ก่อนแล้ว**
(stash โค้ดก้อน G ออกแล้วรันบน HEAD เดิม ก็ยังแดง) — เทสต์คาด `.achieved` เมื่อ 1 เทอม GPA 4.00 เป้า 3.00
ยังไม่แตะเพราะ `GPAXCalculator` อยู่ในลิสต์ห้ามแก้ logic · **ต้องให้ Few ตัดสินว่าเทสต์ผิดหรือสูตรผิด**

### การตัดสินของ Few — 15 ส.ค. 2569

- **ปุ่ม `＋` ขวาบนใช้ไอคอนเปล่า ไม่ใช่ปุ่มมีพื้น** — ล้มข้อ "ปุ่มมีพื้น `+ คณะ`" ใน `06_TCAS` §4.1
  เหตุผล: ทุกหน้าในแอปควรมีปุ่มเพิ่มหน้าตาเดียวกัน (หน้างาน · ตารางเรียน · TCAS · ผลงาน)
  ✅ เขียนกลับเข้า `06_TCAS.md` แล้ว · ✅ **ก้อน F ทำตามแล้ว** — `PortfolioView` ใช้ ＋ เปล่า ไม่ใช่ปุ่มมีพื้น `"+ ผลงาน"` ตามที่ `07_Portfolio` เขียนไว้
- **หนี้ก้อน C (หน้าเกรด) พักไว้ก่อน** ทำ E ให้จบก่อน แล้วค่อยกลับมาเก็บ

### การตัดสินของ Few — 14 ส.ค. 2569

- **ชื่อแท็บ 4 = "ตารางเรียน"** (ปิดข้อค้างใน `02_Schedule` §9)
  ✅ **คำว่า "ตารางสอน" ถูกไล่ลบออกจากทั้งแอปแล้ว** (ก้อน B เก็บ `AddScheduleEntrySheet` · ก้อน C เก็บ `TermGradeEditView` · `ScheduleSettingsSheet` ถูกลบทั้งไฟล์)
- **ก้อน G (`08_Calendar`) ทำ** ไม่ตัดทิ้ง — ยังคงลำดับเดิม: ทำท้ายสุดเป็นก้อนของตัวเอง build ทีละขั้นตาม §8

**🔴 ล้มการตัดสินเดิม 4 ข้อ — ✅ เขียนกลับเข้าสเปค `01_Tasks.md` / `03_QuickAdd.md` เรียบร้อยแล้ว (14 ส.ค.)**
อ่านสเปคสองไฟล์นั้นได้ตรงๆ ไม่ต้องมาไล่ตารางนี้ก่อน — เก็บไว้เป็นบันทึกว่าทำไมถึงเปลี่ยน

| สเปคเดิมเขียนว่า | Few สั่งใหม่ | ผลกับโค้ด |
|---|---|---|
| `01_Tasks` §5 · `03_QuickAdd` §5 — ปุ่ม `+` กลาง tab bar เปลี่ยนตามแท็บ + sheet ชั้นเดียว (`QuickAddTarget`/`QuickAddFlow`) | **ยกเลิกทั้งสองข้อ** — ปุ่ม `+` กลาง tab bar เปิดเมนู `QuickAddSheet()` เหมือนกันทุกแท็บ | `RootTabView` ไม่มี `QuickAddTarget` / `QuickAddFlow` / `quickAddTarget(for:)` แล้ว |
| `03_QuickAdd` §3 — เลิก sheet ซ้อน sheet | **คง sheet ซ้อน sheet ไว้** · บันทึก → ปิดทั้งสองชั้น · ยกเลิก → กลับมาที่เมนู | `QuickAddSheet` ใช้ `.sheet(item:onDismiss:)` + ธง `didSave` |
| `01_Tasks` §4.4 — ไอคอนกรองบน toolbar ขวาบน · เพิ่มงานด้วยปุ่ม `+` กลาง tab bar | **ขวาบนเป็นปุ่ม `+`** — แตะ = `AddTaskSheet` · กดค้าง = เมนูกรอง ประเภท/วิชา/ล้างตัวกรอง | `TaskFilterMenu.swift` → `TaskAddMenu.swift` (`Menu(primaryAction:)`) |
| `03_QuickAdd` §4 — เมนู 4 ทาง กริด 2×2 (มี "คาบเรียน") | **3 ทาง กริด 1×3** — งาน · กิจกรรมปฏิทิน · ผลงาน (ตัด "โน๊ต" ตามเดิม · ไม่เพิ่ม "คาบเรียน") | `QuickAddSheet.options` เหลือ 3 |

### 🟡 หนี้ที่ต้องกลับมาเก็บ — Few 14 ส.ค.

| ก้อน | Few ว่าไง | ต้องทำอะไร |
|---|---|---|
| **C · หน้าเกรด** | **"ยังไม่ดีเท่าไหร่ เดี๋ยวมาเก็บตกละเอียดทีหลัง"** — build เขียว ใช้งานได้ แต่หน้าตายังไม่ผ่าน | ยังไม่ระบุจุด · ต้องถาม Few ว่าไม่ชอบตรงไหนก่อนแก้ **ห้ามเดาแล้วรื้อเอง** · จุดที่น่าสงสัยที่สุดคือกราฟแท่ง (มุมแท่งใช้ `Radius.icon` 11 อาจมนเกิน · เส้นเป้า · ความหนาแน่นของการ์ด) |
| **D · หน้าตั้งค่า** | `SettingsView` 465 บรรทัด เกินแนว ~250 ที่แผนตั้งไว้ | `body` ซอยเป็น 6 computed property แล้ว ความเสี่ยง type-check ต่ำ — **รอ Few ตัดสินว่าจะแยกอีกไหม** |
| **E · SOPEditorView** | 271 บรรทัด เกินแนว ~250 มาตั้งแต่ก่อน redesign | สเปคสั่ง "ทาสีอย่างเดียว" จึงไม่ได้แตะโครง — ถ้า type-check ช้าค่อยแยก `SOPSectionEditor` ออก |
| **F · PortfolioItemSheet** | 418 บรรทัด ใหญ่สุดในโมดูล | สเปคสั่ง "ทาสีอย่างเดียว" จึงแก้แค่ 4 จุดที่เป็นค่า hardcode ไม่แตะโครง 4 แหล่งรูป — ถ้าอยากแยกจริง สเปค §7 แนะให้ตัด `PortfolioImageSourcePicker.swift` ออกก่อน |
| ~~**ทั้งแผน** ยังไม่มีไฟล์ฟอนต์~~ | ✅ **ปิดแล้ว 15 ส.ค.** — Few วาง `IBMPlexSansThai-{Regular,Medium,SemiBold}.ttf` ครบ · log ยืนยัน `🔵 [Theme] IBM Plex Sans Thai พร้อมใช้งาน` | — |

### 🟡 ก้อน F — สถานะการ verify (15 ส.ค. 2569)

**✅ Few ยืนยัน ⌘B เขียว 15 ส.ค.** (เขียวรอบเดียว ไม่มี error ให้แก้)
**🔴 แต่ยังไม่ได้ลองด้วยตาเลยสักข้อ** — session หน้าอย่าเข้าใจผิดว่าใช้งานผ่านแล้ว

รอบ 1 (หน้าจอ): `PortfolioView` · `PortfolioCard` · `PortfolioDetailView` · `PortfolioItem.color` · เมนู Dashboard
รอบ 2 (ทาสีฟอร์ม): `PortfolioItemSheet` — แก้แค่ 4 จุด ไม่แตะโครง 4 แหล่งรูป
(`.font(.system(size: 10))` → `Theme.Font.caption` · `.font(.caption)` → `Theme.Font.caption` · `.padding(4)` → `Theme.Spacing.xs` 2 จุด)

**การตัดสินของ Few ก่อนเริ่ม F:**
- **แก้ `DashboardMenuGrid.swift` ได้ 1 บรรทัด** — "พอร์ต" → "ผลงาน" (ยกเว้นกฎ "ห้ามแตะไฟล์นอกตาราง" เฉพาะบรรทัดนี้)
- **แบ่ง 2 รอบ** — หน้าจอก่อน แล้วค่อยทาสี `PortfolioItemSheet` 418 บรรทัด

**ที่เบี่ยงจากสเปค `07_Portfolio` (ตั้งใจ):**

| # | สเปคเขียนว่า | ทำจริง | เหตุผล |
|---|---|---|---|
| 1 | §4.3 ปุ่มมีพื้น `+ ผลงาน` | ＋ ไอคอนเปล่า | การตัดสิน Few 15 ส.ค. (ข้อเดียวกับก้อน E) |
| 2 | §6 ไฟล์ใหม่ 2 ไฟล์ | ไฟล์ใหม่ **3** — เพิ่ม `PortfolioSortOrder.swift` | `PortfolioView` แตะ 255 บรรทัด เกินแนว ~250 ของ `PLAN_Redesign` §5 ข้อ 5 → แยก enum ออก เหลือ 216 |
| 3 | §4.2 การ์ดสรุปซ่อนตอนกรองหมวด | ซ่อนตอนกรองหมวด แต่ **ตอนค้นหายังโชว์** | สเปคไม่ได้สั่งเรื่องค้นหา ทำตามตัวอักษรไว้ก่อน — ถ้า Few ว่ารก ซ่อนเพิ่มได้ 1 เงื่อนไข |
| 4 | (สเปคไม่ได้เขียน) | ค้นแล้วไม่เจอ → ข้อความ "ไม่พบผลงานที่ตรงกับที่ค้นหา" | ไม่งั้นกริดว่างเปล่าโดยไม่บอกอะไร |
| 5 | (สเปคไม่ได้เขียน) | Menu เรียงลำดับปักท้ายแถว chip **นอก ScrollView** | อยู่ในแถวเลื่อนแล้วจะเลื่อนหาย |

**รายการที่ต้องกด (ยังไม่ได้ลองเลยสักข้อ):**

- กดค้างการ์ด → เมนู "ดูรายละเอียด / ลบผลงาน" → กดลบ → alert ขึ้นไหม → ลบแล้วรูปหายจากเครื่องด้วยไหม
- **`.navigationDestination(item:)` ซ้อนกับ `(for:)` ในหน้าเดียว** — จุดเสี่ยงที่สุดของก้อนนี้ ไม่เคยใช้แบบนี้ในแอปมาก่อน
  ถ้าเมนู "ดูรายละเอียด" กดแล้วไม่ push = ต้องเปลี่ยนวิธี
- ค้นคำที่อยู่ใน `detail` (ไม่ใช่ชื่อ) แล้วเจอไหม · เปลี่ยนเรียงเป็น "ชื่อ ก–ฮ" แล้วลำดับเปลี่ยนจริงไหม
- การ์ดสรุป: แถบสัดส่วนกับจุดตรงกับจำนวนจริงไหม · กรองหมวดแล้วหายไหม
- dark mode ทั้งโมดูล (ขอบการ์ดในกริดต้องยังเห็น)

### ก้อน F ทิ้งอะไรไว้ให้ก้อนอื่น

| ของ | อยู่ที่ | ใครได้ใช้ต่อ |
|---|---|---|
| **`PortfolioItemActions.delete(_:in:)`** | `Features/Portfolio/PortfolioItemActions.swift` | ใครจะลบผลงาน **ต้องเรียกตัวนี้** ห้ามเขียนลบเอง — ไม่งั้นไฟล์รูปค้างถาวร |
| แบบแผน **การ์ดสรุป = แถบสัดส่วนเดียว + legend จุด** | `PortfolioSummaryCard` | `08_Calendar` ถ้าต้องสรุปสัดส่วนประเภทกิจกรรม |
| แบบแผน **pipeline `กรอง → ค้น → เรียง` ใน computed property แทน `@Query(sort:)`** | `PortfolioView.visibleItems` | ทุกลิสต์ที่ให้ผู้ใช้สลับการเรียงเองได้ |
| `PortfolioSortOrder` | `Features/Portfolio/` | เฉพาะโมดูลนี้ (อ้าง `PortfolioItem` ตรงๆ) |

### ✅ ก้อน E — สถานะการ verify (15 ส.ค. 2569)

**Few ยืนยันบนเครื่องแล้ว:** ⌘B เขียว · แอปรันได้ · การ์ดคณะขึ้นคะแนนกับแถบ · ปุ่ม ＋ ขวาบนโอเค · หน้ากรอกคะแนนขึ้นถูก
log ตอนรันสะอาด — ไม่มี error ของเรา มีแต่ constraint warning ของคีย์บอร์ด iOS เอง (`accessoryView.bottom` ชน `inputView.top` — ยิงทุกครั้งที่ `.decimalPad` เปิด/ปิด แก้ไม่ได้จากฝั่งเรา)

**ยังไม่ได้ลองด้วยตา — session หน้าอย่าเข้าใจผิดว่าผ่านหมดแล้ว:**

- ปุ่มดินสอ → `TCASTargetSheet` เปิดไหม · ปุ่ม "ไม่ระบุเป้า" ทำให้ขีดเป้าหายจริงไหม
- section "มีผลกับคณะเป้าหมาย" ท้าย `MyScoresView` ขยับตามที่กรอกไหม
- ลบจนว่างแล้วคะแนนคณะลดกลับจริงไหม (จุดที่พลาดไม่ได้ที่สุดของก้อนนี้)
- กล่องโหมดล็อก `DisclosureGroup` กางแล้วเห็นครบ 4 บรรทัดไหม
- ปัดซ้ายลบคณะ → alert ขึ้นไหม
- **dark mode ทั้งโมดูล** (โดยเฉพาะแถบ 3 ชั้นต้องแยกออกจากกัน)

> `AppLog` ของ FamilyControls ที่โผล่ใน log มาจาก `FocusMode/AppBlockManager` ไม่ใช่ TCAS —
> **Screen Time API ใช้บน simulator ไม่ได้** ถ้าจะเดโม่ฟีเจอร์บล็อกแอปต้องรันบนเครื่องจริง

### ก้อน E ทิ้งอะไรไว้ให้ก้อนอื่น

| ของ | อยู่ที่ | ใครได้ใช้ต่อ |
|---|---|---|
| **`TCASScoreBar`** — แถบ 3 ชั้นในแท่งเดียว (เข้ม = ได้แล้ว · อ่อน = ยังไม่สอบ · ขีดตั้ง = เป้า) | `Features/TCASPlanner/TCASEntryCard.swift` (ไม่ `private`) | ใครอยากได้แถบ "ปัจจุบัน–เพดาน–เป้า" ซ้ำ เรียกได้เลย · เทียบกับ `GPAXRangeBar` ที่เป็นสเกล floor–ceiling คนละแบบ |
| แบบแผน **ปุ่ม ＋ ขวาบนเป็นไอคอนเปล่า** | `TCASPlannerView.addButton` | **ก้อน F ต้องใช้แบบเดียวกัน** (ดูการตัดสิน 15 ส.ค. ข้างบน) |
| แบบแผน **การ์ดใน `List(.plain)` + `plainRow()` + `.swipeActions` + alert ยืนยันลบ** | `TCASPlannerView` | ก้อน F/G ที่มีลิสต์ลบได้ · `plainRow()` เป็น `private extension` ประจำไฟล์ ต้องประกาศเองซ้ำ ไม่ใช่ของกลาง |
| `TCASScoreCard` **เปลี่ยน signature** เป็น `(entry:records:onEditTarget:)` | `TCASScoreCard.swift` | ไม่มีใครนอกโมดูลเรียก — grep ยืนยันแล้ว |

> ⚠️ **ที่เบี่ยงจากสเปค `06_TCAS` 2 ข้อ (ตั้งใจ เขียนเหตุผลไว้ในคอมเมนต์โค้ดแล้ว)**
> 1. แถบชั้นอ่อน **ไม่ได้ใช้ `primarySoft`** ตาม §4.1 — โทเคนนั้นเกือบเท่ากับ `separator` (สีราง) ทั้ง light/dark
>    จะแยกไม่ออก ขัด §7 ข้อ 12 → ใช้ `primary.opacity(0.3)` แทน
> 2. **การ์ดคะแนนไม่ถูกห่อ `NavigationLink` อีกแล้ว** — ปุ่มดินสอ (ตั้งเป้า) ซ้อนใน label ของ NavigationLink กดไม่ติด
>    → ทางไปตั้งน้ำหนักย้ายลงมาเป็นแถว **"น้ำหนักวิชา · 85% · 4 วิชา"** ใน `TCASEntryDetailView`

### ก้อน D ทิ้งอะไรไว้ให้ก้อนอื่น

| ของ | อยู่ที่ | ใครได้ใช้ต่อ |
|---|---|---|
| **`AppTheme`** (system/light/dark) | `Core/DesignSystem/AppTheme.swift` | ธีมทำงานทั้งแอปแล้ว — ก้อน E/F/G **ต้องเช็คหน้าตัวเองในโหมดมืดด้วย** สลับได้ที่ ตั้งค่า → การแสดงผล |
| **`GPAXSettings.resetAll()`** | `Core/Grades/GPAXSettings.swift` | ใครเพิ่ม `Key` ใหม่ใน `GPAXSettings` **ต้องมาเพิ่มในลิสต์ของ `resetAll()` ด้วย** ไม่งั้นลบข้อมูลแล้วค่าค้าง |
| **`SettingsView.reminderDefaultKey`** | `Features/Settings/SettingsView.swift` | `AddTaskSheet` อ่านไปใช้แล้ว — ห้ามลบ key นี้ ไม่งั้นสวิตช์ในตั้งค่ากลายเป็นของหลอก |
| โปรไฟล์ 3 ฟิลด์ (`school`/`room`/`program`) | `Core/Profile/StudentProfileStore.swift` | เป็น display-only ไม่มี logic ไหนอ่าน · ใครอยากโชว์บนหน้าอื่นเรียกได้เลย |
| **แบบแผน 7 แตะปลดล็อกกล่อง dev** | `SettingsView` | ถ้าก้อนอื่นมีเครื่องมือ dev ให้ยัดเข้ากล่องเดิม อย่าสร้างทางเข้าใหม่ |

### ก้อน C ทิ้งอะไรไว้ให้ก้อนอื่น

| ของ | อยู่ที่ | ใครต้องทำอะไร |
|---|---|---|
| **`GPAXTargetSheet` เสร็จแล้ว** | `Features/GradeCenter/GPAXTargetSheet.swift` | **ก้อน D ลบ section เป้า GPAX ใน `SettingsView` ได้แล้ว** — เงื่อนไข "ต้องมีที่ตั้งเป้าใหม่ก่อน" ปลดล็อกแล้ว |
| ปุ่ม **"ขึ้นชั้นแล้ว"** ใน Settings | `SettingsView` | ลิสต์เกรดกับกราฟอ้างชื่อปุ่มนี้ตรงๆ — **ห้ามลบ ห้ามเปลี่ยนชื่อ** |
| `GPAXRangeBar` แยกเป็นคอมโพเนนต์แล้ว (ไม่ `private` แล้ว) | `Features/GradeCenter/GPAXRangeBar.swift` | ใครอยากใช้แถบ floor–ceiling ซ้ำ เรียกได้เลย |

### ก้อน B ทิ้งอะไรไว้ให้ก้อนอื่น

| ของ | อยู่ที่ | ใครได้ใช้ต่อ |
|---|---|---|
| แบบแผน toolbar ของทั้งแอป: **＋ ขวาบน = เพิ่มของในหน้านี้ · ⚙︎/เมนู ซ้ายบน = งานนานๆ ครั้ง** | `ScheduleView` · `AssignmentListView` | ทุกหน้าที่มีปุ่มเพิ่ม (`06_TCAS` "+ คณะ" · `07_Portfolio` "+ ผลงาน") ควรตามแบบนี้ |
| `TimelineView` ชั้นเดียวส่ง `now` ลงลูก แทนที่จะให้ลูกถือนาฬิกาเอง | `ScheduleTimetableSection` | `08_Calendar` ถ้าต้องมีเส้นบอกเวลาปัจจุบัน |
| `CardContainer(padding: 0)` + แถวจัด padding เอง = แถว full-bleed ในการ์ดมุมมนได้ | `ScheduleTimetableSection` + `ScheduleBreakRow` | ทุกก้อนที่มีลิสต์ในการ์ด |

### ก้อน A ทิ้งอะไรไว้ให้ก้อนอื่น

| ของใหม่ | อยู่ที่ | ใครได้ใช้ต่อ |
|---|---|---|
| `ScheduleConstants.todayWeekday` + `defaultEntryDay` | `Features/Schedule/ScheduleConstants.swift` | **`02_Schedule` ไม่ต้องเพิ่ม `todayWeekday` ซ้ำแล้ว** · `defaultEntryDay` ยังไม่มีใครเรียก — `AddScheduleEntrySheet` ควรได้ใช้ |
| `Date.thaiWeekdayDayMonthString` ("พฤ. 13 ส.ค.") | `Core/Extensions/Date+Thai.swift` | `08_Calendar` §3.5 (ของเดิม `thaiWeekdayShort` = "พฤ." ยังอยู่) |
| `EventFormSheet(initialDate:onSaved:)` · `PortfolioItemSheet(mode:onSaved:)` | ไฟล์เดิมของโมดูล Calendar / Portfolio | **เป็น parameter ที่มี default `nil`** — call site เดิมไม่ต้องแก้ · `07_Portfolio` / `08_Calendar` **ห้ามลบทิ้ง** ไม่งั้น QuickAdd ปิด sheet ไม่หมด |
| `TaskAddMenu.swift` | `Features/Tasks/` | — (ไฟล์ใหม่นอกตารางสเปค แทน `TaskFilterMenu` ที่รอบแรกเขียนไว้) |

> หมายเหตุ: `01_Tasks` §7 บอกว่าถ้า `AssignmentListView` เกิน 250 บรรทัดให้แยก `TaskDayGroupSection.swift`
> แต่ Section กับ `.swipeActions` อยู่ใน `List` เดียวกัน — ย้ายออกไปเสี่ยงปัดซ้ายลบพัง จึงแยก **toolbar menu** ออกเป็น `TaskAddMenu.swift` แทน (`AssignmentListView` เหลือ ~250 บรรทัด)

### ✅ ตรวจโค้ดก้อน A กับสเปค — 14 ส.ค. 2569 (รอบปิดก้อน)

ไล่ทีละไฟล์แล้ว ตรงสเปคฉบับแก้ครบทุกข้อ ไม่มีอะไรค้าง:

| ตรวจอะไร | ผล |
|---|---|
| `TaskStatsRow.swift` · `TaskFilterSheet.swift` | หายจากโฟลเดอร์แล้วทั้งคู่ |
| เศษชื่อเก่าทั้งแอป (`CaptureDetailSheet` · `QuickAddTarget` · `QuickAddFlow` · `chipTarget` · `overdueOnly` · `dueSoonSection`) | เหลือแค่ในคอมเมนต์ 2 บรรทัดที่อธิบายว่า "ของเดิมถูกลบไปแล้ว" — ไม่มีโค้ดจริงเรียกถึง |
| `TaskScope` | chip 4 ตัว `[.notDone, .overdue, .done, .all]` · `dueSoon` ยังอยู่ในเนื้อ enum · `showsCount` · `TaskDayGroup` 6 กลุ่ม + `TaskKindFilter` ครบ |
| `AssignmentListView` (267 บรรทัด) | `List(.plain)` + `plainRow()` + `.swipeActions` ยังอยู่ · default scope `.notDone` · ไม่มี FAB · empty state ชี้ไปปุ่มขวาบนถูกแล้ว |
| `TaskAddMenu` | `Menu(primaryAction:)` แตะเพิ่ม/กดค้างกรอง + จุดบอกตัวกรอง |
| `QuickAddSheet` (124 บรรทัด) | 3 ตัวเลือก · `.sheet(item:onDismiss:)` + ธง `didSave` ตาม §5 |
| `onSaved:` ของฟอร์มที่ QuickAdd เรียก | มีครบ 3 ตัว เป็น optional default `nil` → call site เดิมไม่กระทบ |
| `RootTabView` | `.sheet { QuickAddSheet() }` เหมือนกันทุกแท็บ · แท็บ 4 = "ตารางเรียน" |
| `Date.thaiWeekdayDayMonth` · `ScheduleConstants.defaultEntryDay` | มีจริง (`defaultEntryDay` ยังไม่มีใครเรียก — ยกให้ `02_Schedule`) |
| grep ค่า hardcode ใน `Features/Tasks/` + `Features/QuickAdd/` | เจอจุดเดียว `TaskRowCard.swift:47 .font(.system(size: 20))` = SF Symbol → **อยู่ในข้อยกเว้นที่ยอมได้** |

**✅ 14 ส.ค. — Few ยืนยันว่า ⌘B เขียว และกดลองบนเครื่องแล้ว** ("ปุ่ม + ขวาบน กดค้างกรองใช้ได้ดี")
→ **W1 + W2 ก้อน A ถือว่าปิด** · commit `wip:` ของสองก้อนนี้ squash รวมได้เมื่อ Few ต้องการ

สิ่งที่ยังไม่ได้ลองด้วยตาแม้ build เขียว: ปัดซ้ายลบในหน้างาน · บันทึกจาก QuickAdd แล้วปิดครบสองชั้น · dark mode

**ค้างอยู่ที่ Few:** วางไฟล์ `IBMPlexSansThai-{Regular,Medium,SemiBold}.ttf` ใน `StudiiOS/Resources/Fonts/`
(ยังว่างอยู่ · ไม่วางก็ไม่พัง — `Theme.Font` fallback เป็นฟอนต์ระบบ ดู log `[Theme]` ตอนเปิดแอป)

### W1 ทิ้งอะไรไว้ให้ W2 บ้าง

**คอมโพเนนต์ใหม่ใน `Core/DesignSystem/` — ใช้ตัวนี้ ห้ามสร้างใหม่**

| ตัว | เรียกยังไง |
|---|---|
| `PillLabel` | `PillLabel("พรุ่งนี้", systemImage: nil, tone: .accent)` — tone: `.accent`/`.neutral`/`.danger`/`.warning`/`.custom(foreground:background:)` |
| `IconTile` | `IconTile(systemName: "book", size: 32)` หรือผูกสีวิชา `IconTile(systemName:size:color:cornerRadius:)` (พื้น `.opacity(0.14)` อัตโนมัติ) |
| `SectionHeader` | `SectionHeader("หัวข้อ")` หรือ `SectionHeader("หัวข้อ") { SectionMoreLabel() }` |
| `CardContainer` | เพิ่ม `padding:` แล้ว — `CardContainer(padding: Theme.Spacing.md) { }` สำหรับการ์ดเล็ก |
| `PressScaleButtonStyle` | **ย้ายมาอยู่ `Theme.swift` แล้ว** ไม่ได้อยู่ `DashboardMenuGrid.swift` อีก |
| `Theme.Font` | `.font(Theme.Font.body)` — title/heading/body/label/caption/number(size) · **เลิกใช้ `.font(.system(size:))`** |
| `Date.thaiDueLabel` | ป้ายกำหนดส่งสัมพัทธ์ — `01_Tasks` §4.1 ใช้ตัวนี้ได้เลย ไม่ต้องเขียน formatter ใหม่ |

**สิ่งที่ W1 ทำไปแล้วและตารางข้างล่างยังเขียนว่าเป็นงานของ agent อื่น**

- ✅ `AddTaskSheet.init(editing:presetKind:onSaved:)` — เพิ่มแล้ว default `.homework` (call site 6 จุดไม่ต้องแก้)
  `presetKind == .exam` เปิด `hasDueDate` ให้ด้วย ไม่งั้น date picker ไม่โผล่
- ✅ `RootTabView` แท็บ 2 เปลี่ยนเป็น `AssignmentListView` ("งาน") · แท็บ 4 เปลี่ยนชื่อเป็น "ตารางสอน" ·
  `DashboardDestination.calendar` เพิ่มแล้ว (ปฏิทินเข้าทางเมนูหลักทางเดียว)
  → **งานที่เหลือของ `01_Tasks` §5 คือปุ่ม `+` เท่านั้น** ไม่ใช่ทั้งไฟล์
- ✅ `PROJECT_MAP.md` อัปเดตครบแล้ว (§2 Dashboard · §4 Navigation · §5 tokens)
- ~~⚠️ เมนูหลักใช้คำว่า **"พอร์ต"**~~ ✅ ก้อน F เปลี่ยนเป็น **"ผลงาน"** แล้ว ตรงกับหัวข้อหน้าและ QuickAdd
- ⚠️ `Theme.Radius.pill` กับ `Theme.Spacing.xxxl` ประกาศไว้แล้วแต่ **ยังไม่มีใครเรียกใช้** — W2 ควรได้ใช้

| # | โมดูล | ไฟล์ | สถานะสเปค | Few อนุมัติ |
|---|---|---|---|---|
| 01 | Tasks — งาน / การบ้าน | `01_Tasks.md` | ✅ เขียนแล้ว | ✅ ตัดสินครบทุกข้อ |
| 02 | Schedule — ตารางเรียน | `02_Schedule.md` | ✅ เขียนแล้ว | ✅ ตัดสินครบ (เหลือชื่อแท็บ §9) |
| 03 | QuickAdd — เพิ่มอะไรดี | `03_QuickAdd.md` | ✅ เขียนแล้ว | ✅ ตัดสินครบ |
| 04 | GradeCenter — เกรดและ GPAX | `04_GradeCenter.md` | ✅ เขียนแล้ว | ✅ ตัดสินครบ |
| 05 | Settings — ตั้งค่า | `05_Settings.md` | ✅ เขียนแล้ว | ✅ ตัดสินครบ |
| 06 | TCAS — วางแผน TCAS | `06_TCAS.md` | ✅ เขียนแล้ว | ✅ ตัดสินครบ |
| 07 | Portfolio — ผลงาน | `07_Portfolio.md` | ✅ เขียนแล้ว | ✅ ตัดสินครบ |
| 08 | Calendar — ปฏิทิน | `08_Calendar.md` | ✅ เขียนแล้ว | ✅ ตัดสินครบ |
| — | สูตรคอมโพเนนต์ | `RECIPES.md` | ⬜ เขียนหลัง W1 เสร็จ | |

> ⚠️ **`08_Calendar` เป็นงานใหญ่ที่สุดในแผน** — เขียนหน้าใหม่ครึ่งไฟล์ + แตก 6 ไฟล์ + อัลกอริทึมจัดเลนใหม่ + เขียน hit-test การลากใหม่
> ทำเป็นก้อนของตัวเองท้ายสุด ห้ามรวมกับโมดูลอื่น และต้อง build ทีละขั้นตาม §8 ของไฟล์นั้น

---

## กฎสำหรับ agent ที่ทำโมดูลใดโมดูลหนึ่ง

1. `Core/DesignSystem/` **อ่านอย่างเดียวทั้งโฟลเดอร์** (`Theme.swift` · `PillLabel` · `IconTile` · `SectionHeader`)
   — ต้องการ token/คอมโพเนนต์ที่ไม่มี ให้หยุดแล้วรายงาน ห้ามเพิ่มเอง
2. แตะเฉพาะไฟล์ในตาราง "ไฟล์ที่แตะ" ของสเปคตัวเอง — ไฟล์อื่นห้ามแม้แต่เปิดแก้
3. **ห้ามแก้ `PROJECT_MAP.md`** — อัปเดตรวดเดียวตอนจบ wave (W1 อัปเดตแล้ว)
4. ห้ามแก้ logic: `TCASScoreEngine` · `GPAXCalculator` · `PomodoroEngine` · `PeriodShiftCalculator` · `TermStore` · `AssignmentPriorityEngine` · ทุกอย่างใน `Core/OCR/`
5. ไม่เพิ่ม `@Model` · ไม่แตะ `Schema([...])` · ไม่เพิ่ม SPM package
6. ไฟล์ view ยาวเกิน ~250 บรรทัด → แตกเป็น sub-view กัน type-check timeout
7. เสร็จแล้วรายงาน diff ไม่ commit เอง

## ผลกระทบข้ามโมดูล — ห้ามลืม

| ต้นเหตุ | ผลกระทบ | ใครแก้ |
|---|---|---|
| ~~`02_Schedule` ลบ `ScheduleTodayTasksSection`~~ | ✅ **ทำแล้ว ก้อน D** — Toggle + `@AppStorage("scheduleShowsPersonalTasks")` ถูกลบทั้งคู่ grep แล้วไม่เหลือในแอป | — |
| `02_Schedule` เพิ่มทางเข้าที่สองของ `TermManagementView` | ✅ อยู่ร่วมกันแล้ว 2 ทาง: เมนู ⚙︎ ของ `ScheduleView` + Settings → "จัดการเทอม" | — |
| `02_Schedule` เลิกใช้คำว่า "ตารางสอน" | เหลือ 4 จุดใน `TermGradeEditView.swift` (บรรทัด 192 · 201 · 202 · 239) | agent ของ `04_GradeCenter` (ก้อน C) |
| ~~`01_Tasks` §5 ปุ่ม `+` ตามแท็บ~~ | ✅ **ยกเลิกแล้ว (Few 14 ส.ค.)** — `RootTabView` เสร็จหมดแล้ว ปุ่ม `+` เปิดเมนูเดียวกันทุกแท็บ · โมดูลอื่นยังห้ามแตะไฟล์นี้จนถึง W3 | — |
| ~~`01_Tasks` เพิ่ม `presetKind:` ใน `AddTaskSheet`~~ | ✅ **W1 ทำแล้ว** — `init(editing:presetKind:onSaved:)` default `.homework` | — |
| ~~`03_QuickAdd` §5 sheet ชั้นเดียว~~ | ✅ **ยกเลิกแล้ว (Few 14 ส.ค.)** — คง sheet ซ้อน sheet ไว้ | — |
| `03_QuickAdd` เรียก `EventFormSheet` · `PortfolioItemSheet` | ห้ามแก้ signature ของสองตัวนี้ · **`onSaved:` ที่ก้อน A เติมไว้ห้ามลบ** ไม่งั้นบันทึกแล้วเมนูค้าง · `AddScheduleEntrySheet` ไม่ถูกเรียกจาก QuickAdd แล้ว | ทุก agent |
| ~~`04_GradeCenter` ย้ายการตั้งเป้ามาที่ `GPAXTargetSheet`~~ | ✅ **ทำแล้ว ก้อน D** — Settings ไม่มี section เป้า GPAX แล้ว | — |
| `04_GradeCenter` ลิสต์อ้างปุ่ม "ขึ้นชั้นแล้ว" | ✅ ปุ่มยังอยู่ใน Settings → "การเรียน" **ห้ามลบหรือเปลี่ยนชื่อตลอดไป** | ทุก agent |
| ~~`05_Settings` §4.3 สวิตช์ค่าเริ่มต้นการเตือนงาน~~ | ✅ **ทำแล้ว ก้อน D** (Few อนุมัติให้แก้ข้ามโมดูล) — `AddTaskSheet.init` อ่าน `SettingsView.reminderDefaultKey` แล้ว | — |
| ~~`05_Settings` §4.2 ธีมสว่าง/มืด~~ | ✅ **ทำแล้ว ก้อน D** — เติม `.preferredColorScheme` บรรทัดเดียวใน `RootContainerView` ไม่ได้แตะ `Schema([...])` | — |

| ~~`07_Portfolio` เปลี่ยนหัวข้อเป็น "ผลงาน"~~ | ✅ **ทำแล้ว ก้อน F** — `DashboardMenuGrid.swift:26` เป็น "ผลงาน" แล้ว ตรงกับหัวข้อหน้าและ QuickAdd | — |
| ~~`06_TCAS` + `07_Portfolio` ใช้ปุ่มมีพื้น `+ คณะ` / `+ ผลงาน`~~ | ✅ **ทำแล้วทั้งคู่** — ＋ ไอคอนเปล่าทั้ง `TCASPlannerView` (ก้อน E) และ `PortfolioView` (ก้อน F) | — |

**ลำดับที่บังคับ (เหลือข้อเดียว):** `08_Calendar` ทำท้ายสุดเป็นก้อนของตัวเอง — ข้ออื่นปลดหมดแล้ว

## บันทึกการตรวจสอบทั้งชุด — 13 ส.ค. 2569

ตรวจสเปคทั้ง 8 ไฟล์กับซอร์สจริงแล้ว

### ✅ ผ่าน

- **ไม่มีไฟล์ Swift ไหนถูกอ้างเป็น "เจ้าของ" สองโมดูล** — 7 ไฟล์ที่ถูกเอ่ยถึงข้ามโมดูล (`RootTabView` · `AddTaskSheet` · `AddScheduleEntrySheet` · `EventFormSheet` · `PortfolioItemSheet` · `StudiiOSApp` · `SettingsView`) ทุกตัวมีโมดูลเดียวที่แก้ ที่เหลือระบุชัดว่า "ห้ามแตะ / แค่เรียกใช้"
- **ไม่มี design token ที่คิดขึ้นเองนอก `Theme`** — token ทุกตัวที่สเปคอ้าง (`primary` · `primarySoft` · `danger` · `Radius.card`) มีอยู่แล้วหรือประกาศไว้ใน `PLAN_Redesign.md` §1.1
- `subjectPalette` index ที่อ้าง ([1] เขียวมะกอก · [3] น้ำเงินหม่น · [4] ม่วงหม่น · [5] ทอง) ตรงกับ `Theme.swift` จริง
- API ที่สเปคอ้างมีจริงครบ: `GPAXCalculator.upperBandSortKeys/formatted/State` · `TCASScoreEngine` ทั้ง 9 เมธอด · `TCASExamCatalog.all` · `PortfolioImageStore.delete(_:)` · `EventFormSheet(initialDate:)` · `PortfolioItemSheet(mode:)`

### 🔴 เจอปัญหา 3 ข้อ — แก้ในสเปคแล้ว

| # | ปัญหา | แก้ที่ |
|---|---|---|
| 1 | **`GPAXSettings.resetAll()` ไม่มีจริง** — สเปคอ้างถึงราวกับมีอยู่แล้ว | `05_Settings.md` §4.5 — ใส่โค้ดเมธอดที่ต้องเขียนใหม่ + อนุญาตแตะ `Core/Grades/` เฉพาะการเพิ่มเมธอด |
| 2 | **ไม่มี Thai formatter ที่ขึ้นต้นด้วยชื่อวัน** — `01_Tasks` ต้องการ "พฤ 13 ส.ค." · `08_Calendar` ต้องการ "พฤหัสบดี 13 สิงหาคม" แต่ `Date+Thai.swift` มีแต่ `thaiFull` ที่ยาวเกิน | `01_Tasks.md` §4.1 + `08_Calendar.md` §3.5 — ระบุ formatter ที่ต้องเพิ่ม + เตือนว่าสองโมดูลแก้ไฟล์เดียวกัน |
| 3 | **`06_TCAS` §4.4 เขียนผิด จะทำให้คะแนนเพี้ยน** — สั่งให้ "ลบจนว่าง → `score = 0`" แต่ `TCASScoreEngine.breakdown()` ตัดสิน "ยังไม่ระบุ" จาก **การไม่มี record** ไม่ใช่จาก `hasTaken` → ทิ้ง record ที่ score 0 ไว้จะถูกนับเป็น 0 จริง | `06_TCAS.md` §4.4 — เปลี่ยนเป็น `context.delete(record)` |

> ข้อ 3 เผยว่า **มีบั๊กอยู่แล้วในโค้ดปัจจุบัน**: `MyScoresView.update()` สร้าง `TCASScoreRecord` ทันทีที่ binding ถูกแตะ แม้ยังไม่กรอกอะไร → คะแนนวิชานั้นถูกนับเป็น 0 เงียบๆ สเปคใหม่แก้ไปในตัว

### ⚠️ ยังตรวจไม่ได้ในขั้นนี้

- `.onScrollGeometryChange` (ใช้ใน `08_Calendar` §3.2) — เชื่อว่ามีบน iOS 26 แต่ยังไม่ได้คอมไพล์ยืนยัน
- `.contextMenu` ซ้อน `NavigationLink` ในการ์ดกริด (`07_Portfolio` §4.4) — ต้องลองบนเครื่องจริง
- เปลี่ยน `presentationDetents` กลางคัน (`03_QuickAdd` §5) — มี fallback เขียนไว้แล้ว
- ไฟล์ที่สเปคสั่งแค่ "ทาสี" ยังไม่ได้อ่านเต็ม: `SOPEditorView` (271) · `PortfolioItemSheet` (411) · `PeriodShiftSheet` (281) · import sheets

---

## ตรวจว่าเพี้ยนหรือไม่ — รันหลัง agent ทุกตัว

```bash
grep -rnE 'Color\(hex:|Color\(red:|cornerRadius: [0-9]|\.padding\([0-9]|\.font\(\.system\(size:' \
  StudiiOS/Features/ | grep -v Theme.swift
```

เจอที่ไหน = ค่า hardcode ที่ไม่ได้มาจาก `Theme` → ตีกลับให้แก้

> ข้อยกเว้นที่ยอมได้ (W1 ทิ้งไว้โดยตั้งใจ): `.font(.system(size:weight:))` ที่ใช้กับ **SF Symbol เท่านั้น**
> — สัญลักษณ์ต้องใช้ system font จะใช้ `Theme.Font` ไม่ได้ · และ `Color(hex: colorHex)` ที่อ่านสีผู้ใช้เลือกเอง

---

## จบ wave แล้วต้องทำอะไรก่อน `/clear`

1. อัปเดตตาราง "สถานะปัจจุบัน" ข้างบนไฟล์นี้
2. อัปเดต `PROJECT_MAP.md` (ไฟล์ที่เพิ่ม/ลบ · `@Model` ใหม่ · tab · design token) ในคอมมิตเดียวกัน
3. เขียนไว้ให้ชัดว่า **ยังไม่ได้ verify อะไรบ้าง** — session ใหม่จะไม่รู้เลยว่าเคย build ผ่านหรือยัง
