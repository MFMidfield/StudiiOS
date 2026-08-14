# 01 · Tasks — หน้า "งาน / การบ้าน"

> โมดูล `PrototypeApp/Features/Tasks/` (7 ไฟล์ · ~1,100 บรรทัด)
> ✅ **ตรวจแล้ว: ไม่มีไฟล์นอกโมดูลนี้อ้างถึง `TaskScope` / `TaskStatsRow` / `TaskFilterSheet` เลย**
> → ลบไฟล์ในโมดูลนี้ได้โดยไม่กระทบหน้าอื่น

---

## 1. สภาพปัจจุบัน

```
List(.plain)
├── controlsSection   ช่องค้นหา · chip 4 อัน · การ์ดสถิติ 4 ใบ
├── dueSoonSection    งานใกล้ถึงกำหนด (โผล่เมื่อ chip = ทั้งหมด หรือ ยังไม่เสร็จ)
├── mainSection       รายการทั้งหมด — flat list เรียงตาม sortOrder
└── doneSection       DisclosureGroup "เสร็จแล้ว (N)"
+ FAB มุมขวาล่าง
+ TaskFilterSheet: ประเภท · วิชา · Toggle เลยกำหนด · เรียงตาม
```

## 2. ปัญหา UX ที่เจอ

| # | ปัญหา | ความหนัก |
|---|---|---|
| 1 | **chip กับการ์ดสถิติทับกัน 3 ใน 4** (ทั้งหมด · ใกล้ถึงกำหนด · เสร็จแล้ว) ปุ่ม 2 แถวทำเรื่องเดียวกัน | สูง |
| 2 | **"เลยกำหนด" ทำงานแบบซ่อน** — `select(stat:)` เลือก chip `.notDone` แล้วแอบเปิด `overdueOnly` ที่อยู่ใน sheet ผู้ใช้เห็นแค่จุดเล็กบนปุ่มกรอง → งานหายจากจอโดยไม่รู้สาเหตุ | **สูงสุด — เป็นบั๊ก** |
| 3 | งานใบเดียวโผล่ 2 ที่ในจอเดียว (`dueSoonSection` ซ้อน `mainSection`) | สูง |
| 4 | การ์ดใบเดียวบอกเวลา 3 ครั้ง: ป้าย "พรุ่งนี้" + บรรทัด "14 ส.ค. 2569 08:30" + สีขอบ/สีป้าย 4 ระดับ | กลาง |
| 5 | UI 4 ชั้นก่อนเห็นงานใบแรก (ค้นหา → chip → สถิติ → หัวข้อ) กินจอเกือบครึ่ง | กลาง |
| 6 | 2 ทางเพิ่มงานในจอเดียว (FAB + ปุ่ม `+` กลาง tab bar) | ต่ำ |

---

## 3. ตัด / เก็บ / ย้าย — Few ตัดสินแล้วทุกข้อ

### ✂️ ตัดทิ้ง

| ตัด | เหตุผล |
|---|---|
| `TaskStatsRow.swift` **ทั้งไฟล์** | ทับกับ chip · เอาเลขไปไว้บน chip แทน แก้ปัญหา 1+2 พร้อมกัน |
| `TaskFilterSheet.swift` **ทั้งไฟล์** | เหลือของแค่ 2 อย่าง ไม่คุ้มที่จะเป็น sheet ทั้งใบ |
| `dueSoonSection` | ซ้ำกับ chip และซ้อนกับ mainSection (ปัญหา 3) |
| Toggle "เฉพาะงานที่เลยกำหนด" | กลายเป็น chip จริงแทน — ต้นเหตุของบั๊กข้อ 2 |
| ตัวเลือก "เรียงตาม" ทั้งหมด | พอจัดกลุ่มตามวันแล้ว เรียงตามกำหนดส่งเกิดเองโดยธรรมชาติ |
| FAB มุมขวาล่าง | ใช้ปุ่ม `+` กลาง tab bar แทน (ดู §5) |
| บรรทัดวันที่เต็มในการ์ด | ป้ายวันบอกไปแล้ว |
| ขอบการ์ดสีแดงตอนเลยกำหนด | ขีดสีวิชาซ้ายทำหน้าที่แทน + มี chip เลยกำหนดแล้ว |
| ไอคอนสี่เหลี่ยม 36×36 ในการ์ด | แทนด้วยขีดสีวิชา 3pt — เบากว่า แถบยาวเรียงกันอ่านง่ายกว่า |

