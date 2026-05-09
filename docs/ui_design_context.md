# UI Design Context

## Source of truth

Current visual direction should be taken from code, not from
`lib/presentation/auth/screens/README_ONBOARDING.md`.

The README still describes an older purple palette, while the active UI in the
app already uses a light blue glassmorphism-style system.

Primary reference screens:

- `lib/presentation/onboarding/onboarding_screen.dart`
- `lib/presentation/auth/screens/login_screen.dart`
- `lib/presentation/auth/screens/register_screen.dart`
- `lib/presentation/auth/screens/setup_profile_screen.dart`
- `lib/presentation/home/home_shell.dart`
- `lib/presentation/home/screens/events_feed_screen.dart`

## Visual language

### Palette

Base tokens live in `lib/core/theme/app_colors.dart`:

- Primary: `#0961F6`
- Dark text: `#414B4E`
- Accent: `#DCE9FF`
- Background: `#E8F0FF`
- Surface: `#E1EBFF`

Common supporting colors used directly in screens:

- Page gradient: `#EAF2FF -> #D9E8FF -> #EFF5FF`
- Input fill: `#F4F8FF` / `#F5F8FF`
- Primary CTA gradient: `#0961F6 -> #2E8BFF` or `#4B94FF`
- Secondary text: `#5E6D86`, `#5D668C`, `#97A0C4`

### Shapes and spacing

- Large card radius: `24`
- Input/button radius: `16`
- Pills/chips/full-round badges: `999`
- Common page horizontal padding: `16` to `24`
- Floating surfaces use soft borders plus shadow, not hard separators

### Background treatment

- Light gradient background on auth/onboarding
- 1 to 2 oversized blurred circles placed off-screen
- Some navigation/sheets use translucent surfaces with blur

### Surface style

- White or light-blue translucent cards
- Borders with low alpha instead of strong outlines
- Soft shadows with blue-gray tint
- CTA buttons are filled with gradient and glow shadow

### Typography

- Large hero titles: `28` to `32`, weight `700` to `800`
- Body copy is calm, slightly muted, with generous line height
- Section labels often use medium/semibold instead of bold everywhere

### Iconography

- Rounded Material icons
- Icons usually tinted with primary blue
- Hero/auth icons placed inside gradient or tinted circular containers

## Reusable interaction patterns

### Auth form pattern

- Gradient page background
- Decorative circles in the corners
- One central white glass card
- Large centered title and supporting subtitle
- Filled inputs with soft blue borders
- Main action at full width with strong blue gradient

### Onboarding pattern

- Full-screen content with bottom floating action panel
- Horizontal pager
- Progress dots/active pill indicator
- Big illustration zone with soft radial/gradient treatment

### Main app pattern

- Use `AppColors` tokens
- Prefer layered surfaces over plain white blocks
- Floating bottom nav with blur in `home_shell`
- Feed/filter components already continue the updated style

## Mismatch areas

These screens still look closer to an older system and should be updated first:

- `lib/presentation/auth/screens/setup_interests_screen.dart`
- `lib/presentation/auth/screens/setup_location_screen.dart`

Why they stand out:

- Flat white background instead of blue gradient atmosphere
- Harder grayscale palette (`#75878A`, `#9E9E9E`, `#E0E0E0`)
- Simpler cards/buttons without glass/translucent treatment
- Different visual rhythm from `login`, `register`, and `setup_profile`

## Practical rules for new screens

When continuing new screens in the same style:

1. Start with `AppColors` and the auth gradient background.
2. Add subtle decorative background shapes before adding content.
3. Put the main content inside one or more soft cards with radius `24`.
4. Use inputs/buttons with radius `16`.
5. Keep the primary action visually dominant with a blue gradient.
6. Prefer muted blue-gray text over neutral gray.
7. Avoid flat white full-screen layouts unless the existing module already uses them consistently.
8. If a screen belongs to onboarding/auth, match `login/register/setup_profile` first.
9. If a screen belongs to the signed-in app shell, match `home_shell/events_feed`.

## Recommended baseline for future work

If we continue redesigning screens, use this order as the visual baseline:

1. `login_screen.dart`
2. `register_screen.dart`
3. `setup_profile_screen.dart`
4. `onboarding_screen.dart`
5. `home_shell.dart`
6. `events_feed_screen.dart`

## First candidates to restyle next

- `setup_interests_screen.dart`
- `setup_location_screen.dart`
- then profile-related inner screens that still use older neutral styling
