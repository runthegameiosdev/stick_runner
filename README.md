# Stick Runner (Godot 4.2+)

Open `project.godot` in Godot and press F5.

**Desktop test controls:** click = jump (or Space), ATTACK button = J, pause = P.
**Phone:** tap anywhere = jump, ATTACK button = punch, pause button top of the dirt.

## Using your art
- **Obstacles:** drop PNGs in `art/` using the names in `DEFS` at the top of `main.gd`
  (`bricks.png`, `saw.png`, `pipe.png`, `flyer.png`, `water.png`). Missing files fall back to
  coloured boxes, so you can add art one piece at a time. Obstacles align bottom-centre, water top-centre.
- **Player:** in `main.tscn`, add an `AnimatedSprite2D` named `Sprite` under `Player` with animations
  `run`, `jump`, `attack`. Put the feet at the node origin. The placeholder stickman stops drawing.
- **Background/ground:** add your sprites to `Main`, then untick **Draw Placeholder World** in the inspector.
- **HUD:** the labels and buttons under `HUD` are plain placeholders. Swap in your own nodes but keep the
  names `AttackButton` and `PauseButton` (any Control type works).

## Tuning
- Speed, level length, lives: constants at the top of `main.gd`.
- Gravity, jump, attack timing, hitboxes: constants at the top of `player.gd`.
- Spawn mix: `SPAWN_TABLE` in `main.gd`. New obstacle type = one line in `DEFS` plus its name in `SPAWN_TABLE`.
- Set `DEBUG_HITBOXES` to `true` in `obstacle.gd` to see every hitbox.

## Landscape
Project Settings > Display > Window: swap viewport width/height (960 x 540) and set Orientation to Landscape.