### ✅ เก็บไว้

- `List(.plain)` + `plainRow()` — **ห้ามเปลี่ยนเป็น `ScrollView`** ปัดซ้ายลบจะหาย
- ปัดซ้ายลบ + `NotificationManager.cancel(for:)`
- `.searchable` (ซ่อนเองเวลาเลื่อน)
- กลุ่ม "เสร็จแล้ว" แบบพับได้ท้ายลิสต์
- กรองตามประเภท + กรองตามวิชา
- `TaskScope` เป็นจุดเดียวที่นิยามเงื่อนไข (ขยายบทบาท ดู §4.1)

### ➡️ ย้ายที่

| ของ | จาก | ไป |
|---|---|---|
| กรองประเภท + วิชา | sheet ทั้งใบ | `Menu` บนไอคอนกรองใน toolbar |
| จำนวนงานแต่ละสถานะ | การ์ดสถิติ 4 ใบ | ตัวเลขบน chip |
| ปุ่มเพิ่มงาน | FAB | ปุ่ม `+` กลาง tab bar |

---

## 4. หน้าตาใหม่

```
toolbar:  งาน                          🔍  ⚙︎กรอง
──────────────────────────────────────────────
chip:    [ ค้าง 4 ]  เลยกำหนด 1   เสร็จ 8   ทั้งหมด
──────────────────────────────────────────────
เลยกำหนด                       ← หัวข้อสีแดง
  ▍อ่านบท 4 ฟิสิกส์            เลย 2 วัน
     ฟิสิกส์ · 16:00

วันนี้ · พฤ 13 ส.ค.
  ▍ส่งใบงานชีววิทยา                วันนี้
     ชีววิทยา · 15:30

พรุ่งนี้ · ศ 14 ส.ค.
  ▍แบบฝึกหัด 2.1 ข้อ 1-20         พรุ่งนี้
     เคมี · 08:30
  ▍ทบทวนสูตรตรีโกณ
     คณิตศาสตร์

สัปดาห์นี้
  ▍เตรียมพรีเซนต์ภาษาอังกฤษ         จ 17
     ภาษาอังกฤษ

› เสร็จแล้ว 8
```

`▍` = ขีดสีวิชา 3pt ชิดซ้าย · การ์ด `border-radius 0 / 18 / 18 / 0`

### 4.1 `TaskScope.swift` — เจ้าของกฎทั้งหมดของหน้านี้

**chip ชุดใหม่** (เรียงตามนี้):

```swift
static let chips: [TaskScope] = [.notDone, .overdue, .done, .all]
```

| chip | ป้ายที่แสดง | เงื่อนไข |
|---|---|---|
| `.notDone` | `ค้าง N` | `!isDone` (default ตอนเปิดหน้า) |
| `.overdue` | `เลยกำหนด N` — เลขสี `danger` | `isOverdue` |
| `.done` | `เสร็จ N` | `isDone` |
| `.all` | `ทั้งหมด` — ไม่มีเลข | ทุกใบ |

- **ลบ** `static let stats` และ `var chipTarget` — ไม่มีการ์ดสถิติแล้ว `.overdue` มี chip ของตัวเอง
- **เก็บ `case dueSoon` ไว้ในเนื้อ enum** แม้ไม่โผล่ใน chip แล้ว — ลบ case ออกทำให้ต้องไล่แก้ทุก `switch` ไม่คุ้ม
- default ตอนเปิดหน้าเปลี่ยนจาก `.all` → **`.notDone`** (คนเปิดหน้างานมาดูงานที่ยังไม่เสร็จ ไม่ใช่ดูของที่ทำไปแล้ว)

