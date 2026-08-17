# Prompt: สร้างหน้า "ตารางเรียน" (แท็บปฏิทิน) + ระบบเพิ่มวิชาเอง

> คัดลอกทั้งหมดตั้งแต่บรรทัด `---` ด้านล่างไปวางให้ AI ได้เลย
> (แนบภาพ mockup ไปด้วยจะได้ผลดีที่สุด)

---

## บทบาท

คุณเป็น iOS engineer ที่ทำงานต่อยอดบนโปรเจกต์ **PrototypeApp** (Student OS) ซึ่งเป็นแอปนักเรียนไทย เขียนด้วย **SwiftUI + SwiftData**, offline-first, UI ภาษาไทยทั้งหมด

## สิ่งที่ต้องทำ

สร้างหน้า **"ตารางเรียน"** ในแท็บ *ปฏิทิน* (ตอนนี้ `CalendarView` เป็นหน้าว่าง) ให้ตรงตาม design ที่แนบมา พร้อม **ระบบให้ผู้ใช้เพิ่ม/แก้ไข/ลบวิชาเอง** โดยกรอก: คาบ, วัน, ชื่อวิชา, เวลาเริ่ม, เวลาสิ้นสุด, ชื่อครู, ห้องเรียน

---

## 1. บริบทโค้ดที่มีอยู่ — ต้องอ่านก่อนเริ่ม

| ไฟล์ | ใช้ทำอะไร |
|---|---|
| `Core/DesignSystem/Theme.swift` | design tokens: `Theme.Colors`, `Theme.Spacing`, `Theme.Radius`, `CardContainer` |
| `Core/Models/ScheduleEntry.swift` | โมเดลตารางเรียนเดิม (`dayOfWeek` 1=จันทร์…7=อาทิตย์, `startTime`, `endTime`, `kind`, `location`, `subjectName`) |
| `Core/Models/Assignment.swift` | การบ้าน (`title`, `detail`, `dueDate`, `isDone`, `priority`) |
| `Core/Extensions/Date+Thai.swift` | `DateFormatter.thaiShort` / `.time24h`, `Date.thaiShortString`, `Date.daysRemaining` |
| `Core/Extensions/Color+Hex.swift` | `Color(hex:)` |
| `App/PrototypeAppApp.swift` | `Schema([...])` — ต้องเพิ่มโมเดลใหม่ที่นี่ถ้ามี |
| `Features/Calendar/CalendarView.swift` | ปลายทางของงานนี้ (มี `CalendarEvent`/`CalendarTag` อยู่ อย่าลบ) |

**กฎ**

- ใช้ `Theme.*` เท่านั้น ห้าม hardcode สี/ระยะห่างใหม่ ถ้าต้องเพิ่มสีให้เพิ่มเข้า `Theme.Colors`
- ห้ามใช้ third-party library ใด ๆ (SwiftUI + SwiftData ล้วน)
- ข้อความ UI ทั้งหมดเป็นภาษาไทย, ชื่อ type/ตัวแปรเป็นภาษาอังกฤษ
- ทุกไฟล์ใหม่ใส่ header comment สั้น ๆ อธิบายหน้าที่ ตามสไตล์ไฟล์เดิมในโปรเจกต์
- แยกไฟล์ตามหน้าที่ อย่ายัดทุกอย่างไว้ใน `CalendarView.swift`

---

## 2. โครงสร้างข้อมูล

**เก็บเป็น template รายสัปดาห์ วนซ้ำทุกสัปดาห์** — เพิ่มวิชาครั้งเดียวแล้วโผล่ทุกสัปดาห์ ไม่ต้องสร้าง instance ต่อวันที่

ขยาย `ScheduleEntry` เดิม (อย่าสร้างโมเดลใหม่ซ้อน) โดยเพิ่ม property ที่มี default value ทุกตัว เพื่อให้ SwiftData ทำ lightweight migration ผ่าน:

```swift
var period: Int = 0          // เลขคาบ; 0 = ไม่มีคาบ (เช่น พักกลางวัน)
var teacherName: String = "" // "ครูณัฐวุฒิ อินทร์แก้ว"
var colorHex: String = "4A7DFF"
var sortOrder: Int = 0       // ลำดับแสดงผลภายในวัน (ค่าเริ่มต้น = period)
```

