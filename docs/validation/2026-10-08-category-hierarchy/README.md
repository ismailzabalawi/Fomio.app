# Category hierarchy consolidation — 2026-10-08

Status: complete. Following the user's action-time confirmation (“go ahead”), all six approved category records were removed through the deployed Settings UI. The authenticated directory verifies 11 public roots and 9 children, plus unchanged private Staff.

| Category to retire | ID | Parent destination | About topic |
| --- | --- | --- | --- |
| Open Discussions | 50 | General (4) | 94 |
| Questions | 51 | General (4) | 95 |
| Opinions | 52 | General (4) | 96 |
| Ideas | 53 | General (4) | 97 |
| General Fomio Discussions | 49 | Fomio (45) | 92 |
| Random | 34 | Off-topic Discussions (9) | 43 |

All six authenticated latest feeds contained only their About topic, with zero replies. Each editor exposes an enabled Delete category action. Security tabs report public everyone see/reply/create permissions. No regular discussions needed reassignment. The category deletion contract rejects categories with nonzero regular-topic count or children; recheck eligibility immediately before deletion.

Six exact former category URL permalinks target their parent IDs. Existing `c/off-topic-discussions/general-chat-randomness/34` permalink was retargeted from Random (34) to Off-topic Discussions (9). After deletion, all seven paths were opened and resolved to the intended parent URLs with matching latest-topic headings. See [redirect results](redirect-results.json).

[Preflight UI snapshots](preflight.json) capture feeds and General/Security/Settings tabs. They support review but are not a complete server backup. Deletion warning records the deployed irreversible-settings warning. No permissions, member credentials, rate-limit settings or backend checkout files were changed.

The [final hierarchy](final-hierarchy.json) and directory screenshot show General retaining Introductions/Interesting Finds, Fomio retaining seven children, and Off-topic Discussions without children. Category About topics are automatically trashed by the model's after-destroy callback; this source behavior was not separately read back in Trash. Native stale-category/deep-link behavior and arbitrary URL suffix redirects remain unverified. No backend source or native app changes were needed.
