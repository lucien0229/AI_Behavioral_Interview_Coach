# AI Behavioral Interview Coach iOS Hi-Fi Pencil Design

Generated from the current `docs/` specifications, without reusing any existing design file.

## Files

- `AI_Behavioral_Interview_Coach_iOS_HiFi_v1.pen` - Pencil source file.
- `ai_bic_original_renderer.js` - Pencil script renderer used by the `.pen` screens.
- `exports/named_png/` - 27 named PNG screen exports.
- `exports/pdf/AI_Behavioral_Interview_Coach_iOS_HiFi_v1.pdf` - combined PDF export.

## Covered Screens

- IOS-SCR-00 through IOS-SCR-17.
- Home variants: no resume, ready, active session, resume processing, out of credits.
- First-answer variants: idle, recorded review, transcript failure.
- Completed variants: redo review generated and redo review unavailable.
- Global sheets: focus picker, paywall, delete confirmation, microphone permission.

## Design Rules Applied

- Apple-inspired neutral system: `#F5F5F7`, `#FFFFFF`, `#000000`, `#1D1D1F`.
- Apple Blue `#0071E3` is reserved for primary/secondary actions.
- No bottom tab, no marketing landing page, no chat UI.
- Home primary action is not a card; recent practice and history remain supplemental.
- Training and recording states use dark immersive screens.
- Feedback prioritizes biggest gap, redo priority, redo outline, strongest signal, and five visible assessments.
- Cards use 8pt radius or less; no nested cards or decorative gradients.
