# 03 · QuickAdd — เมนู "เพิ่มอะไรดี?"

> โมดูล `StudiiOS/Features/QuickAdd/` (ไฟล์เดียว 338 บรรทัด)
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
| ~~กริด 3 คอลัมน์ → 2×2~~ | 🔴 **ล้ม (Few 14 ส.ค.)** — เหลือ 3 ทาง กริด **1×3** คงคอลัมน์เดิมไว้ ดู §4 |

⚠️ **ห้ามลบ `Note` model และห้ามแตะ `Schema([...])` ใน `StudiiOSApp.swift`**
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
| ~~การเปิดฟอร์ม~~ | ~~sheet ซ้อน sheet~~ | 🔴 **ล้ม (Few 14 ส.ค.) — คง sheet ซ้อน sheet ไว้** ดู §5 |

---

## 4. เมนูใหม่ — 3 ทาง กริด 1×3 ✅ ทำแล้ว

> 🔴 **ของเดิมคือ 4 ทาง กริด 2×2 (มี "คาบเรียน") — Few สั่งใหม่ 14 ส.ค. ให้เหลือ 3 ทาง**
> "คาบเรียน" ไม่เข้าเมนูนี้: การเพิ่มคาบเป็นงานตั้งค่าตารางทั้งเทอม ไม่ใช่ของที่จด "ตอนนี้เดี๋ยวนี้" เหมือนอีก 3 อย่าง
> → `AddScheduleEntrySheet` **ไม่ถูกเรียกจาก QuickAdd แล้ว** และ `ScheduleConstants.defaultEntryDay` ที่เตรียมไว้ยังไม่มีใครเรียก (ยกให้ `02_Schedule`)

| ทาง | เปิดอะไร | สี tile |
|---|---|---|
| งาน | `AddTaskSheet(onSaved:)` | `Theme.Colors.primary` |
| กิจกรรมปฏิทิน | `EventFormSheet(initialDate: .now, onSaved:)` | `subjectPalette[3]` (น้ำเงินหม่น) |
| ผลงาน | `PortfolioItemSheet(mode: .create, onSaved:)` | `subjectPalette[4]` (ม่วงหม่น) |

⚠️ **ห้ามใช้ `danger` / `warning` / `success` เป็นสีตกแต่ง** — สามตัวนี้มีความหมายในระบบ (อันตราย · เตือน · สำเร็จ) เอามาใช้เป็นสีไอคอนเมนูทำให้ความหมายเจือจาง

tile: `IconTile(systemName:size: 64, color:, cornerRadius: Theme.Radius.card)` + ป้ายชื่อใต้ · ทั้งใบใช้ `PressScaleButtonStyle`
กริดยังเป็น `GridItem(.flexible())` 3 คอลัมน์ → 3 ตัวเลือกลงแถวเดียวพอดี ไม่มีช่องโหว่แบบเดิม

---

## 5. sheet ซ้อน sheet — โครงที่ `QuickAddSheet` ถือเอง ✅ ทำแล้ว

> 🔴 **ของเดิม ("sheet ชั้นเดียวที่ `RootTabView` ถือ" · `QuickAddTarget` · `QuickAddFlow`) ถูกล้มทั้งข้อ (Few 14 ส.ค.)**
> `RootTabView` เหลือแค่ `.sheet(isPresented: $showCapture) { QuickAddSheet() }` และ **ห้ามแตะจนถึง W3**
> ทุกอย่างในข้อนี้อยู่ใน `QuickAddSheet.swift` ไฟล์เดียว

```swift
@State private var activeForm: QuickAddForm?   // .task / .event / .portfolio
@State private var didSave = false

.presentationDetents([.medium])
.sheet(item: $activeForm, onDismiss: closeIfSaved) { form in formView(for: form) }
```

**กติกาการปิด** — ต่างกันตามว่าผู้ใช้บันทึกหรือยกเลิก:

| ผู้ใช้กด | เกิดอะไร |
|---|---|
| **บันทึก** | ฟอร์มเรียก `onSaved` → ตั้ง `didSave = true` แล้วปิดตัวเอง → `onDismiss` เห็นธง → ปิดเมนูตาม = **ออกจบทั้งสองชั้น** |
| **ยกเลิก** | ปิดแค่ฟอร์ม **กลับมาที่เมนู** — เผลอกดผิดทางแล้วเลือกใหม่ได้ ไม่ต้องเปิดใหม่ทั้งชุด |

⚠️ การปิดสองชั้นต้องผ่าน `onDismiss` เท่านั้น — สั่ง `dismiss()` ทั้งสองชั้นใน update เดียวกันคือ dismissal สองตัวแย่งกัน sheet จะค้าง

