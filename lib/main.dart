import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import 'dart:html' as html;
import 'dart:ui' as ui;

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter HTTP Request Example',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _formKey = GlobalKey<FormState>();
  String _userInput = '';
  bool _fileGenerated = false;
  bool _fileGenerating = false;
  late html.AudioElement _audioElement;
  double _currentPosition = 0.0;
  double _duration = 0.0;
  bool _isSeeking = false;
  double _temperature = 0.2;
  double _top_p = 0.7;
  int _top_k = 20;

  // Function to send an HTTP request using the input
  Future<void> sendHttpRequest(String input_text, double temperature, double top_p, int top_k) async {
    debugPrint('$input_text from sendHttpRequest');
    setState(() {
      _fileGenerating = true;
      _fileGenerated = false;
    });
    String local = 'http://127.0.0.1:5000/generate_audio?text=$input_text&temperature=$temperature&top_p=$top_p&top_k=$top_k';
    final url = Uri.parse(local);

    try {
      http.Response response = await http.get(url);
      if (response.statusCode == 200) {
        // Access the binary data
        final bytes = response.bodyBytes;

        // Convert bytes to Base64 data URL
        String base64Audio = base64Encode(bytes);
        String dataUrl = 'data:audio/wav;base64,$base64Audio';

        debugPrint("Audio Data URL created.");

        // Set the source of the audio element
        _audioElement.src = dataUrl;

        // Reset the audio element
        _audioElement.pause();
        _audioElement.currentTime = 0;

        setState(() {
          _currentPosition = 0.0;
          _fileGenerating = false;
          _fileGenerated = true;
        });
      } else {
        log('Failed to send request: ${response.statusCode}');
        setState(() {
          _fileGenerating = false;
        });
      }
    } catch (error) {
      log('Error: $error');
      setState(() {
        _fileGenerating = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize the HTML5 audio element
    _audioElement = html.AudioElement()
      ..controls = false // We will create custom controls
      ..style.width = '100%';

    // Listen to duration change events
    _audioElement.onDurationChange.listen((event) {
      setState(() {
        _duration = (_audioElement.duration).toDouble();
      });
    });

    // Listen to time update events
    _audioElement.onTimeUpdate.listen((event) {
      if (!_isSeeking) {
        setState(() {
          _currentPosition = (_audioElement.currentTime).toDouble();
        });
      }
    });

    // Register the view factory
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'audioElement',
      (int viewId) => _audioElement,
    );
  }

  @override
  void dispose() {
    _audioElement.pause();
    _audioElement.src = '';
    super.dispose();
  }

  String _formatDuration(double seconds) {
    Duration duration = Duration(seconds: seconds.round());
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    bool isPlaying = !_audioElement.paused;

    return Scaffold(
      appBar: AppBar(
        title: Text('Natural Language Generator'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                decoration: InputDecoration(labelText: 'Enter something'),
                onSaved: (value) {
                  _userInput = value ?? '';
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Column(
                    children:[
                      const Text('Temperature:'),
                      SizedBox(
                        width: 250,
                        child: Slider(
                          value: _temperature,
                          min: 0,
                          max: 1,
                          divisions: 10,
                          label: _temperature.toString(),
                          onChanged: (double value) {
                            setState(() {
                              _temperature = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Top P value:'),
                        SizedBox(
                          width: 250,
                          child: Slider(
                            value: _top_p,
                            min: 0,
                            max: 1,
                            divisions: 10,
                            label: _top_p.toString(),
                            onChanged: (double value) {
                              setState(() {
                                _top_p = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 20), // Adding some space between the components
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Top K value:'),
                      SizedBox(
                        width: 100,
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Enter a value',
                          ),
                          onSaved: (value) {
                            _top_k = int.parse(value ?? "");
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty || int.parse(value) <= 0) {
                              return 'Please input a top k value greater than 0';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    sendHttpRequest(_userInput, _temperature, _top_p, _top_k);
                  }
                },
                child: const Text('Generate'),
              ),
              const SizedBox(height: 20),
              _fileGenerating
                  ? const Text(
                      "File generating...",
                      style: TextStyle(fontSize: 18),
                    )
                  : _fileGenerated
                      ? Column(
                          children: [
                            // Custom audio player controls
                            Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blueAccent),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Audio',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                  const SizedBox(height: 20),
                                  // Play/Pause button
                                  IconButton(
                                    icon: Icon(
                                      isPlaying ? Icons.pause : Icons.play_arrow,
                                    ),
                                    iconSize: 48,
                                    onPressed: () {
                                      setState(() {
                                        if (isPlaying) {
                                          _audioElement.pause();
                                        } else {
                                          _audioElement.play();
                                        }
                                      });
                                    },
                                  ),
                                  // Progress bar
                                  Slider(
                                    activeColor: Colors.blue,
                                    inactiveColor: Colors.grey,
                                    value: _currentPosition.clamp(0.0, _duration),
                                    min: 0.0,
                                    max: _duration > 0.0 ? _duration : 1.0,
                                    onChangeStart: (value) {
                                      setState(() {
                                        _isSeeking = true;
                                      });
                                    },
                                    onChanged: (double value) {
                                      setState(() {
                                        _currentPosition = value;
                                      });
                                    },
                                    onChangeEnd: (value) {
                                      _audioElement.currentTime = value;
                                      setState(() {
                                        _isSeeking = false;
                                      });
                                    },
                                  ),
                                  // Display duration and position
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_formatDuration(_currentPosition)),
                                      Text(_formatDuration(_duration)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Type something and click the button to generate an audio file!',
                          style: TextStyle(fontSize: 18),
                        ),
            ],
          ),
        ),
      ),
    );
  }
}
