// lib/services/speech_service.dart

import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _transcription = '';

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

    // Request microphone permission
    PermissionStatus status = await Permission.microphone.request();
    if (!status.isGranted) {
      onError?.call('Microphone permission denied');
      return false;
    }

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          print('Speech recognition error: ${error.errorMsg}');
          onError?.call(error.errorMsg);
        },
        onStatus: (status) {
          print('Speech recognition status: $status');
          _isListening = status == 'listening';
        },
      );

      return _isInitialized;
    } catch (e) {
      print('Error initializing speech recognition: $e');
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
      await _speechToText.listen(
        onResult: (result) {
          _transcription = result.recognizedWords;
          onResult?.call(_transcription);
        },
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: partialResults,
        localeId: localeId,
        onSoundLevelChange: (level) {
          onSoundLevel?.call(level);
        },
        cancelOnError: false,
        listenMode: ListenMode.confirmation,
      );

      _isListening = true;
    } catch (e) {
      print('Error starting speech recognition: $e');
      onError?.call('Failed to start listening');
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.stop();
      _isListening = false;
    } catch (e) {
      print('Error stopping speech recognition: $e');
      onError?.call('Failed to stop listening');
    }
  }

  // Cancel listening
  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.cancel();
      _isListening = false;
      _transcription = '';
    } catch (e) {
      print('Error canceling speech recognition: $e');
    }
  }

  // Get available locales
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _speechToText.locales();
  }

  // Check if locale is available
  Future<bool> isLocaleAvailable(String localeId) async {
    List<LocaleName> locales = await getAvailableLocales();
    return locales.any((locale) => locale.localeId == localeId);
  }

  // Get transcription
  String getTranscription() {
    return _transcription;
  }

  // Clear transcription
  void clearTranscription() {
    _transcription = '';
  }

  // Dispose
  Future<void> dispose() async {
    if (_isListening) {
      await stopListening();
    }
    _isInitialized = false;
  }
}
