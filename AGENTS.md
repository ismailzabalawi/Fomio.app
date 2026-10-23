# Fomio iOS project instructions

- Read `README.md` and the documents it links before implementing app features.
- Build a native SwiftUI client backed by Discourse. Keep Discourse authoritative for community data, permissions, and posting rules.
- Use `/Volumes/Develop/Projects/Dicourse` as the local backend source reference. The spelling is intentional. Check its revision before relying on previously recorded behavior.
- Confirm API contracts through routes, controllers, serializers, authorization, and request specs. Route existence alone does not establish availability on the deployed site.
- Record verification status and unresolved assumptions in `docs/discourse-api-reference.md`. Keep documentation current when implementation establishes new facts.
- Use per-user authentication for member actions; never embed an administrator API key in the app or documentation.
- Treat the backend checkout as a reference. Backend changes require a task that authorizes them.
- Do not invent a deployed base URL, enabled plugin list, or credentials. These resources are still pending.
- Reuse existing simulators. Default to the installed "iPhone 17 Pro" (select by name, not UDID) and the installed "iPad Pro 11-inch (M5)" for iPad checks. Do not create, clone or erase simulators (`simctl create/clone/erase`) unless the task asks for it. If the default device is busy with another session's run, wait or report it instead of creating a new one. Evidence from a reused simulator is valid acceptance evidence.