- เพิ่ม case `lunchBreak` ใน `ScheduleKind` → label `"พักกลางวัน"`, icon `"fork.knife"`
- `startTime` / `endTime` ใช้เฉพาะส่วนเวลา (ชั่วโมง:นาที) ส่วนวันที่ให้ normalize เป็นวันอ้างอิงเดียวกันเสมอ เขียน helper `ScheduleEntry.timeOnly(hour:minute:)` และ comment อธิบายไว้ให้ชัด
- เขียน computed helper: `timeRangeText` → `"08:00 – 08:50"`, `durationMinutes`

**Query layer** — สร้าง `ScheduleStore` (หรือ view model) ที่มี:

```
entries(for dayOfWeek: Int) -> [ScheduleEntry]   // เรียงตาม startTime
assignments(dueOn date: Date) -> [Assignment]
hasConflict(with entry:, excluding:) -> Bool     // ตรวจเวลาทับซ้อนในวันเดียวกัน
nextSuggestedPeriodAndTime(for dayOfWeek:) -> (period: Int, start: Date, end: Date)
```

---

## 3. หน้าจอที่ต้องสร้าง

### 3.1 `ScheduleCalendarView` — หน้าหลัก (แทนที่เนื้อหาใน `CalendarView`)

เรียงจากบนลงล่าง:

**A. Navigation bar**

- Title กลาง: `"ตารางเรียน"` (semibold, `.inline`)
- ซ้าย: ปุ่ม back (`chevron.left`) ในวงกลมขอบบาง
- ขวา 3 ปุ่มวงกลม: `list.bullet` (สลับมุมมองรายการ), `line.3.horizontal.decrease` (ตัวกรอง), `ellipsis` (เมนู)
  - ปุ่ม `ellipsis` เปิด menu: `แก้ไขตารางเรียน`, `เพิ่มวิชา`, `ล้างตารางทั้งหมด` (มี confirmation)
  - ตัวกรอง: filter ตามวิชา / แสดงเฉพาะคาบที่มีการบ้าน (ถ้าซับซ้อนเกิน ให้ทำเป็น sheet เปล่าไว้ก่อนแต่ปุ่มต้องกดได้)

**B. Segmented control** — `รายสัปดาห์` / `รายวัน`

- capsule พื้น `Theme.Colors.background`, pill ที่เลือกเป็นสีขาว + เงาอ่อน, ตัวอักษรที่เลือกสี `Theme.Colors.primary`
- ใช้ custom view ไม่ใช้ `.segmented` picker ของระบบ (สไตล์ไม่ตรง)

**C. Week navigator**

- `chevron.left` / `chevron.right` เลื่อนทีละสัปดาห์
- กลาง: ช่วงวันที่ + ปี พ.ศ. เช่น `"28 ก.ค. – 3 ส.ค. 2569"` พร้อม `chevron.down` (กดแล้วเปิด date picker ให้กระโดดไปสัปดาห์อื่น) — ใช้ `Calendar(identifier: .buddhist)` + `Locale("th_TH")`
- แถวชื่อวัน: `จันทร์ อังคาร พุธ พฤหัส ศุกร์ เสาร์ อาทิตย์` + ตัวเลขวันที่ใต้ชื่อ
  - วันที่เลือก: ตัวเลขอยู่ในวงกลมทึบ `Theme.Colors.primary` ตัวอักษรขาว
  - วันอาทิตย์: ชื่อวันและเลขเป็นสีแดง (`Theme.Colors.danger`)
  - วันนี้ (ถ้าไม่ได้เลือก): เลขเป็นสี primary ตัวหนา
  - แตะเลือกวันได้, ปัดซ้าย/ขวาบนพื้นที่ตารางเพื่อเปลี่ยนวัน

**D. การ์ดตารางเรียน (โหมดรายวัน)**

Header ของการ์ด 3 คอลัมน์: `คาบ` | `เวลา` | (กลาง) `วันนี้ • จันทร์ 28 ก.ค.` สี primary | `ห้องเรียน`

