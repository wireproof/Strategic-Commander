# Strategic Commander

An experimental native iPhone and iPad reimagining of the Palm OS space strategy game. Build factories and research facilities, send fleets between worlds, and defend your home planet. The interface adapts to the available screen and includes a battle replay inspired by the original.

## Current status

This is an early reconstruction. The economy, combat, map generation, and computer opponent are approximations rather than recovered original game logic. Multiplayer is not implemented. Artwork and gameplay continue to change.

The source and experimental **0.1.0 build 21** contain inline fleet orders, turn reports, a scalable fighter sprite, native toolbar controls, pinch zoom, selectable 12/16/20/24-planet new games, facility selling, and a portrait panel with a larger grab handle. Build 21 compiled and was installed on the developer's iPhone and iPad, but the previous build had a simulator battle-report test failure, and build 21 facility selling and layout have not been runtime verified. The unsigned IPA requires signing or a compatible sideloading environment, and iOS 17 or later.

## Build the source

Install Xcode and XcodeGen, then run:

```sh
xcodegen generate
open StrategicCommander.xcodeproj
```

Choose an iOS simulator or configure your own development signing in Xcode. The project includes its app icon, fighter artwork, planet artwork, and UI tests in `Sources`, `Art`, and `UITests`.

## Controls in the released IPA

Select an owned planet and use **Send Ships**, or drag from an owned planet to a destination. Select a fleet size, launch it, and end the turn to advance travel. The turn report shows arrivals and battle results. Battles use an animated replay; long replays can be skipped.
