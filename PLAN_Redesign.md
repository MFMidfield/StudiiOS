# PLAN_Redesign — Student OS visual overhaul

> สร้าง 13 ส.ค. 2569 · สถานะ: **รอ Few อนุมัติ ยังไม่เริ่มเขียนโค้ด**
> ทำงานบน branch `redesign` เท่านั้น — `main` ต้อง build ผ่านและเดโม่ได้ตลอดเวลา

---

## 0. การตัดสินใจที่ล็อกแล้ว

| หัวข้อ | ค่า |
|---|---|
| สไตล์ | **Soft minimalist เป็นหลัก** + Organic เฉพาะจุด (แคปซูล/วงกลม/blob) |
| สีหลัก | **Terracotta `C96F4A`** |
| พื้นหลัง light | `FBF7F2` (เดิม) |
| พื้นหลัง dark | `14110E` (เดิม) |
| ฟอนต์ | **IBM Plex Sans Thai** (Regular / Medium / SemiBold) |
| Dashboard | โครงเดิม 5 section ทาสีใหม่ (แบบ A) |
| ไอคอนเมนู | SF Symbols เส้น บนพื้นสี่เหลี่ยมมน `primarySoft` |
| สีวิชา | ชุดเดิม 8 สี เปลี่ยนแค่ตัวแรกเป็น terracotta |
| แอนิเมชัน | **ระดับกลาง** — spring ตอนเปลี่ยนค่า + ตัวเลขนับ ไม่มี `matchedGeometryEffect` |
| Tab bar | Liquid Glass ของ iOS 26 ตามเดิม · default: หน้าแรก · งาน · **+** · ตารางสอน · ตั้งค่า |
| ปุ่ม + | คงที่ ช่องกลาง เปลี่ยนไม่ได้ |
| Tier ตอนเดโม่ | **Pro** (เห็นทุกฟีเจอร์ แต่ป้าย Pro ยังโชว์) |
| Figma | ข้ามไปก่อน |

---

## 1. Theme.swift — token ชุดใหม่

### 1.1 สี (ทุกตัวเป็น `Color(light:dark:)`)

| Token | Light | Dark | ใช้ตอนไหน |
|---|---|---|---|
| `primary` | `C96F4A` | `E8A06B` | fill เล็ก: progress, tab tint, ขีดสีวิชา |
| `primaryDeep` | `A85236` | `E8A06B` | ตัวหนังสือ/ไอคอนสีส้ม บนพื้นอ่อน |
| `onPrimary` | `FFFFFF` | `1A1512` | ตัวหนังสือบน `primary` |
| **`primarySoft`** ⭐ | `F5E7DD` | `332720` | พื้นไอคอนเมนู · ป้ายวัน · chip |
| **`heroFill`** ⭐ | `C96F4A` | `8F4A2C` | การ์ด hero "คาบเรียนถัดไป" |
| **`onHero`** ⭐ | `FFFFFF` | `FFF1E6` | หัวข้อบน hero |
| **`onHeroMuted`** ⭐ | `F7DFD2` | `F0CBB5` | บรรทัดรองบน hero |
| `textPrimary` | `2A2320` | `F4EEE7` | เดิม |
| `textSecondary` | `8A7B6D` | `A79A8B` | อ่อนลงจาก `7A6E62` |
| `background` | `FBF7F2` | `14110E` | เดิม |
| `cardBackground` | `FFFFFF` | `1F1B17` | เดิม |
| `surfaceRaised` | `F6F0E8` | `2A241E` | เดิม |
| `separator` / `cardStroke` | `EDE3D6` | `3A322A` | เดิม |
| `breakBackground` | `FDF3E0` | `2A2416` | เดิม |
| `danger` | `C0503F` | `E8756A` | **เสนอเปลี่ยน** — `FF6B6B` เดิมสดเกินไปบนครีม |
| `warning` `success` `info` `purple` `pink` `indigo` | เดิม | เดิม | ไม่แตะ |

⭐ = token ใหม่ 4 ตัว · ตัวหนา = ต้องเพิ่มใน `Theme.Colors`

`subjectPalette` / `subjectPaletteHex` — เปลี่ยนตัวแรกจาก `E1802F` เป็น `C96F4A` เท่านั้น อีก 7 สีคงเดิม

