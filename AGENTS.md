# Repository Guidelines

## Project Structure & Module Organization

This repository is currently an empty scaffold for `soccer_schedule`. No application source, tests, assets, or dependency manifests are present. The mobile framework and language have not been established.

When scaffolding the application, follow the chosen framework’s standard layout. Keep application code, automated tests, and static assets in clearly separated directories, and update this guide with their actual paths. Organize scheduling features into focused modules rather than a single large screen or file.

## Build, Test, and Development Commands

No build, development, lint, or test commands are configured yet. Do not assume that commands such as `npm test` or `flutter test` are available.

When adding tooling, document the exact dependency installation, local development, production build, lint, and test commands in the project README. Commit dependency manifests and appropriate lockfiles so contributors can reproduce the environment.

## Coding Style & Naming Conventions

No formatter, linter, or language-specific style rules exist yet. Adopt the selected framework’s conventions and configure formatting and linting alongside the first implementation.

Use descriptive names that reflect soccer scheduling concepts. Keep indentation consistent within each file, avoid unrelated formatting changes, and prefer small modules with explicit responsibilities.

## Testing Guidelines

No testing framework or coverage threshold is configured. Establish tests with the initial application setup and document how to run them. Follow the selected framework’s test naming conventions and keep test names descriptive of expected behavior.

Prioritize schedule ordering, date and time handling, and user-visible scheduling behavior as those features are introduced.

## Commit & Pull Request Guidelines

Git history is unavailable in this directory, so no existing commit convention can be verified. Use short, imperative commit subjects, such as `Add match schedule screen`, and keep each commit focused.

Pull requests should describe the change, include validation commands and results, link relevant issues, and provide screenshots for visible interface changes. Explicitly note checks that could not be run.

## Security & Configuration

Keep credentials and local configuration out of committed files. Provide placeholder values in an example configuration file when environment variables are introduced.
