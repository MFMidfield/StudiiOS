# PLAN — หน้า Todo / การบ้าน (AssignmentListView redesign)

> เขียนเพื่อให้ **Sonnet (high)** ลงมือทำต่อ · ตัดสินใจครบแล้วทุกข้อ ไม่ต้องเดา
> อ้างอิงดีไซน์: ภาพ mockup ที่ Few ให้ (หน้า "งาน / การบ้าน")
> สร้างเมื่อ 2026-08-04 · อ่าน `PROJECT_MAP.md` ก่อนเริ่มเสมอ

---

## 0. TL;DR สำหรับผู้ลงมือ

รวม "การบ้าน" กับ "todo ส่วนตัว" ไว้ใน `Assignment` โมเดลเดียว แยกด้วย field `kind`
สร้างฟอร์มเพิ่มงานใหม่ (`AddTaskSheet`) ใช้ร่วมกัน 3 ทางเข้า → tab `+` / Dashboard / FAB ในหน้า Todo
ยกเครื่อง `AssignmentListView` ให้ตรงดีไซน์ (chips + สถิติ 4 ใบ + section ใกล้ถึงกำหนด + รายการ + กลุ่มเสร็จแล้ว)
เพิ่มแจ้งเตือน 3 จุดต่องาน และ logic ความสำคัญอัตโนมัติ

**ทำเป็น 4 เฟส หยุดให้ Few build ทุกเฟส** — ห้ามทำรวดเดียวจบ

---

## 1. สเปคที่ Few ยืนยันแล้ว (ห้ามเปลี่ยนเอง)

| หัวข้อ | คำตอบ |
|---|---|
| แยก todo กับการบ้าน? | **รวม** โมเดลเดียว แยกด้วย `kind` |
| ข้อมูลที่เก็บ | ชื่อ (บังคับ) · ประเภท (default การบ้าน) · รายละเอียด (ไม่บังคับ) · ความสำคัญ (default อัตโนมัติ) · กำหนดส่ง (default ไม่กำหนด) · แจ้งเตือน |
| todo ส่วนตัวผูกวิชาได้ไหม | **ไม่ผูกเลย** — ซ่อน Picker วิชาเมื่อเลือกประเภทส่วนตัว |
| Tier | **Free ทั้งหมด** ไม่ gate |
| dueDate optional ยังไง | **ทาง A** — เพิ่ม `hasDueDate: Bool` ไม่แตะ type เดิม (กัน crash ตอนเปิดแอป) |
| filter บนหน้า | **ตามรูป**: ทั้งหมด / ยังไม่เสร็จ / ใกล้ถึงกำหนด / เสร็จแล้ว · ประเภท+วิชา+เรียงตาม ไปอยู่ในปุ่ม "กรอง" |
| ไอคอนดาวในรูป | **ตัดออก** ไม่ทำ ไม่เพิ่ม field |
| บรรทัดใต้ชื่องาน | **เหลือแค่ชื่อวิชา** ไม่เพิ่มชื่อครู/ระดับชั้นใน `Subject` |
| การ์ดสถิติ + section ใกล้ถึงกำหนด | **ครบตามรูป** |
| ปุ่มแว่นขยาย / ปุ่ม "..." | ค้นหา **ทำ** (`.searchable`) · ปุ่ม "..." **ตัดออก** |
| "ใกล้ถึงกำหนด" นับกี่วัน | **ภายใน 3 วัน** |
| logic ความสำคัญอัตโนมัติ | **เวลา + ประเภท** (สูตรเต็ม §3) |
| แจ้งเตือนซ้ำ | **3 จุดตายตัว**: 1 วันก่อน · เช้าวันกำหนด 07:00 · 1 ชม.ก่อน |
| ปุ่ม `+` กลาง tab bar | เปิด **ฟอร์มเพิ่มงานเลย** (AddTaskSheet) ไม่ใช่เมนู 4 โหมดแบบเดิม |
| งานวันนี้ในแท็บตารางเรียน | default แสดง**เฉพาะการบ้าน** + Toggle ใน Settings เพื่อรวมงานส่วนตัว |

---

## 2. เปลี่ยนโมเดล — `Core/Models/Assignment.swift`

### 2.1 enum ใหม่

