# TinyEMU-iOS

[![Build](https://github.com/fernandotcl/TinyEMU-iOS/workflows/Build/badge.svg)][GitHub Actions]

This is an experimental iOS app that embeds [TinyEMU][].

[GitHub Actions]: https://github.com/fernandotcl/TinyEMU-iOS/actions?query=workflow%3ABuild
[TinyEMU]: https://github.com/fernandotcl/TinyEMU

## Usage

This app is not available in the App Store or in TestFlight. To build it from source, make sure you have the latest version of Xcode installed. You'll also need [XcodeGen][].

[XcodeGen]: https://github.com/yonaskolb/XcodeGen

Before building, make sure you have checked out the git submodules by running `git submodule update`. You can then run `make` to download and set up [Fabrice Bellard's disk images][images] and create the project file. Finally, open `TinyEMU-iOS.xcodeproj`, change the code signing settings as needed and run.

[images]: https://bellard.org/tinyemu/

## Credits

TinyEMU was originally created by [Fabrice Bellard][fabrice]. This app was created by [Fernando Tarlá Cardoso Lemos][fernando].

[fabrice]: https://bellard.org
[fernando]: mailto:fernandotcl@gmail.com

## License

TinyEMU-iOS is available under the BSD 2-clause license. See the LICENSE file for more information.
