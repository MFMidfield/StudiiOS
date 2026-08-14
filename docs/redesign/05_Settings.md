# 05 · Settings — หน้าตั้งค่า

> โมดูล `PrototypeApp/Features/Settings/` (3 ไฟล์ · 1,041 บรรทัด)
> `SettingsView.swift` ไฟล์เดียว 588 บรรทัด บรรจุ 4 struct
> ⚠️ **ทำโมดูลนี้หลัง `04_GradeCenter` เสร็จเท่านั้น** — ไม่งั้นจะมีช่วงที่แอปไม่มีที่ตั้งเป้า GPAX เลย

---

## 1. สภาพปัจจุบัน

```
List
├── (ไม่มีหัวข้อ)  การ์ดโปรไฟล์ + ปุ่มแก้ไข
├── (ไม่มีหัวข้อ)  ดูหน้าแนะนำแอป · เปิดหน้า Setup (ทดสอบ) · ตั้งค่าใหม่อีกครั้ง ⚠️ลบข้อมูลทั้งหมด
├── สถานะสมาชิก    Toggle Pro (เครื่องมือ dev)
├── การแจ้งเตือน    สถานะสิทธิ์ · ทดสอบ 5 วิ · การแจ้งเตือนที่ตั้งไว้
├── ตารางเรียน      เทอมปัจจุบัน → TermManagementView · Toggle งานส่วนตัว
├── ระดับชั้นและเป้า GPAX   6 รายการ
├── เกี่ยวกับ        เวอร์ชัน · โหมด
├── หลักการออกแบบ   Offline-first · Privacy-first · Thai-first (กดไม่ได้)
└── #if DEBUG สำหรับนักพัฒนา → OCRDebugView
```

## 2. ปัญหา

| # | ปัญหา | ระดับ |
|---|---|---|
| 1 | **ปุ่มลบข้อมูลทั้งหมดอยู่อันดับ 3 จากบนสุด** ห่างจาก "ดูหน้าแนะนำแอป" 2 บรรทัด และชื่อปุ่มคือ "ตั้งค่าใหม่อีกครั้ง (Setup ใหม่)" ซึ่ง**ไม่บอกว่าลบ** | **เสี่ยงกับเดโม่** |
| 2 | เครื่องมือ dev 3 ตัวโผล่ใน Release — "เปิดหน้า Setup (ทดสอบ)" · "ทดสอบแจ้งเตือน (5 วินาที)" · Toggle Pro (มีคำอธิบายเขียนเองว่าใช้ทดสอบ) | สูง |
| 3 | Toggle "แสดงงานส่วนตัวในตารางเรียน" กลายเป็นสวิตช์ตาย (จาก `02_Schedule` ลบการ์ดงาน) | สูง |
| 4 | section เป้า GPAX ซ้ำกับหน้าเกรด (จาก `04_GradeCenter`) | สูง |
| 5 | `resetAllData()` ไม่ล้าง GPAX UserDefaults → กดลบข้อมูลแล้ว "ระดับชั้น ม.5 เทอม 1" กับเป้ายังค้าง | กลาง |
| 6 | "หลักการออกแบบ" 3 บรรทัด กดไม่ได้ ไม่มีข้อมูลเพิ่ม | ต่ำ |
| 7 | ไฟล์เดียว 588 บรรทัด 4 struct | ต่ำ |
| 8 | **แจ้งเตือนงานมีค่าเริ่มต้นปิด** (`Assignment.remindersEnabled = false`) → นักเรียนเพิ่มการบ้าน 10 ชิ้นแล้วไม่ได้รับเตือนสักชิ้น ฟีเจอร์แจ้งเตือนที่เขียนไว้ครบ (3 จุด · ยกเลิกอัตโนมัติตอนติ๊กเสร็จ) แทบไม่เคยถูกใช้ และไม่มีที่ไหนบอกว่าเปิดแล้วจะเตือนตอนไหน | สูง |

---

## 3. ตัด / เก็บ / ย้าย / เพิ่ม

### ✂️ ตัดทิ้ง

| ตัด | เหตุผล |
|---|---|
| section "หลักการออกแบบ" | กดไม่ได้ ไม่มีข้อมูลเพิ่ม — เป็นการโฆษณาตัวเองในหน้าตั้งค่า |
| Toggle "แสดงงานส่วนตัวในตารางเรียน" + คำอธิบายใต้ | สวิตช์ตาย (§2 ข้อ 3) · **`@AppStorage("scheduleShowsPersonalTasks")` ลบทิ้งได้เลย** ตรวจแล้วไม่มีที่อื่นใช้ |
| section "ระดับชั้นและเป้า GPAX" — เฉพาะส่วนเป้า | `เป้า GPAX` TextField · `gpaxTargetSource` TextField · ย้ายไป `GPAXTargetSheet` แล้ว |
| `LabeledContent("โหมด", value: "Offline-first")` | ซ้ำกับ section ที่ตัดไป |

