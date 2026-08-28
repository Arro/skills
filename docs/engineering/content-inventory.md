## What it does

Produces a **content inventory** for one scope — a page, component, route, or flow: the complete list of everything it must contain, traced from the code. The inventory names the data shown, the actions, the inputs, the states, the navigation, and the feedback messages — and nothing about how any of it currently looks. No layout, no colors, no widget names, not even the on-screen order survives; every item states what must exist, never how the current UI happens to present it.

## When to reach for it

You invoke this by typing `/content-inventory <scope>` — the agent won't reach for it on its own.

Reach for it at the moment you decide a page needs a redesign rather than another patch. Showing a design session the existing page — a screenshot, or the current component code — anchors it to the choices already made; the inventory is what you hand over instead, so the new design starts from what must be there rather than from what is. For exploring what the new design could look like once you have the inventory, use [prototype](https://aihero.dev/skills-prototype).

## Escaping design accretion

In [vibe coding](https://www.aihero.dev/ai-coding-dictionary/vibe-coding), each new feature gets built in the style of the last, and the design compounds down one path. By the time you want to change direction, every artifact of the current UI — the page itself, its screenshot, its markup — carries that path with it, and a design session fed any of them reproduces it.

The inventory severs that path-dependence by separating the two things the current page has fused: the content is the requirement, the presentation is the accumulated guess. The skill works from the code as the [primary source](https://www.aihero.dev/ai-coding-dictionary/primary-source) for what must exist — it never opens the running app, because the rendered page is exactly the influence it exists to escape.

## Where design leaks

Design hides in more places than colors and coordinates, so the skill translates each current realisation back into the requirement underneath it:

| Leak | Becomes |
| --- | --- |
| A widget name ("a dropdown of three plans") | The requirement ("the user picks one of three plans") |
| "Primary" / "prominent" | Nothing — prominence is the next design's decision |
| Items listed in on-screen order | Alphabetical order within each group |

What does survive are the **non-design constraints** — invariants any design must honour: which action applies to which data, what requires confirmation, what only some users see.

## It's working if

- You could not sketch the current page from the inventory — it says what exists, and the old layout is unrecoverable from it.
- A fresh design session given the inventory proposes layouts genuinely unlike the current one, instead of a restyled copy.
- Building the new design needs no trips back to the old page to find what was forgotten — the list was complete.

## Where it fits

A reach-for-it-anytime standalone: it fires at the boundary between "this page grew" and "this page gets redesigned". Its natural neighbour is [prototype](https://aihero.dev/skills-prototype), because the inventory says what must be present and a prototype explores what it could look like — the inventory is the input, the design exploration is the next step. For the map of the whole set, see [ask-matt](https://aihero.dev/skills-ask-matt).
