# About

This holds the three directories that define the build artifacts for iOS. There is a matching set in the [macOS](../macOS)
folder.

* [App](App) — the executable that runs and as a side-effect installs the AUv3 app extension onto the iOS device
* [Extension](Extension) — the AUv3 app extension that is packaged with the application. This only contains the UI; the
audio unit itself is in the [FilterAudioUnit](Packages/Sources/FilterAudioUnit) package.
