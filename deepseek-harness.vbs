Option Explicit
' Entry point. Paths resolve against THIS file's folder, never the caller's CWD, so the
' shortcut's "start in" value and where you double-click from no longer matter.
Dim shell, fso, scriptDir, target
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
target = fso.BuildPath(scriptDir, "deepseek-harness\deepseek-harness-tray.ps1")

If Not fso.FileExists(target) Then
    MsgBox "找不到 " & target, 16, "deepseek-harness"
    WScript.Quit 1
End If

shell.CurrentDirectory = scriptDir
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & target & """", 0, False
