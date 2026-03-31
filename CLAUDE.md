*NEVER* leave tests unfixed while making changes. Even if they don't seem related to the current change you are making, you should queue a task to look into why tests are failing and make the necessary fixes after you are finished with your current goal.

## Godot Headless Testing

When running Godot in headless mode (e.g. `--headless --script tests/...`), **always** include `--log-file /tmp/godot.log`. Godot has a bug where `RotatedFileLogger::rotate_file()` segfaults in headless mode due to `user://` path resolution failing. Example:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/godot.log --path /Users/flinnburgess/Development/Godot/ElderScrollsLegends --script tests/some_runner.gd
```

## Glossary

