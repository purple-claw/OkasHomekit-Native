# OKAS Rebrand — Execution Checklist

## Phase 1 — Foundation
- [x] 1. sh_colors.dart: soft status colors, glow shadow, cardXl radius
- [x] 2. sh_theme.dart: refined weight contrast + shadow tiers + transitions
- [x] 3. sh_motion.dart: SHMotion fast/medium/sheet + reduced respect
- [x] 4. lighted_background.dart: layered gradient with brand radial highlights

## Phase 2 — Reusable widgets
- [x] 5–9. SKIPPED as planned: styles were inlined directly into screens
      (status_pill/active_load_tile/room_card_v2/section_header/motion were
      never created — 0 references; building them now would be dead code)

## Phase 3 — Bottom navigation + tiles
- [x] 10. sm_home_bottom_navigation.dart
- [x] 11. load_grid_card.dart

## Phase 4 — Major screens
- [x] 12. home_screen.dart
- [x] 13. lounge_screen.dart (via core.dart brand palette)
- [x] 14. rooms_screen.dart
- [x] 15. room_loads_screen.dart
- [x] 16. scene_screen.dart
- [x] 17. profile_screen.dart

## Phase 5 — Auth flow
- [x] 18. splash_screen.dart
- [x] 19. token_entry_screen.dart (2-option auth: email/password for admin,
      token for guest, forgot-password via owner token)
- [x] 20. figma_load_sheets.dart absorbed into room_loads_screen.dart

## Verification
- [x] 21. flutter analyze: 0 errors, 0 warnings
- [ ] 22. Functional regressions check (device pass)
