---
name: lavish
description: Use when a plan, comparison, diagram, table, code diff, report, or any UI is easier to grasp visually than as prose. Renders an HTML artifact the user can open, annotate, and send feedback on, then polls for that feedback.
---

# lavish

Turn complex or visual output into a reviewable HTML artifact the user annotates in a local browser, instead of a wall of markdown. Run the CLI with `bunx lavish-axi` (no global install needed).

## When to use

Plans, option comparisons, architecture diagrams, data tables, code diffs, status reports, or any UI mockup. Skip it for short prose answers.

## Workflow

1. Write a self-contained HTML file (inline all CSS/JS) for the content.
2. Open the review session:
   ```
   bunx lavish-axi <file.html>
   ```
3. Poll for the user's annotations and feedback:
   ```
   bunx lavish-axi poll <file.html>
   ```
4. Apply the feedback, let live-reload refresh, repeat poll until the user is satisfied.
5. End the session:
   ```
   bunx lavish-axi end
   ```

## Styling priority

1. A design system the user named.
2. The project's existing design tokens or Tailwind config.
3. Fallback: Tailwind v4 + DaisyUI v5 via CDN.

## Constraint

Prevent horizontal overflow at every nesting level. Wide content (tables, diagrams, code) scrolls inside its own container; the page body never scrolls sideways.