**เพิ่ม enum ใหม่ในไฟล์เดียวกัน** — จุดเดียวที่นิยามการจัดกลุ่มตามวัน:

```swift
enum TaskDayGroup: String, CaseIterable, Identifiable {
    case overdue, today, tomorrow, thisWeek, later, noDue
}
```

| กลุ่ม | หัวข้อ | เงื่อนไข (ใช้ `AssignmentPriorityEngine.daysUntil` เท่านั้น) |
|---|---|---|
| `.overdue` | `เลยกำหนด` (สี `danger`) | `assignment.isOverdue` |
| `.today` | `วันนี้ · <วันย่อ วันที่ เดือน>` | `daysUntil == 0` |
| `.tomorrow` | `พรุ่งนี้ · <วันย่อ วันที่ เดือน>` | `daysUntil == 1` |
| `.thisWeek` | `สัปดาห์นี้` | `2...7` |
| `.later` | `ภายหลัง` | `> 7` |
| `.noDue` | `ไม่มีกำหนด` | `resolvedDueDate == nil` |

⚠️ **ห้ามเขียนสูตรวันเองใน View** — ทุกอย่างผ่าน `TaskDayGroup` และ `AssignmentPriorityEngine` เท่านั้น

> ✅ **ตรวจแล้ว: `Date+Thai.swift` ยังไม่มี formatter ที่ขึ้นต้นด้วยชื่อวัน**
> ที่มีคือ `thaiFull` (`.dateStyle = .full` → "วันพฤหัสบดีที่ 13 สิงหาคม พ.ศ. 2569" — ยาวเกินไปสำหรับหัวข้อกลุ่ม) ·
> `thaiShort` (`d MMM yy`) · `thaiShortNoYear` (`d MMM`) · `thaiDayMonthYear` (`d MMM yyyy`) · `thaiDayOnly` (`d`)
>
> **ต้องเพิ่ม formatter ใหม่ใน `Core/Extensions/Date+Thai.swift`** (จุดเดียวที่รู้จักการจัดรูปแบบวันไทย — ห้ามสร้าง `DateFormatter` ในไฟล์ View):
> ```swift
> static let thaiWeekdayShort: DateFormatter = {   // "พฤ 13 ส.ค."
>     let f = DateFormatter()
>     f.locale = Locale(identifier: "th_TH")
>     f.calendar = Calendar(identifier: .buddhist)
>     f.dateFormat = "EEEEE d MMM"
>     return f
> }()
> ```
> พร้อม computed property `var thaiWeekdayShortString: String`
> ⚠️ `DateFormatter` เป็นของแพงในการสร้าง — ต้องเป็น `static let` เหมือนตัวอื่นในไฟล์ **ห้ามสร้างใหม่ทุกครั้งที่วาดแถว**
กลุ่มที่ไม่มีงานเลย **ไม่ต้องแสดงหัวข้อ**
ภายในกลุ่มเรียงตาม `resolvedDueDate` แล้วตามด้วย `createdAt` (ของเดิมใน `sorted()` เอาสาขา `.priority` / `.recent` ออก)

### 4.2 `TaskFilterChips.swift`

- รับ `counts: [TaskScope: Int]` เพิ่มเข้ามา
- แสดง `"\(scope.label) \(count)"` — `.all` ไม่มีเลข
- เลขของ `.overdue` ใช้ `Theme.Colors.danger` ตอนไม่ถูกเลือก
- **ลบปุ่ม "กรอง" ออกจากแถบ chip** ย้ายขึ้น toolbar
- ตัวเลขใช้ `.contentTransition(.numericText())`

### 4.3 `TaskRowCard.swift` — เหลือ 4 อย่าง

