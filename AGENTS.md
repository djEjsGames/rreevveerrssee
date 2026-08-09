## Agent skills

### Issue tracker

Issues are tracked as local markdown files under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Triage uses the default canonical labels. See `docs/agents/triage-labels.md`.

### Domain docs

This repo uses a single-context domain docs layout. See `docs/agents/domain.md`.

## Project notes

Read `CONTEXT.md` before making gameplay, scene, Lua character, map, or editor-tool changes. Treat `Assets/_Project/` and `Assets/Editor/` as project-owned code. Treat `Library/`, `Temp/`, `Logs/`, `obj/`, `.vs/`, generated solution/project files, and third-party folders such as `Assets/Plugins/MoonSharp/` as generated or external unless the task explicitly targets them.

When runtime flow, architecture, Lua schema, map/scene setup, or editor tools change, check whether `CONTEXT.md` or `docs/agents/*.md` should be updated as living documentation.

Notion planning documents are organized as a tree under the top-level Alkkagi planning hub page. All new Notion planning documents must be created or moved under that hub, not left as standalone pages. Keep PRD work in this hierarchy: hub -> `PRD` -> individual PRD -> that PRD's issue list -> individual issue result pages. Character-planning documents also live under the hub in their own character-planning branch. Use the all-issues database only as a cross-PRD index/status table, not as the source of truth.

Keep Notion pages and local markdown files in sync. When a planning document, PRD, issue list, or issue result changes in Notion, update the corresponding local `.scratch/<feature>/` markdown when one exists. When local markdown changes first, update or create the corresponding Notion child page under the hub tree. Store Notion page links in local markdown where practical, and store local markdown paths in Notion pages.

When completing a local markdown issue that also has a Notion tracking page, create or update a Notion child page under the relevant PRD issue list page using the issue number in the title. Write the Notion summary content in Korean. Include the goal, changed files, implementation summary, verification result, remaining risks or follow-ups, and the local issue path.

For ongoing issue work, minimize token usage: avoid fetching the full Notion parent page when the page id is already known, prefer direct page IDs/URLs from local markdown, read only relevant file ranges instead of whole large files, use quiet or minimal build logs unless a failure needs detail, and keep progress reports short.

## Session scope rule

Each Codex session should have one clear work unit.

- Coordination sessions are for planning, prioritization, status checks, handoff text, and deciding what another session should do.
- Implementation sessions are for one bounded issue or one small related batch.
- If a request does not match the current session's declared work unit, do not execute it in this session. Tell the user to move it to a separate session.
- At the start of a new work session, identify the target issue/path or create a short working scope before editing files.
- Do not mix broad project coordination, implementation, Notion syncing, and release cleanup in one session unless the user explicitly declares that combined scope.
- If the session has no declared work unit or role, do not start implementation. Ask the user to assign one before proceeding.
- A valid session role should be one of: coordination, implementation, review, verification, documentation, or handoff.
- If the user request is ambiguous, first ask: "이 세션의 역할과 작업단위를 지정해 주세요."
