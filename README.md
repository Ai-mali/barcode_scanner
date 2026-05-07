# Daikin Barcode Scanner

A Flutter Android app that scans Daikin equipment labels (model + serial), accumulates multiple items, and exports the result as CSV.

## Status

Working multi-item scanner with full UI polish. Tested on Tecno POVA 5 Pro 5G, Android 14.

## Where to look

- **[PROJECT_FLOW.md](PROJECT_FLOW.md)** — full project documentation: state machine, screen layout, feature list, and changelog of every update
- **[AI_HANDOFF.md](AI_HANDOFF.md)** — copy-paste prompt for any AI assistant (ChatGPT, Claude, Devin, Gemini) to continue working on this project
- **`lib/main.dart`** — the entire app code (single file)
- **`pubspec.yaml`** — dependencies

## Run on a connected Android phone

```bash
flutter pub get
flutter run
```

## Continuing this project with another AI

If you ever need a different AI assistant to help, open **[AI_HANDOFF.md](AI_HANDOFF.md)** and paste the prompt inside into any AI chat. It will tell that AI to read this repo and pick up exactly where we left off.