```
[○]  ▍  ชื่องาน                        [ป้ายวัน]
        วิชา · เวลา
```

1. วงกลม toggle เสร็จ (ซ้ายสุด) — สปริง `.spring(response: 0.3, dampingFraction: 0.7)`
2. ขีดสีวิชา 3pt (`subject?.color ?? Theme.Colors.primary`)
3. ชื่องาน + บรรทัดรอง `"<วิชา> · <เวลา>"` (ถ้าไม่มีวิชา/เวลา ตัดส่วนนั้นทิ้ง ไม่ต้องมีจุดคั่นลอย)
4. ป้ายวันแคปซูล — ใช้ `PillLabel` จาก DesignSystem

สีป้าย: เลยกำหนด `danger` · วันนี้ `primaryDeep` บน `primarySoft` · ที่เหลือ `textSecondary` บน `surfaceRaised`
งานที่เสร็จแล้ว: `.opacity(0.55)` + `strikethrough` (คงเดิม)

### 4.4 `AssignmentListView.swift`

```
List(.plain)
├── chipSection       TaskFilterChips (plainRow)
└── ForEach TaskDayGroup ที่ไม่ว่าง
      Section { rows } header { หัวข้อกลุ่ม }
└── doneSection       DisclosureGroup (คงเดิม)
```

toolbar:

```swift
.searchable(text: $searchText, prompt: "ค้นหางาน วิชา หรือรายละเอียด")
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Menu {
            Picker("ประเภท", selection: $kindFilter) { … }
            Picker("วิชา", selection: $subjectFilter) { … }
            if hasActiveFilters { Button("ล้างตัวกรอง", role: .destructive) { … } }
        } label: {
            Image(systemName: hasActiveFilters
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle")
        }
    }
}
```

ที่ต้องลบออกจากไฟล์นี้: `addButton` (FAB) · `dueSoonSection` · `dueSoonHighlights` · `select(stat:)` · `overdueOnly` · `sortOrder` · `showFilterSheet` · สาขา `.priority`/`.recent` ใน `sorted()`

`hasActiveFilters` เหลือ `kindFilter != .all || !subjectFilter.isEmpty`

**แก้ข้อความ empty state** — ของเดิมเขียนว่า *"กดปุ่ม + มุมขวาล่างเพื่อเพิ่มงานชิ้นแรก"* → เปลี่ยนเป็น *"กดปุ่ม + ตรงกลางแถบล่างเพื่อเพิ่มงานชิ้นแรก"* (ไม่งั้นชี้ไปที่ปุ่มที่ถูกลบไปแล้ว)

---

## 5. ปุ่ม `+` กลาง tab bar เปลี่ยนตามแท็บ

`RootTabView.swift` มีโค้ดดักไว้อยู่แล้ว (`onChange` เด้งกลับ `previousTab` แล้วเปิด sheet) — เพิ่ม `switch` เข้าไป

| อยู่แท็บ | กด `+` แล้วเปิด |
|---|---|
| งาน | `AddTaskSheet()` |
| ตารางสอน | `AddScheduleEntrySheet(...)` |
| ปฏิทิน (ถ้าผู้ใช้ย้ายเข้า tab bar ใน W3) | `EventFormSheet(...)` |
| หน้าแรก · ตั้งค่า · อื่นๆ | `QuickAddSheet()` เมนูเต็มเหมือนเดิม |

⚠️ **กดค้างบน tab item ทำไม่ได้** — `TabView` มาตรฐานไม่รับ gesture บนปุ่มแท็บ
ทางออก: ใส่แถวล่างสุดใน sheet ที่เปิดตรง ว่า **"เพิ่มอย่างอื่น →"** กดแล้วปิด sheet นี้เปิด `QuickAddSheet` แทน

