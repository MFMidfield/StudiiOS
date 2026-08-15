# คำสั่งสำหรับ Claude Code (Sonnet, thinking: high) — รอบ 1

> วิธีใช้: เปิด Claude Code ที่ `~/Documents/MyTask/PrototypeApp`
> พิมพ์ `/model sonnet` แล้วกด Tab จนขึ้น thinking level สูงสุด
> จากนั้น copy ทุกอย่างใต้เส้นคั่นไปวาง

---

อ่าน `PROJECT_MAP.md` และ `PLAN_ScheduleView.md` ที่รากโปรเจกต์ก่อนเริ่ม แล้วทำ **เฉพาะรอบ 1** ตามที่ระบุใน §7 ของแผน — คือ Models + Schema + resetAllData + AppLog + Theme tokens + seed วิชา **ห้ามแตะ UI ของหน้าตารางเรียนในรอบนี้**

## สิ่งที่ต้องทำ

### 1. สร้าง `PrototypeApp/Core/Logging/AppLog.swift`

```swift
enum AppLog {
    static func action(_ category: String, _ message: String)  // print "🔵 [category] message"
    static func warn(_ category: String, _ message: String)    // "🟠"
    static func error(_ category: String, _ message: String)   // "🔴"
}
```
ใช้ `print` ล้วน ไม่ต้อง import os.Logger

### 2. สร้าง `PrototypeApp/Core/Models/Subject.swift`

```swift
@Model final class Subject {
    var name: String
    var code: String          // "" = ไม่ใส่รหัสวิชา
    var colorHex: String      // เก็บ hex ไม่มี # เช่น "4A7DFF"
    var iconName: String      // SF Symbol
    var isBreak: Bool         // true = ช่วงพัก เรนเดอร์เป็นแถบพิเศษ
    var isBuiltIn: Bool       // true = วิชา seed ห้ามลบ
    var createdAt: Date
}
```
เพิ่ม `var color: Color { Color(hex: colorHex) }` เป็น computed (ใช้ `Color+Hex.swift` ที่มีอยู่)

### 3. สร้าง `PrototypeApp/Core/Models/DayScheduleOverride.swift`

```swift
@Model final class DayScheduleOverride {
    var date: Date              // ต้อง normalize เป็น 00:00 ของวันนั้นเสมอ
    var startMinute: Int
    var periodLengthMinutes: Int
    var createdAt: Date
}
```
ใส่ `static func normalizedDate(_ d: Date) -> Date` ไว้ในไฟล์เดียวกันด้วย (ใช้ `Calendar.current.startOfDay`)

### 4. แก้ `PrototypeApp/Core/Models/ScheduleEntry.swift` — breaking change

- **ลบ** `startTime: Date`, `endTime: Date`, `kindRaw: String`, `enum ScheduleKind` ทั้งก้อน
  (ผม grep แล้ว `ScheduleKind` ไม่ถูกใช้ที่ไหนเลยนอกไฟล์นี้ — ให้ verify ซ้ำก่อนลบ)
- **เพิ่ม** `startMinute: Int`, `endMinute: Int` (นาทีจากเที่ยงคืน 08:00 = 480)
- **เพิ่ม** `periodNumber: Int`
- **เพิ่ม** `teacherName: String` (default "")
- **เพิ่ม** `var subject: Subject?` (relationship)
- **คงไว้** `dayOfWeek: Int` (1=จันทร์…7=อาทิตย์), `location: String`, `subjectName: String`
- เพิ่ม helper แปลงนาที ↔ ข้อความ `"08:00"` ไว้ใน extension ของไฟล์นี้ (จะได้ไม่กระจัดกระจาย)

### 5. แก้ `PrototypeApp/Core/Models/Assignment.swift`

เพิ่ม `var subjectName: String = ""` และเพิ่มพารามิเตอร์ใน `init` โดย**ต้องมี default value** เพื่อไม่ให้ `SmartCaptureView.swift:257` พัง

### 6. แก้ `PrototypeApp/App/PrototypeAppApp.swift`

เพิ่ม `Subject.self` และ `DayScheduleOverride.self` ใน `Schema([...])`

