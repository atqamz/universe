# CODING.md

A repository `AGENTS.md` overrides this file.

Solve the whole problem with the least new code. The best code is the code never written.

## Before Writing

- Question the request: before building, push back on any part the need does not justify.
- Read the task and the code it touches.
- List every place your change must reach: callers, tests, fixtures, config, exports.
- Check what your change could break for users: data it would destroy or expose, callers that stop working.
- That list is scope. Extra features are not.

## Solution Selection

Take the first option that fully works:
- Does it need to exist? Skip features, options, and flexibility nobody asked for, and name them in one line. A vague request ("build me X") gets the smallest version that does the core job.
- Already in this codebase (a helper, component, service, pattern)? Use it the way the surrounding code does.
- Standard library or a platform feature? Use it, unless the project has its own. A house component beats a native widget.
- An installed dependency? Use it. Never add a dependency for a few lines.
- Can it be one line a reader gets at a glance? One line. Otherwise: the minimum code that works.

## Execution Rules

- Finish every part the task needs, including the callers, tests, and fixtures your change breaks.
- No abstraction, wrapper, type conversion, option, config, boilerplate, or "for later" code nobody asked for. Keep values in the form the platform already gives you.
- Deletion beats addition.
- Keep the structure the codebase already has: its layers, interfaces, and conventions.
- The shortest working diff wins, once you know everything it must touch. A one-liner that needs decoding is not short.
- Comment only the why the code cannot show, in one line.
- Bug fix: before you edit, grep every caller of the function you touch, then fix the root cause once in the shared code.
- Code you move or merge keeps its error handling and validation.
- Between options of equal size, take the one that is correct on edge cases.
- New non-trivial logic (a branch, a loop, a parser, money or security, or a whole new script or app) leaves one small test or an assert-based self-check. Trivial changes need none.
- A shortcut with a known limit gets a code comment in this form: `shortcut: <the limit>, <when to upgrade>`.

## Never Cut from Code

- Validation at trust boundaries
- Error handling that prevents data loss
- Security
- Accessibility
- The calibration real hardware needs
- Anything the user asked for
