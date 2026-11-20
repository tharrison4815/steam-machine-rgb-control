# Tests

Qt Quick Test scripts that drive the real editor with a fake hardware object (the LED strip is never touched).

    /usr/lib/qt6/bin/qmltestrunner -input tests/

(On SteamOS from inside a Flatpak sandbox, prefix with `flatpak-spawn --host`.)

The Game Mode save logic (helper) has its own tests. Steam detection/closing is stubbed and only
temporary copies are edited:

    python3 -I tests/test_helper.py [path/to/a/real/localconfig.vdf]

`tests/tst_gamemode.qml` contains a copy of the helper's reachable Game Mode levels. If the
conversion model changes, regenerate it from `sorted(REACHABLE)` in the helper.