### 1.2 มุมโค้ง

```
Radius.card    16 → 18
Radius.hero    22 → 20
Radius.control 12   (คงเดิม)
Radius.icon    11   (ใหม่ — พื้นไอคอนเมนู)
Radius.pill    999  (ใหม่ — chip / ปุ่ม / ป้าย)
```

### 1.3 ระยะห่าง

คงเดิมทั้งหมด เพิ่ม `Spacing.xxxl = 32` สำหรับเว้นบนหัวข้อ section

### 1.4 ฟอนต์

> ✅ **ตรวจแล้ว: โปรเจกต์มี `PrototypeApp/Info.plist` จริง** และผูกไว้ที่ `INFOPLIST_FILE` ใน pbxproj แล้ว
> → **ผมเพิ่ม `UIAppFonts` ให้เองได้ Few ไม่ต้องกด Build Settings**

งานที่ Few ทำ: ดาวน์โหลด IBM Plex Sans Thai (OFL ฟรี) 3 น้ำหนัก — Regular · Medium · SemiBold —
แล้ววางไฟล์ `.ttf` ไว้ที่ `PrototypeApp/Resources/Fonts/`
(โปรเจกต์ใช้ file-system-synchronized groups → ไฟล์เข้า Copy Bundle Resources อัตโนมัติ ไม่ต้องแตะ pbxproj)

งานที่ผมทำ: เพิ่ม 3 ชื่อไฟล์ใน `Info.plist` → `UIAppFonts` + เขียน `Theme.Font`

ฝั่งโค้ด ผมจะเพิ่ม `Theme.Font` ที่ **fallback เป็น system font อัตโนมัติถ้าหาฟอนต์ไม่เจอ** → ถ้า Few ยังไม่ได้ทำ 3 ข้อบน แอปก็ยัง build และหน้าตายังใช้ได้ ไม่พัง

```
Theme.Font.title    24 semibold
Theme.Font.heading  19 semibold
Theme.Font.body     15 regular
Theme.Font.label    13 regular
Theme.Font.caption  11 regular
Theme.Font.number   ตัวเลขใหญ่ 19-24 semibold + .monospacedDigit()
```

### 1.5 CardContainer

- radius 16 → 18
- เงา `0.06/6/y2` → `0.05/10/y3` (นุ่มขึ้น กระจายกว่า)
- โหมดมืดตัดเงาทิ้ง เหลือแค่ `cardStroke` (เงาดำบนพื้นดำไม่มีความหมาย)
- เพิ่ม parameter `padding:` (default `Theme.Spacing.lg`) — บางการ์ดต้องการ 12

### 1.6 คอมโพเนนต์ใหม่ที่จะเพิ่มใน DesignSystem/

| ไฟล์ | หน้าที่ |
|---|---|
| `Theme.swift` (แก้) | token + CardContainer + TierBadge เดิม |
| `PillLabel.swift` | ป้ายแคปซูล — ใช้กับ "พรุ่งนี้" "ศุกร์" "3 งาน" |
| `IconTile.swift` | ไอคอน SF Symbol บนพื้น `primarySoft` มุม `Radius.icon` |
| `SectionHeader.swift` | หัวข้อ section + ปุ่ม "ดูทั้งหมด" ทางขวา |

`PressScaleButtonStyle` มีอยู่แล้วใน `DashboardMenuGrid.swift` → **ย้ายออกมาไว้ที่ `Theme.swift`** เพื่อใช้ทั้งแอป

---

## 2. Wave 1 — Theme + Dashboard + tab bar

**เป้าหมาย:** จบ W1 แล้วเปิดแอปมาต้องเห็นของใหม่ทันที และทุกหน้าที่เหลือยังใช้ได้ปกติ (แค่หน้าตายังเป็นของเดิมที่ได้สีใหม่ไปด้วยอัตโนมัติเพราะอ่าน token ตัวเดียวกัน)

### 2.1 ไฟล์ที่แก้

