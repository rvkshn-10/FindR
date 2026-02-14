import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/liquid_glass_background.dart';

const _currencies = ['USD', 'EUR', 'GBP', 'CAD', 'MXN'];

TextStyle _outfit({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
}) {
  return GoogleFonts.outfit(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  ).copyWith(shadows: const <Shadow>[]);
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      backgroundColor: SupplyMapColors.bodyBg,
      appBar: AppBar(
        backgroundColor: SupplyMapColors.bodyBg,
        foregroundColor: SupplyMapColors.textBlack,
        title: Text('Settings',
            style: _outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: SupplyMapColors.textBlack)),
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
                    Icon(Icons.straighten,
                        color: SupplyMapColors.blue, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Distance unit',
                      style: _outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: SupplyMapColors.textBlack,
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
                Divider(color: SupplyMapColors.borderSubtle, height: 32),
                Row(
                  children: [
                    Icon(Icons.attach_money,
                        color: SupplyMapColors.accentGreen, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Currency',
                      style: _outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: SupplyMapColors.textBlack,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: SupplyMapColors.bodyBg,
                    borderRadius: BorderRadius.circular(kRadiusSm),
                    border: Border.all(color: SupplyMapColors.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: settings.currency,
                      dropdownColor: SupplyMapColors.sidebarBg,
                      isExpanded: true,
                      style: _outfit(
                          color: SupplyMapColors.textBlack, fontSize: 14),
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
                      ? SupplyMapColors.accentGreen
                      : SupplyMapColors.borderStrong,
                  width: 2,
                ),
                color: selected
                    ? SupplyMapColors.accentGreen
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
              style: _outfit(
                fontSize: 14,
                color: SupplyMapColors.textBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