**และ** เพิ่มการ seed วิชาเริ่มต้นครั้งแรก — เช็คว่ามี Subject ใน store แล้วหรือยัง ถ้ายังไม่มีให้ insert 3 ตัวนี้:

| name | isBreak | colorHex | iconName |
|---|---|---|---|
| ชุมนุม | false | 9C27B0 | person.3.fill |
| กิจกรรมในเครื่องแบบ | false | 3F51B5 | figure.hiking |
| พักกลางวัน | **true** | FFB347 | fork.knife |

ทั้ง 3 ตัว `isBuiltIn = true` และ log `AppLog.action("Subject", "seed วิชาเริ่มต้น 3 รายการ")`

### 7. แก้ `PrototypeApp/Core/DesignSystem/Theme.swift`

เพิ่มใน `Theme.Colors`:
```swift
static let breakBackground = Color(hex: "FFF8E7")
static let separator       = Color(hex: "E8EAF0")
static let textSecondary   = Color(hex: "6B7280")
static let subjectPalette: [Color] = [primary, success, warning, danger, purple, pink, indigo, info]
static let subjectPaletteHex: [String] = ["4A7DFF","4CAF50","FFB347","FF6B6B","9C27B0","E91E63","3F51B5","00BCD4"]
```

### 7.5 สร้าง `PrototypeApp/Features/Schedule/ScheduleConstants.swift`

ค่าคงที่ที่ทั้งโปรเจกต์ใช้ร่วมกัน — ประกาศไว้ที่เดียวตั้งแต่รอบนี้ จะได้ไม่ต้องไล่แก้ทีหลัง

```swift
enum ScheduleConstants {
    /// แสดงแค่ จันทร์–ศุกร์ (เสาร์-อาทิตย์ ซ่อน) — แก้ที่นี่ที่เดียวถ้าอยากได้ 7 วันคืน
    static let visibleDays: [Int] = [1, 2, 3, 4, 5]
    static let dayLabels: [Int: String] = [1:"จันทร์", 2:"อังคาร", 3:"พุธ", 4:"พฤหัส", 5:"ศุกร์", 6:"เสาร์", 7:"อาทิตย์"]
    static let dayLabelsFull: [Int: String] = [1:"วันจันทร์", 2:"วันอังคาร", 3:"วันพุธ", 4:"วันพฤหัสบดี", 5:"วันศุกร์", 6:"วันเสาร์", 7:"วันอาทิตย์"]
    static let defaultSubjectIcon = "book.closed.fill"
}
```

**และ** ใส่ helper สร้างวิชาแบบ get-or-create ไว้ที่นี่ด้วย (รอบ 9 กับรอบ 2 จะเรียกใช้ทั้งคู่):
```swift
/// หา Subject ตามชื่อ ถ้าไม่มีให้สร้างใหม่ (สีหมุนตาม subjectPaletteHex) แล้วคืนกลับมา
static func findOrCreateSubject(named: String, in context: ModelContext) -> Subject?
```
- trim ช่องว่าง · ชื่อว่าง → คืน `nil` ไม่สร้าง
- match ชื่อแบบ case-insensitive
- สีเลือกจาก `subjectPaletteHex[จำนวน Subject ที่มีอยู่ % 8]`
- log ทุกครั้งที่สร้างใหม่: `AppLog.action("Subject", "สร้างวิชาอัตโนมัติ: <ชื่อ> สี=<hex>")`

### 8. แก้ `PrototypeApp/Features/Settings/SettingsView.swift`

เพิ่ม `deleteAll(Subject.self)` และ `deleteAll(DayScheduleOverride.self)` ใน `resetAllData()`
ระวัง: ลบ Subject แล้วต้อง seed ใหม่ ไม่งั้นผู้ใช้จะไม่มีวิชาเริ่มต้นเลย — จัดการให้ด้วย

### 9. แก้ callers ที่พังจากข้อ 4

