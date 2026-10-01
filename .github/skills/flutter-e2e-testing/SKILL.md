---
name: flutter-e2e-testing
description: 'Test this Flutter marketplace app end to end with flutter-skill. Use for UI smoke tests, login and purchase flows, seller catalog workflows, form validation, navigation checks, or screenshots on a running app. Requires an available flutter-skill MCP server and an instrumented app.'
---

# Flutter E2E Testing

Use `flutter-skill` to explore and verify the running app through its UI. Prefer observable user workflows over implementation assumptions, and report only states that were actually verified.

## Before Testing

1. Identify the requested workflow, platform/device, required account role, preconditions, and observable success state. Ask only for missing details that affect the test.
2. Check that the `flutter-skill` MCP tools are available and that the app is running or can be launched in the requested environment.
3. Check project instrumentation before attempting a launch. This workspace currently has no `flutter_skill` dependency in `pubspec.yaml` and no `FlutterSkillBinding` initialization in `lib/main.dart`. If that is still true, report the missing prerequisite and stop; do not run `flutter-skill init`, change app code, add packages, or alter MCP configuration unless the user explicitly asks for setup.
4. Use designated test accounts and non-production services. Do not place real orders, trigger real payments, or change production data. If the environment or test data could cause an external side effect, confirm before proceeding.

## Test Procedure

1. Connect to or launch the app using the available `flutter-skill` tools. Confirm the expected app and initial screen with a screenshot before interacting.
2. Call `inspect_interactive()` to discover current controls. Prefer targets in this order: semantic `ref` from inspection, widget key, visible text, then coordinates as a last resort.
3. Perform the requested workflow one meaningful action at a time. After each action, take a screenshot and confirm the expected UI response. After navigation, wait for the destination element before continuing.
4. Verify outcomes explicitly using visible text, element presence or absence, field values, and screenshots. For validation scenarios, submit the form and verify each requested error state. Do not infer backend success solely from a button tap or loading indicator.
5. If an element is missing or the app reaches an unexpected state, take a screenshot, inspect the current elements, and check app logs. Retry only after identifying a plausible transient cause; otherwise stop and report the blocker.
6. For workflows in this app, use the existing coverage as a guide: login and purchase, and seller catalog. Do not claim an automated test suite passed when you only exercised the UI interactively.
7. Leave test-created data in place unless cleanup is clearly safe and authorized. Never clean up production data.

## Reporting

Summarize the tested platform, workflow, and verified result. Separate passed checks from failures and blocked checks. For each failure, include the last confirmed state, the unexpected behavior, and relevant app logs or screenshot evidence when available. State setup or environment limitations plainly; do not imply a check ran when it did not.

## Troubleshooting

- If no app is connected, use the available scan/connect action or launch the target app, then verify the connection before testing.
- If inspection returns no controls, confirm the screen loaded with a screenshot, check app logs, and retry once after a short wait.
- If the app cannot be reached because the Flutter skill bridge is missing, follow the setup instructions in the upstream [flutter-skill repository](https://github.com/ai-dashboad/flutter-skill) only after the user authorizes project setup.
- If a navigation wait times out, capture the current screen and logs, then report the actual state rather than assuming navigation succeeded.