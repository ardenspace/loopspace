# Interview Question Banks (4 lenses)

Ask one question at a time. Skip anything the user already answered.
These are starting points — follow up on interesting answers.

## Company Lens

- What is the deadline or time budget? What happens if it slips?
- What is the cost ceiling (infra, APIs, tokens, services)?
- What is the MVP — the smallest version you would actually ship?
- What is explicitly out of scope for v1?
- Who else (if anyone) depends on this shipping?

## User Lens

- Who uses this, and what do they do today without it?
- What is the single moment where this must feel effortless?
- How does a first-time user get from zero to value? How long may it take?
- What would make a user abandon it within the first minute?
- Is this a must-have or a nice-to-have for them? Why?

## Engineer Lens

Security first — always ask:
- What data does this handle? Any secrets, credentials, or PII?
- What inputs cross a trust boundary (user input, network, files)?

Then:
- What must NOT be over-engineered in v1? Where is "simple" acceptable?
- What failure modes matter (network down, bad input, partial writes)?
  What should the user see when they happen?
- What is the testing strategy — unit, integration, end-to-end? What is
  the one test that, if green, gives the most confidence?
- Any hard platform/runtime constraints (OS, versions, offline)?

## Designer Lens

(Skip entirely when there is no UI surface — say so.)

- Is there an existing design system, brand, or reference product to match?
- What is the primary screen or interaction? Sketch it in words.
- Accessibility requirements (keyboard, contrast, screen readers)?
- Light/dark theme? Responsive down to what width?
