## Watermelon UI reference findings

The public Watermelon UI site describes itself as an open-source React UI platform with animated components, copy-paste blocks, dashboards, templates, and showcases. Its public catalog includes animated interactions and source-backed implementation paths.

Relevant references:

- Watermelon UI home: https://ui.watermelon.sh/
- Components catalog: https://ui.watermelon.sh/components
- Marketing animated components: https://ui.watermelon.sh/animated-components/category/marketing
- Changelog: https://ui.watermelon.sh/changelog
- Public source repository: https://github.com/WatermelonCorp/watermelon-platform

The catalog emphasizes animated interactions, polished micro-interactions, smooth transitions, shared-layout-style motion, responsive behavior, accessibility, and reduced layout shifts. The current storefront already uses Anime.js from `https://cdn.jsdelivr.net/npm/animejs@4.5.0/dist/bundles/anime.umd.min.js`, so the safe implementation is to adapt these principles using the existing runtime rather than adding a second animation framework or copying a component wholesale.

Planned adaptations: interactive card-level add-to-bag controls with a short press/feedback transition; staggered card entrance and hover lift already present, refined with quick-action reveal; product-gallery swipe gestures that coexist with the existing previous/next buttons and thumbnails; and a compact cart cleanup notice when discontinued catalogue items are removed from local storage. All motion will respect `prefers-reduced-motion` through the existing `reduced()` helper.
