Option Explicit
' The only file you need to click. Everything else lives in C:\Users\user001\dsh
Dim shell, fso, target
target = "C:\Users\user001\dsh\dsh-tray.ps1"
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

If Not fso.FileExists(target) Then
    MsgBox "找不到 " & target, 16, "dsh"
    WScript.Quit 1
End If

shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & target & """", 0, False
