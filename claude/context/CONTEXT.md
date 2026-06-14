# Context discipline

- Auto-compact handles the hard limit near the top of the window. Don't nag
  `/compact` or `/clear` on a token count alone — keep working.
- Recommend `/clear` only when the next prompt starts genuinely unrelated work
  (fresh task, no shared state). Recommend `/compact` only when actively losing
  needed earlier context, not preemptively.
- Still prefer self-contained chunks: finish a logical unit before starting the
  next. This is about clean handoffs, not a token ceiling.
- Don't pre-load unneeded context: read the slice you need, not whole file;
  targeted search over broad dump.
