# Third-party software & assets

Everything shipped in this repository is original unless listed here. Any addition must be
MIT or similarly permissive (or public domain / CC0 for assets) and recorded below.

## Shipped with the game
| Name | License | Used for |
|---|---|---|
| Godot Engine 4.7.2 | MIT | Engine (runtime). Include Godot's license/notice in builds (Help → About → Licenses lists FreeType, etc.). |

## Development tools only (not shipped)
| Name | License | Used for |
|---|---|---|
| Blender 5.2.2 (`bpy` module) | GPL-2.0-or-later | Running `tools/blender/*.py` to generate `.glb` props. Output assets are ours; GPL does not apply to generated content. |
| barichello/godot-ci Docker image | MIT | CI container / fallback source of the official Godot binary. |

No addons, fonts, sounds or textures from third parties are used yet. (UI uses Godot's
built-in default font.)
