# ucsconvertertool

This program is a tool for converting various step formats to the UCS format used by Pump It Up arcade games.

## Running in Linux

You may need to install the following packages if on Debian distribution to work:

sudo apt-get install libgtk-3-0 libblkid1 liblzma5

## Please Read Before Use

This tool is still a work in progress, and improvements and support for more formats are planned.

The following formats are currently supported:
- .SM files (pre-Stepmania 5)
- .SSC files (Stepmania 5 and beyond)

Support for the following formats are planned:
- .KSF files (Kick It Up)
- .SMA files

SM file features supported:
- BPM changes
- Stops (through some trickery with slow BPMs and start times)

No other features are supported due to the limitations of the UCS file format.

SSC file features supported:
- BPM changes
- Stops (through some trickery with slow BPMs and start times)
- Tickcount/Beatsplit changes

No other features are supported due to the limitations of the UCS file format.