```swift
enum AssignmentKind: String, Codable, CaseIterable {
    case homework, personal

    var label: String {
        switch self {
        case .homework: return "การบ้าน"
        case .personal: return "งานทั่วไป"
        }
    }

    var iconName: String {
        switch self {
        case .homework: return "book.closed.fill"
        case .personal: return "checkmark.circle.fill"
        }
    }
}
```

### 2.2 field ใหม่ใน `Assignment` — **ทุกตัวต้องมี default value**

```swift
var kindRaw: String = "homework"
var hasDueDate: Bool = true        // ⚠️ default true — ดู §2.4
var isPriorityManual: Bool = false
var remindersEnabled: Bool = false
var uid: String = ""               // stable id สำหรับ notification — ดู §2.5
```

เพิ่ม parameter ใน `init` ให้ครบ โดยใช้ default ค่าเดียวกัน เพื่อไม่ให้ call site เดิมพัง

### 2.3 computed properties (ที่อื่นต้องเรียกผ่านตัวเหล่านี้เท่านั้น)

```swift
var kind: AssignmentKind {
    get { AssignmentKind(rawValue: kindRaw) ?? .homework }
    set { kindRaw = newValue.rawValue }
}

/// วันกำหนดส่งจริง — nil = ไม่กำหนด. **ห้ามอ่าน `dueDate` ตรงๆ ที่ไหนอีก**
var resolvedDueDate: Date? { hasDueDate ? dueDate : nil }

/// ความสำคัญที่เอาไปแสดง/เรียงจริง (auto ถ้าผู้ใช้ไม่ได้เลือกเอง)
var effectivePriority: AssignmentPriority {
    isPriorityManual
        ? priority
        : AssignmentPriorityEngine.priority(kind: kind, dueDate: resolvedDueDate)
}

var isOverdue: Bool {
    guard !isDone, let due = resolvedDueDate else { return false }
    return due < .now
}
```

### 2.4 ทำไม `hasDueDate` default = **true**

SwiftData backfill ข้อมูลเดิมด้วยค่า default ของ property ใหม่
งานเก่าทุกชิ้นถูกสร้างจาก `SmartCaptureView` ซึ่ง**ใส่วันส่งเสมอ** → default `true` ทำให้ข้อมูลเดิมยังแสดงวันส่งถูกต้อง
ฟอร์มใหม่จะส่งค่า `false` มาเองเมื่อผู้ใช้ไม่เปิด toggle กำหนดส่ง

### 2.5 ทำไมต้องมี `uid: String` แทนที่จะเพิ่ม `id: UUID = UUID()`

`UUID()` ในตำแหน่ง default value อาจถูก evaluate ครั้งเดียวตอน migrate → **แถวเก่าทุกแถวได้ UUID เดียวกัน** = notification ทับกัน
ใช้ `""` แล้ว lazily เติมตอนใช้งานจริงแทน:

```swift
func ensureUID() -> String {
    if uid.isEmpty { uid = UUID().uuidString }
    return uid
}
```

### 2.6 ✅ เช็คลิสต์บังคับหลังแตะโมเดล

- [ ] **ไม่ต้อง**เพิ่มใน `Schema([...])` — ไม่ได้สร้าง `@Model` ใหม่ แค่เพิ่ม field ในตัวเดิม
- [ ] **ไม่ต้อง**แตะ `SettingsView.resetAllData()` — `Assignment` อยู่ในนั้นแล้ว (ยืนยันก่อนด้วย grep)
- [ ] `grep -rn "\.dueDate" PrototypeApp/` แล้วไล่แก้ทุกจุดให้ใช้ `resolvedDueDate`
      **จุดที่รู้แล้วว่าต้องแก้:** `DashboardView.swift:21` (`isDateInToday($0.dueDate)`) · `AssignmentListView.swift:19,43` · `ScheduleTodayTasksSection.swift`
      `DashboardView.swift:11` `@Query(sort: \Assignment.dueDate)` ปล่อยไว้ได้ (sort ระดับ store ไม่ใช่ logic)

---

## 3. Logic ความสำคัญอัตโนมัติ — ไฟล์ใหม่ `Core/Tasks/AssignmentPriorityEngine.swift`

