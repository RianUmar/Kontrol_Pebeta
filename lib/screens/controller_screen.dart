// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:async';
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
  Timer? _streamTimer;

  @override
  void dispose() {
    _stopStreamTimer();
    super.dispose();
  }

  void _triggerHaptic() {
    if (_mappingService.hapticFeedbackEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  void _startStreamTimer() {
    _streamTimer?.cancel();
    if (!_mappingService.continuousStreamEnabled) return;

    final intervalMs = _mappingService.streamIntervalMs;
    _streamTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (!_btService.isConnected || _activeActions.isEmpty) {
        timer.cancel();
        _streamTimer = null;
        return;
      }
      final lastAction = _activeActions.last;
      final char = _mappingService.mappings[lastAction] ?? 'x';
      _btService.send(char);
    });
  }

  void _stopStreamTimer() {
    _streamTimer?.cancel();
    _streamTimer = null;
  }

  void _handleActionDown(String actionKey) {
    if (!_btService.isConnected) return;
    
    _triggerHaptic();
    
    // Add to active set
    _activeActions.add(actionKey);
    
    // Send mapped character immediately
    final char = _mappingService.mappings[actionKey] ?? 'x';
    _btService.send(char);
    
    // Start continuous stream timer while held
    _startStreamTimer();
    
    // Trigger UI refresh to show pressed visual state
    setState(() {});
  }

  void _handleActionUp(String actionKey) {
    if (!_btService.isConnected) return;
    
    // Remove from active set
    _activeActions.remove(actionKey);
    
    if (_activeActions.isEmpty) {
      _stopStreamTimer();
      // Send stop character ('x') when all keys are released
      final stopCharKey = _mappingService.robotMode == RobotMode.car ? 'car_stop' : 'hex_stop';
      final stopChar = _mappingService.mappings[stopCharKey] ?? _mappingService.mappings['stop'] ?? 'x';
      _btService.send(stopChar);
      _triggerHaptic();
    } else {
      // Resume the last held action and restart stream timer
      final lastAction = _activeActions.last;
      final char = _mappingService.mappings[lastAction] ?? 'x';
      _btService.send(char);
      _startStreamTimer();
    }
    
    // Trigger UI refresh to show released visual state
    setState(() {});
  }

  void _sendEmergencyStop() {
    if (!_btService.isConnected) return;
    _activeActions.clear();
    _stopStreamTimer();
    final stopCharKey = _mappingService.robotMode == RobotMode.car ? 'car_stop' : 'hex_stop';
    final stopChar = _mappingService.mappings[stopCharKey] ?? _mappingService.mappings['stop'] ?? 'x';
    _btService.send(stopChar);
    if (_mappingService.hapticFeedbackEnabled) {
      HapticFeedback.heavyImpact();
    }
    setState(() {});
  }

  void _handleCustomButtonDown(CustomButton btn) {
    if (!_btService.isConnected) return;
    _triggerHaptic();
    _btService.send(btn.code);
  }

  void _handleCustomButtonUp(CustomButton btn) {
    if (!_btService.isConnected) return;
    if (btn.behavior == 'hold') {
      final stopCharKey = _mappingService.robotMode == RobotMode.car ? 'car_stop' : 'hex_stop';
      final stopChar = _mappingService.mappings[stopCharKey] ?? _mappingService.mappings['stop'] ?? 'x';
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
        final isCarMode = _mappingService.robotMode == RobotMode.car;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCarMode ? Icons.directions_car : Icons.pest_control_rounded,
                  color: isCarMode ? const Color(0xFF00E5FF) : const Color(0xFFFF007F),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isCarMode ? 'ROBOT CAR PILOT' : 'HEXAPOD PILOT',
                  style: GoogleFonts.orbitron(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            actions: [
              _buildModeSwitchSegment(),
              const SizedBox(width: 8),
            ],
          ),
          body: !isConnected
              ? _buildDisconnectedOverlay(isCarMode)
              : Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: isCarMode
                      ? _buildCarLayout(txLogs, customButtons)
                      : _buildHexapodLayout(txLogs, customButtons),
                ),
        );
      },
    );
  }

  Widget _buildModeSwitchSegment() {
    final currentMode = _mappingService.robotMode;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1425),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeSwitchItem(
            mode: RobotMode.car,
            icon: Icons.directions_car,
            label: 'CAR',
            isActive: currentMode == RobotMode.car,
            activeColor: const Color(0xFF00E5FF),
          ),
          const SizedBox(width: 2),
          _buildModeSwitchItem(
            mode: RobotMode.hexapod,
            icon: Icons.pest_control_rounded,
            label: 'HEXAPOD',
            isActive: currentMode == RobotMode.hexapod,
            activeColor: const Color(0xFFFF007F),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitchItem({
    required RobotMode mode,
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: () {
        if (_mappingService.robotMode == mode) return;
        _stopStreamTimer();
        _activeActions.clear();
        final stopCharKey = mode == RobotMode.car ? 'car_stop' : 'hex_stop';
        final stopChar = _mappingService.mappings[stopCharKey] ?? _mappingService.mappings['stop'] ?? 'x';
        _btService.send(stopChar);
        _triggerHaptic();
        _mappingService.setRobotMode(mode);
      },
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? activeColor : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? activeColor : const Color(0xFF64748B)),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? activeColor : const Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectedOverlay(bool isCarMode) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111726).withOpacity(0.65),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF3D00).withOpacity(0.4), width: 1.5),
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
              isCarMode ? 'ROBOT CAR DISCONNECTED' : 'HEXAPOD PILOT OFFLINE',
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFF3D00),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isCarMode
                  ? 'Please connect to your Robot Car Bluetooth module on the CONNECT tab before driving.'
                  : 'Please connect to your Hexapod (HC-05) on the CONNECT tab before attempting manual pilot control.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusBar({bool isCarMode = true}) {
    final statusColor = isCarMode ? const Color(0xFF00E5FF) : const Color(0xFFFF007F);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C242E).withOpacity(0.65),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(begin: const Offset(1, 1), end: const Offset(1.5, 1.5), duration: 1.seconds),
              const SizedBox(width: 8),
              Text(
                isCarMode ? 'ROBOT CAR LINK: ACTIVE' : 'HEXAPOD LINK: ACTIVE',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          Text(
            'SPP PROTOCOL',
            style: GoogleFonts.shareTechMono(
              fontSize: 10,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LAYOUT 1: ROBOT CAR LAYOUT
  // ===========================================================================
  Widget _buildCarLayout(List<String> txLogs, List<CustomButton> customButtons) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT COLUMN: Maju / Mundur Controls (Throttle)
        Expanded(
          flex: 3,
          child: _buildThrottleSection(),
        ),

        const SizedBox(width: 10),

        // CENTER COLUMN: Status bar + Emergency Stop + Transmission log
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildConnectionStatusBar(isCarMode: true),
              const SizedBox(height: 6),
              _buildEmergencyStopButton(),
              const SizedBox(height: 6),
              Expanded(
                child: _buildTransmissionConsole(txLogs),
              ),
              if (customButtons.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildCustomButtonsBar(customButtons),
              ],
            ],
          ),
        ),

        const SizedBox(width: 10),

        // RIGHT COLUMN: Klakson & Belok Kiri / Kanan Controls (Steering)
        Expanded(
          flex: 3,
          child: _buildSteeringSection(),
        ),
      ],
    );
  }

  Widget _buildThrottleSection() {
    final bool isMajuPressed = _activeActions.contains('car_maju');
    final bool isMundurPressed = _activeActions.contains('car_mundur');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524).withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isMajuPressed || isMundurPressed)
              ? const Color(0xFF00E5FF).withOpacity(0.6)
              : const Color(0xFF1E293B).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: (isMajuPressed || isMundurPressed)
            ? [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.12),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.speed, size: 14, color: Color(0xFF00E5FF)),
              const SizedBox(width: 6),
              Text(
                'MAJU / MUNDUR',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF00E5FF),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              children: [
                // MAJU (FORWARD)
                Expanded(
                  child: _buildDriveButton(
                    actionKey: 'car_maju',
                    label: 'MAJU',
                    sublabel: 'FORWARD [w]',
                    icon: Icons.keyboard_double_arrow_up_rounded,
                    accentColor: const Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(height: 8),
                // MUNDUR (BACKWARD)
                Expanded(
                  child: _buildDriveButton(
                    actionKey: 'car_mundur',
                    label: 'MUNDUR',
                    sublabel: 'REVERSE [s]',
                    icon: Icons.keyboard_double_arrow_down_rounded,
                    accentColor: const Color(0xFFFF007F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteeringSection() {
    final bool isKiriPressed = _activeActions.contains('car_kiri');
    final bool isKananPressed = _activeActions.contains('car_kanan');
    final bool isKlaksonPressed = _activeActions.contains('car_klakson');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524).withOpacity(0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isKiriPressed || isKananPressed || isKlaksonPressed)
              ? const Color(0xFFFF007F).withOpacity(0.6)
              : const Color(0xFF1E293B).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: (isKiriPressed || isKananPressed || isKlaksonPressed)
            ? [
                BoxShadow(
                  color: const Color(0xFFFF007F).withOpacity(0.12),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.explore, size: 14, color: Color(0xFFFF007F)),
              const SizedBox(width: 6),
              Text(
                'KEMUDI & KLAKSON',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF007F),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // KLAKSON (HORN) BUTTON (ABOVE STEERING)
          Expanded(
            flex: 1,
            child: _buildHornButton(),
          ),
          const SizedBox(height: 8),
          // STEERING (BELOK KIRI & KANAN)
          Expanded(
            flex: 3,
            child: Row(
              children: [
                // KIRI (LEFT)
                Expanded(
                  child: _buildDriveButton(
                    actionKey: 'car_kiri',
                    label: 'BELOK KIRI',
                    sublabel: 'LEFT [f]',
                    icon: Icons.arrow_back_rounded,
                    accentColor: const Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(width: 8),
                // KANAN (RIGHT)
                Expanded(
                  child: _buildDriveButton(
                    actionKey: 'car_kanan',
                    label: 'BELOK KANAN',
                    sublabel: 'RIGHT [j]',
                    icon: Icons.arrow_forward_rounded,
                    accentColor: const Color(0xFFFF007F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHornButton() {
    final bool isPressed = _activeActions.contains('car_klakson');
    const accentColor = Color(0xFFFFB000); // Warm Amber Cyber theme for Klakson

    return Listener(
      onPointerDown: (_) => _handleActionDown('car_klakson'),
      onPointerUp: (_) => _handleActionUp('car_klakson'),
      onPointerCancel: (_) => _handleActionUp('car_klakson'),
      child: AnimatedContainer(
        duration: 80.ms,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isPressed ? accentColor.withOpacity(0.25) : const Color(0xFF111726).withOpacity(0.65),
          border: Border.all(
            color: isPressed ? accentColor : const Color(0xFFFFB000).withOpacity(0.5),
            width: isPressed ? 2.5 : 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.35),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_rounded,
              color: isPressed ? accentColor : const Color(0xFFFFB000),
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'KLAKSON',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isPressed ? accentColor : Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '[a]',
              style: GoogleFonts.shareTechMono(
                fontSize: 10,
                color: isPressed ? accentColor : const Color(0xFFFFB000),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyStopButton() {
    final isStopped = _activeActions.isEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _sendEmergencyStop,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3D00).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFF3D00).withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF3D00).withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pan_tool_rounded, color: Color(0xFFFF3D00), size: 16),
              const SizedBox(width: 6),
              Text(
                'EMERGENCY STOP (X)',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF3D00),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isStopped ? const Color(0xFF10B981).withOpacity(0.2) : const Color(0xFFFF3D00).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isStopped ? 'STOPPED' : 'ACTIVE',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isStopped ? const Color(0xFF10B981) : const Color(0xFFFF3D00),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // LAYOUT 2: HEXAPOD ROBOT LAYOUT
  // ===========================================================================
  Widget _buildHexapodLayout(List<String> txLogs, List<CustomButton> customButtons) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT COLUMN: Walk controls (D-Pad)
        Expanded(
          flex: 3,
          child: _buildDPadSection(),
        ),

        const SizedBox(width: 10),

        // CENTER COLUMN: Status bar + Head controls + Gripper + Transmission log
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildConnectionStatusBar(isCarMode: false),
              const SizedBox(height: 6),
              _buildHeadSection(),
              const SizedBox(height: 6),
              _buildGripperSection(),
              const SizedBox(height: 6),
              Expanded(
                child: _buildTransmissionConsole(txLogs),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // RIGHT COLUMN: Rotation + Custom channels
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRotationSection(),
              const SizedBox(height: 8),
              Expanded(
                child: _buildCustomButtonsSection(customButtons),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDPadSection() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524).withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B).withOpacity(0.4), width: 1.5),
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
          const SizedBox(height: 6),
          Expanded(
            child: AspectRatio(
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
                          actionKey: 'hex_maju',
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
                          actionKey: 'hex_kiri',
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
                                    ? const Color(0xFF1E293B).withOpacity(0.4)
                                    : const Color(0xFFFF007F).withOpacity(0.4),
                                width: 2,
                              ),
                              color: _activeActions.isEmpty
                                  ? const Color(0xFF070B12).withOpacity(0.3)
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
                          actionKey: 'hex_kanan',
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
                          actionKey: 'hex_mundur',
                          icon: Icons.keyboard_arrow_down,
                          label: 'REV',
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524).withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B).withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            'ROTATE CONTROLS',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildControlPadButton(
                  actionKey: 'hex_putar_kiri',
                  icon: Icons.rotate_left,
                  label: 'ROT L',
                  compact: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildControlPadButton(
                  actionKey: 'hex_putar_kanan',
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524).withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B).withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            'HEAD CONTROL',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildControlPadButton(
                  actionKey: 'hex_kepala_kiri',
                  icon: Icons.subdirectory_arrow_left,
                  label: 'HEAD L',
                  compact: true,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildControlPadButton(
                  actionKey: 'hex_kepala_tengah',
                  icon: Icons.vertical_align_center,
                  label: 'CTR',
                  compact: true,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildControlPadButton(
                  actionKey: 'hex_kepala_kanan',
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

  Widget _buildGripperSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524).withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B).withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            'GRIPPER MANIPULATOR',
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // LENGAN GROUP
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'LENGAN (ARM)',
                      style: GoogleFonts.orbitron(fontSize: 8, color: const Color(0xFFFFB000), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGripperButton(
                            actionKey: 'hex_lengan_naik',
                            stopActionKey: 'hex_lengan_naik_stop',
                            icon: Icons.arrow_upward,
                            label: 'NAIK',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildGripperButton(
                            actionKey: 'hex_lengan_turun',
                            stopActionKey: 'hex_lengan_turun_stop',
                            icon: Icons.arrow_downward,
                            label: 'TURUN',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // CAPIT GROUP
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'CAPIT (CLAW)',
                      style: GoogleFonts.orbitron(fontSize: 8, color: const Color(0xFFFFB000), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGripperButton(
                            actionKey: 'hex_capit_tangkap',
                            stopActionKey: 'hex_capit_tangkap_stop',
                            icon: Icons.blur_circular,
                            label: 'TANGKAP',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildGripperButton(
                            actionKey: 'hex_capit_lepas',
                            stopActionKey: 'hex_capit_lepas_stop',
                            icon: Icons.open_in_full,
                            label: 'LEPAS',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGripperButton({
    required String actionKey,
    required String stopActionKey,
    required IconData icon,
    required String label,
  }) {
    final bool isPressed = _activeActions.contains(actionKey);
    const themeColor = Color(0xFFFFB000); // Warm yellow/orange cyber theme for gripper

    return Listener(
      onPointerDown: (_) {
        if (!_btService.isConnected) return;
        _triggerHaptic();
        _activeActions.add(actionKey);
        final char = _mappingService.mappings[actionKey] ?? '';
        _btService.send(char);
        setState(() {});
      },
      onPointerUp: (_) {
        if (!_btService.isConnected) return;
        _activeActions.remove(actionKey);
        final stopChar = _mappingService.mappings[stopActionKey] ?? '';
        _btService.send(stopChar);
        _triggerHaptic();
        setState(() {});
      },
      onPointerCancel: (_) {
        if (!_btService.isConnected) return;
        _activeActions.remove(actionKey);
        final stopChar = _mappingService.mappings[stopActionKey] ?? '';
        _btService.send(stopChar);
        _triggerHaptic();
        setState(() {});
      },
      child: AnimatedContainer(
        duration: 80.ms,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: isPressed ? themeColor.withOpacity(0.15) : const Color(0xFF111726).withOpacity(0.55),
          border: Border.all(
            color: isPressed ? themeColor : const Color(0xFF1E293B).withOpacity(0.4),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(8),
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
              size: 18,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: isPressed ? themeColor : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
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
      onPointerCancel: (_) => _handleActionUp(actionKey),
      child: AnimatedContainer(
        duration: 80.ms,
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isPressed ? themeColor.withOpacity(0.15) : const Color(0xFF111726).withOpacity(0.55),
          border: Border.all(
            color: isPressed ? themeColor : const Color(0xFF1E293B).withOpacity(0.4),
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

  // ===========================================================================
  // COMMON HELPER WIDGETS
  // ===========================================================================
  Widget _buildDriveButton({
    required String actionKey,
    required String label,
    required String sublabel,
    required IconData icon,
    required Color accentColor,
  }) {
    final bool isPressed = _activeActions.contains(actionKey);

    return Listener(
      onPointerDown: (_) => _handleActionDown(actionKey),
      onPointerUp: (_) => _handleActionUp(actionKey),
      onPointerCancel: (_) => _handleActionUp(actionKey),
      child: AnimatedContainer(
        duration: 80.ms,
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: isPressed ? accentColor.withOpacity(0.22) : const Color(0xFF111726).withOpacity(0.65),
          border: Border.all(
            color: isPressed ? accentColor : const Color(0xFF1E293B).withOpacity(0.6),
            width: isPressed ? 2.5 : 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 14,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPressed ? accentColor : Colors.white,
              size: 38,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isPressed ? accentColor : Colors.white,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: GoogleFonts.shareTechMono(
                fontSize: 9,
                color: isPressed ? accentColor.withOpacity(0.9) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomButtonsBar(List<CustomButton> customButtons) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524).withOpacity(0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B).withOpacity(0.4), width: 1),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: customButtons.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final btn = customButtons[index];
          return Listener(
            onPointerDown: (_) => _handleCustomButtonDown(btn),
            onPointerUp: (_) => _handleCustomButtonUp(btn),
            onPointerCancel: (_) => _handleCustomButtonUp(btn),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF111726).withOpacity(0.75),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFFB000).withOpacity(0.5), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, size: 10, color: Color(0xFFFFB000)),
                  const SizedBox(width: 4),
                  Text(
                    btn.label.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFB000),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomButtonsSection(List<CustomButton> customButtons) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524).withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B).withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CUSTOM PILOT CHANNELS',
            textAlign: TextAlign.center,
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: customButtons.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        'No Custom Channels.\nGo to Settings!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.shareTechMono(
                          color: const Color(0xFF475569),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: customButtons.length,
                      itemBuilder: (context, index) {
                        final btn = customButtons[index];
                        return Listener(
                          onPointerDown: (_) => _handleCustomButtonDown(btn),
                          onPointerUp: (_) => _handleCustomButtonUp(btn),
                          onPointerCancel: (_) => _handleCustomButtonUp(btn),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF111726).withOpacity(0.55),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF1E293B).withOpacity(0.4), width: 1.5),
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
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransmissionConsole(List<String> logs) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B101D).withOpacity(0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B).withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1524).withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                bottom: BorderSide(color: const Color(0xFF1E293B).withOpacity(0.4), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 12, color: Color(0xFF00E5FF)),
                const SizedBox(width: 6),
                Text(
                  'REAL-TIME COMMAND FEED',
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00E5FF),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: logs.isEmpty
                  ? Center(
                      child: Text(
                        'Ready. Tap controls to transmit commands...',
                        style: GoogleFonts.shareTechMono(
                          color: const Color(0xFF475569),
                          fontSize: 10,
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
                                log.substring(0, 11),
                                style: GoogleFonts.shareTechMono(
                                  color: const Color(0xFF475569),
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  log.substring(11),
                                  style: GoogleFonts.shareTechMono(
                                    color: isTx ? const Color(0xFF00E5FF) : const Color(0xFF10B981),
                                    fontSize: 10,
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
          ),
        ],
      ),
    );
  }
}
