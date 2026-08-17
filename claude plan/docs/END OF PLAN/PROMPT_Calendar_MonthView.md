# PROMPT — Month View Calendar (Student OS)

> เวอร์ชันที่เขียนใหม่จาก design brief ภาษาอังกฤษ ให้ตรงกับโค้ดจริงใน repo นี้
> อัปเดต: 10 ส.ค. 2569 · เป้าหมาย: ส่งอาจารย์ / ประกวด

---

## 0. บริบทที่ต้องรู้ก่อนเริ่ม (ห้ามเดา ห้ามสร้างใหม่ทับของเดิม)

**Repo:** `~/Documents/MyTask/PrototypeApp` · source ใน `PrototypeApp/`
**Deployment target:** iOS 26.5 — ใช้ API ใหม่ได้หมด ไม่ต้อง `if #available`
**Dependency ภายนอก:** ไม่มีเลย และห้ามเพิ่ม SPM package
**ภาษา UI:** ไทยล้วน · วันที่เป็น พ.ศ. ผ่าน `Date+Thai.swift` · ปฏิทินใช้ `Calendar(identifier: .gregorian)` แล้วบวก 543 เอง

### ไฟล์ที่เกี่ยวข้องโดยตรง

| ไฟล์ | บรรทัด | บทบาท |
|---|---|---|
| `Features/Calendar/CalendarView.swift` | 758 | หน้าปฏิทิน + `@Model` 3 ตัว + `EventFormSheet` อยู่รวมในไฟล์เดียว |
| `Core/DesignSystem/Theme.swift` | 87 | design tokens + `CardContainer` + `TierBadge` |
| `Core/Models/Assignment.swift` | 133 | การบ้าน/งานทั่วไป |
| `Core/Models/ExamEvent.swift` | 27 | **model ตายแล้ว** — อยู่ใน `Schema` กับ `resetAllData()` เท่านั้น ไม่มีที่ไหนสร้างหรือแสดง |
| `Features/Tasks/AddTaskSheet.swift` | — | ฟอร์มเพิ่มงาน มี picker `AssignmentKind` |
| `Features/Tasks/TaskScope.swift` | — | switch แบบ exhaustive บน kind — เพิ่ม case แล้วต้องแก้ที่นี่ |
| `App/PrototypeAppApp.swift` | 136 | `Schema([...])` — ลืมเพิ่ม model = crash ทันทีตอนเปิด |
| `Features/Settings/SettingsView.swift` | 357 | `resetAllData()` — เคยลืม Calendar 3 ตัวมาแล้ว |

### สิ่งที่ **มีอยู่แล้ว** ห้ามออกแบบซ้ำ

```swift
@Model CalendarEvent   // id, title, startDate, endDate, isAllDay, location,
                       // alertRaw, customAlertMinutes, notes, urlString,
                       // colorHex, createdAt, updatedAt, attachments[], tags[]
@Model CalendarTag              // name, colorHex, events[]
@Model CalendarAttachmentItem   // filename, urlString, fileType
enum  EventAlert                // none / atTime / 5 / 15 / 30 นาที / 1 ชม. / 1 วัน / custom
struct EventFormSheet           // add + edit initializer, color picker 6 สี, save(), delete()
```

ทำแล้วเช่นกัน: long press ช่องวัน → เปิด sheet เพิ่มกิจกรรม · จุดสีสูงสุด 3 จุดต่อช่อง · ปัดซ้าย-ขวาเปลี่ยนเดือน · แจ้งเตือนผ่าน `NotificationManager`

### ปัญหาของโค้ดปัจจุบันที่ต้องแก้

1. `CalendarView` `@Query` แค่ `CalendarEvent` — **ไม่ดึงการบ้านหรือสอบเลย** ทั้งที่แอปโฆษณาว่าเป็น all-in-one
2. ปุ่มค้นหา (แว่นขยาย) เป็นปุ่มเปล่า `Button { } label:` ไม่ทำอะไร
3. ปุ่มชื่อเดือน + chevron เป็นปุ่มเปล่าเช่นกัน
4. `topBar` ใช้ `.padding(.top, 56)` hardcode + `.ignoresSafeArea(edges: .top)` — ไม่ใช่ `NavigationStack` จึงไม่มี large title ที่ยุบได้
5. `calendarCard` ใช้ `Color.white` ตรงๆ (ไม่ใช่ token) → dark mode พัง
6. ปุ่ม `bell.badge` ส่ง test notification — เป็นปุ่ม debug ไม่ควรอยู่ใน production UI
7. ช่องวันสูงคงที่ 50pt แสดงได้แค่จุดสี

