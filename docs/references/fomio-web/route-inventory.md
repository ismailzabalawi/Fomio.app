The mobile route map is done. Two background agents are still going through the web theme and CLI routes. While they run, I'm checking how deep links map in the mobile app.

The mobile and CLI parts are done. The web theme agent is still running, and I'll put the whole inventory together once it reports back.

# Route inventory: mobile, web theme, CLI

I checked the mobile routes directly. Two helper agents went through the web theme and the CLI; their results are built from searching the code, so a few web entries are marked as uncertain.

## 1. One set of content types, three clients

| Content type | Mobile app (Expo Router) | Web theme (Discourse URL) | CLI command · TUI screen |
|---|---|---|---|
| **Home feed** | `/(tabs)` (index) · also `/feed` (separate 560-line screen) | `/`, `/latest`, `/hot`, `/unread` | `feed [--hot\|--latest]` · `FeedScreen` |
| **Discover / Hubs directory** | `/(tabs)/discover` | `/categories`, `/top` | `hub` · `HubListScreen` |
| **Hub** (category) | `/hub/[slug]` | `/c/:hub/:id` | none · `HubScreen` |
| **Teret** (subcategory) | `/teret/[slug]?id=` · also `/feed?category=slug` | `/c/:hub/:teret/:id` | `teret <slug>` · `TeretScreen` |
| **Byte** (topic) | `/feed/[byteId]` | `/t/:slug/:id` | `byte <id>` · `ByteScreen` |
| **Byte edit** | `/feed/[byteId]/edit?postId=` | inside the composer | none |
| **Comments** (posts) | shown inline; `/feed/[id]/comments` just redirects back to the Byte | inline, and called **"Reply"** | `reply <id>` · inside `ByteScreen` |
| **Compose** | `/compose?teret=\|hub=` | composer panel | `post` · `ComposerPane` |
| **Search** | `/(tabs)/search?q=` (hidden tab) | `/search` + a search palette | `search <q>` · `SearchScreen` |
| **Notifications** | `/(tabs)/notifications` | `/notifications` + a notifications menu | **none** |
| **Own profile** | `/(tabs)/profile` → re-exports `/(profile)/index` | `/u/:user`, `/summary` | `whoami` |
| **Other user** | `/profile/[username]` | `/u/:user` | `user <name>` · `UserScreen` |
| **Activity / Saved** | **none** | `/u/:user/activity/*`, `/activity/bookmarks` | none (`bookmark` is a write action only) |
| **Messages** (private messages) | **none** | `/u/:user/messages/*`, `/my/messages` | **none** |
| **Settings** | `/(profile)/settings`, `notification-settings`, `edit-profile`, `blocked-users`, `confirm-delete-account` | `/my/preferences/*` (9 sections) + `?fomio_menu=1` overlay | `config --feed` (local only) |
| **Paywall** | `/paywall` (has a `.web` variant) | none | none |

## 2. Persistent layout shells

- **Screen-width breakpoints are already shared** between the web theme and mobile (`useSurfaceMode`): touch below 768, rail from 768, compact-desktop from 1024, expanded from 1280. These should become layout tokens in the token schema.
- **Mobile** (`WebAppShell`):
  - Native and web touch: a floating dock with Home, Discover, Compose button, Notifications, Profile.
  - Web desktop: a sidebar with Home, Search, Notifications, Write, Profile, plus the hubs tree. At rail width it also shows the `MasterPane`.
- **Framing:** only these route groups get the shell: `(tabs)`, `teret`, `hub`, `feed`, `(profile)`, `(protected)`. `compose` gets only a top bar; auth screens and the paywall render full-bleed.
- **Web theme:** sidebar and mobile drawer, master pane, bottom bar (Home, Discover, Create, Notifications, Me), restyled header. The theme's own shell turns off on auth routes and `/admin`.
- **Navigation model:**
  - Mobile uses stacks with slide-from-right. The only modal presentation is `auth-modal` (full-screen, slides up).
  - The TUI is one stack (push, replace, back) with a command palette. It has no tabs.

## 3. Auth and onboarding

- **Mobile auth screens:** onboarding (3-step flow), signin, auth-modal, activate, awaiting-activation, pending-approval, plus `auth/callback` and `auth_redirect`.
- **Web theme auth pages:**
  - Styled: login, signup, 2FA (all variants), forgot password, password reset, activation, account-created.
  - Only lightly styled: user-api-key consent. That page is shown to every mobile and CLI sign-in.
  - Unstyled: `/session/email-login/:token`. It probably shows plain Discourse.
- **Deep links** (`lib/deep-linking.ts`) map Discourse URLs to mobile routes: `/t/…` → Byte, `/u/…` → profile, `/c/…` → Teret, `/login` → signin, `/search`, and the activation link.

## 4. Problems the route map shows

1. **Signed-out users are still blocked.** `app/index.tsx` sends anyone not signed in to `/(auth)`. My notes say anonymous reading shipped in PR #61, and that this exact file was what blocked it. Either the change never merged or it was lost. Please check this before designing the signed-out home.
2. **There are two routes for the same thing:**
   - Two feed screens: `/(tabs)` and `/feed`.
   - Two ways to show a Teret: `/teret/[slug]` and `/feed?category=`.
   - Two profile entry points: the `(tabs)/profile` re-export and `(profile)/index`.
3. **Hubs and Terets are addressed inconsistently.** The app uses `?id=` in some places and `?byId=true` in others. Every Discourse `/c/` deep link opens as a Teret, even when it points at a Hub.
4. **"Comment" and "Reply" are both in use.** The web theme says "Reply"; mobile code and routes say "comments". Pick one word before wireframing.
5. **Search and Discover appear in different places:** the desktop sidebar has Search but no Discover, while the dock has Discover but no Search.
6. **Some features exist in only one client:**
   - Messages and Activity/Saved exist only on web.
   - Notifications are missing from the CLI.
   - Settings: web has 9 preferences sections; mobile covers 4.
7. **Leftover redirect-only files:** `(protected)/notifications`, `feed/[id]/comments` and `(auth)/index` (which only shows a spinner). They're harmless, but they shouldn't appear in the IA diagram.

## Decisions needed before wireframing

1. **Word choice:** "Comment" or "Reply"?
2. **Messages and Activity/Saved:** in scope for mobile in this redesign, or web-only for now?
3. **Canonical route shape:** keep the mobile `/feed/[byteId]` form, or move to shared names like `/byte/:id`, `/hub/:slug` and `/teret/:slug` that all clients map to? I'd recommend the shared names; the deep-link table already uses them as `fomio://byte/…` and `fomio://teret/…`.
4. **Signed-out state:** is the signed-out home a real destination (open reading), or does the app go straight to onboarding?

Once you've answered those, I can turn this into the target IA: one tree of content types plus a navigation map per client. I can save it in `docs/`, or publish it as a page if you want to share it.
