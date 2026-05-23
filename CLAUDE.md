# CLAUDE.md

## Project role

You are assisting with the update, refactor, and optimization of an existing video downloader GitHub repository.

The repository already has working behavior. Your job is to improve the project safely without breaking existing features.

Primary goals:

- Improve code quality.
- Improve maintainability.
- Improve error handling.
- Improve download stability.
- Improve configuration clarity.
- Improve documentation.
- Preserve existing user-facing behavior unless a change is explicitly requested.
- Avoid unnecessary rewrites.

---

## Repository rules

- Do not modify unrelated files.
- Do not rewrite the whole project unless explicitly requested.
- Follow the existing code style.
- Preserve existing naming conventions, comments, indentation, and file structure unless a change is required.
- Before editing, inspect the target file and nearby related files.
- Before making large changes, understand the current control flow.
- Prefer small, incremental, reviewable changes.
- Do not push to remote.
- Do not delete files unless explicitly requested or clearly obsolete.
- Do not remove existing features without documenting why.
- Do not introduce new external dependencies unless necessary.
- If a new dependency is required, explain why it is needed and update the dependency file.
- If a requested change is ambiguous, make the smallest safe change and document the assumption.
- After editing, check `git diff` carefully.
- Keep commits small and logically separated.

---

## Safety rules for video downloader projects

This project may interact with network resources, external websites, local files, and user-provided URLs.

Follow these rules strictly:

- Do not add code that bypasses paywalls, authentication, DRM, or access controls.
- Do not add code intended for unauthorized downloading.
- Do not hardcode personal accounts, cookies, tokens, API keys, or credentials.
- Do not log sensitive data such as cookies, tokens, full authorization headers, or private URLs.
- Do not silently overwrite existing downloaded files.
- Do not write files outside the configured output directory unless explicitly requested.
- Validate user-provided URLs and file paths.
- Sanitize filenames before saving.
- Handle network failures gracefully.
- Handle partial downloads safely.
- Do not execute downloaded files.
- Do not add shell execution unless strictly necessary and clearly justified.

---

## Target areas

Main target areas may include:

- CLI interface
- URL parsing
- Download logic
- Retry logic
- Progress display
- Logging
- Configuration
- Error handling
- Output path handling
- README / usage documentation
- Tests
- Packaging files

Before editing, scan the repository and identify the actual project structure.

Common files/directories to inspect first:

- `README.md`
- `requirements.txt`
- `pyproject.toml`
- `package.json`
- `src/`
- `app/`
- `lib/`
- `tests/`
- `docs/`
- `.gitignore`

Do not assume the language or framework before inspecting the repository.

---

## Workflow

Follow this workflow for every task:

1. Inspect the repository structure.
2. Read the relevant files before editing.
3. Identify the smallest safe change.
4. Update `PLANS.md` if the task is multi-step.
5. Edit one logical area at a time.
6. Run available checks.
7. Inspect `git diff`.
8. Update `CLAUDE_PROGRESS.md`.
9. Commit the completed change.
10. Stop before pushing.

---

## Planning file

If the task requires multiple steps, create or update `PLANS.md`.

Use this format:

```md
# PLANS.md

## Goal

Describe the current optimization or update goal.

## Scope

Files/directories that may be edited:

- path/to/file
- path/to/directory/

Files/directories that must not be edited:

- unrelated/path/

## Workflow

1. Inspect current implementation.
2. Identify required changes.
3. Apply small edits.
4. Run checks.
5. Review diff.
6. Commit completed changes.

## Task list

| Task | Status | Notes |
|---|---|---|
| Inspect repository | pending | - |
| Improve error handling | pending | - |
| Update README | pending | - |

```

---

## Progress file

Create or update `CLAUDE_PROGRESS.md` after each completed step.

Use this format:

```md
# CLAUDE_PROGRESS.md

## File status

| File | Status | Commit | Notes |
|---|---|---|---|
| path/to/file | pending | - | - |
| path/to/file | done | abc1234 | Updated safely |

## Current assumptions

- Existing behavior should be preserved.
- No remote push is allowed.
- Changes should be small and reviewable.
- New dependencies should be avoided unless necessary.

## Completed work

| Step | Result |
|---|---|
| Repository scan | Completed |
| Download logic review | Pending |
| README update | Pending |

## Remaining work

- List remaining tasks here.

```

---

## Commit rules

Commit after each completed logical change.

Preferred commit format:

```text
<area>: <short description>

```

Examples:

