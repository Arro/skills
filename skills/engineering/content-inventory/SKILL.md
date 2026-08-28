---
name: content-inventory
description: List everything a page or component must contain — data, actions, states — with every design decision stripped out, ready to carry into a fresh design session.
argument-hint: "page, component, or route to inventory"
disable-model-invocation: true
---

# /content-inventory — what must be there, not how it looks

Produce a **content inventory** for one scope — a page, component, route, or flow: the complete list of what it must contain, carrying nothing about how any of it currently looks or where anything sits. A redesign fed the existing UI inherits its accumulated choices; the inventory is the escape hatch — taken into a fresh design session, it lets the design start from first principles.

## Standing instructions

Check the repo root for `.content-inventory.md`. When present, read it and follow it — it carries the user's standing instructions for this skill in this repo. Typical contents: a folder to write each finished inventory into, shared chrome to always leave out (a global nav or footer owned elsewhere), extra groups to always capture (analytics events, microcopy, accessibility text). It steers scope and delivery only — an instruction to keep layout, widget names, or styling contradicts the point of the skill; set it aside and say so in the final message.

## Resolve the scope

The argument names the scope. Find it in the codebase and trace everything it owns: child components, conditional branches, the data it fetches or receives. Given no argument, or a name matching more than one thing, ask which.

Work from the code — it is the source of truth for what must exist. Never open the running app or take a screenshot: the rendered page is exactly the accumulated design the inventory exists to escape.

## Enumerate

Walk the traced code and collect every requirement into these groups:

- **Data shown** — each piece of information, named by meaning and source ("the project's name", "count of unread replies"), with its shape where it matters (a datetime, a 0–N list, a percentage).
- **Actions** — everything the user can do here, named by effect ("archive the selected item"), including destructive ones and their confirmations.
- **Inputs** — what each field collects, and its validation rules.
- **States** — every variant the scope can be in: loading, empty, error, and anything gated by permission, feature flag, or condition. Note what each variant adds or removes.
- **Navigation** — every place the user can go from here.
- **Feedback** — every message the scope can emit — validation errors, confirmations, notices — named by meaning ("confirms the save succeeded"), not mechanism.

Close with the **non-design constraints** — invariants any new design must still honour: which action applies to which data, what requires confirmation, what only some users see, cardinality bounds. These are requirements; everything about arrangement is not.

## Strip the design

The defining constraint: every item states *what* it is and does, never *how it currently appears*. Translate each current realisation back into the requirement underneath it:

- A widget name is a design decision already made. "A dropdown of three plans" becomes "the user picks one of three plans"; "a modal confirms deletion" becomes "deletion requires confirmation".
- Position, grouping, order, color, size, typography, icons, and emphasis stay out entirely. "Primary" and "prominent" are prominence decisions the next design makes afresh.
- Order leaks design too: list items alphabetically within each group, never in source or on-screen order.

Before delivering, sweep the finished inventory for leaks — widget names, position words, color or size words, an order mirroring the current UI — and rewrite every hit.

## Deliver

The final message carries the inventory as one fenced markdown block, ready to paste whole into a fresh design session. Open the block with a preamble addressed to the agent that will receive it:

> Content inventory for <scope>. Everything listed must be present in the design. Nothing here specifies arrangement, hierarchy, or styling — decide those from first principles.

Then the six groups (omitting any empty one) and the non-design constraints.

When `.content-inventory.md` names a destination folder, also write the block there as `<scope-slug>.md` (creating the folder if needed) and say where it landed.
