After using a skill other than skill-reflector, run the skill-reflector skill to determine if there are any modifications/improvements that could be made to the skill based on the last run results

*NEVER* leave tests unfixed while making changes. Even if they don't seem related to the current change you are making, you should queue a task to look into why tests are failing and make the necessary fixes after you are finished with your current goal.

If you ever encounter terminology from the user that you are not familiar with, after providing a response to the prompt, at the end determine the likely definition of the term based on the context you have gathered, and then present it to the user, offering to add it to the glossary in CLAUDE.md. The user should have the opportunity to give an alternative definition if the assumed one is incorrect.

## Godot Headless Testing

When running Godot in headless mode (e.g. `--headless --script tests/...`), **always** include `--log-file /tmp/godot.log`. Godot has a bug where `RotatedFileLogger::rotate_file()` segfaults in headless mode due to `user://` path resolution failing. Example:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/godot.log --path /Users/flinnburgess/Development/Godot/ElderScrollsLegends --script tests/some_runner.gd
```

## Glossary

