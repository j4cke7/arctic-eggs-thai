# Arctic Eggs ภาษาไทย | Thai Translation Mod

[![Arctic Eggs](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2763670/header.jpg?t=1777045542)](https://store.steampowered.com/app/2763670/Arctic_Eggs/)

ม็อดภาษาไทยสำหรับ **Arctic Eggs บน Steam Windows build 18492481** รุ่นทดลอง 0.1.4

A Thai translation mod for Arctic Eggs on Steam Windows, with Thai fonts and installation and uninstall instructions.

## [ดาวน์โหลดม็อดภาษาไทย (.zip)](https://github.com/j4cke7/arctic-eggs-thai/releases/download/v0.1.4-build18492481/Arctic-Eggs-Thai-replace-en-build18492481.zip)

[รายละเอียดรุ่น](https://github.com/j4cke7/arctic-eggs-thai/releases/tag/v0.1.4-build18492481) · [ไฟล์ตรวจสอบ SHA-256](https://github.com/j4cke7/arctic-eggs-thai/releases/download/v0.1.4-build18492481/Arctic-Eggs-Thai-replace-en-build18492481.zip.sha256)

ม็อดใช้แทนช่องภาษา **English** เปิดเกมจาก Steam ตามปกติได้ ไม่ต้องเปิดผ่าน Play-Thai ฟอนต์ไทยรวมอยู่ในชุดแล้ว

<!-- release:summary -->
รุ่น 0.1.4 ตัวติดตั้งไม่ปฏิเสธเพียงเพราะเลขรุ่นของ Steam เปลี่ยน ถ้า game.exe และ game.pck ยังตรงกับไฟล์ที่ทดสอบ จะขึ้นคำเตือนแล้วติดตั้งหรือติดตั้งซ้ำได้ และหาก Steam อัปเดตไฟล์เกมแล้ว ตัวติดตั้งจะแจ้งให้รอรุ่นใหม่ และ Uninstall.cmd ถอนได้เสมอ แม้ไฟล์ข้อมูลแอปของ Steam จะหายไป
<!-- /release:summary -->

## วิธีติดตั้ง

1. ปิด Arctic Eggs
2. ดาวน์โหลด ZIP ด้านบน แล้วแตกไฟล์ทั้งหมดก่อนใช้งาน
3. ดับเบิลคลิก `Install.cmd` ตัวติดตั้งจะค้นหาเกมใน Steam และตรวจรุ่นที่รองรับ
4. เปิดเกมจาก Steam หรือ `game.exe` ตามปกติ แล้วเลือกภาษา **English** ข้อความที่แปลไว้จะแสดงเป็นไทย

ตัวติดตั้งใช้ `.cmd` เรียก PowerShell ที่มีอยู่ใน Windows ไม่ต้องติดตั้ง Python หรือฟอนต์เพิ่ม อ่าน [ซอร์ส Patch.ps1](source/Patch.ps1) ได้ก่อนใช้งาน

## วิธีถอนม็อด

1. ปิดเกม
2. ดับเบิลคลิก `Uninstall.cmd` ในโฟลเดอร์ที่แตก ZIP
3. เปิดเกมตามปกติ ช่อง English จะกลับเป็นภาษาอังกฤษ

เก็บโฟลเดอร์ที่แตก ZIP ไว้สำหรับถอนการติดตั้ง หากต้องย้ายโฟลเดอร์เกม ให้ถอนม็อดก่อน แล้วติดตั้งใหม่หลังย้ายเสร็จ

## อัปเดตจากรุ่นก่อน

ปิดเกม แล้วใช้ `Uninstall.cmd` จากโฟลเดอร์ที่ใช้ติดตั้งรุ่นเดิมถอนม็อดก่อน จากนั้นติดตั้ง 0.1.4 ตามขั้นตอนด้านบน ตัวติดตั้งจะไม่เขียนทับม็อดคนละรุ่น

## หากติดตั้งรุ่น 0.1.0 อยู่แล้ว

ตัวถอนของชุดใหม่ไม่ข้าม ownership เพื่อรับไฟล์ม็อดคนละรุ่น หากเกมยังเป็น build ที่รองรับ ให้ถอนด้วย ZIP รุ่น 0.1.0 เดิมก่อน แล้วจึงติดตั้ง 0.1.4

หาก Steam อัปเดตจนตัวถอน 0.1.0 หยุด ให้ใช้ [วิธีซ่อมตัวถอนรุ่นเดิม](repair-v0.1.0/README-th.md) โดยคง manifest เดิม ไฟล์นี้เป็นการซ่อมเฉพาะตัวถอน ไม่ทำให้ม็อดรองรับเกม build ใหม่

## หากติดตั้งไม่สำเร็จ

- ตรวจว่าแตกไฟล์ครบและเกมปิดอยู่
- รองรับเฉพาะ build 18492481 หากเกมอัปเดตเป็นรุ่นอื่น ให้รอแพ็กที่รองรับ
- หากมี `override.cfg` หรือไฟล์ของม็อดอื่นที่ชนกัน ตัวติดตั้งจะหยุดพร้อมระบุสาเหตุ ให้เก็บไฟล์เดิมไว้ ไม่ต้องลบทิ้งเพื่อบังคับติดตั้ง
- หากการติดตั้งถูกขัดจังหวะ ให้ปิดเกมแล้วเรียก `Install.cmd` อีกครั้ง

## ขอบเขตของรุ่นทดลอง

ใช้บทแปลชุดที่ตรวจแล้วและฟอนต์ Sarabun บทสนทนาคงลูกเล่นขึ้นทีละตัวอักษรเดิม บางข้อความยังอาจเป็นภาษาอังกฤษ ข้อความที่ยังยืนยันต้นฉบับหรือจุดแสดงผลไม่ได้ยังไม่ถูกเดาเติม

ม็อดนี้เป็นงานแปลชุมชน รุ่นนี้ยังไม่ได้รับรองว่าทุกฉากและทุกขนาดหน้าจอผ่านการเล่นครบแล้ว ดูผลทดสอบเฉพาะรุ่นใน [รายละเอียดรุ่น](https://github.com/j4cke7/arctic-eggs-thai/releases/tag/v0.1.4-build18492481)

## ภาพจากเกมต้นฉบับ

ภาพต่อไปนี้เป็นภาพประชาสัมพันธ์จากหน้า Steam ของเกม ไม่ใช่ภาพทดสอบคำแปลไทย

![Arctic Eggs — ภาพจากเกมต้นฉบับ](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2763670/ss_da061e95820699b2e171071d0b5890c1adb6f887.1920x1080.jpg?t=1777045542)

![Arctic Eggs — บรรยากาศในเกม](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2763670/ss_3805a60d91e8840b7a8d690cc39bf55fad228a60.1920x1080.jpg?t=1777045542)

[หน้าเกมบน Steam](https://store.steampowered.com/app/2763670/Arctic_Eggs/) · [แจ้งปัญหา](https://github.com/j4cke7/arctic-eggs-thai/issues)
