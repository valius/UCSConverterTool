import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:ucsconvertertool/generators/converter_generator.dart';
import "package:path/path.dart" as p;
import 'package:ucsconvertertool/helpers/path_helpers.dart';
import 'package:ucsconvertertool/step_files/ucs_file.dart';

class ConvertView extends StatefulWidget {
  const ConvertView({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<ConvertView> createState() => _ConvertViewState();
}

class _ConvertViewState extends State<ConvertView> {
  final _controller = TextEditingController();
  final List<String> _supportedExtensions = ['sm', 'ssc'];
  String _statusText = "Idle";
  bool _buttonsEnabled = true;

  void _openFileDialog() async {
    setState(() {
      _buttonsEnabled = false;
    });

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _supportedExtensions,
    );

    if (result != null) {
      setState(() {
        _controller.text = result.files.single.path!;
      });
    }

    setState(() {
      _buttonsEnabled = true;
    });
  }

  void _openDirectoryDialog() async {
    setState(() {
      _buttonsEnabled = false;
    });

    String? result = await FilePicker.platform.getDirectoryPath();

    if (result != null) {
      setState(() {
        _controller.text = result;
      });
    }

    setState(() {
      _buttonsEnabled = true;
    });
  }

  void _convertfile() async {
    if (_controller.text.isEmpty) {
      setState(() {
        _statusText = "No file or directory selected!";
      });
      return;
    }
    setState(() {
      _buttonsEnabled = false;
      _statusText = "Generating list of supported files from input ${_controller.text}";
    });

    var listFiles =
        await getListOfFilesFromPath(_controller.text, _supportedExtensions);

    List<UCSFile> ucsFiles = [];
    for (var file in listFiles) {
      setState(() {
        _statusText = "Generating UCS files from $file...";
      });

      var converter = ConverterGenerator.createConverter(file);
      ucsFiles += await converter.convert();

      String resultString = "Generated ";
      for (var ucsFile in ucsFiles) {
        ucsFile.outputToFile();

        String filenameOnly = p.basename(ucsFile.getFilename);
        resultString += "$filenameOnly, ";
      }

      resultString += "in the folder ${p.dirname(_controller.text)}";

      setState(() {
        _statusText = resultString;
      });
    }

    setState(() {
      _buttonsEnabled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.

    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Choose a file or directory',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                hintText: 'No file or directory selected',
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      side: BorderSide(
                        color: Colors.black,
                        width: 5,
                      ),
                    ),
                  ),
                  onPressed: _buttonsEnabled? _openFileDialog : null,
                  child: const Text('Open File'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      side: BorderSide(
                        color: Colors.black,
                        width: 5,
                      ),
                    ),
                  ),
                  onPressed: _buttonsEnabled? _openDirectoryDialog : null,
                  child: const Text('Open Folder'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      side: BorderSide(
                        color: Colors.black,
                        width: 5,
                      ),
                    ),
                  ),
                  onPressed: _buttonsEnabled ? _convertfile : null,
                  child: const Text('Convert'),
                ),
              ],
            ),
            Text(_statusText)
          ],
        ),
      ),
    );
  }
}