เป็น **logic ล้วน ไม่มี View** (ตามแบบ `PeriodShiftCalculator`) เพื่อให้ test/แก้สูตรได้จุดเดียว

```
คะแนนจากเวลา — นับเป็น "วันปฏิทิน" ไม่ใช่ 24 ชม. (ใช้ Calendar.dateComponents)
  เลยกำหนดแล้ว     → 4
  ครบกำหนดวันนี้    → 3
  พรุ่งนี้           → 2
  อีก 2–3 วัน       → 1
  อีก ≥4 วัน        → 0
  ไม่กำหนดส่ง       → 0

คะแนนจากประเภท
  การบ้าน  → +1
  งานทั่วไป → +0

รวมแล้วแปลงเป็นระดับ
  ≥3   → สูง
  1–2  → ปานกลาง
  0    → ต่ำ
```

**ตัวอย่างที่ต้องออกมาแบบนี้** (ใช้เป็น test case ตอน verify)

| งาน | คะแนน | ผล |
|---|---|---|
| การบ้าน ส่งพรุ่งนี้ | 2+1 | สูง |
| งานทั่วไป ส่งพรุ่งนี้ | 2+0 | ปานกลาง |
| การบ้าน เลยกำหนด | 4+1 | สูง |
| การบ้าน อีก 3 วัน | 1+1 | ปานกลาง |
| งานทั่วไป อีก 5 วัน | 0+0 | ต่ำ |
| การบ้าน ไม่กำหนดส่ง | 0+1 | ปานกลาง |
| งานทั่วไป ไม่กำหนดส่ง | 0+0 | ต่ำ |

**สำคัญ:** คำนวณตอน**อ่าน** เท่านั้น ห้าม cache ลง `priorityRaw` — เพราะผลขึ้นกับวันที่ปัจจุบัน ถ้าเก็บไว้จะค้างและผิดในวันถัดไป

API ที่ต้องมี:

```swift
enum AssignmentPriorityEngine {
    static func priority(kind: AssignmentKind, dueDate: Date?, now: Date = .now) -> AssignmentPriority
    static func daysUntil(_ dueDate: Date, from now: Date = .now) -> Int   // ติดลบ = เลยกำหนด
    /// ป้ายวันแบบในดีไซน์: "เลยกำหนด" · "วันนี้" · "พรุ่งนี้" · "อีก 3 วัน" · "ไม่กำหนด"
    static func dueLabel(for dueDate: Date?, now: Date = .now) -> String
}
```

---

## 4. แจ้งเตือน — `Core/Notifications/NotificationManager.swift`

เพิ่มส่วนของ `Assignment` **โดยไม่แตะโค้ด `CalendarEvent` เดิมเลย**

### 4.1 3 จุดตายตัว

| slot | เวลา | identifier |
|---|---|---|
| `d1` | 24 ชม. ก่อนกำหนดส่ง | `assignment-{uid}-d1` |
| `am` | 07:00 ของวันที่กำหนดส่ง | `assignment-{uid}-am` |
| `h1` | 1 ชม. ก่อนกำหนดส่ง | `assignment-{uid}-h1` |

ยิงเฉพาะ slot ที่ยัง**อยู่ในอนาคต** — งานที่สร้างตอนเย็นวันเดียวกันจะได้แค่ `h1` ซึ่งถูกต้อง

### 4.2 เนื้อหา

```
title: ชื่องาน
body:  การบ้าน · เคมี · ส่งพรุ่งนี้ 23:59
       งานทั่วไป · ส่งวันนี้ 18:00
```
(ประเภท · ชื่อวิชา ถ้ามี · ป้ายวันจาก `dueLabel` · เวลา)

### 4.3 กฎ

- `hasDueDate == false` → บังคับ `remindersEnabled = false` (ไม่มีจุดอ้างอิงเวลา)
- **เพดาน 64 pending ของ iOS**: schedule เฉพาะงานที่กำหนดส่ง**ภายใน 14 วัน** และยังไม่เสร็จ
- `cancel(for:)` ต้องลบทั้ง 3 identifier
- ต้อง cancel + schedule ใหม่เมื่อ: แก้วันส่ง · แก้ชื่อ/ประเภท · ปิด toggle แจ้งเตือน
- ต้อง cancel อย่างเดียวเมื่อ: กด isDone = true · ลบงาน
- กด isDone กลับเป็น false → schedule ใหม่

