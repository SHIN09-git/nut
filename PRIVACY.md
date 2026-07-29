# Colony Under Glass — Privacy

Last updated: 2026-07-29

## Summary

Colony Under Glass is an offline single-player game. This build does not use:

- user accounts;
- analytics or telemetry;
- advertising;
- crash-report uploads;
- cloud saves;
- online multiplayer;
- purchases; or
- other network services.

The game does not intentionally collect or transmit personal information.

## Local data

Godot stores the following data locally for the current Windows user:

- `settings.json`: language, window, UI, motion, audio, and shortcut settings;
- `profiles/main.json`: the main game profile;
- local backup or recovery candidates created by the crash-safe save process.

With this project's current Godot settings, the default Windows data directory
is:

```text
%APPDATA%\Godot\app_userdata\Colony Under Glass\
```

The profile screen can delete the game profile and its recovery candidates.
Settings remain until the data directory or `settings.json` is removed.

## Portable removal

The Windows candidate is a portable build, not an installer. Removing its EXE,
PCK, and accompanying documents removes the application files but does not
automatically remove the local data directory above. This prevents an
accidental reinstall from silently destroying a profile.

To remove all local data, close the game and delete the `Colony Under Glass`
data directory shown above.

## Changes

If a later build adds an online service, telemetry, a platform SDK, or cloud
storage, this notice must be revised before that build is distributed.
