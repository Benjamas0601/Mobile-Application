<#
.SYNOPSIS
    จุดเดียวสำหรับเปิด emulator แล้วติดตั้งแอป ไม่ต้องจำคำสั่งยาว

.DESCRIPTION
    Android Studio เปิด emulator เองไม่ได้ ต้องกดเองทุกครั้ง และการกด "Run"
    ใน Android Studio จะ build ทั้งโปรเจกต์ใหม่ทุกครั้ง (ช้า) สคริปต์นี้แยกสอง
    อย่างนี้ออกจากกัน: build ครั้งเดียว แล้วติดตั้ง/เปิดซ้ำได้เร็ว

.PARAMETER Action
    up       (ค่าเริ่มต้น) เปิด emulator → ติดตั้ง APK → เปิดแอป
    start    เปิด emulator แล้วรอจน boot เสร็จ
    stop     ปิด emulator
    build    build APK debug (ใส่ --dart-define ของ Cloudinary ให้แล้ว)
    install  ติดตั้ง APK ที่ build ไว้ล่าสุด
    launch   เปิดแอปที่ติดตั้งไว้
    logs     ดู logcat ของแอป
    status   ดูว่ามีอะไรเชื่อมอยู่

.EXAMPLE
    .\tool\run.ps1
    .\tool\run.ps1 build
    .\tool\run.ps1 install
    .\tool\run.ps1 logs
#>
[CmdletBinding()]
param(
  [ValidateSet('up', 'start', 'stop', 'build', 'install', 'launch', 'logs', 'status')]
  [string]$Action = 'up',

  # AVD ที่จะเปิด — ดูรายชื่อทั้งหมดด้วย `flutter emulators`
  [string]$Avd = 'Pixel_9',

  # ข้ามการ build (ติดตั้ง APK ที่มีอยู่แล้ว) ตอน `up` เพื่อให้เร็วขึ้น
  [switch]$SkipBuild
)

# PowerShell 5.1 ใช้ codepage ของ console ที่ไม่ใช่ UTF-8 ทำให้ข้อความไทยใน
# ไฟล์นี้ออกมาเป็นตัวยึก ต้องบอก console ให้รู้ก่อน
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# ตั้งเป็น Continue เพราะ PowerShell 5.1 แปลง stderr จากคำสั่ง native (เช่น
# Gradle ที่เตือนเรื่อง KGP) ให้เป็น error record ซึ่งจะทำให้ script หยุดกลางคัน
# ทุกจุดที่ต้องการความล้มเหลวจึงตรวจ $LASTEXITCODE หรือ throw เองแทน
$ErrorActionPreference = 'Continue'
Set-Location (Join-Path $PSScriptRoot '..')

