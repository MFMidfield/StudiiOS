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
| **W1** Theme + Dashboard + tab bar | ✅ เขียนโค้ดครบ 10 step · **⏳ Few ยังไม่ได้ยืนยันว่า build ผ่าน** |
| **W2** หน้าที่เหลือ (ไฟล์ 01–07 ในโฟลเดอร์นี้) | ⬜ ยังไม่เริ่ม — รอ Few สั่ง |
| **W3** custom nav · แตก CalendarView · onboarding | ⬜ ยังไม่เริ่ม |

**ยังไม่ได้ build แม้แต่ครั้งเดียวตลอด W1** — 12 commit ขึ้นต้น `wip:` ถ้า Few ยืนยันว่าเขียวแล้วค่อย squash

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
| `02_Schedule` ลบ `ScheduleTodayTasksSection` | Toggle "แสดงงานส่วนตัวในตารางเรียน" ที่ `SettingsView.swift:167` กลายเป็นสวิตช์ตาย | agent ของ `05_Settings` |
| `01_Tasks` §5 ปุ่ม `+` ตามแท็บ | `RootTabView.swift` ถูกแตะโดย agent ของ Tasks — โมดูลอื่นห้ามแตะไฟล์นี้ซ้ำ · **W1 แก้แท็บไปแล้ว เหลือแค่ปุ่ม `+`** | agent ของ `01_Tasks` เท่านั้น |
| ~~`01_Tasks` เพิ่ม `presetKind:` ใน `AddTaskSheet`~~ | ✅ **W1 ทำแล้ว** — `init(editing:presetKind:onSaved:)` default `.homework` | — |
| `03_QuickAdd` §5 sheet ชั้นเดียว | ต้องแก้ `RootTabView.swift` ก้อนเดียวกับ `01_Tasks` §5 — **ทำพร้อมกัน ห้ามแยกสองรอบ** | agent ของ `01_Tasks` |
| `03_QuickAdd` เรียก `EventFormSheet` · `PortfolioItemSheet` · `AddScheduleEntrySheet` | ห้ามโมดูลใดแก้ signature ของสามตัวนี้ | ทุก agent |
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
