# TinyEMU-iOS

[![Build Status](https://travis-ci.com/fernandotcl/TinyEMU-iOS.svg?branch=master)](https://travis-ci.com/fernandotcl/TinyEMU-iOS)

This is an experimental iOS app that embeds [TinyEMU][tinyemu].

[tinyemu]: https://github.com/fernandotcl/TinyEMU

## Usage

This app is not available in the App Store or in TestFlight. To build it from source, make sure you have the latest version of Xcode installed. You'll also need [xcodegen][XcodeGen].

[xcodegen]: https://github.com/yonaskolb/XcodeGen

You can run `make` to download and set up [Fabrice Bellard's disk images][diskimages] and create the project file. Then open `TinyEMU-iOS.xcodeproj`, change the code signing settings as needed and run.

[diskimages]: https://bellard.org/tinyemu/

## Credits

TinyEMU was originally created by [Fabrice Bellard][fabrice]. This app was created by [Fernando Tarlá Cardoso Lemos][fernando].

[fabrice]: https://bellard.org
[fernando]: mailto:fernandotcl@gmail.com

## License

TinyEMU-iOS is available under the BSD 2-clause license. See the LICENSE file for more information.