| ไฟล์ | ทำอะไร |
|---|---|
| `Core/DesignSystem/Theme.swift` | token ทั้งหมด §1 |
| `Core/DesignSystem/PillLabel.swift` | **ใหม่** |
| `Core/DesignSystem/IconTile.swift` | **ใหม่** |
| `Core/DesignSystem/SectionHeader.swift` | **ใหม่** |
| `Features/Dashboard/DashboardView.swift` | ยุบ `DateBadge` เข้า `HeaderSection` · ย่อ `AvatarView` 60→34 · จัดลำดับ section ใหม่ |
| `Features/Dashboard/DashboardNextClassCard.swift` | **ทาสีอย่างเดียว** + ต่อท้ายด้วยงานชิ้นถัดไป — empty state มีครบแล้ว §2.3 |
| `Features/Dashboard/DashboardStatsCard.swift` | 2 ช่อง → **กริด 2×2** §2.2 |
| `Features/Dashboard/DashboardMenuGrid.swift` | ใช้ `IconTile` · **เพิ่มปฏิทินเข้าเมนู** · ย้าย `PressScaleButtonStyle` ออก |
| `Features/Dashboard/DashboardPendingCard.swift` | ใช้ `SectionHeader` + `PillLabel` + ขีดสีวิชา |
| `Features/Dashboard/GPAXDashboardCard.swift` | แถวเดียว: GPAX + เป้า + progress + chevron |
| `App/RootTabView.swift` | สลับแท็บ 2: ปฏิทิน → **งาน** (`AssignmentListView`) · เปลี่ยน label "ตารางเรียน" → "ตารางสอน" |

### 2.2 แถบสรุปใต้ hero — กริด 2×2

| ช่อง | ที่มาข้อมูล |
|---|---|
| โฟกัสวันนี้ | `FocusSession` วันนี้ (เดิม) |
| งานค้าง | `TaskScope` เดิม |
| **ส่งพรุ่งนี้** | `Assignment` ที่ `!isDone` และ `dueDate` ตกวันพรุ่งนี้ |
| **นับถอยหลังสอบ** | `Assignment` ที่ `kind == .exam` · `dueDate` อนาคต · ใกล้สุด |

ถ้าไม่มีงานชนิดสอบเลย → ช่องที่ 4 กลายเป็นการ์ดชวน **"เพิ่มวันสอบ"** กดแล้วเปิด `AddTaskSheet` แบบตั้งค่า `kind = .exam` ไว้ล่วงหน้า

⚠️ **`AddTaskSheet` ปัจจุบันคือ `init(editing:onSaved:)` ไม่มีช่องรับ kind**
ต้องเพิ่ม `init(editing: Assignment? = nil, presetKind: AssignmentKind = .homework, onSaved: (() -> Void)? = nil)`
default เป็น `.homework` เพื่อให้ call site เดิม 3 จุด (QuickAddSheet · DashboardPendingCard · FAB ในหน้างาน) คอมไพล์ผ่านโดยไม่ต้องแก้

> ไม่ต้องเพิ่ม `@Model` ใหม่ — `AssignmentKind.exam` มีจริงที่ `Assignment.swift:24`
> แถม `ExamScope` (กลางภาค / ปลายภาค / เก็บคะแนน) ก็มีอยู่แล้ว → การ์ดนับถอยหลังโชว์ได้เลยว่าเป็นสอบอะไร

### 2.3 การ์ด hero — ✅ empty state มีครบแล้ว ไม่ต้องเขียนใหม่

`DashboardNextClassCard.swift` มี 5 สถานะครบตั้งแต่แรก:

| สถานะ | ข้อความปัจจุบัน | บรรทัด |
|---|---|---|
| กำลังเรียน | "อีก N นาที" + วิชา + เวลา + ห้อง | ~136 |
| คาบถัดไป | "คาบถัดไป · อีก N นาที" | ~170 |
| หมดคาบแล้ว | "หมดคาบเรียนวันนี้แล้ว" | 108 |
| เสาร์/อาทิตย์ | "วันหยุดสุดสัปดาห์" | 61 |
| ตารางว่าง | "วันนี้ยังไม่มีตารางเรียน" | 77 |