---

## 1. ขอบเขตงาน (ตามที่ Few ตัดสินใจแล้ว)

### ✅ ทำ

1. **เปลี่ยน design system ทั้งแอปเป็นโทน warm** (ไม่ใช่เฉพาะปฏิทิน)
2. **ช่องวันแสดง pill ข้อความ + "+X"** ไม่ใช่จุดสี
3. **Ghost Event เต็มรูปแบบ** — ทั้งลากสร้างใหม่ และลากย้ายกิจกรรมที่มีอยู่
4. **รวมข้อมูล 3 ชนิดในปฏิทิน**: `CalendarEvent` + `Assignment` (การบ้าน/งาน) + สอบ
5. **เพิ่ม "สอบ" เป็นตัวเลือกในหน้าเพิ่มงาน** พร้อมเลือกกลางภาค/ปลายภาค + วันที่
6. ค้นหาที่ใช้งานได้จริง
7. Large title ที่ยุบตอนเลื่อน

### ❌ ตัดทิ้ง (ยืนยันแล้ว)

| ตัด | เหตุผล |
|---|---|
| **Repeat / กิจกรรมซ้ำ** | ไม่ใช่ field แต่เป็น engine — expand occurrence, notification รายครั้ง, "แก้ครั้งนี้/ทุกครั้ง" เสี่ยงพังสูงสุดในลิสต์ ก่อนเดโม่ไม่คุ้ม |
| **Attachments UI** | model มีแล้วแต่ไม่มี picker/storage ทำครึ่งๆ = "กรอกแล้วข้อมูลหายเงียบๆ" |
| **Hover state** | iPhone ไม่มี |
| **Emoji 📚📝 ใน pill** | แอปใช้ SF Symbols ตลอด และ emoji ทำให้ดูไม่ premium — ใช้จุดสี 6pt หรือ SF Symbol 9pt แทน |
| **ScheduleEntry ในปฏิทิน** | คาบเรียนประจำจะทำให้ทุกวันจันทร์-ศุกร์เต็ม แล้ว event จริงจมหาย — ให้ซ่อนเป็น toggle ใน filter ถ้าจะทำทีหลัง |
| **ปุ่ม test notification** | ย้ายไปหน้า Settings |
| **long press 350ms** | ใช้ 500ms มาตรฐาน iOS — 350ms จะแย่ง gesture กับ scroll |

### ⚠️ เสี่ยง ต้องรู้ก่อนลงมือ

- **Gesture ชนกัน 3 ทาง**: ปัดเปลี่ยนเดือน (`DragGesture` minimumDistance 40 ที่มีอยู่ บรรทัด 317) + long-press-drag ghost + scroll ที่ทำให้ title ยุบ
  → **ทางออกที่กำหนดไว้: เอาการปัดเปลี่ยนเดือนออก** ใช้ปุ่ม `‹ ›` ข้างชื่อเดือนแทน ตัดปัญหาที่ต้นเหตุ
- **เปลี่ยนสีทั้งแอป** กระทบทุกหน้า (118 ไฟล์) — ต้องไล่ดูภาพจริงทุกแท็บ ไม่ใช่แค่ปฏิทิน และต้องอัปเดต Figma variable 19 ตัวให้ตรง
- **`Color.white` / `Color(.systemGray*)` ที่ hardcode ไว้** จะไม่เปลี่ยนตามธีม ต้อง grep เก็บให้หมด

---

## 2. Design System — โทน Warm (ค่าที่ตรวจ contrast แล้ว)

แก้ที่ `Core/DesignSystem/Theme.swift` เท่านั้น **ห้าม hardcode สีในไฟล์ view**

### 2.1 Surfaces & text

```swift
// Light                                    Dark
background     #FBF7F2   warm off-white     #14110E
cardBackground #FFFFFF   ขาวบริสุทธิ์         #1F1B17
surfaceRaised  #F6F0E8   การ์ดซ้อนการ์ด      #2A241E
breakBackground #FDF3E0                     #2A2416  (คงเดิม)
separator      #EDE3D6                      #3A322A
cardStroke     #EDE3D6                      #3A322A
textPrimary    #2A2320                      #F4EEE7
textSecondary  #7A6E62                      #A79A8B
```

