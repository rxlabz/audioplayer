# Changelog

## 0.5.2
- fix objC warning
- updated example

## 0.5.1
- Allow Dart 2 SDK
- Fix java lint warnings.

## 0.5.0
- BREAKING Change: No more separate handlers for communicating the state of the player. Instead we rely on streams to publish state changes and position updates.
- Code formatting and flow improvements. Preparation for testing.

## 0.4.0

- Feat : merge PR from [mindon](https://github.com/mindon) with mute methods and various improvements
- fixes Future<int> errors with --preview-dart2
- Example : add a slider to demonstrate the seek feature

## 0.3.0

- merge PR from [johanhenselmans](https://github.com/johanhenselmans) to switch iOS to ObjectiveC
- merge PR from [oaks](https://github.com/oakes) to add the seek feature

## 0.2.0

- support for local files

## 0.1.0

- update to the current Plugin API
- move to https://github.com/rxlabz/audioplayer

## 0.0.2

Separated handlers for position, duration, completion and errors

- setDurationHandler(TimeChangeHandler handler)
- setPositionHandler(TimeChangeHandler handler)
- setCompletionHandler(VoidCallback callback)
- setErrorHandler(ErrorHandler handler)

- new typedef
```dart
typedef void TimeChangeHandler(Duration duration);
typedef void ErrorHandler(String message);
```

## 0.0.1

- first POC :
  - methods : play, pause, stop
  - a globalHandler for position, duration, completion and errors