**งานจริงในรอบนี้จึงเหลือแค่:**
1. ทาสี `heroFill` / `onHero` / `onHeroMuted` แทนสีเดิม
2. เพิ่ม progress bar ในสถานะ "กำลังเรียน"
3. เพิ่มบรรทัด "ถัดไป · <วิชา> <เวลา>" ในสถานะกำลังเรียน
4. **ทุกสถานะที่ไม่ใช่กำลังเรียน ต่อท้ายด้วยงานชิ้นถัดไป** (`Assignment` ยังไม่เสร็จ due ใกล้สุด) ถ้าไม่มีเลยแสดง "ไม่มีงานค้าง"
5. แก้ข้อความบรรทัด 81 "ไปที่แท็บ **ตารางเรียน**" → **ตารางสอน** ให้ตรงกับชื่อแท็บใหม่

### 2.3.1 ลำดับ section — ของจริงต่างจากที่ PROJECT_MAP บอก

ลำดับปัจจุบันใน `DashboardView.body`:
`HeaderSection` → `DateBadge` → `NextClassCard` → `StatsCard` → **`GPAXCard`** → **`MenuGrid`** → `PendingCard`

ลำดับใหม่:
`HeaderSection` (รวมวันที่แล้ว) → `NextClassCard` → `StatsCard` (2×2) → `MenuGrid` → `PendingCard` → `GPAXCard`

→ ต้อง **ลบ struct `DateBadge`** ทิ้ง และย้าย `date.thaiFullString` ขึ้นไปเป็นบรรทัดบนของ `HeaderSection`

### 2.4 เมนูหลัก W1

ปฏิทิน ย้ายเข้าเมนู → เมนูมี 7 ช่อง กริด 3 คอลัมน์ 3 แถว (แถวสุดท้ายเหลือ 1 ช่อง)
เรียง: ปฏิทิน · ศูนย์เกรด · TCAS · พอร์ต · ค้นหาอาชีพ · โหมดโฟกัส · งานทั้งหมด

> ต้องเพิ่ม `case calendar` ใน `DashboardDestination` และ `destinationView(for:)` ใน `RootTabView`
> ⚠️ `CalendarView` เดิมเป็น root ของ NavigationStack ตัวเอง — ตอน push จาก Dashboard ต้องเช็คว่าไม่มี `NavigationStack` ซ้อนอยู่ข้างใน ไม่งั้น toolbar จะหาย

### 2.5 แอนิเมชัน W1

- เข้าหน้า: fade + offset ที่มีอยู่แล้ว — คงไว้ ไม่แตะ
- ตัวเลขทุกช่อง: `.contentTransition(.numericText())` (มีอยู่แล้วบางที่ ทำให้ครบ)
- ปุ่ม/การ์ดที่กดได้: `PressScaleButtonStyle`
- ติ๊กงานเสร็จ: `.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDone)`
- **ห้าม** `matchedGeometryEffect` · **ห้าม** `.blur` ซ้อน material

---

## 3. Wave 2 — หน้าที่เหลือที่เดโม่ต้องเดินผ่าน

ทำหลัง Few ยืนยันว่า W1 build ผ่านและกดดูแล้วโอเค

| ลำดับ | หน้า | จุดที่ต้องระวัง |
|---|---|---|
| 1 | `Features/Tasks/*` (7 ไฟล์) | `List(.plain)` + `plainRow()` — **ปัดซ้ายลบต้องยังทำงาน** |
| 2 | `Features/Schedule/ScheduleTimetableSection` + `SchedulePeriodRow` + `ScheduleBreakRow` | ผูกกับ `[ResolvedPeriod]` ห้ามแตะ logic การร่นคาบ |
| 3 | `Features/QuickAdd/QuickAddSheet` | กริดไอคอน → `IconTile` |
| 4 | `Features/GradeCenter/*` | `GPAXSummaryCard` range bar ใช้สีใหม่ |
| 5 | `Features/Settings/SettingsView` (588 บรรทัด) | อ่าน/แก้เป็นช่วง อย่าเปิดทั้งไฟล์ · `developerSection` ห้ามยุ่ง |
| 6 | `Features/TCASPlanner/*` | การ์ดคะแนน — ห้ามแตะสูตรใน `TCASScoreEngine` |
| 7 | `Features/Portfolio/*` | `PortfolioCard` รูป bleed ถึงขอบ — radius ต้องตรงกับการ์ดใหม่ |

---

## 4. Wave 3 — เสี่ยงสุด ตัดทิ้งได้ถ้าเวลาไม่พอ