Contrast ที่ตรวจแล้ว (WCAG AA ต้อง ≥ 4.5 สำหรับข้อความปกติ):

| คู่สี | Light | Dark |
|---|---|---|
| textPrimary บนการ์ด | **15.44** ✅ | **14.85** ✅ |
| textPrimary บนพื้นหลัง | **14.48** ✅ | **16.33** ✅ |
| textSecondary บนการ์ด | **4.96** ✅ | **6.22** ✅ |

> หมายเหตุ: `textSecondary` เดิมที่คิดไว้ `#857A6E` ได้ 4.19 → **ตก** จึงใช้ `#7A6E62` แทน

### 2.2 Accent — ต้องมีสองระดับ

ส้มอุ่นที่สวยจะ contrast ไม่ผ่านถ้าเอาไปวางข้อความ จึงแยกเป็น 2 token:

```swift
primary      #E1802F   // ใช้เป็น "พื้น" เท่านั้น: highlight ช่องวัน, progress, เส้นคั่น
                       //   ขาวบนสีนี้ = 2.86 → ห้ามวางข้อความบนพื้นนี้
primaryDeep  #A85C1C   // ใช้กับ "ข้อความ/ไอคอน": ขาวบนสีนี้ = 4.99 ✅
                       //   ตัวมันเองบนพื้นหลัง = 4.67 ✅
// Dark mode
primary      #F2A65A   // บนการ์ดมืด = 8.45 ✅
onPrimary    #1A1512   // ข้อความบน primary ในโหมดมืด = 8.95 ✅
```

**กฎ:** วงกลม "วันนี้" ที่มีเลขสีขาวข้างใน → ใช้ `primaryDeep` เป็น fill · แถบ highlight / พื้นอ่อน → ใช้ `primary.opacity(0.12)`

### 2.3 Event palette — ปรับให้เข้าโทน warm

สีเดิมสด/เย็นเกินไป (`#4A7DFF`, `#00BCD4`) จะตีกับพื้นครีม เปลี่ยนเป็นโทน muted:

```
E1802F  ส้ม (default)      C2703C  น้ำตาลอบ
7D8F69  เขียวเซจ          C25B4E  แดงดินเผา
6B7FA3  น้ำเงินหม่น        8E6B9E  ม่วงลาเวนเดอร์
B08D57  ทอง               5F8A8B  เขียวน้ำทะเลหม่น
```

ยังต้องให้นักเรียนเลือกสีเองได้อิสระเหมือนเดิม ห้ามบังคับสีตามหมวด

### 2.4 Typography

SF Pro ผ่าน `.system(size:weight:)` ตามที่ใช้อยู่ **ห้ามใส่ฟอนต์ custom**

```
Large title (ชื่อเดือน)  34 / bold          — ยุบเหลือ 17 / semibold ตอนเลื่อน
Section header           15 / semibold
Day number               15 / medium (17 / bold เมื่อเป็นวันนี้)
Weekday header           11 / semibold / textSecondary / uppercase ไม่ต้อง
Event pill               10 / medium        — ล็อกขนาด ไม่ scale
Body                     15 / regular
Caption                  12 / regular
```

---

## 3. Month Grid — สเปคตัวเลขจริง

**หน้าจออ้างอิง: iPhone 16 Pro — 402 × 874pt** (ตรงกับเฟรม Figma)

```
กว้างจอ                402
- padding ซ้าย/ขวา      12 × 2  = 24
= พื้นที่กริด            378
÷ 7 คอลัมน์            = 54pt ต่อช่อง
- ระยะห่างช่อง 2pt      = 52pt ที่ใช้ได้จริงต่อช่อง
```

### 3.1 โครงช่องวัน

```
┌──────────── 52pt ────────────┐
│  15                    ●     │  ← เลขวัน + จุด "ครบกำหนดวันนี้"
│  ██ คณิต                     │  ← pill 1   สูง 14pt
│  ██ อังกฤษ                   │  ← pill 2   สูง 14pt
│  +2                          │  ← overflow 10pt
└──────────────────────────────┘
ความสูงช่อง: 78pt   →  6 แถว = 468pt
```