แต่ละแถวคาบเรียน (`SchedulePeriodRow`) เรียงซ้าย→ขวา:

| ส่วน | รายละเอียด |
|---|---|
| เลขคาบ | ตัวเลขใหญ่ semibold |
| เวลา | 2 บรรทัด `08:00` / `08:50` ตัวเล็ก สีเทา |
| จุดสี | วงกลม 8pt สีประจำวิชา |
| ไอคอน | สี่เหลี่ยมมน 32×32 พื้นสีวิชา opacity 0.12 + SF Symbol สีวิชา |
| ข้อความ | ชื่อวิชา (semibold, `Theme.Colors.textPrimary`) / ชื่อครู (caption, เทา) |
| ห้องเรียน | capsule พื้นสีวิชา opacity 0.12 ตัวอักษรสีวิชา เช่น `5201` |
| `chevron.right` | สีเทาอ่อน |

- คั่นแต่ละแถวด้วยเส้น divider บาง เว้น inset ด้านซ้าย
- แตะแถว → เปิดหน้ารายละเอียด/แก้ไข
- ปัดซ้าย → ลบ (มี confirm), ปัดขวา → แก้ไข
- long-press → context menu: `แก้ไข`, `ทำซ้ำไปวันอื่น`, `ลบ`

**แถวพักกลางวัน** — พื้นเหลืองอ่อน (`Theme.Colors.warning.opacity(0.10)`), ไอคอน `fork.knife` ในวงกลมขาว, ข้อความ `พักกลางวัน` + `12:00 – 13:00`, ไม่มีเลขคาบ ไม่มี chevron

**E. Empty state** — วันที่ไม่มีคาบ: ไอคอน `calendar.badge.plus` สีเทา + `"ยังไม่มีคาบเรียนในวันนี้"` + ปุ่ม `เพิ่มวิชา`

**F. การ์ด "งาน / การบ้านวันนี้"**

- Header: `งาน / การบ้านวันนี้` + badge นับจำนวน (`3 รายการ`) พื้น primary opacity 0.12 + ปุ่มขวา `ดูทั้งหมด ›` → push ไป `AssignmentListView()`
- แต่ละแถว: ไอคอนวิชา (สไตล์เดียวกับตาราง) / ชื่อวิชา (semibold) + รายละเอียดงาน (caption เทา) / ขวา `ส่ง 31 ก.ค.` + chevron
- ถ้าเกินกำหนดให้ข้อความวันส่งเป็นสี `Theme.Colors.danger`
- ดึงจาก `Assignment` ที่ `dueDate` อยู่ในวันที่เลือกหรืออนาคตอันใกล้ และ `isDone == false` แสดงสูงสุด 3 รายการ
- ไม่มีงาน → `"ไม่มีการบ้านค้างส่ง 🎉"` (ข้อความอย่างเดียว ไม่ต้องซ่อนการ์ด)

**G. ปุ่มเพิ่ม** — ใช้ปุ่ม `+` กลาง tab bar เดิมของ `RootTabView`

> **สำคัญ:** ตอนนี้ปุ่ม `+` เปิด `SmartCaptureView` อยู่ อย่าไปเปลี่ยน behavior นั้น ให้ใส่ **FAB ของหน้านี้เอง** แทน: วงกลม 56pt สี primary + `plus` สีขาว วางมุมขวาล่างเหนือ tab bar → เปิด `ScheduleEntryEditorView` โหมดสร้างใหม่

### 3.2 โหมดรายสัปดาห์ — grid ทั้งอาทิตย์

- แกนตั้ง = คาบ (1–8 + พักกลางวัน), แกนนอน = จันทร์–ศุกร์ (เสาร์–อาทิตย์แสดงเฉพาะถ้ามีคาบ)
- คอลัมน์แรกตรึงไว้ (คาบ + เวลา), ส่วน grid เลื่อนแนวนอนได้
- แต่ละเซลล์: ชื่อวิชาย่อ + ห้องเรียน บนพื้นสีวิชา opacity 0.12 มุมมน `Theme.Radius.control`
- คอลัมน์ของวันนี้ไฮไลต์เบา ๆ
- เซลล์ว่าง = แตะแล้วเปิดฟอร์มเพิ่มวิชาโดย pre-fill วันและคาบนั้นให้เลย
- แตะเซลล์ที่มีวิชา → เปิดแก้ไข