### ✅ เก็บไว้

- `resetAllData()` — logic การลบ **ห้ามแตะ** (มี 24 `deleteAll` + `PortfolioImageStore` + `PomodoroEngine.stop` + `AppBlockManager.stopBlocking` ครบแล้ว) แค่ย้ายที่ปุ่มกับเพิ่มการล้าง GPAX
- ปุ่ม **"ขึ้นชั้นแล้ว"** — `04_GradeCenter.md` อ้างถึงในบรรทัดอธิบายท้ายลิสต์ **ห้ามลบหรือเปลี่ยนชื่อ**
- `advanceToNextTerm()` · `canAdvanceTerm` — เขียนผ่าน `GPAXSettings.setCurrentTerm` เท่านั้น ถูกแล้ว
- ping pattern `@AppStorage(GPAXSettings.Key.currentGradeLevel/currentTermNumber)` — **ห้ามลบ** (เหตุผลเดียวกับ `04_GradeCenter` §7)
- `#if DEBUG` รอบ `developerSection` และคอมเมนต์ที่อธิบายว่าทำไมต้องแยกออกจาก `body`
- `PendingNotificationsView` · `EditProfileView` · `SetupFlowTestContainer` (แค่แยกไฟล์)

### ➡️ ย้ายที่

| ของ | จาก | ไป |
|---|---|---|
| ปุ่มลบข้อมูลทั้งหมด | อันดับ 3 จากบนสุด | **ล่างสุดใน `#if DEBUG`** + เปลี่ยนชื่อเป็น `"ลบข้อมูลทั้งหมดถาวร"` |
| "เปิดหน้า Setup (ทดสอบ)" | section ที่ 2 | `#if DEBUG` |
| "ทดสอบแจ้งเตือน (5 วินาที)" + คำอธิบาย | section การแจ้งเตือน | `#if DEBUG` |
| Toggle Pro + คำอธิบาย | section "สถานะสมาชิก" | `#if DEBUG` (ชื่อใหม่: `"เปิด Pro"`) |
| "ดูหน้าแนะนำแอปอีกครั้ง" | section ที่ 2 | section "เกี่ยวกับแอป" |
| "เทอมปัจจุบัน → TermManagementView" | section "ตารางเรียน" | section "การเรียน" (ชื่อแถวใหม่: `"จัดการเทอม"`) |

### ➕ เพิ่ม

| เพิ่ม | รายละเอียด |
|---|---|
| **ธีม** | Picker 3 ตัวเลือก: อัตโนมัติ / สว่าง / มืด · §4.2 |
| **สวิตช์ค่าเริ่มต้นการเตือนงาน** | §4.3 — **ไม่แตะ `NotificationManager` เลย** |
| **โปรไฟล์: โรงเรียน · ห้อง · แผนการเรียน** | §4.4 |
| **ลิงก์ไปหน้าโหมดโฟกัส** | `NavigationLink` บรรทัดเดียวใน section "การเรียน" — ตั้งค่า Pomodoro ยังอยู่ที่หน้าโฟกัสเหมือนเดิม ไม่ย้าย |
| **ป้ายแผน Pro** | แถว read-only ใน "เกี่ยวกับแอป" แสดง `TierBadge` — ตอนเดโม่จะขึ้น Pro |

---

## 4. โครงใหม่

```
การ์ดโปรไฟล์          รูป + ชื่อ + "ธน · ม.5 เทอม 1" + chevron → EditProfileView

การเรียน
  ระดับชั้นปัจจุบัน        ม.5 เทอม 1  ›     → GradeLevelSheet
  ขึ้นชั้นแล้ว → ม.5 เทอม 2                  (ซ่อนเมื่อถึง ม.6 เทอม 2)
  วิธีกรอกเทอมที่ผ่านมา     ทีละเทอม  ›
  [ถ้า cumulative] GPAX สะสมที่กรอกไว้ · ปุ่มกรอก
  จัดการเทอม              3 เทอม  ›        → TermManagementView
  โหมดโฟกัส                        ›        → FocusModeView

การแจ้งเตือน
  สถานะสิทธิ์              อนุญาตแล้ว
  [ถ้ายังไม่ขอ/ถูกปิด] ปุ่มขอสิทธิ์ / เปิดตั้งค่าเครื่อง
  เตือนงานใหม่อัตโนมัติ     [Toggle]
  ↳ คำอธิบาย 3 จุด
  การแจ้งเตือนที่ตั้งไว้     12 รายการ  ›

การแสดงผล
  ธีม                     อัตโนมัติ  ›

เกี่ยวกับแอป
  ดูหน้าแนะนำแอปอีกครั้ง            ›
  เวอร์ชัน                 1.0.0 (Prototype)
  แผน                     [Pro]

#if DEBUG · สำหรับนักพัฒนา · ไม่ขึ้นในเวอร์ชันจริง
  เปิด Pro                 [Toggle]
  เปิดหน้า Setup อีกครั้ง
  ทดสอบแจ้งเตือน (5 วินาที)
  ทดสอบ OCR                        ›
  ลบข้อมูลทั้งหมดถาวร               ← destructive ล่างสุด
```

