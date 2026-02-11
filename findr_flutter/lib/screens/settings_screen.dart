import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/liquid_glass_background.dart';

const _currencies = ['USD', 'EUR', 'GBP', 'CAD', 'MXN'];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      backgroundColor: SupplyMapColors.bodyBg,
      appBar: AppBar(
        backgroundColor: SupplyMapColors.bodyBg,
        foregroundColor: Colors.white,
        title: Text('Settings',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        children: [
          GlassPanel(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.straighten,
                        color: SupplyMapColors.blue, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Distance unit',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _RadioOption<DistanceUnit>(
                  value: DistanceUnit.mi,
                  groupValue: settings.distanceUnit,
                  label: 'Miles (mi)',
                  onChanged: (v) => settings.setDistanceUnit(v!),
                ),
                _RadioOption<DistanceUnit>(
                  value: DistanceUnit.km,
                  groupValue: settings.distanceUnit,
                  label: 'Kilometers (km)',
                  onChanged: (v) => settings.setDistanceUnit(v!),
                ),
                const Divider(color: Colors.white24, height: 32),
                Row(
                  children: [
                    const Icon(Icons.attach_money,
                        color: SupplyMapColors.green, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Currency',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: SupplyMapColors.glass,
                    borderRadius: BorderRadius.circular(kRadiusSm),
                    border: Border.all(color: SupplyMapColors.glassBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: settings.currency,
                      dropdownColor: SupplyMapColors.darkBg,
                      isExpanded: true,
                      style: GoogleFonts.inter(
                          color: Colors.white, fontSize: 14),
                      items: _currencies
                          .map((c) => DropdownMenuItem(
                              value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          settings.setCurrency(v ?? 'USD'),
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
}

class _RadioOption<T> extends StatelessWidget {
  const _RadioOption({
    super.key,
    required this.value,
    required this.groupValue,
    required this.label,
    required this.onChanged,
  });

  final T value;
  final T groupValue;
  final String label;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? SupplyMapColors.blue
                      : Colors.white38,
                  width: 2,
                ),
                color: selected
                    ? SupplyMapColors.blue
                    : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