⚠️ **`onSaved:` ของ `EventFormSheet` / `PortfolioItemSheet` / `AddTaskSheet` ห้ามลบ** (เป็น optional มี default `nil` · call site เดิมไม่กระทบ)
ลบเมื่อไร = บันทึกแล้วเมนูค้างค้างอยู่หลังฟอร์มทันที

detent: เมนูเป็น `.medium` · ฟอร์มลูกใช้ detent ของตัวเอง (เต็มจอ) — ไม่มีการเปลี่ยน detent กลางคัน ปัญหาเดิมจึงไม่เกิด

---

## 6. ไฟล์ที่แตะ

| ไฟล์ | ทำอะไร | สถานะ |
|---|---|---|
| `Features/QuickAdd/QuickAddSheet.swift` | ลบ `CaptureDetailSheet` + 3 enum + extension · เหลือ 3 ตัวเลือก · `QuickAddForm` + ธง `didSave` (§5) | ✅ 338 → **124 บรรทัด** |
| `App/RootTabView.swift` | ~~sheet ชั้นเดียว~~ ยกเลิก — **ไม่แตะ** | — |
| `Features/Calendar/EventFormSheet.swift` | เติม `onSaved: (() -> Void)? = nil` ใน `init` ทั้ง 2 ตัว | ✅ |
| `Features/Portfolio/PortfolioItemSheet.swift` | เติม `onSaved: (() -> Void)? = nil` ใน `init(mode:)` | ✅ |

ไฟล์ที่**ไม่แตะ**แต่ถูกเรียกใช้: `AddTaskSheet.swift` (W1 เติม `onSaved` ไปแล้ว)
→ ห้ามแก้ signature เดิมของฟอร์มเหล่านี้ · `AddScheduleEntrySheet` ไม่ถูกเรียกจากโมดูลนี้แล้ว

---

## 7. ความเสี่ยง

| เสี่ยง | กัน |
|---|---|
| ลบ `Note` model แล้วแอป crash ตอนเปิด | **ไม่ลบ model** ตัดแค่ทางสร้างใน UI |
| `EventFormSheet(initialDate:)` signature ไม่ตรง | ✅ ตรวจแล้ว — มีจริง ใช้อยู่ที่ `CalendarView.swift:232` |
| `PortfolioItemSheet(mode: .create)` signature ไม่ตรง | ✅ ตรวจแล้ว — มีจริง ใช้อยู่ที่ `PortfolioView.swift:34` |
| ~~`defaultDay` เป็นเสาร์/อาทิตย์~~ | ✅ ไม่เกี่ยวแล้ว — ตัด "คาบเรียน" ออกจากเมนู (§4) |
| ~~agent 2 ตัวแก้ `RootTabView.swift` ชนกัน~~ | ✅ ไม่เกี่ยวแล้ว — โมดูลนี้ไม่แตะ `RootTabView` (§5) |
| ~~เปลี่ยน detent กลางคันแล้ว sheet เด้ง~~ | ✅ ไม่เกี่ยวแล้ว — sheet ซ้อน sheet ต่างคนต่างถือ detent ของตัวเอง |
| **บันทึกแล้วเมนูค้าง** (sheet ซ้อน sheet) | ปิดชั้นนอกใน `onDismiss` ไม่ใช่ใน update เดียวกับชั้นใน (§5) |

---

## 8. เกณฑ์เสร็จ

อยู่หน้าแรก กดปุ่ม `+` กลางแถบล่าง:

1. เมนูเด้งขึ้นครึ่งจอ มี **3 ช่องเรียงแถวเดียว** ไม่มี "โน๊ต" และไม่มี "คาบเรียน" แล้ว
2. กด "กิจกรรมปฏิทิน" → ฟอร์มปฏิทินตัวจริงขึ้นมาทับเมนู (มีช่องชื่อกิจกรรม · เลือก tag ได้ · เลือกสีได้)
3. กด **"ยกเลิก" ในฟอร์ม → กลับมาที่เมนู** เลือกทางอื่นต่อได้ทันที
4. กด "ปิด" บนเมนู → ออกกลับหน้าแรก
5. กด "ผลงาน" → ฟอร์มพอร์ตตัวจริง **เพิ่มรูปได้**
6. **บันทึกกิจกรรมปฏิทิน → ปิดหมดทั้งสองชั้นรวดเดียว** ไม่มีเมนูค้าง · ไปเปิดหน้าปฏิทินเห็นกิจกรรมนั้นจริง
7. ไม่มีช่องไหนในเมนู/ฟอร์มที่เลือกแล้วค่าหาย
8. อยู่แท็บงานแล้วกด `+` กลางแถบล่าง → **ได้เมนูเดียวกันนี้** (ทางลัดเพิ่มงานอยู่ที่ปุ่ม `+` ขวาบนแทน — `01_Tasks.md` §4.4)