### 4.1 Custom navigation (Pro)

**หลักการ:** tab bar กับเมนูหลักดึงจากบ่อเดียวกัน ย้ายเข้า tab = หายจากเมนู อัตโนมัติ

```
enum AppDestination: String, CaseIterable, Codable {
    case dashboard, tasks, schedule, calendar, settings,
         gradeCenter, tcasPlanner, portfolio, careerDiscovery, focusMode
}
```

- `NavPreferences` (ไฟล์ใหม่ ใน `Core/Navigation/`) — **จุดเดียว**ที่รู้จัก UserDefaults key ของ tab bar (แบบเดียวกับ `PomodoroSettings` / `GPAXSettings`)
  เก็บ `[AppDestination]` 4 ตัว · default `[.dashboard, .tasks, .schedule, .settings]`
- เมนูหลัก = `AppDestination.allCases` − ตัวที่อยู่ใน tab bar
- ปุ่ม `+` แทรกตำแหน่งที่ 3 เสมอ ไม่นับเป็น destination
- หน้าตั้งค่า: `NavCustomizeView` — ลิสต์ 4 ช่อง แตะเลือกจาก menu · ลากสลับลำดับ · gate ด้วย `EntitlementStore`

⚠️ **ข้อจำกัดที่ต้องมี:** ช่องแรกล็อกเป็น `dashboard` เสมอ
เหตุผล: เมนูหลักอยู่ในหน้า Dashboard — ถ้า user เอา Dashboard ออกจาก tab bar จะไม่มีทางเข้าถึงเมนูอีกเลย = ติดกับดักถาวร
ถ้า Few ไม่อยากล็อก ต้องย้ายเมนูหลักไปอยู่ใน `SettingsView` ด้วยอีกที่หนึ่งก่อน

⚠️ หน้าที่ย้ายจาก tab → เมนู จะไม่มี `NavigationStack` ของตัวเอง ต้องถูก push ใน stack ของ Dashboard
→ ต้องไล่เช็คทุกหน้าว่าไม่ได้ประกาศ `NavigationStack` ซ้อนอยู่ข้างใน

### 4.2 `CalendarView.swift` (963 บรรทัด — ใหญ่กว่าที่ PROJECT_MAP บอก)

**ต้องแยกไฟล์ก่อนแตะ UI** — `PROJECT_MAP.md` เตือนเรื่องนี้ไว้เองแล้ว
แตกเป็น: `CalendarMonthGrid` · `CalendarDayDetailSheet` · `CalendarEventRow` · `CalendarView` (root)
ถ้าเวลาไม่พอ → **ทาสีอย่างเดียว ไม่แตะโครง** ปลอดภัยกว่า

### 4.3 Onboarding 5 หน้า

30 วินาทีแรกที่กรรมการเห็น — ทำท้ายสุด เมื่อทุกอย่างนิ่งแล้ว

---

## 5. กฎที่ห้ามลืมระหว่างทำ

1. **ห้าม hardcode สี/ระยะ/มุม** — ทุกค่าจาก `Theme` ถ้าไม่มี token ให้เพิ่มใน `Theme.swift` ก่อน
2. **ห้ามแตะ logic** — `TCASScoreEngine` · `GPAXCalculator` · `PomodoroEngine` · `PeriodShiftCalculator` · `TermStore` · ทุกอย่างใน `Core/OCR/` งานนี้เป็นงานเปลี่ยนหน้าตาล้วน
3. **ไม่มี `@Model` ใหม่** ทั้งแผน → ไม่ต้องแตะ `Schema([...])` ไม่ต้องแตะ `resetAllData()` และ **ข้อมูลเดิมในเครื่อง Few ไม่หาย**
4. **ไม่เพิ่ม SPM package** — ฟอนต์เป็นไฟล์ `.ttf` ไม่ใช่ dependency
5. ไฟล์ view ยาวเกิน ~250 บรรทัด → แตกเป็น sub-view ก่อน กัน type-check timeout
6. แก้อะไรที่ทำให้ `PROJECT_MAP.md` ผิด → อัปเดตในคอมมิตเดียวกัน
7. commit ทีละก้อนย่อย ขึ้นต้น `wip:` จนกว่า Few จะยืนยันว่า build ผ่าน

---