```text
download: add retry handling for transient network errors
cli: improve invalid URL error message
config: validate output directory before download
docs: update usage examples in README
tests: add coverage for filename sanitization

```

Before every commit:

- Run available formatting/check commands.
- Confirm `git status`.
- Confirm `git diff`.
- Confirm only intended files changed.
- Do not include unrelated formatting changes.
- Do not include generated files unless required.

---

## Verification

Use whatever checks are available in the repository.

For Python projects, check for commands such as:

```bash
python -m pytest
python -m unittest
python -m compileall .
ruff check .
black --check .
mypy .

```

For Node.js projects, check for commands such as:

```bash
npm test
npm run lint
npm run build
npm run typecheck

```

For general projects:

```bash
git status
git diff

```

If no test or lint command exists, document this in `CLAUDE_PROGRESS.md`.

Do not invent passing test results. If a command was not run, say so.

---

## Refactoring rules

When refactoring:

- Preserve public behavior.
- Prefer extracting small helper functions over rewriting large files.
- Avoid changing function signatures unless necessary.
- Avoid changing CLI arguments unless explicitly requested.
- Avoid changing output format unless required.
- Keep backward compatibility when possible.
- Add comments only where they clarify non-obvious logic.
- Do not over-engineer.
- Do not introduce abstractions without immediate benefit.

---

## Error handling rules

Improve error handling carefully.

Good error handling should:

- Show clear user-facing messages.
- Preserve useful debug information in logs.
- Avoid exposing sensitive data.
- Distinguish between invalid input, network failure, permission failure, and unsupported URL.
- Avoid crashing on common recoverable errors.
- Use specific exceptions where possible.
- Avoid broad silent `except` blocks.

---

## Logging rules

When adding or modifying logs:

- Do not log secrets.
- Do not log cookies.
- Do not log authorization headers.
- Do not log full private URLs if they may contain tokens.
- Prefer concise, actionable messages.
- Keep debug logs useful for troubleshooting.
- Keep normal output clean.

---

## Download behavior rules

When touching download logic:

- Preserve existing supported sites and formats.
- Preserve existing output naming behavior unless explicitly requested.
- Avoid overwriting existing files silently.
- Handle interrupted downloads when possible.
- Handle slow or unstable networks gracefully.
- Use timeouts where appropriate.
- Use retry logic only for safe transient failures.
- Do not retry permanent errors indefinitely.
- Validate output paths before writing files.

---

## Dependency rules

Before adding a dependency:

1. Check whether the existing code already has a suitable utility.
2. Check whether the standard library is enough.
3. Explain why the dependency is necessary.
4. Update dependency files.
5. Update documentation if users need to install anything new.

Avoid large dependencies for small utilities.

---

## Documentation rules

When updating documentation:

- Keep examples accurate.
- Use commands that match the actual project.
- Do not document features that do not exist.
- Include basic usage examples.
- Include installation steps if missing.
- Include troubleshooting notes if relevant.
- Clearly mark optional features.

---

## Cursor / Claude behavior rules

When responding in chat:

- Explain what you changed.
- Mention files modified.
- Mention checks run.
- Mention assumptions made.
- Mention remaining risks.
- Do not claim tests passed unless they were actually run.
- If unable to complete something, explain the exact blocker.

When editing files:

- Prefer direct edits over broad rewrites.
- Do not modify unrelated formatting.
- Do not rename files casually.
- Do not push to remote.
- Stop after committing the requested changes.

---

## Default task strategy

For a general “update and optimize this video downloader” request, proceed in this order:

1. Inspect repository structure.
2. Identify language, framework, entry point, and dependency system.
3. Read README and main source files.
4. Create `PLANS.md`.
5. Create `CLAUDE_PROGRESS.md`.
6. Check whether tests exist.
7. Run existing tests if available.
8. Improve only the safest high-value areas first:
  - error messages
  - input validation
  - output path safety
  - retry handling
  - logging cleanup
  - README accuracy
9. Commit each logical change separately.
10. Stop before pushing.

---

## Prohibited actions

Do not do the following unless explicitly instructed:

- Push to remote.
- Force push.
- Rewrite Git history.
- Delete branches.
- Delete large parts of the project.
- Replace the entire implementation.
- Add DRM bypass logic.
- Add credential scraping.
- Add cookie theft or browser profile extraction.
- Add hidden telemetry.
- Add background services.
- Add auto-update behavior.
- Add unrelated features.
- Change license text.
- Change author information.




