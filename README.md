# UCS Converter Tool

This program is a tool for converting various step formats to the UCS format used by the Pump It Up arcade games since Pump It Up Fiesta EX.

## Running in Linux

You may need to install the following packages if on Debian distribution to work:

sudo apt-get install libgtk-3-0 libblkid1 liblzma5

## Compiling and running through make

You can build and run this project through the _make_ command instead of through an IDE.  You can build using _make build_os_ or _make build_os_debug_ for debug (substitute _os_ with _windows_, _macos_, or _linux_).  _make help_ will display other options.

## Please Read Before Use

The tool will dynamically convert in either single file mode or folder/path mode based on whether it is given a file or folder/path.  You can mass convert entire folders recursively or single files if you wish.

## Supported Formats

This tool is still a work in progress, and improvements and support for more formats are planned.

The following formats are currently supported:
- .SM files (pre-Stepmania 5)
- .SSC files (Stepmania 5 and beyond)
- .STX files
- .NOT5 files

Support for the following formats are planned:
- .KSF files (Kick It Up)
- .NOT files (pre-NOT5)
- .SMA files
- .SEE files
- .NX files (NX10)

SM file features supported:
- BPM changes
- Stops (through some trickery with slow BPMs and start times)

No other features are supported due to the limitations of the UCS file format.

SSC file features supported:
- BPM changes
- Stops (through some trickery with slow BPMs and start times)
- Tickcount/Beatsplit changes

No other features are supported due to the limitations of the UCS file format.

STX file features supported:
- BPM changes (same as UCS)
- Tickcount/Beatsplit changes (same as UCS)
- converts Division Mode charts with all possibilities so you can see all possible Division Mode charts in an STX (labeled _filename_variant_x_y_z_.ucs_ where x, y, and z are numbers)

Due to limitations of the UCS file format, the scroll speed change feature is not supported.

NOT5 file features supported:
- BPM changes (the tool converts the changes from the Bunki system to the block system used by UCS)

The UCS format supports all NOT5 features fully.
