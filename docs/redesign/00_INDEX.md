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
| **W2** หน้าที่เหลือ (ไฟล์ 01–08 ในโฟลเดอร์นี้) | 🔄 **ก้อน A + B จบ · ก้อน C build เขียวแต่ 🟡 หน้าตายังไม่ผ่าน (ดูตารางหนี้ข้างล่าง)** · กำลังทำก้อน D · E–G ยังไม่เริ่ม |

**W2 เหลือ 4 ก้อน** — D `05_Settings` (ปลดล็อกแล้ว: C เสร็จ) · E `06_TCAS` · F `07_Portfolio` · G `08_Calendar` (ท้ายสุด เดี่ยว)
| **W3** custom nav · แตก CalendarView · onboarding | ⬜ ยังไม่เริ่ม |

**W2 เหลือ 6 ก้อน** — B `02_Schedule` · C `04_GradeCenter` · D `05_Settings` · E `06_TCAS` · F `07_Portfolio` · G `08_Calendar`
ลำดับบังคับ: **C ก่อน D เสมอ** · **G ท้ายสุดเป็นก้อนเดี่ยว** · B/E/F สลับกันได้

### การตัดสินของ Few — 14 ส.ค. 2569

- **ชื่อแท็บ 4 = "ตารางเรียน"** (ปิดข้อค้างใน `02_Schedule` §9) — แก้ `RootTabView` + `DashboardNextClassCard` แล้ว
  ยังเหลือคำว่า "ตารางสอน" ในเนื้อความของ `TermGradeEditView` · `AddScheduleEntrySheet` · `ScheduleSettingsSheet` (ไฟล์สุดท้ายจะถูกลบตาม `02_Schedule`) → agent ของโมดูลนั้นๆ เก็บตอนทำ
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

### ก้อน C ทิ้งอะไรไว้ให้ก้อนอื่น — 🔴 ก้อน D อ่านตรงนี้ก่อน

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
- ⚠️ เมนูหลักใช้คำว่า **"พอร์ต"** — `07_Portfolio` อยากได้ "ผลงาน" ยังไม่ตรงกัน (ดูตารางผลกระทบข้อ 48)
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
| `02_Schedule` ลบ `ScheduleTodayTasksSection` | 🔴 **เกิดขึ้นจริงแล้วตั้งแต่ก้อน B (14 ส.ค.)** — Toggle "แสดงงานส่วนตัวในตารางเรียน" ที่ `SettingsView.swift:167` + `@AppStorage` ที่บรรทัด 29 **เป็นสวิตช์ตายอยู่ตอนนี้** ไม่ควบคุมอะไรเลย ต้องลบทั้งคู่ | agent ของ `05_Settings` (ก้อน D) |
| `02_Schedule` เพิ่มทางเข้าที่สองของ `TermManagementView` | `SettingsView` ยังเปิดหน้านี้อีกทาง — **ห้ามลบทางนั้น** สองทางอยู่ร่วมกันได้ | agent ของ `05_Settings` |
| `02_Schedule` เลิกใช้คำว่า "ตารางสอน" | เหลือ 4 จุดใน `TermGradeEditView.swift` (บรรทัด 192 · 201 · 202 · 239) | agent ของ `04_GradeCenter` (ก้อน C) |
| ~~`01_Tasks` §5 ปุ่ม `+` ตามแท็บ~~ | ✅ **ยกเลิกแล้ว (Few 14 ส.ค.)** — `RootTabView` เสร็จหมดแล้ว ปุ่ม `+` เปิดเมนูเดียวกันทุกแท็บ · โมดูลอื่นยังห้ามแตะไฟล์นี้จนถึง W3 | — |
| ~~`01_Tasks` เพิ่ม `presetKind:` ใน `AddTaskSheet`~~ | ✅ **W1 ทำแล้ว** — `init(editing:presetKind:onSaved:)` default `.homework` | — |
| ~~`03_QuickAdd` §5 sheet ชั้นเดียว~~ | ✅ **ยกเลิกแล้ว (Few 14 ส.ค.)** — คง sheet ซ้อน sheet ไว้ | — |
| `03_QuickAdd` เรียก `EventFormSheet` · `PortfolioItemSheet` | ห้ามแก้ signature ของสองตัวนี้ · **`onSaved:` ที่ก้อน A เติมไว้ห้ามลบ** ไม่งั้นบันทึกแล้วเมนูค้าง · `AddScheduleEntrySheet` ไม่ถูกเรียกจาก QuickAdd แล้ว | ทุก agent |
| `04_GradeCenter` ย้ายการตั้งเป้ามาที่ `GPAXTargetSheet` | `SettingsView` ต้องลบ section เป้า GPAX — **ทำหลัง GradeCenter เสร็จเท่านั้น** ไม่งั้นจะไม่มีที่ตั้งเป้าเลย | agent ของ `05_Settings` |
| `04_GradeCenter` ลิสต์อ้างปุ่ม "ขึ้นชั้นแล้ว" | ปุ่มนั้นใน Settings ห้ามลบหรือเปลี่ยนชื่อ | agent ของ `05_Settings` |
| `05_Settings` §4.3 สวิตช์ค่าเริ่มต้นการเตือนงาน | ต้องแก้ `AddTaskSheet.init` 1 บรรทัด — **agent Tasks เป็นคนแก้** ไม่ใช่ agent Settings | agent ของ `01_Tasks` |
| `05_Settings` §4.2 ธีมสว่าง/มืด | แตะ `App/StudiiOSApp.swift` (เดิมชื่อ `PrototypeAppApp.swift`) ได้**เฉพาะบรรทัด `.preferredColorScheme`** — ห้ามแตะ `Schema([...])` | agent ของ `05_Settings` |

| `07_Portfolio` เปลี่ยนหัวข้อเป็น "ผลงาน" | เมนูหลักใน Dashboard (`PLAN_Redesign.md` §2.4) เขียน "พอร์ต" → ต้องเปลี่ยนให้ตรง | agent ของ W1 |
| `06_TCAS` + `07_Portfolio` ใช้ปุ่มมีพื้น `+ คณะ` / `+ ผลงาน` | สองหน้านี้เข้าจากเมนูหลักเหมือนกัน ปุ่มต้องหน้าตาเดียวกันเป๊ะ | agent ของ 06 กับ 07 |

**ลำดับที่บังคับ:** `04_GradeCenter` ต้องเสร็จก่อน `05_Settings` เสมอ · `01_Tasks` §5 กับ `03_QuickAdd` §5 ต้องทำในก้อนเดียวกัน · `08_Calendar` ทำท้ายสุดเป็นก้อนของตัวเอง

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
