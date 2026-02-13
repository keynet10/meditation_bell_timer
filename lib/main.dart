import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MeditationApp());
}

class MeditationApp extends StatelessWidget {
  const MeditationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meditation Bell Timer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF81D4FA),
      ),
      home: const MeditationScreen(),
    );
  }
}

// --- Data Models ---
enum SoundType {
  rain, waves, birds, forest, bowl,
  omchant, steamtrain, spaceship, campfire, cicadas,
  brownNoise, bellOnly
}

class SoundProfile {
  final SoundType type;
  final String name;
  final IconData icon;
  final String audioAssetPath;
  final String imageAssetPath;

  SoundProfile({
    required this.type,
    required this.name,
    required this.icon,
    required this.audioAssetPath,
    required this.imageAssetPath,
  });
}

// --- Main Screen ---
class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key});

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen> {
  // Audio Players
  late AudioPlayer _ambiencePlayer;
  late AudioPlayer _bellPlayer;

  // Logic State
  bool _isPlaying = false;

  // Timer State
  int _remainingSeconds = 0;
  Timer? _timer;

  // Dropdown State
  int _selectedDurationMinutes = 10; // Default Duration
  int _selectedIntervalMinutes = 1;  // Default Interval (0 = Off)

  // Options for the Dropdowns (0 added for 'Off')
  final List<int> _durationOptions = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 300, 360, 420, 480];
  final List<int> _intervalOptions = [0, 1, 3, 5, 10, 15, 20, 30, 60];

  // Volume State
  double _volume = 0.5;

  // UI State
  bool _isBlackScreen = false;

  // --- SOUND CONFIGURATION ---
  final List<SoundProfile> _sounds = [
    SoundProfile(type: SoundType.rain, name: "Soothing Rain Storm", icon: Icons.water_drop, audioAssetPath: "rain.mp3", imageAssetPath: "assets/rain_bg.webp"),
    SoundProfile(type: SoundType.waves, name: "Crashing Waves", icon: Icons.waves, audioAssetPath: "waves.mp3", imageAssetPath: "assets/waves_bg.webp"),
    SoundProfile(type: SoundType.birds, name: "Bird Song", icon: Icons.flutter_dash, audioAssetPath: "birds.mp3", imageAssetPath: "assets/birds_bg.webp"),
    SoundProfile(type: SoundType.forest, name: "Rain Forest", icon: Icons.forest, audioAssetPath: "forest.mp3", imageAssetPath: "assets/forest_bg.webp"),
    SoundProfile(type: SoundType.bowl, name: "Tibetan Singing Bowl", icon: Icons.surround_sound, audioAssetPath: "bowl.mp3", imageAssetPath: "assets/bowl_bg.webp"),
    SoundProfile(type: SoundType.omchant, name: "Deep Omm Chant", icon: Icons.self_improvement, audioAssetPath: "omchant.mp3", imageAssetPath: "assets/omchant_bg.webp"),
    SoundProfile(type: SoundType.steamtrain, name: "Soothing Steam Train", icon: Icons.train, audioAssetPath: "steamtrain.mp3", imageAssetPath: "assets/steamtrain_bg.webp"),
    SoundProfile(type: SoundType.spaceship, name: "Deep Space Ambient", icon: Icons.rocket_launch, audioAssetPath: "spaceship.mp3", imageAssetPath: "assets/spaceship_bg.webp"),
    SoundProfile(type: SoundType.campfire, name: "Calming Camp Fire", icon: Icons.local_fire_department, audioAssetPath: "campfire.mp3", imageAssetPath: "assets/campfire_bg.webp"),
    SoundProfile(type: SoundType.cicadas, name: "Cicadas in the Evening", icon: Icons.nightlight_round, audioAssetPath: "cicadas.mp3", imageAssetPath: "assets/cicadas_bg.webp"),
    SoundProfile(type: SoundType.brownNoise, name: "Brown Noise", icon: Icons.graphic_eq, audioAssetPath: "brownnoise.mp3", imageAssetPath: "assets/brownnoise_bg.webp"),
    SoundProfile(type: SoundType.bellOnly, name: "Tibetan Bell", icon: Icons.notifications_active, audioAssetPath: "", imageAssetPath: "assets/bell_bg.webp"),
  ];

  late SoundProfile _currentProfile;

  @override
  void initState() {
    super.initState();
    _currentProfile = _sounds[0];

    _ambiencePlayer = AudioPlayer();
    _bellPlayer = AudioPlayer();

    _ambiencePlayer.setReleaseMode(ReleaseMode.loop);
    _bellPlayer.setReleaseMode(ReleaseMode.stop);

    _ambiencePlayer.setVolume(_volume);
    _bellPlayer.setVolume(_volume);

    _configureAudioMixing();
  }

  Future<void> _configureAudioMixing() async {
    if (kIsWeb) return;

    final AudioContext audioContext = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {
          AVAudioSessionOptions.mixWithOthers,
          AVAudioSessionOptions.defaultToSpeaker
        },
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
    );
    await AudioPlayer.global.setAudioContext(audioContext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ambiencePlayer.dispose();
    _bellPlayer.dispose();
    super.dispose();
  }

  // --- DEDICATED BELL FUNCTION ---
  Future<void> _playBell() async {
    try {
      await _bellPlayer.stop();
      await _bellPlayer.setVolume(_volume);
      await _bellPlayer.play(AssetSource('bell.mp3'));
    } catch (e) {
      print("Error playing bell: $e");
    }
  }

  // --- CORE LOGIC ---
  void _changeSound(SoundProfile newSound) async {
    setState(() => _currentProfile = newSound);

    if (_isPlaying && newSound.type != SoundType.bellOnly) {
      await _ambiencePlayer.stop();
      await _ambiencePlayer.play(AssetSource(newSound.audioAssetPath));
    } else if (_isPlaying && newSound.type == SoundType.bellOnly) {
      await _ambiencePlayer.stop();
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _stopMeditation();
    } else {
      _startMeditation();
    }
  }

  void _startMeditation() async {
    setState(() {
      _isPlaying = true;
      _remainingSeconds = (_selectedDurationMinutes * 60);
    });

    // 1. RING THE STARTING BELL
    _playBell();

    // 2. PLAY BACKGROUND AUDIO
    if (_currentProfile.type != SoundType.bellOnly) {
      try {
        await _ambiencePlayer.setVolume(_volume);
        await _ambiencePlayer.play(AssetSource(_currentProfile.audioAssetPath));
      } catch (e) {
        print("Error playing audio: $e");
      }
    }

    // 3. START TIMER LOGIC
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });

        // Check if we hit 0 this exact second
        if (_remainingSeconds == 0) {
          _playBell(); // RING THE ENDING BELL
          _stopMeditation();
        } else {
          _checkIntervalBell(); // Check for intervals
        }
      }
    });
  }

  void _stopMeditation() {
    _timer?.cancel();
    _ambiencePlayer.stop();
    setState(() {
      _isPlaying = false;
      _remainingSeconds = (_selectedDurationMinutes * 60);
    });
  }

  void _checkIntervalBell() {
    // Only process interval logic if the interval is NOT set to "Off" (0)
    if (_selectedIntervalMinutes > 0) {
      int totalSeconds = (_selectedDurationMinutes * 60);
      int elapsed = totalSeconds - _remainingSeconds;
      int intervalSeconds = _selectedIntervalMinutes * 60;

      // Ring if it's a multiple of the interval, and NOT the start (elapsed > 0)
      if (elapsed > 0 && elapsed % intervalSeconds == 0) {
        _playBell();
      }
    }
  }

  // --- FORMATTING HELPERS ---
  String _formatTime(int totalSeconds) {
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    int s = totalSeconds % 60;
    return h > 0
        ? "${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}"
        : "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  String _formatDropdownLabel(int minutes) {
    if (minutes == 0) {
      return "Off"; // Handle the zero option
    } else if (minutes < 60) {
      return "$minutes mins";
    } else {
      int h = minutes ~/ 60;
      int m = minutes % 60;
      return m > 0 ? "$h h $m m" : "$h hour${h > 1 ? 's' : ''}";
    }
  }

  // --- UI COMPONENTS ---
  Widget _buildControlsArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // DURATION DROPDOWN
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Duration", style: TextStyle(color: Colors.white54, fontSize: 10)),
                const SizedBox(height: 5),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24)
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedDurationMinutes,
                      dropdownColor: Colors.grey[900],
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.bold),
                      items: _durationOptions.map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(_formatDropdownLabel(value), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedDurationMinutes = newValue);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),

          // INTERVAL DROPDOWN
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text("Bell Interval", style: TextStyle(color: Colors.white54, fontSize: 10)),
                const SizedBox(height: 5),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24)
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedIntervalMinutes,
                      dropdownColor: Colors.grey[900],
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      style: GoogleFonts.lato(
                        // Color switches to white54 if 'Off' is selected, otherwise amber
                          color: _selectedIntervalMinutes == 0 ? Colors.white54 : Colors.amber,
                          fontWeight: FontWeight.bold
                      ),
                      items: _intervalOptions.map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(_formatDropdownLabel(value), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedIntervalMinutes = newValue);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI CONSTRUCTION ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: Container(
                key: ValueKey<String>(_currentProfile.imageAssetPath),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(_currentProfile.imageAssetPath),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.4),
                        BlendMode.darken
                    ),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.dark_mode, color: Colors.white70),
                            tooltip: "Black Screen",
                            onPressed: () => setState(() => _isBlackScreen = true),
                          ),
                          Text("MEDITATION BELL TIMER", style: GoogleFonts.lato(fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold, color: Colors.white70)),
                          const SizedBox(width: 48),
                        ],
                      ),
                      Text(
                          _isPlaying
                              ? _formatTime(_remainingSeconds)
                              : _formatTime(_selectedDurationMinutes * 60),
                          style: GoogleFonts.lato(fontSize: 56, fontWeight: FontWeight.w300, color: Colors.white)
                      ),
                      Expanded(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 500),
                          opacity: _isPlaying ? 0.0 : 1.0,
                          child: IgnorePointer(
                            ignoring: _isPlaying,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      childAspectRatio: 0.75,
                                      crossAxisSpacing: 6,
                                      mainAxisSpacing: 6,
                                    ),
                                    itemCount: _sounds.length,
                                    itemBuilder: (context, index) {
                                      final sound = _sounds[index];
                                      final isSelected = _currentProfile == sound;
                                      return GestureDetector(
                                        onTap: () => _changeSound(sound),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isSelected ? Colors.white24 : Colors.transparent,
                                            borderRadius: BorderRadius.circular(10),
                                            border: isSelected ? Border.all(color: Colors.white30, width: 1) : Border.all(color: Colors.white10),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(sound.icon, color: Colors.white, size: 24),
                                                const SizedBox(height: 6),
                                                Text(
                                                    sound.name,
                                                    textAlign: TextAlign.center,
                                                    maxLines: 3,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  _buildControlsArea(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.volume_up, size: 16, color: Colors.white54),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2.0,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                  ),
                                  child: Slider(
                                    value: _volume, min: 0.0, max: 1.0,
                                    activeColor: Colors.white, inactiveColor: Colors.white24,
                                    onChanged: (newVal) {
                                      setState(() { _volume = newVal; });
                                      _ambiencePlayer.setVolume(newVal);
                                      _bellPlayer.setVolume(newVal);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          GestureDetector(
                            onTap: _togglePlay,
                            child: Container(
                              height: 70, width: 70,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white38, width: 1)),
                              child: Icon(_isPlaying ? Icons.stop : Icons.play_arrow, color: Colors.white, size: 32),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isBlackScreen)
            GestureDetector(
              onTap: () => setState(() => _isBlackScreen = false),
              child: Container(width: double.infinity, height: double.infinity, color: Colors.black),
            ),
        ],
      ),
    );
  }
}