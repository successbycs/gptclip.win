AI-BRIDGE v1 (Clipboard -> Notepad++)

DOWNLOAD + UNZIP
1) Download: AI-bridge-v1.zip
2) Right-click the zip -> Extract All...
3) Choose where you want it (Desktop is fine)
4) You should end up with a folder like:
   AI-bridge-v1\
     run_ai_bridge.ahk
     README.txt
     scratch\

WHAT THIS TOOL DOES
- You copy text (for example a ChatGPT code block).
- You press a hotkey.
- Notepad++ opens a NEW file and pastes your copied text into it.
- The new file is saved into the scratch folder next to this script.

PREREQUISITES (install once)
1) AutoHotkey v2
2) Notepad++

START THE TOOL
1) Open the AI-bridge-v1 folder
2) Double-click: run_ai_bridge.ahk
3) Confirm the green "H" icon appears in the Windows tray (bottom-right, maybe under the ^ hidden icons)

HOTKEYS
- Ctrl + Alt + N : Run (create new file + paste clipboard)
- Ctrl + Alt + T : Test (shows a popup to confirm the script is running)
- Ctrl + Alt + L : Open logs folder
- Ctrl + Alt + R : Reload the script (useful if you edit the file)

HOW TO USE
1) In ChatGPT, click Copy on a code block (or copy any text from anywhere)
2) Press Ctrl + Alt + N
3) Notepad++ will open a new file and paste the content
4) The file will be created in:
   AI-bridge-v1\scratch\

LOGS (where they are)
Logs are saved to:
  %LOCALAPPDATA%\AI-bridge\logs\runs.tsv

Fast way to open logs:
- Press Ctrl + Alt + L

SCRATCH CLEANUP (optional)
The script can delete scratch files older than 30 days.
This is controlled inside run_ai_bridge.ahk near the top:
- AI_BRIDGE_PURGE_ENABLED := true / false
- AI_BRIDGE_SCRATCH_RETENTION_DAYS := 30

TROUBLESHOOTING
1) Hotkeys do nothing
- The script is not running. Start run_ai_bridge.ahk and confirm the green H tray icon is visible.
- If you have AutoHotkey v1 installed as well, right-click the script and choose "Run with AutoHotkey v2".

2) Error: CLIP_EMPTY
- Your clipboard has no text. Copy text (not an image or file) and try again.

3) Error: NPP_NOT_FOUND
- Notepad++ is not installed in a standard location. Install Notepad++ normally and try again.

OPTIONAL: START ON LOGIN (AUTO-RUN)
1) Press Win + R
2) Type: shell:startup
3) Create a shortcut to run_ai_bridge.ahk inside that Startup folder