### 4.1 การ์ดโปรไฟล์

- ทั้งใบเป็น `NavigationLink` ไป `EditProfileView` (เดิมเป็นปุ่ม "แก้ไข" เล็กๆ ทางขวา)
- รูปวงกลม 46 · ถ้าไม่มีรูปใช้อักษรย่อจากชื่อเล่นบนพื้น `primarySoft` (เดิมเป็นไอคอน `person.fill` สีเทา)
- บรรทัดรอง: `"<ชื่อเล่น> · <ระดับชั้นจริง>"` — ถ้าไม่มีชื่อเล่นใช้ชื่อจริง

### 4.2 ธีม

```swift
enum AppTheme: String, CaseIterable { case system, light, dark }
@AppStorage("appTheme") private var appTheme: AppTheme = .system
```

- Picker `.menu` ในหน้า Settings
- **จุดที่ใช้จริง:** `RootContainerView` ใน `App/PrototypeAppApp.swift` ใส่ `.preferredColorScheme(...)`
  `system → nil` · `light → .light` · `dark → .dark`
- ⚠️ `PrototypeAppApp.swift` เป็นไฟล์ที่มี `Schema([...])` อยู่ — **แตะเฉพาะบรรทัด `.preferredColorScheme` เท่านั้น ห้ามแตะ Schema**
- ประกาศ `enum AppTheme` ไว้ใน `Core/DesignSystem/` (ไฟล์ใหม่ `AppTheme.swift` ~20 บรรทัด) ไม่ใช่ใน `SettingsView`

### 4.3 เตือนงานใหม่อัตโนมัติ — ไม่แตะ `NotificationManager`

**ปัญหาจริง:** `Assignment.remindersEnabled` มีค่าเริ่มต้น `false` → เพิ่มงานแล้วไม่มีเตือน เว้นแต่ผู้ใช้จะสังเกตเห็น Toggle ในฟอร์ม

**วิธีแก้ที่เสี่ยงเกือบศูนย์:**

```swift
// Settings
@AppStorage("assignmentRemindersDefaultOn") private var remindersDefaultOn = true

// AddTaskSheet.init — บรรทัดเดียว
_remindersEnabled = State(initialValue:
    editing?.remindersEnabled
    ?? UserDefaults.standard.bool(forKey: "assignmentRemindersDefaultOn"))
```

- ⚠️ `UserDefaults.bool(forKey:)` คืน `false` ถ้ายังไม่เคยเขียน → ต้อง `UserDefaults.standard.register(defaults: ["assignmentRemindersDefaultOn": true])` ใน `PrototypeAppApp` init **หรือ** ใช้ `object(forKey:) as? Bool ?? true`
- ใต้ Toggle มีคำอธิบายว่าเปิดแล้วเตือนตอนไหน — **ข้อความต้องตรงกับโค้ดจริงใน `NotificationManager` slot `.d1`/`.am`/`.h1`:**
  > `"เปิดไว้ = งานใหม่ที่มีกำหนดส่งจะเตือน 3 ครั้ง — 1 วันก่อน · 07:00 ของวันกำหนด · 1 ชั่วโมงก่อน (ปรับรายชิ้นได้ในฟอร์มเพิ่มงาน)"`
- **ห้ามแก้ `Core/Notifications/NotificationManager.swift`** ในสเปคนี้
- ⚠️ `AddTaskSheet.swift` **เป็นไฟล์ของ agent โมดูล Tasks** — ให้ agent Tasks แก้บรรทัดนั้น ไม่ใช่ agent Settings

### 4.4 โปรไฟล์เพิ่ม 3 ฟิลด์

`StudentProfileStore` เป็น UserDefaults-based **ไม่ใช่ `@Model`** → เพิ่มฟิลด์ไม่กระทบ SwiftData schema ไม่เสี่ยง crash

