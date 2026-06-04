import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/bluetooth_service.dart';
import '../services/control_mapping_service.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  final BluetoothService _btService = BluetoothService();
  final ControlMappingService _mappingService = ControlMappingService();

  // Track currently active pressed actions to manage release safety correctly
  final Set<String> _activeActions = {};

  void _triggerHaptic() {
    if (_mappingService.hapticFeedbackEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void _handleActionDown(String actionKey) {
    if (!_btService.isConnected) return;
    
    _triggerHaptic();
    
    // Add to active set
    _activeActions.add(actionKey);
    
    // Send mapped character
    final char = _mappingService.mappings[actionKey] ?? 'x';
    _btService.send(char);
  }

  void _handleActionUp(String actionKey) {
    if (!_btService.isConnected) return;
    
    // Remove from active set
    _activeActions.remove(actionKey);
    
    if (_activeActions.isEmpty) {
      // Replicate Python safety logic: Send stop character ('x') when all keys are released
      final stopChar = _mappingService.mappings['stop'] ?? 'x';
      _btService.send(stopChar);
      _triggerHaptic();
    } else {
      // Resume the last held action
      final lastAction = _activeActions.last;
      final char = _mappingService.mappings[lastAction] ?? 'x';
      _btService.send(char);
    }
  }

  void _handleCustomButtonDown(CustomButton btn) {
    if (!_btService.isConnected) return;
    _triggerHaptic();
    _btService.send(btn.code);
  }

  void _handleCustomButtonUp(CustomButton btn) {
    if (!_btService.isConnected) return;
    if (btn.behavior == 'hold') {
      final stopChar = _mappingService.mappings['stop'] ?? 'x';
      _btService.send(stopChar);
      _triggerHaptic();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_btService, _mappingService]),
      builder: (context, child) {
        final isConnected = _btService.isConnected;
        final customButtons = _mappingService.customButtons;
        final txLogs = _btService.consoleLogs.where((log) => log.contains("TX:") || log.contains("Robot:")).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('HEXAPOD PILOT'),
          ),
          body: !isConnected
              ? _buildDisconnectedOverlay()
              : Column(
                  children: [
                    // Connection Status bar
                    _buildConnectionStatusBar(),

                    // Main Controls Layout
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Layout Grid for Movement and Rotation
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // LEFT: D-Pad Movement (Maju, Mundur, Kiri, Kanan)
                                  Expanded(
                                    flex: 5,
                                    child: _buildDPadSection(),
                                  ),
                                  const SizedBox(width: 16),
                                  // RIGHT: Rotation controls
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      children: [
                                        _buildRotationSection(),
                                        const SizedBox(height: 16),
                                        _buildHeadSection(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Custom Buttons Grid
                              _buildCustomButtonsSection(customButtons),

                              const SizedBox(height: 16),

                              // Compact Transmission Console
                              _buildTransmissionConsole(txLogs),

                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildConnectionStatusBar() {
    return Container(
      color: const Color(0xFF0C242E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF00E5FF),
                  shape: BoxShape.circle,
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(begin: const Offset(1, 1), end: const Offset(1.5, 1.5), duration: 1.seconds),
              const SizedBox(width: 8),
              Text(
                'BLUETOOTH LINK: ACTIVE',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00E5FF),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          Text(
            'SPP PROTOCOL',
            style: GoogleFonts.shareTechMono(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111726),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF3D00).withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Color(0xFFFF3D00),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms),
            const SizedBox(height: 16),
            Text(
              'PILOT OFFLINE',
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFF3D00),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please connect to your Hexapod (HC-05) on the CONNECT tab before attempting manual pilot control.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDPadSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            'WALK CONTROLS',
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final btnSize = constraints.maxWidth / 3;
                return Stack(
                  children: [
                    // Up (Maju - w)
                    Positioned(
                      top: 0,
                      left: btnSize,
                      width: btnSize,
                      height: btnSize,
                      child: _buildControlPadButton(
                        actionKey: 'maju',
                        icon: Icons.keyboard_arrow_up,
                        label: 'FWD',
                      ),
                    ),
                    // Left (Kiri - a)
                    Positioned(
                      top: btnSize,
                      left: 0,
                      width: btnSize,
                      height: btnSize,
                      child: _buildControlPadButton(
                        actionKey: 'kiri',
                        icon: Icons.keyboard_arrow_left,
                        label: 'L',
                      ),
                    ),
                    // Center indicator
                    Positioned(
                      top: btnSize,
                      left: btnSize,
                      width: btnSize,
                      height: btnSize,
                      child: Center(
                        child: Container(
                          width: btnSize * 0.7,
                          height: btnSize * 0.7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _activeActions.isEmpty
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFFF007F).withOpacity(0.4),
                              width: 2,
                            ),
                            color: _activeActions.isEmpty
                                ? const Color(0xFF070B12)
                                : const Color(0xFFFF007F).withOpacity(0.05),
                          ),
                          child: Center(
                            child: Icon(
                              _activeActions.isEmpty ? Icons.radar : Icons.motion_photos_on_outlined,
                              size: 16,
                              color: _activeActions.isEmpty
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFFF007F),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Right (Kanan - s)
                    Positioned(
                      top: btnSize,
                      right: 0,
                      width: btnSize,
                      height: btnSize,
                      child: _buildControlPadButton(
                        actionKey: 'kanan',
                        icon: Icons.keyboard_arrow_right,
                        label: 'R',
                      ),
                    ),
                    // Down (Mundur - z)
                    Positioned(
                      bottom: 0,
                      left: btnSize,
                      width: btnSize,
                      height: btnSize,
                      child: _buildControlPadButton(
                        actionKey: 'mundur',
                        icon: Icons.keyboard_arrow_down,
                        label: 'REV',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            'ROTATE CONTROLS',
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildControlPadButton(
                  actionKey: 'putar_kiri',
                  icon: Icons.rotate_left,
                  label: 'ROT L',
                  compact: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildControlPadButton(
                  actionKey: 'putar_kanan',
                  icon: Icons.rotate_right,
                  label: 'ROT R',
                  compact: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeadSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            'HEAD CONTROL',
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildControlPadButton(
                  actionKey: 'kepala_kiri',
                  icon: Icons.subdirectory_arrow_left,
                  label: 'HEAD L',
                  compact: true,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildControlPadButton(
                  actionKey: 'kepala_tengah',
                  icon: Icons.vertical_align_center,
                  label: 'CTR',
                  compact: true,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildControlPadButton(
                  actionKey: 'kepala_kanan',
                  icon: Icons.subdirectory_arrow_right,
                  label: 'HEAD R',
                  compact: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlPadButton({
    required String actionKey,
    required IconData icon,
    required String label,
    bool compact = false,
  }) {
    final bool isPressed = _activeActions.contains(actionKey);
    final themeColor = compact ? const Color(0xFF00E5FF) : const Color(0xFFFF007F);

    return Listener(
      onPointerDown: (_) => _handleActionDown(actionKey),
      onPointerUp: (_) => _handleActionUp(actionKey),
      child: AnimatedContainer(
        duration: 80.ms,
        padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12, horizontal: 4),
        decoration: BoxDecoration(
          color: isPressed ? themeColor.withOpacity(0.15) : const Color(0xFF111726),
          border: Border.all(
            color: isPressed ? themeColor : const Color(0xFF1E293B),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: themeColor.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPressed ? themeColor : Colors.white,
              size: compact ? 20 : 28,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: compact ? 9 : 10,
                fontWeight: FontWeight.bold,
                color: isPressed ? themeColor : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomButtonsSection(List<CustomButton> customButtons) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CUSTOM PILOT CHANNELS',
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          customButtons.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No Custom Channels Configured.\nConfigure them in Settings!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.shareTechMono(
                        color: const Color(0xFF475569),
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: customButtons.length,
                  itemBuilder: (context, index) {
                    final btn = customButtons[index];
                    return Listener(
                      onPointerDown: (_) => _handleCustomButtonDown(btn),
                      onPointerUp: (_) => _handleCustomButtonUp(btn),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111726),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              btn.label.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.orbitron(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFFB000),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'CMD: \'${btn.code}\' [${btn.behavior.toUpperCase()}]',
                              style: GoogleFonts.shareTechMono(
                                fontSize: 8,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildTransmissionConsole(List<String> logs) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B101D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1524),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.flash_on, size: 14, color: Color(0xFF00E5FF)),
                const SizedBox(width: 8),
                Text(
                  'TX / RX DATA REAL-TIME FEED',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00E5FF),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 100,
            padding: const EdgeInsets.all(12),
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'Transmission line open. Press controls to transmit...',
                      style: GoogleFonts.shareTechMono(
                        color: const Color(0xFF475569),
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[logs.length - 1 - index];
                      final isTx = log.contains("TX:");
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Row(
                          children: [
                            Text(
                              log.substring(0, 11), // Timestamp e.g. [12:34:56]
                              style: GoogleFonts.shareTechMono(
                                color: const Color(0xFF475569),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                log.substring(11), // The actual command
                                style: GoogleFonts.shareTechMono(
                                  color: isTx ? const Color(0xFF00E5FF) : const Color(0xFF10B981),
                                  fontSize: 12,
                                  fontWeight: isTx ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