### 4.4 API ที่ต้องเพิ่ม

```swift
func schedule(for assignment: Assignment) async
func cancel(for assignment: Assignment)
/// เรียกตอนแอปขึ้น foreground — กวาดงานทั้งหมด reschedule ให้ตรงปัจจุบัน
func refreshAssignmentReminders(_ assignments: [Assignment]) async
```

`refreshAssignmentReminders` เรียกจาก `RootContainerView` (`PrototypeAppApp.swift`) ด้วย
`.onChange(of: scenePhase)` เมื่อเข้า `.active` — ทำในเฟส 3 เท่านั้น อย่าเพิ่งใส่ตั้งแต่เฟส 1

---

## 5. ฟอร์มใหม่ — `Features/Tasks/AddTaskSheet.swift`

รองรับทั้ง**สร้างใหม่และแก้ไข**: `AddTaskSheet(editing: Assignment? = nil)`
ห่อด้วย `NavigationStack` + `Form` · toolbar ซ้าย "ยกเลิก" ขวา "บันทึก" (disabled ถ้าชื่อว่าง)

ลำดับฟิลด์ — **ตรงตามสเปค 6 ข้อของ Few**

| # | ฟิลด์ | ชนิด | default | หมายเหตุ |
|---|---|---|---|---|
| 1 | ชื่องาน | `TextField` | ว่าง | **บังคับ** — trim แล้วว่าง = บันทึกไม่ได้ |
| 2 | ประเภท | `Picker(.segmented)` | **การบ้าน** | บนสุดของฟอร์ม |
| 3 | วิชา | `Picker` | "ไม่ระบุ" (`""`) | **แสดงเฉพาะเมื่อประเภท = การบ้าน** · มีปุ่ม "เพิ่มวิชาใหม่" เปิด `AddSubjectSheet` ที่มีอยู่แล้ว |
| 4 | รายละเอียด | `TextField(axis: .vertical)` | ว่าง | ไม่บังคับ |
| 5 | ความสำคัญ | `Picker` 4 ตัวเลือก | **อัตโนมัติ** | อัตโนมัติ / ต่ำ / ปานกลาง / สูง · เลือก "อัตโนมัติ" → แสดง footer ว่าคำนวณได้ระดับไหนตอนนี้ |
| 6 | กำหนดส่ง | `Toggle` + `DatePicker` | **ปิด** | เปิดแล้วค่อยโชว์ DatePicker · default = วันนี้ 23:59 |
| 7 | แจ้งเตือน | `Toggle` | ตาม §4 | **เปิดอัตโนมัติเมื่อเปิดกำหนดส่ง · ปิด+disable เมื่อไม่กำหนด** · footer: "เตือน 1 วันก่อน · เช้าวันกำหนด 07:00 · 1 ชม.ก่อน" |

**ท้ายฟอร์ม** — Section แยก ปุ่ม "เพิ่มอย่างอื่น (ปฏิทิน / โน้ต / Portfolio)" เปิด `SmartCaptureView` เป็น sheet ซ้อน
เหตุผล: `SmartCaptureView` มีทางเข้าเดียวคือปุ่ม `+` กลาง tab (ยืนยันด้วย grep แล้ว) ถ้าแทนที่ทิ้งเฉยๆ **โหมดปฏิทิน/โน้ต/Portfolio จะกลายเป็นโค้ดตาย เข้าไม่ถึงทั้งหมด**

ตอนกดบันทึก: insert/update → `try context.save()` → `await NotificationManager.shared.schedule(for:)` ถ้า `remindersEnabled`

---

## 6. หน้าหลัก — ยกเครื่อง `AssignmentListView`

### 6.1 ย้ายโฟลเดอร์

`Features/SubjectHub/AssignmentListView.swift` → `Features/Tasks/AssignmentListView.swift`
โปรเจกต์ใช้ file-system-synchronized groups → **ย้ายไฟล์เฉยๆ พอ ห้ามแตะ `.pbxproj`**
ถ้า `Features/SubjectHub/` ว่างแล้วให้ลบโฟลเดอร์

