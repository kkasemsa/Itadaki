# Itadaki

แอป iPhone/iPad ส่วนตัว: ถ่ายรูปเมนูอาหารภาษาญี่ปุ่น แล้วได้รายการอาหารภาษาไทยพร้อมคำอธิบาย ราคา
และรูปอาหารที่ตัดมาจากเมนู สเปกเต็มอยู่ใน [SPEC.md](SPEC.md)

## ติดตั้งลงเครื่อง

ต้องใช้ Mac ที่มี Xcode 16 ขึ้นไป และ [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

```sh
echo 'DEVELOPMENT_TEAM = <Team ID ของคุณ>' > Config/Local.xcconfig   # ครั้งแรกครั้งเดียว
xcodegen generate
open Itadaki.xcodeproj
```

เลือก iPhone หรือ iPad แล้วกด Run จากนั้นเปิดแอป เข้า **ตั้งค่า** แล้วใส่ Claude API key
(สร้างได้ที่ platform.claude.com) key เก็บใน Keychain ของเครื่องเท่านั้น

ถ้าใช้ Apple ID แบบฟรี แอปจะหมดอายุทุก 7 วัน ให้ build ใหม่

## ทดสอบ

```sh
xcodebuild -scheme Itadaki -destination 'platform=iOS Simulator,name=iPhone 16' test   # ทั้งแอป
swift test                                                                              # เฉพาะ logic ไม่ต้องใช้ Xcode
```

ใน simulator ไม่มีกล้อง ให้เลือกรูปจากคลัง หรือเปิด **โหมดตัวอย่าง** ในตั้งค่าเพื่อดูหน้าจอโดยไม่เรียก API
