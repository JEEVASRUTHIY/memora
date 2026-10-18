# Contributing to Memora

## Branch Model

| Branch | Purpose |
|---|---|
| `main` | Shared base after the foundation is merged |
| `feature/<name>` | One feature per branch, branched from `main` |

## Workflow

1. `git checkout -b feature/<name> main`
2. Build your feature. Keep PRs small — one screen at a time if possible.
3. Run `flutter analyze` before opening a PR — zero warnings allowed.
4. Do **not** edit anything in `lib/core/` without noting the reason in the PR description.
5. Open a PR into `main`. All teammates must review before merge.

## Code Style

- Screens contain **no** Firestore/Firebase calls — only Riverpod provider reads.
- Models are immutable (`final` fields, `copyWith`, `fromJson`/`toJson`).
- Error strings come from `AppErrorHandler.handle()` — do not hard-code messages.
- New providers use `AsyncNotifier` / `Notifier` (Riverpod 2 API), not `StateNotifier`.

## Feature Flags

Set your feature's flag in `lib/core/feature_flags.dart` to `false` for the PR.
Enable it in a separate commit once everything is tested end-to-end.

