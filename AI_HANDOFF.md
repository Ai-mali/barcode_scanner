# AI Handoff Prompt

If you lose access to your previous AI assistant, paste the prompt below into ANY new AI chat (ChatGPT, Claude, Devin, Gemini, Copilot, etc.) to continue working on this project from where we left off.

---

## How to use

1. Open a new AI chat
2. Copy everything between the `===== PROMPT =====` markers below
3. Paste it as your first message to the AI
4. The AI will read this repo, understand the full state, and you can continue from there

---

```
===== PROMPT =====

I am continuing work on a Flutter Android barcode scanner app. The full source code, project structure documentation, and changelog of every change made so far live in this GitHub repository:

  https://github.com/Ai-mali/barcode_scanner

Before answering anything, please:

1. Fetch and read https://github.com/Ai-mali/barcode_scanner/blob/main/README.md
2. Fetch and read https://github.com/Ai-mali/barcode_scanner/blob/main/PROJECT_FLOW.md (this contains mermaid diagrams of the architecture, the state machine, the screen layout, every feature, and a dated changelog of all changes)
3. Fetch and read https://github.com/Ai-mali/barcode_scanner/blob/main/lib/main.dart (the entire app code in a single file)

Once you have read those three files, briefly summarize back to me:
  - What the app does
  - The current state per the most recent changelog entry in PROJECT_FLOW.md
  - The architecture (state machine + Stack-based camera overlay pattern)

Then ask me what I want to work on next. My environment:
  - Windows 10 PC
  - Flutter SDK installed at C:\develop\flutter
  - Project folder: C:\Users\Office\flutter_projects\barcode_scanner
  - Editing with Notepad (so when you give me code edits, please give exact Ctrl+F search strings and complete code blocks I can copy-paste)
  - Test device: Tecno POVA 5 Pro 5G, Android 14, connected via wireless ADB
  - I commit and push to GitHub after each change with: git add . / git commit -m "..." / git push

When proposing changes, follow the same pattern that has been working:
  - Tell me which file to edit (always lib\main.dart unless stated otherwise)
  - Give me a Ctrl+F search string to locate the block
  - Show me the BEFORE block and the AFTER block to paste
  - Tell me what to do in the terminal afterward (q + flutter run, or Shift+R for hot restart)
  - At the end, remind me to commit and push, and to add a one-line entry to section 8 (Changelog) of PROJECT_FLOW.md describing what changed

Architecture rules to preserve:
  - MobileScanner widget is ALWAYS mounted at the bottom of a Stack — never call _controller.stop() during state transitions; render review screens as Positioned.fill overlays on top
  - ScannedItem.itemNumber is permanent; deleting an item leaves a gap in numbering, _nextItemNumber only increments
  - Model regex: ^[A-Z]{2,}[A-Z0-9]+$, Serial regex: K\d+, Tracking ignore: ^\d{3,}-\d{2,}$

Confirm you have read the files and summarize the state, then wait for my next request.

===== END PROMPT =====
```

---

## What the AI will do

The new AI will fetch the three files from GitHub, summarize the current state, and wait for your instructions. Because PROJECT_FLOW.md has the full changelog, the AI knows exactly which features exist and what was changed last. Because lib/main.dart is in the repo, it can give you precise edits that match your actual current code.

## What you need to keep doing

After every change you push, add a one-line bullet to PROJECT_FLOW.md section 8 (Changelog) describing what changed and the date. That keeps this handoff accurate for any future AI.

## What to do if you also lose access to GitHub

You'd lose the project entirely. **Two ways to prevent that**:

1. **Add a co-maintainer** to the GitHub repo: Settings → Collaborators → invite a trusted email/GitHub account
2. **Local backup**: occasionally zip your `C:\Users\Office\flutter_projects\barcode_scanner` folder to a USB drive or a cloud drive (OneDrive, Google Drive)

The combination of GitHub + a second backup means you're protected even if your GitHub account itself is locked.

## Important: this repo is private

If you want another AI to fetch the files automatically (like the prompt above asks), you'll need to either:
- **Make the repo public temporarily** (Settings → General → Danger Zone → Change visibility), OR
- **Manually paste the contents** of README.md, PROJECT_FLOW.md, and lib/main.dart into the AI chat instead of having it fetch them

For most AIs, public is the easier path — your code has nothing sensitive in it (no API keys, no secrets, just barcode-scanning logic).