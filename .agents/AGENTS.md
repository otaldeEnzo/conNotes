# Project Behavioral & Design Rules

## Iconography Rule
- **No Emojis**: Never use emojis anywhere in the application (UI, icons, labels, defaults, modals, toolbars, sidebars, or headers).
- **SVG Icons Only**: Use vector SVG elements (`svg { ... }` or icon components from `src/icons.rs`) for all iconography, status indicators, tabs, buttons, and note type identifiers.

## Visual Design & Aesthetics Rule (Moscaro Modern Standard)
- **Moscaro Aesthetic**: All generated UI, layouts, modals, popovers, expandable menus, sidebars, note views, and custom scrollbars must adhere to the **Moscaro** modern aesthetic.
- **Design Specifications**:
  - Dark liquid glass backdrop (`rgba(14, 16, 24, 0.92)` or `rgba(18, 20, 28, 0.95)`) with backdrop blur (`backdrop-filter: blur(20px)`).
  - Subtle cyan glowing borders (`rgba(0, 225, 255, 0.3)` or `#00e1ff`) and glowing drop-shadows.
  - Smooth rounded corners (`border-radius: 12px` to `16px`) and pill-shaped action bars.
  - Custom sleek scrollbars (`::-webkit-scrollbar` styled with thin dark tracks and cyan/purple translucent thumbs).
  - Smooth hover micro-animations and micro-interactions for buttons, tabs, and collapsible panels.