### 3.2 ข้อจำกัดข้อความไทยที่ต้องยอมรับ

pill กว้าง ~48pt ที่ฟอนต์ 10pt → **ข้อความไทยลงได้ประมาณ 5-6 ตัวอักษร**

- ตัดด้วย `.lineLimit(1)` + `.truncationMode(.tail)`
- ถ้ามี `subjectName` ให้แสดงชื่อวิชาแทน title (สั้นกว่า) — `"คณิต"` ดีกว่า `"การบ้านคณ..."`
- **ล็อกฟอนต์ pill ไม่ให้ scale ตาม Dynamic Type** (`.dynamicTypeSize(...DynamicTypeSize.large)` เฉพาะ pill) — ยอมแลกเพื่อให้เลย์เอาต์ไม่พัง
- แต่ **เลขวัน / ชื่อเดือน / รายการด้านล่าง ต้อง scale ตามปกติ** ห้ามล็อกทั้งหน้า

### 3.3 จำนวน pill ที่แสดง

- แสดงสูงสุด **2 pill** + `+X` เมื่อเกิน
- ถ้ามี 3 พอดี → แสดง 2 + `+1` (ไม่บีบเป็น 3)
- ลำดับ: สอบ → การบ้านที่ครบกำหนด → กิจกรรม (เรียงตามเวลา)
- วันนอกเดือน: เลขสีจาง ไม่แสดง pill เลย

### 3.4 สถานะช่องวัน

| สถานะ | หน้าตา |
|---|---|
| ปกติ | พื้นใส |
| วันนี้ | เลขวันในวงกลม `primaryDeep` ตัวอักษรขาว 17/bold |
| เลือกอยู่ | ช่องทั้งช่องพื้น `primary.opacity(0.10)` มุมโค้ง `Theme.Radius.control` |
| วันนี้ + เลือก | ทั้งสองอย่างพร้อมกัน |
| กดค้าง (pressed) | scale 0.96 + พื้น `primary.opacity(0.06)` |
| เป้าหมายที่ลากไปวาง | เส้นขอบ `primary` 2pt + พื้น `primary.opacity(0.14)` |
| มีงานครบกำหนด | จุด `#C25B4E` 5pt มุมขวาบน |

เส้นคั่นตาราง: **ไม่มีเส้น** ใช้ระยะห่าง 2pt อย่างเดียว (ตาม "very subtle separators")

---

## 4. Ghost Event — สเปคละเอียด

### 4.1 โหมด A — ลากสร้างกิจกรรมใหม่

```
กดค้างที่ช่องว่างในวัน 500ms
  → haptic .impact(.medium)
  → เกิด ghost pill ใต้นิ้ว: scale 1.08, shadow radius 8 opacity 0.18,
    ข้อความ "กิจกรรมใหม่", สี primary
  → ghost ไม่ถูก insert เข้า modelContext และไม่มี id ถาวร
ระหว่างลาก
  → ghost ตามนิ้วแบบ 1:1 (ใช้ .offset ไม่ใช่ animation ต่อเฟรม)
  → ช่องวันที่นิ้วอยู่ = สถานะ drop target
  → เข้าช่องใหม่ → haptic .selection (throttle อย่างน้อย 60ms กันสั่นรัว)
ปล่อยในกริด
  → spring(response: 0.35, dampingFraction: 0.75) ให้ ghost ลงช่อง
  → สร้าง CalendarEvent จริง วันที่ = ช่องปลายทาง isAllDay = true
  → เปิด EventFormSheet(event:) ทันที
  → ถ้าผู้ใช้กด "ยกเลิก" ใน sheet → ลบ event ที่เพิ่งสร้าง
ปล่อยนอกกริด
  → ghost บินกลับจุดเริ่ม spring เดียวกัน แล้วหายไป ไม่สร้างอะไร
```

### 4.2 โหมด B — ลากย้ายกิจกรรมที่มีอยู่

