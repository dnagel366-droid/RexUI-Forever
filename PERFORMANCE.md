# RexUI 4.0 performance model

RexUI keeps work proportional to the UI elements that are actually enabled.

- UnitFrames remain an internal RexUI module so their renderer always loads with
  the main addon. Profile-level disable switches stop its runtime work.
- Unit frames are created on demand. Disabled unit types and boss slots do not
  allocate oUF frames until enabled.
- Unit events are registered only for player, pet, target, focus, and boss tokens.
- Cast progress uses an `OnUpdate` handler only on the visible cast widget; layout,
  colors, and spell identity are resolved on cast events rather than every frame.
- Target/focus resolution is cached and invalidated when units change.

Visual defaults prioritize target and cast readability while remaining adjustable
through `/rexui` and the existing unlock mode.
