# Responsive GameView

Godot editor plugin that adds a `GameView Controls` bottom-panel tab for applying common portrait and landscape project resolutions.

## Ratios

With the default short side of `1080`, the plugin applies:

| Ratio | Portrait | Landscape |
| --- | --- | --- |
| `3:4` | `1080 x 1440` | `1440 x 1080` |
| `9:16` | `1080 x 1920` | `1920 x 1080` |
| `9:21` | `1080 x 2520` | `2520 x 1080` |
| `3:5` | `1080 x 1800` | `1800 x 1080` |

## Usage

    - Unzip the plugin.
    - Drag and import it in the res://addos/ directory.
    - Then the plugin needs to be enabled in `project.godot` from project settings.
    - Open the Godot editor, select the `GameView Controls` tab at the bottom, choose an orientation and ratio, then press `Apply to Project`.
    
## Future scope

Custom resolution values to be added.