## 6. Definition of done ของแต่ละ wave

**W1** — Few กด ⌘B เขียว แล้วเปิดแอป เห็น:
- Dashboard สีส้ม terracotta ทั้งหน้า การ์ดมุม 18 นุ่มขึ้น
- hero คาบเรียนพื้นส้มเข้ม มี progress bar
- แถบสรุป 4 ช่อง (ถ้าไม่มีงานสอบ → ช่องที่ 4 เป็นปุ่มชวนเพิ่มวันสอบ กดแล้วฟอร์มเปิดจริง)
- เมนู 7 ช่อง มีปฏิทิน กดเข้าปฏิทินได้
- tab bar: หน้าแรก · งาน · + · ตารางสอน · ตั้งค่า — แท็บ "งาน" กดแล้วเข้าหน้างานจริง
- สลับ dark mode ในระบบ แล้วทุกอย่างยังอ่านออก ไม่มีตัวหนังสือหาย

**W2** — เดินเดโม่ครบวง: เพิ่มงาน → เห็นในตารางสอน → ติ๊กเสร็จ → เกรดอัปเดต โดยหน้าตาเป็นชุดเดียวกันหมด

**W3** — เปลี่ยนแท็บใน Settings แล้ว tab bar กับเมนูหลักสลับกันจริง ปิดแอปเปิดใหม่ค่าคงอยู่

---

## 6.5 บันทึกการตรวจสอบกับโค้ดจริง — 13 ส.ค. 2569

สิ่งที่ **ยืนยันแล้วว่าจริง** (ไม่ต้องตรวจซ้ำ):

- `Color(light:dark:)` มีอยู่จริงที่ `Color+Hex.swift:21` → token adaptive ทำได้ทันที
- `CalendarView` และ `AssignmentListView` **ไม่มี `NavigationStack` ซ้อนข้างใน** (เจอเฉพาะใน `#Preview`)
  → §2.4 push ปฏิทินจาก Dashboard และ §4.1 ย้ายหน้าเข้า/ออก tab bar ปลอดภัย
- `PressScaleButtonStyle` อยู่ที่ `DashboardMenuGrid.swift:84` ตามที่แผนบอก → ย้ายได้
- `Theme.Radius.hero` **ไม่มีที่ไหนเรียกใช้เลย** → เปลี่ยนค่าได้อิสระ
- `AvatarView` + `StudentProfileStore.cachedProfileImage` มีอยู่แล้ว → ไม่ต้องทำ avatar ใหม่

ข้อควรระวังที่เพิ่งเจอ:

- **`Theme.Colors.primary` ถูกเรียก 46 จุดทั่วแอป** — เปลี่ยน hex ตัวเดียวเปลี่ยนหมดทั้งแอปทันที
  ข้อดีคือไม่มีจุดตกหล่น ข้อเสียคือ **จบ W1 แล้วหน้าอื่นจะดู "ครึ่งๆ"** (ได้สีใหม่แต่ยังเป็น layout เก่า) จนกว่า W2 จะเสร็จ — เป็นเรื่องปกติ ไม่ใช่บั๊ก
- **`HeaderSection` ใช้ `.padding(.top, 60)` คู่กับ `.ignoresSafeArea(edges: .top)` ใน `DashboardView`**
  เป็นการชดเชย safe area ด้วยมือ ไม่ใช่ layout ปกติ → แก้ header ต้องเช็คบนจอจริงว่าหัวไม่ชน Dynamic Island
- `PROJECT_MAP.md` อ้างถึง `PLAN_GPA.md` · `PLAN_RIASEC.md` · `PLAN_TCASPlanner.md` · `PLAN_OCRAccuracy.md`
  แต่ **ไฟล์เหล่านี้ไม่มีอยู่ที่ราก repo แล้ว** — เป็นลิงก์ตาย ควรลบการอ้างอิงตอนอัปเดต PROJECT_MAP รอบหน้า

---

## 7. สิ่งที่ยังไม่ตัดสิน

- Figma sync — ยกไปคุยหลังโค้ดนิ่ง
- `danger` เปลี่ยนจาก `FF6B6B` เป็น `C0503F` ไหม (§1.1)
- ล็อกช่องแรกของ tab bar เป็น Dashboard ไหม (§4.1)
