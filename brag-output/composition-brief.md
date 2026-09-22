# Hyperframes Composition Brief: BimTalk

## Objective

Create a 22-second, app-store-style launch video for BimTalk, an offline-first Flutter app for selected BIM sign recognition, confirmed text, and spoken Malay.

## Output

- Composition directory: `C:\Users\junht\StudioProjects\fyp-handgesture\brag-output\composition\`
- Rendered video: `C:\Users\junht\StudioProjects\fyp-handgesture\brag-output\brag.mp4`
- Format: landscape — 1920x1080
- Duration: 22 seconds

## Source Material

- Project root: `C:\Users\junht\StudioProjects\fyp-handgesture`
- Primary files read: `lib/main.dart`, `lib/screens/translate_screen.dart`, `lib/screens/speak_screen.dart`, `lib/screens/dictionary_screen.dart`, `lib/screens/avatar_test_screen.dart`, `lib/logic/vision_vm.dart`, `lib/logic/gesture_logic.dart`, `lib/data/gesture_data.dart`
- Product name: BimTalk
- Tagline / strongest claim: “BIM sign language translation in real time” (use accurate wording: selected BIM signs, confirmed by the user)
- Key UI moment to recreate: a live-camera recognition screen with hand and body landmark overlays and a candidate selection card for `BAGUS`.
- Copy that must appear verbatim:
  - “When words need a hand.”
  - “You stay in control.”
  - “See the sign. Choose the word. Let it speak.”

## Creative Direction

- Tone preset: app-store
- Creative direction: calm, accessible Malaysian mobile-app launch
- Interpretation: crisp rounded cards, generous spacing, indigo-led interface, and calm feature storytelling. Do not call the app a complete BIM translator or imply it works without user confirmation.
- Angle: Show BimTalk as an intentional communication loop—AI landmarks see the sign, deterministic gesture rules suggest a word, the user confirms it, and the device speaks it.
- Hook: a hand transforms into landmark points inside a floating phone with “When words need a hand.”
- Outro / punchline: final BimTalk logo and “See the sign. Choose the word. Let it speak.”
- Avoid:
  - Generic SaaS language
  - Abstract filler visuals
  - Claims of universal BIM translation, model-trained gesture classification, or measured performance that are not demonstrated

## Visual Identity

- Background: `#F8FAFC`, with `#F5F5DC` for the introductory warmth
- Text: `#1E1B4B`
- Accent: `#6366F1`; secondary support accent `#10B981`
- Display font: clean system sans-serif / Arial fallback
- Body font: clean system sans-serif / Arial fallback
- Visual references from the project: `assets/logo.png`, `assets/translate.png`, `assets/speak.png`, `assets/avatar.png`, the live landmark overlay, rounded white cards, and the 3D avatar concept.

## Storyboard

Use `brag-output/brag-plan.md` as the creative contract.

1. Hand becomes signal — 3.00s — phone, hand silhouette, landmark dots, hook copy.
2. See the sign — 5.74s — camera-style recognition view with hand/body landmarks.
3. Choose the word — 4.37s — candidate `BAGUS`, visible confirmation tap, speech bubble.
4. Say it your way — 4.36s — typed phrase, favourites, Speak action.
5. Learn, then connect — 4.53s — 3D sign lesson cue and final logo lockup.

## Audio

- Audio role: warm, polished product bed
- Audio arc: gentle opening → clear confirmation moment → friendly speech utility → warm final resolution
- Music: `assets/music/happy-beats-business-moves-vol-12-by-ende-dot-app.mp3`
- Music treatment: volume near 0.34; start at 0s; fade from 21.2–22.0s.
- Music cue guidance: bundled preset `assets/music/cues/happy-beats-business-moves-vol-12-by-ende-dot-app.music-cues.json`; 109.96 BPM. Major locks: 8.74s candidate confirmation and 17.47s avatar reveal. Sequential Scene 4 chips can align near 13.11s and 14.20s but must retain readable holds.
- Audio-reactive treatment: subtle, if supported—use RMS/bass only to breathe the indigo phone glow and final logo halo. No waveforms, visualizers, strobing, or text scaling.
- Audio-coupled moments:
  - Landmark resolve — gentle reveal accent
  - Candidate tap — low-risk UI click
  - Speech bubble — quiet success accent
  - Final logo — one warm resolution accent
- SFX selection guidance: choose from the installed `/brag` SFX library; use only low/medium high-frequency-risk files. Prefer `interface/click_003.ogg`, `interface/bong_001.ogg`, and `impact/impactSoft_medium_001.ogg` when appropriate.
- SFX analysis guidance: `C:\Users\junht\.codex\skills\brag\assets\sfx\sfx-analysis.md`
- Exact SFX choice: select filenames, timestamps, density, and volume to match final motion.
- Audio files: copy chosen music and SFX to `brag-output/composition/assets/` before render.

## Hyperframes Instructions

Create the composition using current Hyperframes conventions. Show actual project-based UI/copy rather than a generic AI animation. Keep every on-screen line readable. Use only local composition assets. Respect the 22-second duration and run `npx hyperframes check` before rendering. If audio-reactive extraction is unavailable, document that and continue; it must not block the render.
