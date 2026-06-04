import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/bluetooth_service.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final BluetoothService _btService = BluetoothService();

  @override
  void initState() {
    super.initState();
    // Auto-refresh bonded devices on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _btService.refreshBondedDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _btService,
      builder: (context, child) {
        final isConnected = _btService.isConnected;
        final isConnecting = _btService.isConnecting;
        final devices = _btService.bondedDevices;
        final logs = _btService.consoleLogs;

        return Scaffold(
          appBar: AppBar(
            title: const Text('HEXAPOD CORE'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF00E5FF)),
                tooltip: 'Refresh Devices',
                onPressed: isConnecting
                    ? null
                    : () {
                        _btService.refreshBondedDevices();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Refreshing bonded devices list...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // System Status Header
              _buildStatusHeader(isConnected, isConnecting),

              const SizedBox(height: 16),

              // Title Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'PAIRED BLUETOOTH DEVICES',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B),
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Paired Devices List
              Expanded(
                flex: 3,
                child: devices.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return _buildDeviceCard(device);
                        },
                      ),
              ),

              // Console / Terminal Output preview
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.all(16),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.terminal, size: 16, color: Color(0xFFFF007F)),
                                const SizedBox(width: 8),
                                Text(
                                  'SYSTEM CONSOLE',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFFF007F),
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => _btService.clearLogs(),
                              child: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: logs.isEmpty
                            ? Center(
                                child: Text(
                                  'Console idle. Ready for connection.',
                                  style: GoogleFonts.shareTechMono(
                                    color: const Color(0xFF475569),
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                reverse: true,
                                padding: const EdgeInsets.all(12),
                                itemCount: logs.length,
                                itemBuilder: (context, index) {
                                  // Show newest logs at bottom
                                  final log = logs[logs.length - 1 - index];
                                  Color logColor = const Color(0xFF94A3B8);
                                  if (log.contains("TX:")) {
                                    logColor = const Color(0xFF00E5FF);
                                  } else if (log.contains("Robot:")) {
                                    logColor = const Color(0xFF10B981);
                                  } else if (log.contains("Error") || log.contains("failed")) {
                                    logColor = const Color(0xFFEF4444);
                                  } else if (log.contains("Connected")) {
                                    logColor = const Color(0xFF10B981);
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Text(
                                      log,
                                      style: GoogleFonts.shareTechMono(
                                        color: logColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(bool isConnected, bool isConnecting) {
    String statusText = 'DISCONNECTED';
    Color statusColor = const Color(0xFFFF3D00);
    IconData statusIcon = Icons.bluetooth_disabled;
    List<Color> gradientColors = [const Color(0xFF1E1B29), const Color(0xFF140F1D)];

    if (isConnected) {
      statusText = 'SYSTEM ONLINE / CONNECTED';
      statusColor = const Color(0xFF00E5FF);
      statusIcon = Icons.bluetooth_connected;
      gradientColors = [const Color(0xFF0C242E), const Color(0xFF071520)];
    } else if (isConnecting) {
      statusText = 'ESTABLISHING LINK...';
      statusColor = const Color(0xFFFFB000);
      statusIcon = Icons.bluetooth_searching;
      gradientColors = [const Color(0xFF2E220C), const Color(0xFF1E170A)];
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ).animate(onPlay: (controller) => controller.repeat(reverse: isConnecting))
           .scale(
              begin: const Offset(1, 1),
              end: isConnecting ? const Offset(1.15, 1.15) : const Offset(1, 1),
              duration: 800.ms,
              curve: Curves.easeInOut,
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROBOT INTERFACE STATE',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: GoogleFonts.orbitron(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          if (isConnected)
            ElevatedButton(
              onPressed: () => _btService.disconnect(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3D00).withOpacity(0.2),
                foregroundColor: const Color(0xFFFF3D00),
                side: const BorderSide(color: Color(0xFFFF3D00), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Text(
                'DISCONNECT',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111726),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bluetooth_searching,
                size: 48,
                color: Color(0xFF475569),
              ),
              const SizedBox(height: 16),
              Text(
                'No Paired Devices Found',
                style: GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please pair your HC-05 module in your phone\'s system Bluetooth settings first, then click refresh.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _btService.refreshBondedDevices(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('REFRESH LIST'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BluetoothDevice device) {
    final bool isDeviceConnecting = _btService.isConnecting && 
        _btService.consoleLogs.last.contains(device.address);
    
    // Check if this specific device is the connected one
    // Note: To match address, we compare _btService.isConnected and verify device properties
    final bool isThisDeviceConnected = _btService.isConnected && 
        _btService.consoleLogs.any((log) => log.contains("Connected to") && log.contains(device.address));

    final cardBorderColor = isThisDeviceConnected 
        ? const Color(0xFF00E5FF)
        : const Color(0xFF1E293B);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111726),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: isThisDeviceConnected
            ? [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isThisDeviceConnected 
                ? const Color(0xFF00E5FF).withOpacity(0.1)
                : const Color(0xFF1E293B),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isThisDeviceConnected ? Icons.bluetooth_connected : Icons.bluetooth,
            color: isThisDeviceConnected ? const Color(0xFF00E5FF) : const Color(0xFF64748B),
          ),
        ),
        title: Text(
          device.name ?? 'Unknown Device',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.5,
            color: isThisDeviceConnected ? const Color(0xFF00E5FF) : Colors.white,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            device.address,
            style: GoogleFonts.shareTechMono(
              color: const Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
        ),
        trailing: _btService.isConnecting
            ? (isDeviceConnecting 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFB000)),
                    ),
                  )
                : null)
            : ElevatedButton(
                onPressed: isThisDeviceConnected
                    ? () => _btService.disconnect()
                    : () => _btService.connect(device),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isThisDeviceConnected 
                      ? const Color(0xFFFF3D00).withOpacity(0.2)
                      : const Color(0xFF00E5FF).withOpacity(0.1),
                  foregroundColor: isThisDeviceConnected 
                      ? const Color(0xFFFF3D00)
                      : const Color(0xFF00E5FF),
                  side: BorderSide(
                    color: isThisDeviceConnected 
                        ? const Color(0xFFFF3D00)
                        : const Color(0xFF00E5FF),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isThisDeviceConnected ? 'DISCONNECT' : 'CONNECT',
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }
}