### 6.2 ไฟล์ใหม่ทั้งหมดใน `Features/Tasks/`

| ไฟล์ | หน้าที่ | บรรทัดโดยประมาณ |
|---|---|---|
| `AssignmentListView.swift` | root — ประกอบร่าง + state ของ filter/search | ~160 |
| `TaskFilterChips.swift` | แถบ chip 4 อัน + ปุ่ม "กรอง" | ~70 |
| `TaskFilterSheet.swift` | sheet: ประเภท · วิชา · เรียงตาม | ~90 |
| `TaskStatsRow.swift` | การ์ดสถิติ 4 ใบ (กดได้) | ~90 |
| `TaskRowCard.swift` | การ์ดงาน 1 แถว (ใช้ทั้ง section ใกล้ถึงกำหนด และรายการทั้งหมด) | ~110 |
| `AddTaskSheet.swift` | §5 | ~200 |

**บังคับแตกเป็นไฟล์/sub-view ย่อยแบบนี้** — SwiftUI compiler จะฟ้อง `unable to type-check this expression in reasonable time` ถ้ายัด body เดียวยาวๆ (เคยเจอในโปรเจกต์นี้แล้ว)

### 6.3 โครงหน้า (บนลงล่าง)

```
ScrollView บนพื้น Theme.Colors.background   ← ไม่ใช้ List เพราะดีไซน์เป็นการ์ดลอย
├ TaskFilterChips        ทั้งหมด · ยังไม่เสร็จ · ใกล้ถึงกำหนด · เสร็จแล้ว   [ปุ่ม กรอง ขวาสุด]
├ TaskStatsRow           4 ใบ: ทั้งหมด / ใกล้ถึงกำหนด / เลยกำหนด / เสร็จแล้ว
├ Section "ใกล้ถึงกำหนด"  + ลิงก์ "ดูทั้งหมด >"   ← แสดงเมื่อ chip = ทั้งหมด/ยังไม่เสร็จ เท่านั้น
├ Section "รายการทั้งหมด" + ป้าย "เรียงตาม: กำหนดส่ง ↓" (กดเปิด TaskFilterSheet)
└ DisclosureGroup "เสร็จแล้ว (n)"  ← ปิดไว้เป็น default
FAB "+" overlay ล่างขวา → AddTaskSheet
.searchable(text:) กรองจาก ชื่องาน + รายละเอียด + ชื่อวิชา
.navigationTitle("งาน / การบ้าน")
```

### 6.4 นิยาม chip / การ์ดสถิติ (ใช้ค่าเดียวกันทั้งคู่ ห้ามคำนวณคนละที่)

| ตัว | เงื่อนไข |
|---|---|
| ทั้งหมด | ทุกงาน |
| ยังไม่เสร็จ | `!isDone` |
| ใกล้ถึงกำหนด | `!isDone && resolvedDueDate != nil && 0 <= daysUntil <= 3` |
| เลยกำหนด | `isOverdue` |
| เสร็จแล้ว | `isDone` |

กดการ์ดสถิติ = สลับ chip ไปตัวที่ตรงกัน (เลยกำหนดไม่มี chip → ใช้ chip "ยังไม่เสร็จ" + set filter ใน sheet เป็นเลยกำหนด)

### 6.5 การ์ดงาน 1 แถว (`TaskRowCard`)

```
[ ○ ]  [ไอคอนวิชา]  ชื่องาน                              [ป้ายวัน]
                    เคมี                                 ← ชื่อวิชาเท่านั้น (งานส่วนตัวเว้นไว้)
                    📅 30 ก.ค. 2569 23:59                ← ใช้ Date+Thai.swift (พ.ศ.)
```

- วงกลมซ้าย = toggle `isDone` (ต้อง cancel notification ด้วย)
- ไอคอน: `subject.iconName` + พื้น `subject.color.opacity(0.12)` · งานส่วนตัวใช้ `kind.iconName` + `Theme.Colors.primary.opacity(0.12)`
- ป้ายวันขวาบน — สีจาก `dueLabel`:

| ป้าย | สีข้อความ | พื้นหลัง |
|---|---|---|
| เลยกำหนด | `Theme.Colors.danger` | `danger.opacity(0.15)` |
| วันนี้ | `Theme.Colors.warning` | `warning.opacity(0.15)` |
| พรุ่งนี้ | `Theme.Colors.purple` | `purple.opacity(0.15)` |
| อีก N วัน | `Theme.Colors.success` | `success.opacity(0.15)` |
| ไม่กำหนด | `Theme.Colors.textSecondary` | `separator` |

- แถวที่ `isOverdue` → เพิ่ม border `danger.opacity(0.4)` 1pt + วันที่เป็นสีแดง
- งานเสร็จแล้ว → `.strikethrough()` + ทั้งการ์ด `.opacity(0.6)`
- **ห้าม hardcode สี/ระยะห่าง** ทุกค่าต้องมาจาก `Theme` — โทเคนที่มีครบแล้ว ไม่ต้องเพิ่มตัวใหม่
- แตะการ์ด (ไม่ใช่วงกลม) → เปิด `AddTaskSheet(editing:)` · ปัดซ้าย → ลบ

### 6.6 การเรียง

default = **กำหนดส่ง** (ตามดีไซน์) · งานที่ไม่กำหนดส่งไป**ท้ายสุดเสมอ** ทุกโหมดการเรียง
ตัวเลือกใน `TaskFilterSheet`: กำหนดส่ง · ความสำคัญ (ใช้ `effectivePriority`) · เพิ่งเพิ่ม (`createdAt`)

---

## 7. ทางเข้าอื่น

### 7.1 `RootTabView.swift` — แก้หนี้ปุ่ม `+`

เปลี่ยน `.sheet { SmartCaptureView() }` → `.sheet { AddTaskSheet() }`
กลไก `onChange` ที่ดีดกลับแท็บเดิมยังใช้ของเดิม **ห้ามแก้** (มันทำงานอยู่แล้ว)
ทางเข้า `SmartCaptureView` ย้ายไปอยู่ท้าย `AddTaskSheet` ตาม §5

### 7.2 `DashboardView.swift`

- บรรทัด 221: เปลี่ยน title เมนู `"งาน & To-Do"` → `"งาน / การบ้าน"` ให้ตรงกับหัวข้อหน้า
- บรรทัด 21: `isDateInToday($0.dueDate)` → ต้องใช้ `resolvedDueDate` (งานไม่กำหนดส่งต้องไม่นับว่าครบวันนี้)
- เพิ่มปุ่ม `+` เล็กบนหัวการ์ด "งานค้าง" เปิด `AddTaskSheet()` ตัวเดียวกัน

### 7.3 `ScheduleTodayTasksSection.swift` + `SettingsView.swift`

- Section นี้ default กรอง `kind == .homework` เท่านั้น
- `@AppStorage("scheduleShowsPersonalTasks") private var showsPersonal = false`
- Settings เพิ่ม Toggle "แสดงงานส่วนตัวในตารางเรียน" (ตามรูปแบบ `@AppStorage` ที่ใช้อยู่แล้วใน `SettingsView.swift:24-28`)

---

## 8. แบ่งเฟส — หยุดรอ Few build ทุกเฟส

| เฟส | ทำอะไร | ไฟล์ | Few เช็คยังไง |
|---|---|---|---|
| **1** | โมเดล + priority engine | `Assignment.swift` · `AssignmentPriorityEngine.swift` · ไล่แก้ทุกจุดที่อ่าน `.dueDate` | เปิดแอป → **ไม่ crash** และงานเก่าที่มีอยู่ยังแสดงวันส่งเหมือนเดิม |
| **2** | ฟอร์ม + ทางเข้า | `AddTaskSheet.swift` · `RootTabView.swift` · `DashboardView.swift` | กด `+` กลาง tab → เจอฟอร์มเพิ่มงาน · สร้างการบ้าน 1 ชิ้น (มีวิชา) + งานทั่วไป 1 ชิ้น (ไม่กำหนดส่ง) → ทั้งคู่โผล่ในรายการ · ปุ่มท้ายฟอร์มยังเปิดปฏิทิน/โน้ต/Portfolio ได้ |
| **3** | หน้า Todo ตามดีไซน์ | `AssignmentListView.swift` + ไฟล์ย่อย 4 ตัว (ย้ายเข้า `Features/Tasks/`) | เข้าจาก Dashboard → เห็น chips + สถิติ 4 ใบ + section ใกล้ถึงกำหนด · กด chip/การ์ดสถิติแล้วรายการเปลี่ยน · ค้นหาได้ · งานเลยกำหนดขอบแดง |
| **4** | แจ้งเตือน | `NotificationManager.swift` · `PrototypeAppApp.swift` (scenePhase) | สร้างงานกำหนดส่งอีก ~65 นาที เปิดแจ้งเตือน → รอ 5 นาที ต้องเด้ง slot `h1` · กดเสร็จแล้วต้องไม่เด้งอีก |