# ค่าจาก android/local.properties ถ้ามี ไม่งั้นใช้ค่ากลางของเครื่อง
$sdkDir = $env:ANDROID_HOME
if (Test-Path 'android\local.properties') {
  $line = Select-String -Path 'android\local.properties' -Pattern '^sdk\.dir=(.+)$' |
    Select-Object -First 1
  if ($line) { $sdkDir = $line.Matches[0].Groups[1].Value -replace '\\\\', '\' }
}
if (-not $sdkDir) { $sdkDir = 'D:\Android\sdk' }

$emulatorExe = Join-Path $sdkDir 'emulator\emulator.exe'
$adbExe = Join-Path $sdkDir 'platform-tools\adb.exe'
$package = 'com.thaiotop.thai_otop_marketplace'
$apk = 'build\app\outputs\flutter-apk\app-debug.apk'

# Cloudinary ไม่ต้องส่ง flag แล้ว — ค่า default อยู่ใน
# lib/core/config/cloudinary_config.dart แล้ว จุดเดียวในโปรเจกต์ที่ต้องแก้
# ถ้าจะเปลี่ยน cloud หรือ upload preset (ห้ามใส่ API secret เด็ดขาด)
$dartDefines = @()

function Get-Target {
  $devices = & $adbExe devices | Select-String -Pattern '^(emulator-\d+)\s+device$'
  if ($devices) { return $devices[0].Matches[0].Groups[1].Value }
  return $null
}

function Wait-Boot {
  param([string]$Serial)
  Write-Host '  รอ emulator boot เสร็จ (ครั้งแรกรอนานกว่าปกติ)...' -ForegroundColor DarkGray
  $deadline = (Get-Date).AddMinutes(4)
  do {
    Start-Sleep -Seconds 5
    $done = (& $adbExe -s $Serial shell getprop sys.boot_completed 2>$null) -match '1'
  } until ($done -or (Get-Date) -gt $deadline)
  if (-not $done) { throw 'emulator boot ไม่เสร็จใน 4 นาที' }
  Write-Host '  boot เสร็จ' -ForegroundColor Green
}

switch ($Action) {
  'status' {
    & flutter devices
    Write-Host ''
    & flutter emulators
  }

  'start' {
    if (Get-Target) {
      Write-Host "emulator กำลังรันอยู่แล้ว ($(Get-Target))" -ForegroundColor Yellow
    }
    else {
      Write-Host "เปิด emulator: $Avd" -ForegroundColor Cyan
      Start-Process -FilePath $emulatorExe -ArgumentList @('-avd', $Avd, '-no-boot-anim')
      Start-Sleep -Seconds 8
      $serial = Get-Target
      if (-not $serial) { throw 'เปิด emulator ไม่ขึ้น ด้านล่าง' }
      Wait-Boot -Serial $serial
    }
  }

  'stop' {
    $serial = Get-Target
    if ($serial) {
      & $adbExe -s $serial emu kill
      Write-Host 'ปิดแล้ว' -ForegroundColor Green
    }
    else {
      Write-Host 'ไม่มี emulator ที่กำลังรัน' -ForegroundColor Yellow
    }
  }

  'build' {
    Write-Host 'กำลัง build APK debug...' -ForegroundColor Cyan
    & flutter build apk --debug --no-pub @dartDefines
    if ($LASTEXITCODE -ne 0) { throw 'build ไม่สำเร็จ' }
    Write-Host "ได้ $apk" -ForegroundColor Green
  }

  'install' {
    if (-not (Test-Path $apk)) { throw "ยังไม่มี $apk — รัน .\tool\run.ps1 build ก่อน" }
    $serial = Get-Target
    if (-not $serial) { throw 'ยังไม่มี emulator — รัน .\tool\run.ps1 start ก่อน' }
    & $adbExe -s $serial install -r $apk
    if ($LASTEXITCODE -ne 0) { throw 'ติดตั้งไม่สำเร็จ' }
    Write-Host 'ติดตั้งบน emulator แล้ว' -ForegroundColor Green
  }

  'launch' {
    $serial = Get-Target
    if (-not $serial) { throw 'ยังไม่มี emulator' }
    & $adbExe -s $serial shell am start -n "$package/.MainActivity" | Out-Null
    Write-Host 'เปิดแอปแล้ว' -ForegroundColor Green
  }

  'logs' {
    $serial = Get-Target
    if (-not $serial) { throw 'ยังไม่มี emulator' }
    Write-Host 'กด Ctrl+C เพื่อหยุด' -ForegroundColor DarkGray
    & $adbExe -s $serial logcat --pid=$(& $adbExe -s $serial shell pidof $package) *
  }

  'up' {
    if (-not $SkipBuild) { & $PSCommandPath build }
    if (-not (Get-Target)) { & $PSCommandPath start } else { Wait-Boot -Serial (Get-Target) }
    & $PSCommandPath install
    & $PSCommandPath launch
    Write-Host ''
    Write-Host 'พร้อมใช้งาน — ดู log ด้วย: .\tool\run.ps1 logs' -ForegroundColor Green
  }
}