```swift
private let schoolKey  = "com.studentos.profile.school"
private let roomKey    = "com.studentos.profile.room"
private let programKey = "com.studentos.profile.program"
```

- `school` — TextField ธรรมดา
- `room` — TextField ธรรมดา (เช่น "5/2")
- `program` — TextField ธรรมดา (เช่น "วิทย์-คณิต") **ไม่ทำเป็น Picker** เพราะแผนการเรียนไทยมีหลากหลายเกินกว่าจะ hardcode รายการ
- ทั้ง 3 ฟิลด์**ไม่บังคับกรอก** และไม่มี logic ไหนอ่าน — เป็นข้อมูลแสดงผลล้วน
- เพิ่มใน `EditProfileView` และใน `reset()` ของ store

### 4.5 `resetAllData()` — ล้าง GPAX ด้วย

ต่อท้ายฟังก์ชันเดิม (ห้ามแตะ 24 บรรทัด `deleteAll` ที่มีอยู่):

```swift
GPAXSettings.resetAll()              // ← ต้องเขียนเมธอดนี้ขึ้นมาใหม่ก่อน (ดูด้านล่าง)
StudentProfileStore.shared.reset()   // มีอยู่แล้ว
```

> ✅ **ตรวจกับโค้ดจริงแล้ว (13 ส.ค. 2569): `GPAXSettings` ยังไม่มี `resetAll()`**
> มีแต่ `setCurrentTerm` · `setTarget` · `setEntryMode` · `setCumulative` — ทั้งหมดเป็น setter ไม่ใช่ตัวล้าง

**ต้องเพิ่มเมธอดใหม่ใน `Core/Grades/GPAXSettings.swift`:**

```swift
/// ล้างค่า GPAX ทั้งหมด — ใช้โดย SettingsView.resetAllData() เท่านั้น
static func resetAll() {
    for key in [Key.currentGradeLevel, Key.currentTermNumber, Key.target,
                Key.targetSource, Key.entryMode, Key.priorGPAX,
                Key.priorCredits, Key.priorTermCount] {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
```

⚠️ **นี่คือการแตะ `Core/Grades/` ซึ่งปกติห้าม — อนุญาตเฉพาะครั้งนี้เพราะเป็นการ *เพิ่มเมธอดใหม่* ไม่ได้แก้ของเดิมสักบรรทัด**
เหตุผลที่ต้องอยู่ในไฟล์นั้น: `GPAXSettings` เป็น**จุดเดียวที่รู้จัก UserDefaults key ของ GPAX** ถ้าไปเขียน `UserDefaults.standard.removeObject` ตรงๆ ใน `SettingsView` จะมีสองที่ที่รู้จัก key แล้วเพี้ยนกันตอนเพิ่ม key ใหม่
⚠️ ให้ไล่ `Key` ทุกตัวที่มีจริงในไฟล์ ณ ตอนเขียน — **ห้ามลอกรายการข้างบนมาแปะโดยไม่เช็ค** ถ้ามี key เพิ่มมาภายหลังจะล้างไม่ครบแบบเงียบๆ

**ไม่ล้าง:** `PomodoroSettings` · `appTheme` · `assignmentRemindersDefaultOn` — สามตัวนี้เป็น preference ของเครื่อง ไม่ใช่ข้อมูลนักเรียน (ตรงกับ convention เดิม)

### 4.6 แยกไฟล์

| ไฟล์ใหม่ | ย้ายอะไรไป |
|---|---|
| `Features/Settings/EditProfileView.swift` | `EditProfileView` (บรรทัด 382–503) + 3 ฟิลด์ใหม่ |
| `Features/Settings/PendingNotificationsView.swift` | `PendingNotificationsView` (บรรทัด 553–588) |
| `Features/Settings/SetupFlowTestContainer.swift` | `SetupFlowTestContainer` (บรรทัด 509–550) — ครอบ `#if DEBUG` ทั้งไฟล์ |

เหลือ `SettingsView.swift` ~250 บรรทัด

---

## 5. ไฟล์ที่แตะ

