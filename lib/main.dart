import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'dart:developer';
import 'dart:io';
// import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:html' as html;
// import 'package:just_audio/just_audio.dart';



void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter HTTP Request Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
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
  late String _audioUrl;
  bool _fileGenerated = false;
  bool _fileGenerating = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  late AudioPlayer _audioPlayer;

  // Function to send an HTTP request using the input
  Future<void> sendHttpRequest(String input) async {
    debugPrint('$input from sendHttpRequest');
    setState(() {
      _fileGenerating = true;
      _fileGenerated = false;
    });
    String local = 'http://127.0.0.1:5000/generate_audio?text=$input';
    final url = Uri.parse(local);

    try {
      // debugPrint('before http.get');
      http.Response response = await http.get(url);
      // debugPrint('This is status code: ${response.statusCode}');
      if (response.statusCode == 200) {
        // Access the binary data
        final bytes = response.bodyBytes;

        // Create a Blob from the bytes
        final blob = html.Blob([bytes], 'audio/wav');

        // Generate a URL for the Blob
        final audioUrl = html.Url.createObjectUrlFromBlob(blob);

        debugPrint("Audio URL created: $audioUrl");

        setState(() {
          _fileGenerating = false;
          _fileGenerated = true;
          _audioUrl = audioUrl; // Store the URL for playback
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
    _audioPlayer = AudioPlayer();
  
    // Listen to audio player state changes
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      setState(() {
        _isPlaying = state == PlayerState.PLAYING;
      });
    });

    // Listen to audio duration changes
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        _duration = duration;
      });
    });

    // Listen to audio position changes
    _audioPlayer.onAudioPositionChanged.listen((Duration position) {
      setState(() {
        _position = position;
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playAudio() async {
    if (_audioUrl != null) {
      int result = await _audioPlayer.play(_audioUrl!);
      if (result == 1) {
        // Successfully started playing
        debugPrint('Audio started playing.');
      } else {
        // Error playing audio
        debugPrint('Error playing audio.');
      }
    } else {
      debugPrint('Audio URL is not available.');
    }
  }

  void _pauseAudio() async {
    int result = await _audioPlayer.pause();
    if (result == 1) {
      // Successfully paused
      debugPrint('Audio paused.');
    } else {
      // Error pausing audio
      debugPrint('Error pausing audio.');
    }
  }


  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    // Call the function to send the HTTP request with user input
                    sendHttpRequest(_userInput).then((_) {
                      // // After the HTTP request is completed, use setState to update the UI
                      // setState(() {
                      //   // Ensure that _fileGenerated and _filename are updated to trigger rerender
                      //   _fileGenerated = true;  // Assuming the request was successful
                      //   _fileUrl = 'http://127.0.0.1:5000/get_audio?filename=' + _filename;
                      // });
                    });
                  }
                },
                child: const Text('Generate'),
              ),
              _fileGenerating
                ? const Text(
                  "File generating...",
                  style: TextStyle(fontSize: 18),
                )
                : _fileGenerated
                  ? Column(
                    children: [
                      // Display the audio file box
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
                            SizedBox(height: 50),
                            // Play/Pause button
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                              ),
                              iconSize: 48,
                              onPressed: () {
                                // _isPlaying ? _pauseAudio() : _playAudio();
                                if (_isPlaying) {
                                  _pauseAudio();
                                } else {
                                  _playAudio();
                                }
                              },
                            ),
                            // Progress bar
                            Slider(
                              activeColor: Colors.blue,
                              inactiveColor: Colors.grey,
                              value: _position.inSeconds.toDouble().clamp(0.0, (_duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0)),
                              min: 0.0,
                              max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                              onChanged: (double value) {
                                final position = Duration(seconds: value.toInt());
                                _audioPlayer.seek(position);
                              },
                            ),
                            // Display duration and position
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(_position)),
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
            // const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