### 3.3 `ScheduleEntryEditorView` — ฟอร์มเพิ่ม/แก้ไขวิชา (sheet)

ใช้ `Form` / grouped list, presentation detent `.large`, ปุ่ม `ยกเลิก` ซ้าย และ `บันทึก` ขวาบน

**Section "รายละเอียดวิชา"**

| ฟิลด์ | ชนิด | เงื่อนไข |
|---|---|---|
| ประเภท | Picker (`ScheduleKind`) | ค่าเริ่มต้น `คาบเรียน` |
| ชื่อวิชา | TextField | **บังคับ**; มี autocomplete แนะนำจากวิชาที่เคยกรอก |
| คาบ | Stepper หรือ Picker 0–12 | 0 = ไม่ระบุคาบ |
| วัน | เลือกได้**หลายวัน** (chip จันทร์–อาทิตย์) | **บังคับอย่างน้อย 1 วัน**; เลือกหลายวัน = สร้างหลาย entry รวดเดียว |
| เวลาเริ่ม | DatePicker `.hourAndMinute` | |
| เวลาสิ้นสุด | DatePicker `.hourAndMinute` | ต้องมากกว่าเวลาเริ่ม |
| ชื่อครู | TextField | ไม่บังคับ; autocomplete จากครูที่เคยกรอก |
| ห้องเรียน | TextField | ไม่บังคับ |
| สี | แถบเลือกสีจาก `Theme.Colors` (primary, success, warning, danger, info, purple, pink, indigo) | ค่าเริ่มต้นสุ่มจากสีที่ยังไม่ถูกใช้ |

**พฤติกรรม**

- เปิดฟอร์มใหม่ → pre-fill วันที่เลือกอยู่ + คาบถัดไป + เวลาเริ่ม = เวลาจบของคาบสุดท้าย + 10 นาที (ผ่าน `nextSuggestedPeriodAndTime`)
- เปลี่ยนเวลาเริ่ม → เวลาสิ้นสุดขยับตามอัตโนมัติให้คงระยะเวลาเดิม (ค่าเริ่มต้น 50 นาที)
- **ตรวจเวลาทับซ้อน**: ถ้าชนกับคาบที่มีอยู่ในวันเดียวกัน แสดง inline warning สีส้ม `"เวลาทับกับ <ชื่อวิชา> (09:00–09:50)"` — เตือนแต่**ยังบันทึกได้**
- ปุ่ม `บันทึก` disabled จนกว่าชื่อวิชาไม่ว่าง, เลือกอย่างน้อย 1 วัน, และเวลาสิ้นสุด > เวลาเริ่ม
- โหมดแก้ไข: เพิ่ม `ลบวิชานี้` สีแดงท้ายฟอร์ม + confirmation dialog; ถ้าวิชานี้ซ้ำหลายวัน ให้ถามว่า `ลบเฉพาะวันนี้` หรือ `ลบทุกวัน`
- บันทึกสำเร็จ → ปิด sheet + haptic `.success`

---

## 4. รายละเอียด visual

- พื้นหลังหน้า `Theme.Colors.background`, การ์ดขาว มุมมน `Theme.Radius.card`, เงา `black.opacity(0.06)` radius 6 y 2 — ใช้ `CardContainer` ที่มีอยู่
- ระยะห่างระหว่างการ์ด `Theme.Spacing.lg`, padding แนวนอนของหน้า `Theme.Spacing.lg`
- ทั้งหน้าอยู่ใน `ScrollView` แนวตั้ง
- ไอคอนวิชา: map ชื่อวิชา → SF Symbol เขียนเป็น `SubjectIconMapper` (คณิต `function`/`gearshape.2`, ฟิสิกส์ `book.closed`, ภาษาอังกฤษ `character.book.closed`, ภาษาไทย `text.book.closed`, เคมี `flask`, สังคม `globe.asia.australia`, ศิลปะ `paintpalette`, พลศึกษา `figure.run`, ค่า fallback `book.closed`)
- รองรับ Dynamic Type (ใช้ `.font(.system(size:weight:))` เท่าที่จำเป็น อย่าล็อกความสูงแถวตายตัว ให้ใช้ `minHeight`)
- รองรับ Dark Mode: `Theme.Colors.background` / `cardBackground` ถ้ายัง hardcode ขาวอยู่ ให้เพิ่ม dynamic color ใน `Theme` แทนการ hardcode ในหน้านี้
- ใส่ `.accessibilityLabel` ให้ทุกแถว เช่น `"คาบ 1 คณิตศาสตร์เพิ่มเติม ม.5 เวลา 08:00 ถึง 08:50 ห้อง 5201 ครูณัฐวุฒิ อินทร์แก้ว"`
- ปุ่มกดได้ทุกปุ่มต้องมี hit area อย่างน้อย 44×44