**เฟส 3 คือชิ้นที่ใหญ่และเสี่ยง type-check error ที่สุด** — ถ้าเวลาไม่พอสำหรับเดโม่ เฟส 1-2 ก็ใช้งานได้ครบแล้ว เฟส 4 ตัดได้

---

## 9. กับดักเฉพาะโปรเจกต์นี้ (อ่านก่อนเขียนโค้ด)

1. **ห้ามเปลี่ยน type ของ property เดิมใน `@Model`** — เพิ่ม field ใหม่ที่มี default ได้ แต่แก้/ลบของเดิม = crash ตอนเปิดแอป (มี `fatalError` รออยู่ที่ `PrototypeAppApp.swift`)
2. **ไม่มี `@Model` ใหม่ในแผนนี้** — ถ้าเผลอสร้าง ต้องเพิ่มใน `Schema([...])` + `SettingsView.resetAllData()` ครบทั้งสองที่
3. **ไฟล์ใหม่เข้า target เอง** — ห้ามแตะ `.pbxproj`
4. **ห้าม hardcode สี/ระยะห่าง** — `Theme.Colors` / `Theme.Spacing` / `Theme.Radius` เท่านั้น
5. **UI ทั้งหมดภาษาไทย** วันที่ใช้ `Date+Thai.swift` (พ.ศ.)
6. **iOS 26.5** ไม่ต้องเขียน `if #available` · **ห้ามเพิ่ม SPM package**
7. แตก SwiftUI body เป็น sub-view ย่อยตั้งแต่แรก อย่ารอให้ compiler ฟ้อง
8. อัปเดต **`PROJECT_MAP.md`** ในคอมมิตเดียวกัน — §2 โครงสร้างไฟล์ (โฟลเดอร์ `Features/Tasks/` ใหม่, `SubjectHub` หาย) · §3 field ใหม่ของ `Assignment` · §8 ลบหนี้ "แตะแถวงานแล้วแค่ log"
9. เพิ่มเฟรม Figma ชื่อ `AddTaskSheet` ในไฟล์ **Student OS — UI Frames** (กฎ: ชื่อ frame = ชื่อ struct)

---

## 10. Definition of done

- [ ] เปิดแอปด้วยข้อมูลเดิมในเครื่องแล้วไม่ crash และงานเก่ายังมีวันส่งครบ
- [ ] กด `+` กลาง tab / ปุ่มใน Dashboard / FAB ในหน้า Todo → เปิดฟอร์มเดียวกัน
- [ ] สร้างงานได้ทั้ง 2 ประเภท · งานส่วนตัวไม่มี Picker วิชา
- [ ] ไม่กำหนดส่ง → toggle แจ้งเตือนปิดและกดไม่ได้
- [ ] ความสำคัญ "อัตโนมัติ" ให้ผลตรงตารางทดสอบใน §3 ทั้ง 7 เคส
- [ ] หน้า Todo มีครบ: chips 4 · สถิติ 4 · section ใกล้ถึงกำหนด · รายการ · กลุ่มเสร็จแล้วพับได้ · ค้นหา · FAB
- [ ] งานเลยกำหนดมีขอบ/ป้ายแดงชัด
- [ ] แท็บตารางเรียนแสดงเฉพาะการบ้าน จนกว่าจะเปิด Toggle ใน Settings
- [ ] ปฏิทิน / โน้ต / Portfolio ยังสร้างได้ (ไม่กลายเป็นโค้ดตาย)
- [ ] `PROJECT_MAP.md` อัปเดตแล้ว