- `PrototypeApp/Core/OCR/ScheduleOCRParser.swift` — `struct ScheduleDraftEntry` มี `startTime: Date` / `endTime: Date` → เปลี่ยนเป็น `startMinute: Int` / `endMinute: Int` แล้วไล่แก้ทุกจุดที่ parser เซ็ตค่า
- `PrototypeApp/Features/Onboarding/ScheduleSetupView.swift`
  - จุดที่แสดงเวลา (~บรรทัด 180) และ `ManualScheduleEntrySheet` (DatePicker → แปลงเป็นนาทีก่อนส่งออก)
  - `ManualScheduleEntrySheet` รอบนี้ **ยังไม่ต้องเพิ่มฟิลด์ใหม่** (คาบ/ครู/ห้อง) แค่ให้คอมไพล์ผ่านพอ · `periodNumber` ใส่ 0 ไปก่อน
  - **Picker "วัน" เปลี่ยนจาก `1...7` เป็น `ScheduleConstants.visibleDays`** (จันทร์–ศุกร์)
  - **`saveAndContinue()` ต้องสร้าง Subject อัตโนมัติ** — วนทุก draft แล้วเรียก `ScheduleConstants.findOrCreateSubject(named:in:)` ผูกเข้า `entry.subject` ก่อน insert (ชื่อซ้ำต้องได้ Subject ตัวเดิม ไม่สร้างซ้ำ)
  - log ตอนจบ: `AppLog.action("Onboarding", "บันทึกตาราง N คาบ · สร้างวิชาใหม่ M รายการ")`
- `PrototypeApp/Features/Onboarding/SetupSummaryView.swift` — อ่านแค่ `.subjectName` กับ `.count` **น่าจะไม่ต้องแก้** แต่ verify ด้วย

### 10. อัปเดต `PROJECT_MAP.md`

แก้ §2 (ไฟล์ใหม่), §3 (ตาราง @Model — เพิ่ม Subject, DayScheduleOverride, ลบหมายเหตุ "ไม่มี Subject model แล้ว"), §5 (design tokens ใหม่)

---

## กฎที่ต้องทำตาม

1. **ห้ามบอกว่า build ผ่าน** — คุณคอมไพล์ไม่ได้ ถ้าจะรัน `xcodebuild` ให้ลองจริงและรายงานผลจริงเท่านั้น
2. **ห้ามแตะ `.pbxproj`** — โปรเจกต์ใช้ file-system-synchronized groups ไฟล์ใหม่เข้า target เอง
3. **ห้าม hardcode สี/ระยะห่าง** — ต้องมาจาก `Theme` เท่านั้น
4. **ห้ามเพิ่ม SPM package** — โปรเจกต์นี้ไม่มี dependency ภายนอกเลย
5. Deployment target = iOS 26.5 → **ไม่ต้องเขียน `if #available`**
6. UI ข้อความทั้งหมดเป็นภาษาไทย คอมเมนต์โค้ดเป็นอังกฤษได้
7. **ยังไม่ต้อง commit** — รอผมยืนยันว่า build ผ่านก่อน ถ้าจะ commit ให้ขึ้นต้น `wip:`
8. ก่อนแก้ signature ของอะไรก็ตาม → grep หาที่เรียกใช้ให้ครบก่อน แล้วบอกผมว่ากระทบไฟล์ไหนบ้าง

## ปิดท้ายด้วยบล็อกนี้เสมอ

```
เช็คแล้ว:
- <สิ่งที่ verify ได้จริง เช่น grep ยืนยันว่า...>

ยังไม่ได้เช็ค:
- <ข้อที่ยังไม่ได้ verify>

รบกวน Few:
1. ลบแอปออกจาก simulator ก่อน (schema เปลี่ยน — ไม่ลบจะ crash)
2. กด ⌘B — ถ้าแดง copy error ทั้งก้อนจาก Issue Navigator มาวาง
3. ถ้าเขียว รันแอป → เปิด console ดูว่ามี `🔵 [Subject] seed วิชาเริ่มต้น 3 รายการ` ไหม
4. เดิน onboarding: หน้าตารางเรียน → กรอกคาบเอง 2 คาบ (ชื่อวิชาซ้ำกัน 1 คู่) → console ต้องขึ้น `สร้างวิชาอัตโนมัติ` แค่ครั้งเดียว
5. เข้า Settings → กดล้างข้อมูลทั้งหมด → เช็คว่าไม่ crash และวิชาเริ่มต้น 3 ตัวกลับมา
```