| ไฟล์ | ทำอะไร |
|---|---|
| `Features/Settings/SettingsView.swift` | จัดกลุ่มใหม่ทั้งหน้า · ย้าย dev tools · ตัด 3 อย่าง · เพิ่ม 4 อย่าง · แยก 3 struct ออก |
| `Features/Settings/EditProfileView.swift` | **ไฟล์ใหม่** (ย้ายมา) + 3 ฟิลด์ |
| `Features/Settings/PendingNotificationsView.swift` | **ไฟล์ใหม่** (ย้ายมา) |
| `Features/Settings/SetupFlowTestContainer.swift` | **ไฟล์ใหม่** (ย้ายมา, `#if DEBUG`) |
| `Features/Settings/TermManagementView.swift` | **ทาสีอย่างเดียว** |
| `Features/Settings/OCRDebugView.swift` | **ไม่แตะ** — เป็น dev tool ล้วน |
| `Core/Profile/StudentProfileStore.swift` | เพิ่ม 3 key + ล้างใน `reset()` |
| `Core/DesignSystem/AppTheme.swift` | **ไฟล์ใหม่** ~20 บรรทัด |
| `App/PrototypeAppApp.swift` | **เฉพาะบรรทัด `.preferredColorScheme`** — ห้ามแตะ `Schema` |

**ไฟล์ที่ agent อื่นเป็นเจ้าของ — ห้ามแตะ:**
`AddTaskSheet.swift` (agent Tasks — §4.3) · `RootTabView.swift` (agent Tasks) · `Core/Notifications/NotificationManager.swift` (ห้ามทุกคน)

---

## 6. ความเสี่ยง

| เสี่ยง | กัน |
|---|---|
| ลบ section เป้า GPAX ก่อน `GPAXTargetSheet` เสร็จ → ไม่มีที่ตั้งเป้าเลย | **ทำโมดูลนี้หลัง `04_GradeCenter` เท่านั้น** |
| ลบ ping `@AppStorage` เพราะดูเหมือนไม่ได้ใช้ | มีคอมเมนต์เตือนในไฟล์ — ห้ามลบ |
| แตะ `Schema([...])` ตอนแก้ `PrototypeAppApp.swift` | แตะได้บรรทัดเดียวคือ `.preferredColorScheme` |
| `resetAllData` เขียน UserDefaults ตรงๆ แทนที่จะผ่าน `GPAXSettings` | §4.5 — ถ้าไม่มี `resetAll()` ให้หยุดถาม |
| ย้าย 3 struct ออกแล้วมี `private` ที่เข้าไม่ถึงกัน | ทั้ง 3 ตัวเป็น `private struct` → ต้องเปลี่ยนเป็น `struct` ธรรมดา (internal) ตอนแยกไฟล์ |
| `UserDefaults.bool` คืน false เมื่อยังไม่เคยเขียน → สวิตช์เตือนงานดูเหมือนปิดทั้งที่ควรเปิด | §4.3 — ใช้ `register(defaults:)` หรือ `object(forKey:) as? Bool ?? true` |

---

## 7. เกณฑ์เสร็จ

เข้าแท็บตั้งค่า:

1. **ไม่มีปุ่มลบข้อมูลใน 3 บรรทัดแรกแล้ว** — อยู่ล่างสุดในกล่อง "สำหรับนักพัฒนา" ชื่อ "ลบข้อมูลทั้งหมดถาวร"
2. Toggle Pro · เปิดหน้า Setup · ทดสอบแจ้งเตือน ทั้งสามอยู่ในกล่อง dev เดียวกัน
3. ไม่มี Toggle "แสดงงานส่วนตัวในตารางเรียน" และไม่มี section "หลักการออกแบบ" แล้ว
4. ไม่มีช่องตั้งเป้า GPAX ในหน้านี้ — ตั้งได้ที่หน้าเกรดที่เดียว
5. **เปลี่ยนธีมเป็น "มืด" → ทั้งแอปเป็นมืดทันทีแม้ระบบตั้งเป็นสว่าง** · ปิดแอปเปิดใหม่ค่ายังอยู่
6. กดการ์ดโปรไฟล์ → แก้ไขได้ · กรอกโรงเรียน/ห้อง/แผนการเรียนแล้วกลับมาเห็นบนการ์ด
7. เปิด "เตือนงานใหม่อัตโนมัติ" → ไปเพิ่มงานใหม่ **Toggle แจ้งเตือนในฟอร์มติ๊กมาให้แล้ว** · ปิดสวิตช์นี้แล้วเพิ่มงานใหม่ → Toggle ไม่ติ๊ก
8. กด "ลบข้อมูลทั้งหมดถาวร" → ยืนยัน → กลับหน้า Welcome และ **"ระดับชั้นปัจจุบัน" ต้องกลายเป็น "ยังไม่ได้ตั้ง"** (ไม่ค้างเหมือนเดิม)
9. ปุ่ม "ขึ้นชั้นแล้ว" ยังอยู่และยังใช้ได้ (หน้าเกรดอ้างถึงปุ่มนี้)
10. สลับ dark mode แล้วทุกแถวยังอ่านออก