```
กดค้างที่ pill 500ms
  → haptic .impact(.medium) + pill ต้นทางจางลงเหลือ opacity 0.3
  → ghost = สำเนาของ pill นั้น (สีเดิม ข้อความเดิม)
ระหว่างลาก / ปล่อย  → เหมือนโหมด A
ปล่อยในช่องอื่น
  → เลื่อน startDate/endDate ของ event เดิม (รักษาช่วงเวลาและระยะเวลาเดิม)
  → ยกเลิกแล้วตั้งแจ้งเตือนใหม่ผ่าน NotificationManager
  → haptic .notification(.success)
  → แสดง toast "ย้ายไป 15 ส.ค. แล้ว" พร้อมปุ่ม "เลิกทำ" 4 วินาที
ปล่อยนอกกริด หรือปล่อยในช่องเดิม
  → ไม่มีอะไรเปลี่ยน ghost บินกลับ
```

**การบ้าน (`Assignment`) ลากได้เหมือนกัน** → เลื่อน `dueDate` แต่ถ้า `hasDueDate == false` ต้องลากไม่ได้ (ห้ามลาก แสดง haptic `.warning`)

### 4.3 ข้อกำหนดเทคนิค

- ใช้ `LongPressGesture(minimumDuration: 0.5).sequenced(before: DragGesture(coordinateSpace: .named("monthGrid")))`
- คำนวณช่องปลายทางจากตำแหน่งนิ้ว **ด้วยเลขคณิต** (`col = x / cellW`, `row = y / cellH`) ไม่ใช้ `GeometryReader` ซ้อนทุกช่อง — 42 ช่องจะกิน CPU
- `@State` ของ ghost เก็บที่ระดับ `CalendarView` ไม่ใช่ในช่อง
- ghost วาดใน `.overlay` ชั้นบนสุดของกริด ไม่ใช่ในช่อง (ไม่งั้นจะถูก clip)
- ระหว่างลากต้อง `.scrollDisabled(true)` ที่ ScrollView ครอบ
- ห้ามใช้ `.draggable`/`.dropDestination` — ออกแบบมาเพื่อลากข้ามแอป ทำ ghost 60fps + haptic ต่อช่องไม่ได้

---

## 5. รวมข้อมูล 3 ชนิด

### 5.1 โครงสร้าง

สร้าง `Features/Calendar/CalendarItem.swift` — **struct ธรรมดา ไม่ใช่ `@Model`** (ห้ามแตะ schema เพิ่ม)

```swift
enum CalendarItemKind { case event, homework, personal, exam }

struct CalendarItem: Identifiable {
    let id: String            // "event_<uuid>" / "task_<uid>"
    let kind: CalendarItemKind
    let title: String
    let shortLabel: String    // ชื่อที่โชว์ใน pill — subjectName ถ้ามี
    let date: Date
    let isAllDay: Bool
    let color: Color
    let isDone: Bool
    let sourceEvent: CalendarEvent?   // อย่างใดอย่างหนึ่งเป็น nil
    let sourceTask: Assignment?
}
```

`CalendarView` `@Query` ทั้ง `CalendarEvent` และ `Assignment` แล้ว map เป็น `[CalendarItem]` ครั้งเดียว เก็บเป็น `[Date: [CalendarItem]]` (key = `startOfDay`) เพื่อไม่ให้ `eventsFor()` วน array ทั้งก้อนใหม่ทุกช่อง — ปัจจุบันเรียก 42 ครั้งต่อการ render หนึ่งรอบ

### 5.2 ExamEvent — จัดการยังไง

`ExamEvent` **ไม่มีใครใช้** อยู่ใน `Schema` กับ `resetAllData()` เท่านั้น

- **ห้ามลบออกจาก `Schema`** — store ที่ผู้ใช้มีอยู่มี entity นี้อยู่ ลบแล้วอาจเปิดไม่ขึ้น
- ปล่อยไว้เฉยๆ ใส่คอมเมนต์ `// Unused — kept for store compatibility. Exams live on Assignment.kind == .exam`
- สอบ **เก็บใน `Assignment`** แทน เพื่อให้อยู่ในลิสต์งานเดียวกัน เรียง priority ร่วมกันได้

### 5.3 เพิ่ม "สอบ" ในหน้าเพิ่มงาน

**แก้ `Core/Models/Assignment.swift`:**

```swift
enum AssignmentKind: String, Codable, CaseIterable {
    case homework, personal, exam        // เพิ่ม .exam
    var label: String { ... "สอบ" }
    var iconName: String { ... "pencil.and.list.clipboard" }
}

enum ExamScope: String, Codable, CaseIterable {
    case midterm, final, quiz
    var label: String { "กลางภาค" / "ปลายภาค" / "เก็บคะแนน" }
}

// เพิ่มใน @Model Assignment — ต้องมี default value ไม่งั้น backfill crash
var examScopeRaw: String = ""
var examScope: ExamScope? { ... }
```