---

## 5. งานเชื่อมต่อ

1. เพิ่มไฟล์ใหม่ใน `Features/Calendar/` และให้ `CalendarView` render `ScheduleCalendarView`
2. ตรวจว่า `ScheduleEntry` อยู่ใน `Schema` ใน `PrototypeAppApp.swift` แล้ว (อยู่แล้ว) — ถ้าเพิ่มโมเดลใหม่ต้องเพิ่มด้วย
3. ใส่ `#Preview` ให้ทุก view ใหม่ พร้อม in-memory `ModelContainer` + seed ข้อมูลตัวอย่างตาม mockup (คณิตศาสตร์เพิ่มเติม ม.5 / ฟิสิกส์ / ภาษาอังกฤษ / ภาษาไทย / พักกลางวัน / เคมี / สังคมศึกษา / ศิลปะ / พลศึกษา)
4. ไม่ต้องแตะ `TimelineView`, `SmartCaptureView`, `ScheduleSetupView` — แต่ถ้าเจอ logic ตารางเรียนซ้ำซ้อน ให้ note ไว้ท้ายงาน อย่าเพิ่ง refactor

---

## 6. เกณฑ์ตรวจรับ

- [ ] โปรเจกต์ build ผ่าน ไม่มี warning ใหม่
- [ ] หน้าตาตรงกับ mockup: navigation bar, segmented control, week strip, การ์ดตาราง, พักกลางวัน, การ์ดการบ้าน
- [ ] เพิ่มวิชาใหม่แล้วแสดงในตารางทันที และยังอยู่หลังปิด-เปิดแอป (persist จริงผ่าน SwiftData)
- [ ] เพิ่มวิชาแบบเลือกหลายวันพร้อมกันได้
- [ ] แก้ไขและลบวิชาได้
- [ ] เตือนเมื่อเวลาทับซ้อน แต่ไม่บล็อกการบันทึก
- [ ] เลื่อนสัปดาห์ไป-กลับได้ วันที่แสดงเป็น พ.ศ. ถูกต้อง
- [ ] สลับ รายสัปดาห์ / รายวัน ได้ทั้งสองโหมด
- [ ] วันที่ไม่มีคาบแสดง empty state
- [ ] VoiceOver อ่านแต่ละแถวได้ครบถ้วน

---

## 7. นอกขอบเขต (อย่าทำ)

- ระบบแจ้งเตือน / notification
- นำเข้าตารางเรียนด้วย OCR (มี `ScheduleOCRParser` อยู่แล้ว ค่อยเชื่อมทีหลัง)
- Sync ขึ้นคลาวด์ หรือ export
- แก้ระบบ tier / paywall

---

## 8. วิธีทำงาน

1. อ่านไฟล์ใน section 1 ให้ครบก่อนเขียนโค้ด
2. สรุปแผน + รายชื่อไฟล์ที่จะสร้าง/แก้ ให้ดูก่อน **แล้วรอ confirm**
3. ทำทีละส่วน: model → store → row components → หน้าหลัก (รายวัน) → ฟอร์ม → โหมดรายสัปดาห์
4. จบแต่ละส่วนให้ build ผ่านก่อนไปต่อ
5. ถ้ามีจุดที่ mockup ไม่ชัด ให้ถามก่อน อย่าเดาเอง
