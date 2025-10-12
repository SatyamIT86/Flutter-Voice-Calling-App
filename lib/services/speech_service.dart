// lib/services/speech_service.dart

import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _transcription = '';
  String _lastWords = '';

  // Callbacks
  Function(String text)? onResult;
  Function(String error)? onError;
  Function(double level)? onSoundLevel;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get transcription => _transcription;

  // Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    PermissionStatus status = await Permission.microphone.request();
    if (!status.isGranted) {
      onError?.call('Microphone permission denied');
      return false;
    }

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          print('Speech error: ${error.errorMsg}');
          onError?.call(error.errorMsg);
          _isListening = false;
        },
        onStatus: (status) {
          print('Speech status: $status');
          if (status == 'listening') {
            _isListening = true;
          } else if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
        },
      );

      print('Speech-to-text initialized: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      print('Error initializing speech: $e');
      onError?.call('Failed to initialize speech recognition');
      return false;
    }
  }

  // Start listening
  Future<void> startListening({
    String localeId = 'en_US',
    bool partialResults = true,
  }) async {
    if (!_isInitialized) {
      bool initialized = await initialize();
      if (!initialized) return;
    }

    if (_isListening) {
      print('Already listening');
      return;
    }

    try {
      print('Starting speech recognition...');

      await _speechToText.listen(
        onResult: (result) {
          print('Speech result: ${result.recognizedWords}');

          if (result.finalResult) {
            // Append final result with space
            if (result.recognizedWords.isNotEmpty &&
                result.recognizedWords != _lastWords) {
              _transcription += result.recognizedWords + '. ';
              _lastWords = result.recognizedWords;
              onResult?.call(_transcription.trim());
            }
          } else {
            // Show temporary partial result
            final tempTranscript = _transcription + result.recognizedWords;
            onResult?.call(tempTranscript.trim());
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: partialResults,
        localeId: localeId,
        onSoundLevelChange: (level) {
          onSoundLevel?.call(level);
        },
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );

      _isListening = true;
      print('Speech recognition started');
    } catch (e) {
      print('Error starting speech: $e');
      onError?.call('Failed to start listening');
      _isListening = false;
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.stop();
      _isListening = false;
      _isInitialized = false; // Prevent auto-restart
      print('Speech recognition stopped');
    } catch (e) {
      print('Error stopping speech: $e');
    }
  }

  // Cancel listening
  Future<void> cancelListening() async {
    try {
      await _speechToText.cancel();
      _isListening = false;
      _isInitialized = false;
      _transcription = '';
      _lastWords = '';
    } catch (e) {
      print('Error canceling speech: $e');
    }
  }

  // Get available locales
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _speechToText.locales();
  }

  // Get transcription
  String getTranscription() {
    return _transcription.trim();
  }

  // Clear transcription
  void clearTranscription() {
    _transcription = '';
    _lastWords = '';
  }

  // Dispose
  Future<void> dispose() async {
    _isInitialized = false;
    if (_isListening) {
      await _speechToText.stop();
    }
    _isListening = false;
  }
}