หน้าที่ push มาจากเมนูหลัก (พอร์ต · เกรด · TCAS) แท็บยังเป็น "หน้าแรก" → ได้เมนูเต็ม
ถ้าอยากให้ฉลาดถึงระดับนั้นต้องใช้ `PreferenceKey` ให้หน้าลูกประกาศเอง — **ยกไป W3 ไม่ทำรอบนี้**

---

## 6. ไฟล์ที่แตะ

| ไฟล์ | ทำอะไร |
|---|---|
| `Features/Tasks/TaskScope.swift` | chip ชุดใหม่ · ลบ `stats`/`chipTarget` · เพิ่ม `TaskDayGroup` |
| `Features/Tasks/TaskFilterChips.swift` | รับ counts · แสดงเลข · ลบปุ่มกรอง |
| `Features/Tasks/TaskRowCard.swift` | เหลือ 4 อย่างตาม §4.3 |
| `Features/Tasks/AssignmentListView.swift` | จัดกลุ่มตามวัน · toolbar Menu · ลบ FAB/dueSoon/sort |
| `Features/Tasks/AddTaskSheet.swift` | เพิ่ม `presetKind:` (จาก `PLAN_Redesign.md` §2.2) |
| `App/RootTabView.swift` | ปุ่ม `+` ตามแท็บ (§5) |
| ~~`Features/Tasks/TaskStatsRow.swift`~~ | **ลบไฟล์** |
| ~~`Features/Tasks/TaskFilterSheet.swift`~~ | **ลบไฟล์** |

⚠️ ลบไฟล์ใน sandbox อาจติด `Operation not permitted` → เรียก `mcp__cowork__allow_cowork_file_delete` แล้วลองใหม่
ไฟล์หายจากโฟลเดอร์ = หายจาก target อัตโนมัติ (file-system-synchronized groups) ไม่ต้องแตะ `.pbxproj`

---

## 7. ความเสี่ยง

| เสี่ยง | กัน |
|---|---|
| เปลี่ยนเป็น `ScrollView` แล้วปัดซ้ายลบหาย | คง `List(.plain)` + `plainRow()` ห้ามแตะ |
| `AssignmentListView` ยาวขึ้นจนคอมไพล์ไม่ผ่าน | ตอนนี้ 334 บรรทัด · ตัดของออกเยอะกว่าเพิ่ม ควรสั้นลง ถ้าเกิน 250 ให้แยก `TaskDayGroupSection.swift` |
| `AddTaskSheet` เปลี่ยน signature แล้ว call site พัง | `presetKind` ต้องมี default `.homework` |
| ลบ `TaskScope.stats` แล้วมีที่อื่นเรียก | ✅ ตรวจแล้ว — ไม่มีไฟล์นอกโมดูล Tasks อ้างถึงเลย |

---

## 8. เกณฑ์เสร็จ

Few กด ⌘B เขียว แล้วเข้าแท็บ "งาน":

1. เห็น chip 4 อันมีเลขในตัว · **default อยู่ที่ "ค้าง"** ไม่ใช่ "ทั้งหมด"
2. กด chip "เลยกำหนด" แล้วเห็นเฉพาะงานเลยกำหนด **และรู้ว่าตัวเองอยู่ตัวกรองไหน** (chip ติดสี)
3. งานถูกจัดเป็นกลุ่มตามวัน · กลุ่มที่ไม่มีงานไม่โผล่หัวข้อ
4. ไม่มีงานใบไหนโผล่ซ้ำ 2 ที่ในจอเดียว
5. **ปัดซ้ายลบยังทำงาน**
6. ไม่มี FAB มุมขวาล่างแล้ว · กดปุ่ม `+` กลางแถบล่างขณะอยู่แท็บงาน → `AddTaskSheet` เด้งขึ้นตรงๆ ไม่ผ่านเมนู
7. กดไอคอนกรองบนขวา → Menu เด้ง เลือกประเภท/วิชาได้ ไม่มี sheet เปิดขึ้นมาทั้งใบ
8. สลับ dark mode แล้วทุกอย่างยังอ่านออก