> `kindRaw` เป็น `String` อยู่แล้ว → **เพิ่ม case ปลอดภัย ไม่ต้อง migrate**
> `examScopeRaw` มี default `""` → **แถวเดิมถูก backfill ได้ ไม่ crash**

**แก้ `Features/Tasks/AddTaskSheet.swift`:**

```
[ การบ้าน ]  [ งานทั่วไป ]  [ สอบ ]      ← segmented เดิม เพิ่มปุ่มที่ 3

เมื่อเลือก "สอบ" ให้โผล่เพิ่ม:
  ประเภท   [ กลางภาค ] [ ปลายภาค ] [ เก็บคะแนน ]
  วิชา     (ใช้ subjectSection เดิม — เดิมโชว์เฉพาะ .homework ต้องเปลี่ยนเป็น
            kind != .personal)
  วันสอบ   (DatePicker เดิม — บังคับมีวันเสมอ ซ่อน toggle "ไม่กำหนดส่ง")
```

**ไฟล์ที่ compiler จะฟ้องเพราะ switch ไม่ครบ — ต้องแก้ตาม:**

- `Features/Tasks/TaskScope.swift` (บรรทัด 67-76)
- `Features/Tasks/TaskFilterSheet.swift` (บรรทัด 42)
- `Core/Tasks/AssignmentPriorityEngine.swift` (บรรทัด 39) — สอบควรได้น้ำหนักสูงกว่าการบ้าน
- `Features/Schedule/ScheduleTodayTasksSection.swift` (บรรทัด 28)
- `Features/Tasks/AddTaskSheet.swift` (บรรทัด 80, 195)

---

## 6. Header + ค้นหา

### 6.1 Large title ที่ยุบได้

```
กางเต็ม (scrollOffset = 0)          ยุบแล้ว
┌──────────────────────────┐        ┌──────────────────────────┐
│                          │        │  ‹  สิงหาคม 2569  ›  วันนี้│
│  สิงหาคม 2569       วันนี้│        └──────────────────────────┘
│  34/bold                 │        17/semibold + เส้นคั่นบางๆ
│                          │
│  🔍 ค้นหากิจกรรม           │
│  ‹  ›                    │
└──────────────────────────┘
```

- ครอบด้วย `NavigationStack` + `.navigationTitle` + `.navigationBarTitleDisplayMode(.large)` ให้ระบบจัดการการยุบ **อย่าเขียน scroll offset เอง**
- เอา `.ignoresSafeArea(edges: .top)` และ `.padding(.top, 56)` ออก
- ปุ่ม "วันนี้": `.toolbar` ขวา · แตะแล้ว `withAnimation(.spring(response: 0.4, dampingFraction: 0.8))` เด้งกลับเดือนปัจจุบัน + เลือกวันนี้ + haptic `.impact(.light)` · **disable เมื่ออยู่เดือนปัจจุบันและเลือกวันนี้อยู่แล้ว**
- ปุ่ม `‹ ›` เปลี่ยนเดือน — touch target อย่างน้อย 44×44
- ย้ายปุ่ม test notification ไป Settings

### 6.2 ช่องค้นหา

`.searchable(text:placement: .navigationBarDrawer(displayMode: .always))`
placeholder: `"ค้นหากิจกรรม การบ้าน วิชา"`

ค้นจาก: `CalendarEvent.title`, `.location`, `.notes`, `CalendarTag.name` · `Assignment.title`, `.detail`, `.subjectName`

**ครู/teacher: ตัดออก** — `Assignment` และ `CalendarEvent` ไม่มี field ครู มีแค่ `ScheduleEntry` ซึ่งเราไม่รวมในปฏิทินรอบนี้

เมื่อมีคำค้น: ซ่อนกริด แสดงลิสต์ผลลัพธ์จัดกลุ่มตามเดือน แตะแล้วเด้งไปวันนั้น
ไม่เจอ: `ContentUnavailableView.search(text:)`

---

## 7. Event Editor

ใช้ `EventFormSheet` เดิม เพิ่ม/แก้ตามนี้:

| ฟิลด์ | สถานะ |
|---|---|
| ชื่อ · ทั้งวัน · เริ่ม-สิ้นสุด · สี · แจ้งเตือน | ✅ มีแล้ว |
| สถานที่ (`location`) | ➕ model มี field แล้ว แค่ยังไม่มีช่องกรอก |
| โน้ต (`notes`) | ➕ เหมือนกัน — `TextEditor` สูง 80pt |
| วิชา | ➕ ใช้ `SubjectPickerFields` ที่มีอยู่ใน `Features/Schedule/` |
| แท็ก | ➕ `CalendarTag` มี model แล้ว ทำ chip เลือก/สร้างใหม่ |
| จานสี | 🔄 เปลี่ยนจาก 6 สีเดิม เป็น 8 สี warm ตาม §2.3 |
| ทำซ้ำ · ไฟล์แนบ | ❌ ตัด |

**พฤติกรรม:** เปิดขึ้นมาแล้ว focus ที่ช่องชื่อทันที (คีย์บอร์ดเด้ง) · `.presentationDetents([.medium, .large])` · ปุ่ม "บันทึก" disable จนกว่าจะมีชื่อ (มีแล้วผ่าน `canSave`)

---

## 8. Empty states

| กรณี | ข้อความ |
|---|---|
| เดือนนี้ไม่มีอะไรเลย | ไอคอน `calendar` จาง + "เดือนนี้ยังว่าง" + "กดค้างที่วันไหนก็ได้เพื่อเพิ่มกิจกรรม" |
| เลือกวันที่ไม่มีอะไร | "ไม่มีอะไรในวันนี้" (สั้นๆ ไม่ต้องมีไอคอนใหญ่ พื้นที่จำกัด) |
| ค้นหาไม่เจอ | `ContentUnavailableView.search(text:)` |

โทน: เป็นกลาง ไม่ต้องเชียร์ ไม่ต้องมีอิโมจิ — "ปฏิทินที่ว่างคือเรื่องดี ไม่ใช่ปัญหาที่ต้องแก้"

---

## 9. Motion

```swift
เลือกวัน            .spring(response: 0.28, dampingFraction: 0.85)
เปลี่ยนเดือน         .spring(response: 0.40, dampingFraction: 0.85) + .opacity transition
ghost ยกขึ้น         .spring(response: 0.25, dampingFraction: 0.70)  scale 1.0 → 1.08
ghost ตกลงช่อง       .spring(response: 0.35, dampingFraction: 0.75)
ghost ยกเลิก         .spring(response: 0.45, dampingFraction: 0.80)  กลับที่เดิม
ปุ่มวันนี้            scale 0.94 ตอนกด, .spring(response: 0.20, dampingFraction: 0.60)
title ยุบ            ระบบจัดการเอง
```

ทุกอย่างต้องเคารพ `@Environment(\.accessibilityReduceMotion)` — ถ้าเปิดอยู่ให้เหลือ fade อย่างเดียว

---

## 10. ลำดับงาน — แบ่งเป็น 4 รอบ หยุดให้ Few build ได้ทุกรอบ

| รอบ | ทำอะไร | เสี่ยง | ตัดได้ไหมถ้าเวลาไม่พอ |
|---|---|---|---|
| **1** | Theme warm + เก็บ hardcoded color ทั้งแอป | กลาง — กระทบทุกหน้า | ไม่ได้ เป็นฐานของทุกอย่าง |
| **2** | รวม `Assignment` + `.exam` เข้าปฏิทิน · `CalendarItem` · pill + "+X" · index by day | กลาง — แตะ `AssignmentKind` | ไม่ได้ นี่คือคุณค่าหลัก |
| **3** | Header ยุบได้ · ค้นหา · Editor ฟิลด์เพิ่ม | ต่ำ | ค้นหาตัดได้ |
| **4** | Ghost Event ทั้งสองโหมด | **สูง** | ตัดได้ — ถ้าตัด ยังเหลือ long press → sheet เดิมใช้งานได้ |

**เอา Ghost Event ไว้รอบสุดท้ายโดยตั้งใจ** — เป็น moment ที่ว้าวที่สุดในเดโม่ แต่ก็เสี่ยงที่สุด ถ้าทำแล้วพังต้อง `git checkout` ย้อนได้โดยไม่กระทบรอบ 1-3

---

## 11. Definition of done — Few จะเช็คยังไง

