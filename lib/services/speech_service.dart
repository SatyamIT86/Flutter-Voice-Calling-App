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

  // Add this method to debug device capabilities
  Future<void> debugSpeechRecognition() async {
    try {
      // Check basic availability
      bool isAvailable = await _speechToText.isAvailable;
      print('🔍 Speech recognition available: $isAvailable');

      // Check if already listening
      bool isListening = await _speechToText.isListening;
      print('🔍 Currently listening: $isListening');

      // Get all available locales
      List<LocaleName> locales = await _speechToText.locales();
      print('🔍 Available locales: ${locales.length}');

      for (var locale in locales) {
        print('   - ${locale.localeId}: ${locale.name}');
      }

      // Check if our target locale is available
      bool hasEnUS = locales.any((locale) => locale.localeId == 'en_US');
      print('🔍 en_US locale available: $hasEnUS');

      if (!isAvailable) {
        print('❌ Speech recognition is not available on this device');
        print('💡 This could be due to:');
        print('   1. Missing Google Speech Services');
        print('   2. Device not supporting speech recognition');
        print('   3. Network issues (for cloud-based recognition)');
      }
    } catch (e) {
      print('❌ Error debugging speech recognition: $e');
    }
  }

  // Enhanced capability checking
  Future<Map<String, dynamic>> checkSpeechRecognitionCapabilities() async {
    try {
      await debugSpeechRecognition(); // Add debug info

      bool isAvailable = await _speechToText.isAvailable;
      bool isListening = await _speechToText.isListening;
      List<LocaleName> locales = await _speechToText.locales();

      print('🎤 Speech Recognition Capabilities:');
      print('   Available: $isAvailable');
      print('   Listening: $isListening');
      print('   Supported Locales: ${locales.length}');

      for (var locale in locales) {
        print('     - ${locale.localeId}: ${locale.name}');
      }

      return {
        'available': isAvailable,
        'listening': isListening,
        'locales': locales.length,
        'localeList': locales.map((e) => e.localeId).toList(),
      };
    } catch (e) {
      print('❌ Error checking speech capabilities: $e');
      return {'available': false, 'error': e.toString()};
    }
  }

  // Enhanced initialize method
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      print('🎤 Starting speech recognition initialization...');

      // Step 1: Debug capabilities first
      await debugSpeechRecognition();

      // Step 2: Check and request permissions with better logging
      PermissionStatus status = await Permission.microphone.status;
      print('📱 Current microphone permission: $status');

      if (!status.isGranted) {
        status = await Permission.microphone.request();
        print('📱 Requested microphone permission: $status');

        if (!status.isGranted) {
          print('❌ Microphone permission denied after request');
          onError?.call(
              'Microphone permission is required for speech recognition');
          return false;
        }
      }

      // Step 3: Initialize speech to text
      bool initialized = await _speechToText.initialize(
        onError: (errorNotification) {
          print('🗣️ Speech error: ${errorNotification.errorMsg}');
          onError?.call(errorNotification.errorMsg);
          _isListening = false;
        },
        onStatus: (status) {
          print('🗣️ Speech status: $status');
          if (status == 'listening') {
            _isListening = true;
          } else if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
        },
      );

      print('✅ Speech initialization result: $initialized');

      if (initialized) {
        _isInitialized = true;

        // Test availability again after initialization
        bool available = await _speechToText.isAvailable;
        print('🎤 Final availability check: $available');

        if (!available) {
          print('❌ Speech recognition unavailable even after initialization');
          print('💡 Try installing Google Speech Services from Play Store');
        }
      }

      return initialized;
    } catch (e) {
      print('❌ Speech initialization failed: $e');
      onError?.call('Failed to initialize speech recognition: $e');
      return false;
    }
  }

  // Enhanced startListening with locale fallback
  Future<void> startListening({
    String localeId = 'en_US',
    bool partialResults = true,
  }) async {
    if (!_isInitialized) {
      bool initialized = await initialize();
      if (!initialized) {
        onError?.call('Speech recognition not initialized');
        return;
      }
    }

    if (_isListening) {
      print('Already listening');
      return;
    }

    try {
      print('Starting speech recognition...');

      // Get available locales and find the best match
      List<LocaleName> locales = await _speechToText.locales();
      String selectedLocale = localeId;

      // Check if requested locale is available, if not try alternatives
      if (!locales.any((locale) => locale.localeId == localeId)) {
        print('⚠️ Requested locale $localeId not available');

        // Try alternative English locales
        final alternativeLocales = ['en-US', 'en_IN', 'en'];
        for (String altLocale in alternativeLocales) {
          if (locales.any((locale) => locale.localeId == altLocale)) {
            selectedLocale = altLocale;
            print('🎯 Using alternative locale: $selectedLocale');
            break;
          }
        }

        // If still no match, use first available locale
        if (selectedLocale == localeId && locales.isNotEmpty) {
          selectedLocale = locales.first.localeId;
          print('🎯 Using first available locale: $selectedLocale');
        }
      }

      await _speechToText.listen(
        onResult: (result) {
          print(
              'Speech result - Final: ${result.finalResult}, Words: "${result.recognizedWords}"');

          if (result.finalResult) {
            // For final results, append to transcription
            if (result.recognizedWords.isNotEmpty) {
              _transcription += result.recognizedWords + ' ';
              _lastWords = result.recognizedWords;
              onResult?.call(_transcription.trim());
            }
          } else {
            // For partial results, show current transcription + partial
            final currentTranscript = _transcription.isEmpty
                ? result.recognizedWords
                : '$_transcription ${result.recognizedWords}';
            onResult?.call(currentTranscript.trim());
          }
        },
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 10),
        partialResults: partialResults,
        localeId: selectedLocale,
        onSoundLevelChange: (level) {
          onSoundLevel?.call(level);
        },
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      );

      _isListening = true;
      print(
          'Speech recognition started successfully with locale: $selectedLocale');
    } catch (e) {
      print('Error starting speech recognition: $e');
      onError?.call('Failed to start listening: $e');
      _isListening = false;
    }
  }

  // Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speechToText.stop();
      _isListening = false;
      print('Speech recognition stopped');
    } catch (e) {
      print('Error stopping speech: $e');
      _isListening = false;
    }
  }

  // Cancel listening
  Future<void> cancelListening() async {
    try {
      await _speechToText.cancel();
      _isListening = false;
      _transcription = '';
      _lastWords = '';
      print('Speech recognition cancelled');
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

  // Check if speech recognition is available
  Future<bool> isSpeechAvailable() async {
    return await _speechToText.isAvailable;
  }

  // Dispose
  Future<void> dispose() async {
    if (_isListening) {
      await _speechToText.stop();
    }
    _isInitialized = false;
    _isListening = false;
  }
}
