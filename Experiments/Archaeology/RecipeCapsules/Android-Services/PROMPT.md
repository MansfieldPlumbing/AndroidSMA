# Android services and integrations mission

## What is valuable

These files record foreground-service, notification, speech, voice-interaction, accessibility, screen-capture, floating-surface, assistant-dispatch, and wallpaper lifecycle machinery.

> # SIREN WARNING
>
> Do not resurrect the old service host, dependency graph, singleton state, routing, or manifest wholesale. Do not compile these files or hide them in a bootstrap DLL. A foreground service is an Android lifecycle contract, not permission to import an application architecture.

## Permitted work

Extract public API order, manifest declarations, permissions, notification behavior, callback lifetimes, and teardown. Re-express one integration at a time in fresh PS1.

## Proof gate

Cold start, foreground notification, Activity reconnect, process recreation, clean stop, permission denial, and recovery must pass without ADB carrying product behavior.
