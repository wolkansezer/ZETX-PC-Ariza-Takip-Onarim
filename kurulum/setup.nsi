Unicode true
SetCompressor /SOLID lzma
!include "MUI2.nsh"
!include "x64.nsh"

!define APPNAME "ZETX PC Arıza Takip Onarım"
!define APPEXE "ZETX PC Ariza Takip Onarim.exe"
!define VERSION "1.3.1"
!define PUBLISHER "Volkan Sezer — ZETX"
!define REGKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\ZETXPCArizaTakipOnarim"
!define TASKNAME "ZETX PC Ariza Takip - Haftalik Tarama"

Name "${APPNAME}"
OutFile "ZETX PC Ariza Takip Onarim Setup.exe"
InstallDir "$PROGRAMFILES64\ZETX PC Ariza Takip Onarim"
InstallDirRegKey HKLM "${REGKEY}" "InstallLocation"
RequestExecutionLevel admin
BrandingText "ZETX • Volkan Sezer"
VIProductVersion "1.3.1.0"
VIAddVersionKey /LANG=1055 "ProductName" "ZETX PC ARIZA TAKIP ONARIM"
VIAddVersionKey /LANG=1055 "CompanyName" "ZETX - Volkan Sezer"
VIAddVersionKey /LANG=1055 "FileDescription" "ZETX PC ARIZA TAKIP ONARIM Kurulum"
VIAddVersionKey /LANG=1055 "FileVersion" "1.3.1.0"
VIAddVersionKey /LANG=1055 "LegalCopyright" "(c) Volkan Sezer - Ucretsiz"

!define MUI_ICON "zetx.ico"
!define MUI_UNICON "zetx.ico"
!define MUI_ABORTWARNING
!define MUI_WELCOMEFINISHPAGE_BITMAP "wizard.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "wizard.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP "header.bmp"
!define MUI_WELCOMEPAGE_TITLE "ZETX PC Arıza Takip Onarım Kurulumu"
!define MUI_WELCOMEPAGE_TEXT "Bu sihirbaz ZETX PC Arıza Takip Onarım ${VERSION} programını bilgisayarınıza kuracak.$\r$\n$\r$\nDonanım ve sistem arızalarını tespit eder, tek tıkla onarır; sürücü/BIOS kontrolü, darboğaz analizi, oyun FPS tahmini ve ölçümü yapar.$\r$\n$\r$\nProgram tamamen ücretsizdir.$\r$\n$\r$\nDevam etmek için İleri’ye tıklayın."
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APPEXE}"
!define MUI_FINISHPAGE_RUN_TEXT "ZETX PC Arıza Takip Onarım’ı şimdi başlat"
!define MUI_FINISHPAGE_LINK "Discord topluluğuna katıl"
!define MUI_FINISHPAGE_LINK_LOCATION "https://discord.gg/nvqc84AHZf"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "license_tr.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "Turkish"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "Bu program 64 bit Windows 10 / 11 gerektirir."
    Abort
  ${EndIf}
  SetRegView 64
FunctionEnd

Section "Program dosyaları (gerekli)" SecMain
  SectionIn RO
  SetOutPath "$INSTDIR"
  File "${APPEXE}"
  File "ZETX-PC-Ariza-Takip-Onarim.ps1"
  File "zetx.ico"
  File /oname=BeniOku.txt "KURULUM-OKU.txt"
  WriteUninstaller "$INSTDIR\Kaldir.exe"
  ; Başlat menüsü
  CreateDirectory "$SMPROGRAMS\ZETX"
  CreateShortCut "$SMPROGRAMS\ZETX\ZETX PC Arıza Takip Onarım.lnk" "$INSTDIR\${APPEXE}" "" "$INSTDIR\zetx.ico" 0
  CreateShortCut "$SMPROGRAMS\ZETX\ZETX PC Arıza Takip Onarım'ı Kaldır.lnk" "$INSTDIR\Kaldir.exe" "" "$INSTDIR\zetx.ico" 0
  ; Programlar ve Özellikler kaydı
  WriteRegStr HKLM "${REGKEY}" "DisplayName" "${APPNAME}"
  WriteRegStr HKLM "${REGKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${REGKEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKLM "${REGKEY}" "DisplayIcon" "$INSTDIR\zetx.ico"
  WriteRegStr HKLM "${REGKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${REGKEY}" "UninstallString" '"$INSTDIR\Kaldir.exe"'
  WriteRegStr HKLM "${REGKEY}" "QuietUninstallString" '"$INSTDIR\Kaldir.exe" /S'
  WriteRegStr HKLM "${REGKEY}" "URLInfoAbout" "https://discord.gg/nvqc84AHZf"
  WriteRegStr HKLM "${REGKEY}" "HelpLink" "https://discord.gg/nvqc84AHZf"
  WriteRegStr HKLM "${REGKEY}" "Comments" "Ücretsiz PC arıza tespit ve onarım programı"
  WriteRegDWORD HKLM "${REGKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${REGKEY}" "NoRepair" 1
  WriteRegDWORD HKLM "${REGKEY}" "EstimatedSize" 400
SectionEnd

Section "Masaüstü kısayolu" SecDesk
  CreateShortCut "$DESKTOP\ZETX PC Arıza Takip Onarım.lnk" "$INSTDIR\${APPEXE}" "" "$INSTDIR\zetx.ico" 0
SectionEnd

LangString DESC_Main ${LANG_TURKISH} "Programın çalışması için gereken dosyalar."
LangString DESC_Desk ${LANG_TURKISH} "Masaüstüne program kısayolu ekler."
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMain} $(DESC_Main)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesk} $(DESC_Desk)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Function un.onInit
  SetRegView 64
FunctionEnd

Section "Uninstall"
  nsExec::Exec 'schtasks.exe /Delete /TN "${TASKNAME}" /F'
  Delete "$INSTDIR\${APPEXE}"
  Delete "$INSTDIR\ZETX-PC-Ariza-Takip-Onarim.ps1"
  Delete "$INSTDIR\zetx.ico"
  Delete "$INSTDIR\BeniOku.txt"
  Delete "$INSTDIR\Kaldir.exe"
  RMDir "$INSTDIR"
  Delete "$DESKTOP\ZETX PC Arıza Takip Onarım.lnk"
  Delete "$SMPROGRAMS\ZETX\ZETX PC Arıza Takip Onarım.lnk"
  Delete "$SMPROGRAMS\ZETX\ZETX PC Arıza Takip Onarım'ı Kaldır.lnk"
  RMDir "$SMPROGRAMS\ZETX"
  DeleteRegKey HKLM "${REGKEY}"
  MessageBox MB_YESNO|MB_ICONQUESTION "Raporlar, tarama geçmişi ve kayıt defteri yedekleri (Belgeler\ZETX PC Ariza Takip) de silinsin mi?$\r$\n$\r$\nHayır derseniz bu dosyalar korunur." /SD IDNO IDNO keep
    RMDir /r "$DOCUMENTS\ZETX PC Ariza Takip"
  keep:
SectionEnd
