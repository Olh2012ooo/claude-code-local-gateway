Set WShell = CreateObject("WScript.Shell")

Desktop = WShell.SpecialFolders("Desktop")
Router = Desktop & "\Claude Code\system\gateway\router.mjs"

WShell.Run "node.exe """ & Router & """", 0, False