**รอบ 1** เปิดทุกแท็บ (หน้าแรก · ปฏิทิน · เพิ่ม · ตารางเรียน · ตั้งค่า) ทั้ง light และ dark → ไม่มีจุดไหนเป็นสีน้ำเงินเดิมหลงเหลือ ไม่มีข้อความอ่านไม่ออก

**รอบ 2** เพิ่มการบ้าน 1 ชิ้น + สอบกลางภาค 1 วิชา + กิจกรรม 1 อัน คนละวัน → ทั้งสามโผล่เป็น pill ในปฏิทิน · ใส่ 4 อย่างในวันเดียว → เห็น 2 pill + `+2`

**รอบ 3** เลื่อนลง → ชื่อเดือนยุบเป็นแถบเล็ก · พิมพ์ชื่อวิชาในช่องค้นหา → เจอทั้งการบ้านและกิจกรรม

**รอบ 4** กดค้างช่องว่าง → ghost โผล่ตามนิ้ว · ลากข้ามวัน → รู้สึกสั่น · ปล่อย → sheet เด้ง · กดค้าง pill ที่มีอยู่ → ลากไปวันอื่นได้ · ลากออกนอกตาราง → เด้งกลับไม่มีอะไรเกิด

---

## 12. Figma — ข้อจำกัดของไฟล์นี้

ไฟล์ **Student OS — UI Frames** `7qTFOazJhInRwMm7viQbGr` · เฟรม iPhone 16 Pro 402×874

- **SF Pro ใช้ไม่ได้** → ใช้ `Inter` (Latin) + `Noto Sans Thai` (ไทย) แทน
- **SF Symbols ใช้ไม่ได้** (ต้องพึ่ง SF Pro) → ใช้รูปทรงแทน
- **`figma.createPage()` เกิน 3 หน้า = error ทั้งสคริปต์** (แพลน Starter)
- TEXT ใน auto-layout: `textAutoResize='HEIGHT'` → `layoutSizingHorizontal='FIXED'` → `resize(w,h)` → ค่อย `'FILL'`
- ชื่อเฟรม = ชื่อ struct ใน Swift ตรงตัว: `CalendarView`, `CalendarView.search`, `CalendarView.ghostDrag`, `CalendarView.empty`, `EventFormSheet`
- ต้องอัปเดต variable `color/*` ทั้งชุดให้ตรงกับ `Theme.swift` ใหม่

> **ข้อเสนอ:** ด้วยเวลาที่มี การทำ SwiftUI ก่อนแล้วแคปหน้าจอจริงไปใส่สไลด์ จะได้ภาพที่ดีกว่าและตรงกว่าการวาด mockup ใน Figma ที่ใช้ฟอนต์ผิดกับไม่มีไอคอน — ให้ Figma เป็นเอกสารประกอบทีหลัง

---

## 13. เช็คลิสต์กันพัง (จากที่เคยพลาดมาแล้ว)

- [ ] เพิ่ม `@Model` ใหม่? → **ไม่มีในงานนี้** (`CalendarItem` เป็น struct) ถ้าเปลี่ยนใจต้องเพิ่มครบ 3 ที่: ไฟล์ model · `Schema([...])` · `resetAllData()`
- [ ] property ใหม่ใน `@Model` เดิมต้องมี default value เสมอ (`examScopeRaw: String = ""`)
- [ ] **ห้ามลบหรือเปลี่ยน type ของ property เดิม** = crash ตอนเปิดแอป
- [ ] **ห้ามลบ `ExamEvent` ออกจาก `Schema`**
- [ ] ไฟล์ใหม่แค่สร้างในโฟลเดอร์ **ห้ามแก้ `.pbxproj`** (ใช้ file-system-synchronized groups)
- [ ] `CalendarView.swift` 758 บรรทัดจะยาวขึ้นอีกมาก → **แยกเป็น `CalendarView.swift` / `CalendarModels.swift` / `MonthGridView.swift` / `DayCellView.swift` / `GhostEventLayer.swift` / `EventFormSheet.swift`** ไม่งั้นจะเจอ `unable to type-check this expression in reasonable time`
- [ ] ไม่มี SPM package ใหม่
- [ ] อัปเดต `PROJECT_MAP.md` ในคอมมิตเดียวกัน (**หมายเหตุ: ไฟล์นี้ยังไม่มีใน repo — ต้องสร้าง**)
