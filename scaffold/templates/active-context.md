# Active context

Human-chosen direction for the current effort. Not the glossary (`CONTEXT.md`).

Seeded to `active-context.md` at the repository root, never `context.md`: on the
case-insensitive filesystems macOS and Windows default to, a root `context.md` and
`CONTEXT.md` are one path, and whichever tool writes second wins — see
`docs/memory.md`.

Agents recover factual repository state via `.cursor/skills/orient-in-project/`; this file only states intent.

## Direction

<!-- One short paragraph: what we are optimizing for right now. -->

## Active goal

<!-- Concrete outcome being pursued (not implementation steps). -->

## Active specification

<!-- Both forms, on one line: F:007-auth-envelope — specs/007-auth-envelope/. The
address is what goes into a prompt, a packet or a PR body; the path is what a reader
clicks. Write "none" when no feature is active, and do not repeat the feature's
Status or Stage here — they live on its spec.md and nowhere else. -->

## Out of scope for now

<!-- Explicit non-goals that agents must not expand into. -->

## Notes for the next session

<!-- Optional pointers the human wants preserved across sessions. -->
