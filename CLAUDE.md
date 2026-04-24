*NEVER* leave tests unfixed while making changes. Even if they don't seem related to the current change you are making, you should queue a task to look into why tests are failing and make the necessary fixes after you are finished with your current goal.

## Godot Headless Testing

When running Godot in headless mode (e.g. `--headless --script tests/...`), **always** include `--log-file "$TMPDIR/godot.log"`. Godot has a bug where `RotatedFileLogger::rotate_file()` segfaults in headless mode when it can't open its log file (e.g. `user://` path resolution failing, or a sandbox blocking the write). Using `$TMPDIR` stays inside sandbox-writable paths; bare `/tmp/godot.log` is denied under Claude Code's sandbox and triggers the same segfault. Example:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file "$TMPDIR/godot.log" --path /Users/flinnburgess/Development/Godot/ElderScrollsLegends --script tests/some_runner.gd
```

## Glossary

