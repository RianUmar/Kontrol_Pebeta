import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/control_mapping_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ControlMappingService _mappingService = ControlMappingService();
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _mappingService.mappings.forEach((key, value) {
      _controllers[key] = TextEditingController(text: value);
    });
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveStandardMappings() async {
    for (var entry in _controllers.entries) {
      await _mappingService.updateMapping(entry.key, entry.value.text);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Standard mappings updated successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _resetStandardMappings() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111726).withOpacity(0.95),
        title: Text(
          'RESET MAPPINGS',
          style: GoogleFonts.orbitron(color: const Color(0xFFFF3D00), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to reset all standard mappings to defaults (w, s, a, z, d, k, f, j, e, x)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _mappingService.resetMappings();
              setState(() {
                _initControllers();
              });
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Standard mappings reset to defaults.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3D00)),
            child: const Text('RESET', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddCustomButtonDialog() {
    final labelCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String selectedBehavior = 'tap';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF111726).withOpacity(0.95),
            title: Text(
              'ADD CUSTOM CHANNEL',
              style: GoogleFonts.orbitron(color: const Color(0xFF00E5FF), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Button Label (e.g. LED ON)',
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF))),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Char Code (e.g. 1 or u)',
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF))),
                    ),
                    maxLength: 3, // Allow commands like 1, u, or off
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Button Press Behavior:',
                    style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'tap',
                        groupValue: selectedBehavior,
                        activeColor: const Color(0xFF00E5FF),
                        onChanged: (val) {
                          setDialogState(() => selectedBehavior = val!);
                        },
                      ),
                      const Text('Tap (Trigger once)'),
                    ],
                  ),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'hold',
                        groupValue: selectedBehavior,
                        activeColor: const Color(0xFF00E5FF),
                        onChanged: (val) {
                          setDialogState(() => selectedBehavior = val!);
                        },
                      ),
                      const Text('Hold (Sends code on down, release code on up)'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () {
                  final label = labelCtrl.text.trim();
                  final code = codeCtrl.text.trim();
                  if (label.isEmpty || code.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill out all fields.'), backgroundColor: Color(0xFFFF3D00)),
                    );
                    return;
                  }
                  _mappingService.addCustomButton(label, code, selectedBehavior);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
                child: const Text('ADD BUTTON', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _mappingService,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('ROBOTECH TADULAKO'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment .stretch,
              children: [
                // General Settings Card
                _buildSectionHeader('GENERAL SYSTEMS'),
                _buildGeneralSettingsCard(),
                
                const SizedBox(height: 24),
                
                // Mappings Card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('CONTROL CODE MAPPINGS'),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _resetStandardMappings,
                          child: const Text(
                            'RESET',
                            style: TextStyle(color: Color(0xFFFF3D00), fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveStandardMappings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('SAVE MAPPINGS', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildMappingsCard(),

                const SizedBox(height: 24),

                // Custom Channels Card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('CUSTOM PILOT CHANNELS'),
                    ElevatedButton.icon(
                      onPressed: _showAddCustomButtonDialog,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('ADD'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF007F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8), 
                _buildCustomButtonsCard(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.orbitron(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF64748B),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildGeneralSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111726).withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B).withOpacity(0.4)),
      ),
      child: SwitchListTile(
        title: Text(
          'HAPTIC FEEDBACK',
          style: GoogleFonts.orbitron(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        subtitle: const Text('Vibrate phone briefly during pilot actions to provide tactile feedback'),
        value: _mappingService.hapticFeedbackEnabled,
        activeColor: const Color(0xFF00E5FF),
        onChanged: (val) {
          _mappingService.setHapticFeedback(val);
        },
      ),
    );
  }

  Widget _buildMappingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111726).withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          _buildMappingSubCategory('Walk Directives', [
            _buildMapField('maju', 'FORWARD ACTION (W)'),
            _buildMapField('kiri', 'STRAFE LEFT ACTION (A)'),
            _buildMapField('kanan', 'STRAFE RIGHT ACTION (S)'),
            _buildMapField('mundur', 'BACKWARD ACTION (Z)'),
            _buildMapField('stop', 'STANDBY/RELEASE CODE (X)'),
          ]),
          const Divider(color: Color(0xFF1E293B), height: 32),
          _buildMappingSubCategory('Rotation Commands', [
            _buildMapField('putar_kiri', 'ROTATE LEFT (D)'),
            _buildMapField('putar_kanan', 'ROTATE RIGHT (K)'),
          ]),
          const Divider(color: Color(0xFF1E293B), height: 32),
          _buildMappingSubCategory('Head Movements', [
            _buildMapField('kepala_kiri', 'HEAD TILT LEFT (F)'),
            _buildMapField('kepala_tengah', 'HEAD CENTER (E)'),
            _buildMapField('kepala_kanan', 'HEAD TILT RIGHT (J)'),
          ]),
          const Divider(color: Color(0xFF1E293B), height: 32),
          _buildMappingSubCategory('Gripper Manipulator', [
            _buildMapField('lengan_naik', 'ARM UP START (u)'),
            _buildMapField('lengan_naik_stop', 'ARM UP STOP (U)'),
            _buildMapField('lengan_turun', 'ARM DOWN START (n)'),
            _buildMapField('lengan_turun_stop', 'ARM DOWN STOP (N)'),
            _buildMapField('capit_tangkap', 'CLAW CLOSE START (o)'),
            _buildMapField('capit_tangkap_stop', 'CLAW CLOSE STOP (O)'),
            _buildMapField('capit_lepas', 'CLAW OPEN START (c)'),
            _buildMapField('capit_lepas_stop', 'CLAW OPEN STOP (C)'),
          ]),
        ],
      ),
    );
  }

  Widget _buildMappingSubCategory(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.orbitron(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFFF007F),
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildMapField(String key, String label) {
    final controller = _controllers[key];
    if (controller == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: GoogleFonts.shareTechMono(
                fontSize: 13,
                color: const Color(0xFFE2E8F0),
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              maxLength: 1,
              decoration: const InputDecoration(
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF))),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1E293B))),
              ),
              style: GoogleFonts.orbitron(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00E5FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomButtonsCard() {
    final customButtons = _mappingService.customButtons;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111726).withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B).withOpacity(0.4)),
      ),
      child: customButtons.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No custom pilot buttons configured.',
                  style: GoogleFonts.shareTechMono(color: const Color(0xFF475569)),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: customButtons.length,
              separatorBuilder: (context, index) => const Divider(color: Color(0xFF1E293B), height: 1),
              itemBuilder: (context, index) {
                final btn = customButtons[index];
                return ListTile(
                  title: Text(
                    btn.label,
                    style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'TRANSMITS: \'${btn.code}\' | BEHAVIOR: ${btn.behavior.toUpperCase()}',
                    style: GoogleFonts.shareTechMono(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFFF3D00)),
                    onPressed: () {
                      _mappingService.deleteCustomButton(btn.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Custom button "${btn.label}" deleted.'),
                          backgroundColor: const Color(0xFFFF3D00),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
