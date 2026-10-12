# Moonwood

A small **Godot 4** first-person fantasy orienteering game. Explore a low-poly
forest, navigate by a paper map and compass, and gather five fallen stars.
Bring them back to the lantern at base camp to finish the adventure.

There are no enemies, time limits, live position markers, or quest arrows.
The challenge is matching your surroundings to the map. Paths are off by default;
enable **Forest paths** on the title screen before starting for an easier route.
The option adds trails to both the forest and paper map. With paths off, trees
also fill the former trail corridors. Giant mushrooms, an ancient tree,
standing stones, a ruined tower, and a forgotten arch make the controls easy
to recognize. Fireflies, floating crystals, and gentle chimes add some magic.

## License
See [LGPLv3+NoEvil](licence.md)

## Play

1. Download the standard edition of [Godot](https://godotengine.org/download/)
   (4.3 or newer; no .NET edition required).
2. In Godot's Project Manager, choose **Import** and select `project.godot`.
3. Open the project and press **F6** on the main scene or **F5** to run it.
4. Choose **Enter the forest**. The mouse is captured while exploring;
   press **Escape** to release it.

| Control | Action |
| --- | --- |
| WASD / arrow keys | Walk |
| Mouse | Look around |
| Shift | Sprint; breath recovers when not sprinting |
| M / Tab | Open or fold the map |
| C | Toggle the optional handheld compass while exploring or reading the map |
| E | Gather a nearby star / restore the camp lantern |
| Escape | Pause / close the map / resume |

If you run out of breath, walk or rest briefly before sprinting again.

Your starting position is the camp triangle on the map, facing **north**.
The compass shows your viewing direction; north is always at the top of the
paper map. Each grid square represents 20 metres. The lake is too deep to
cross, so walk around it. All five stars can be collected in any order.
Collected controls are checked off on your map.

Enable the optional handheld compass with **C** or from the map. On the map,
drag the compass to move it; **Shift-drag** or use the mouse wheel to rotate the
whole baseplate. Right-drag the dial until its orienting arrow points to the
north needle. This ring setting carries into the forest. Turn yourself until
the magnetic needle meets the orienting arrow, then walk in the direction of
the travel arrow.

Brown contour lines show the same hills, ridges, and lake basin that you walk
over in the forest. Thin lines mark every 2 metres of elevation; heavier,
labelled index contours mark every 10 metres. Closely spaced lines indicate
steeper slopes, and closed loops reveal hilltops. Trails follow the terrain,
while the camp and control clearings provide level ground.

Movement and the exploration timer pause while the map or a menu is open.
Switching away from the game also pauses movement. The final screen shows
your exploring time and distance travelled; replay resets the adventure.
The pause menu includes a chime toggle and a quit button.

## Project

- `scripts/main.gd`: quest state, interaction, menus, HUD, and synthesized chimes.
- `scripts/player.gd`: first-person movement, collision, compass heading, and sprint.
- `scripts/world.gd`: deterministic procedural forest, landmarks, trails, and stars.
- `scripts/forest_map.gd`: map drawn from the same coordinates as the 3D world.
- `scripts/compass.gd`: heading strip and optional map/handheld compass.
- `tests/game_test.gd`: automated gameplay smoke tests.
- `tests/visual_test.gd`: rendered screenshots of the menus, map, and landmarks.

Everything is generated locally using Godot primitives. No asset downloads,
plugins, package installation, network access, or paid assets are needed to play.
The Compatibility renderer is used for broader hardware support.

## Validate

With Godot on your PATH (substitute your Godot executable for `godot`):

```sh
godot --headless --path . --editor --import
godot --headless --audio-driver Dummy --path . --script tests/game_test.gd
```

The gameplay tests exercise contour-to-terrain agreement, uphill movement,
sprinting, stamina recovery, water and
boundary collision, compass bearings, map pausing, gathering all five stars,
the return-to-camp victory, and replay.

For visual checks, create a screenshot directory and run with a display:

```sh
godot --path . --script tests/visual_test.gd -- --output-dir /absolute/path/to/screenshots
```

On macOS, the executable inside the standard app is
`/Applications/Godot.app/Contents/MacOS/Godot`.
