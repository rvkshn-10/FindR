import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'design_system.dart';

// Shared font helper for Outfit
TextStyle _outfit({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.outfit(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  ).copyWith(shadows: const <Shadow>[]);
}

const _currencies = ['USD', 'EUR', 'GBP', 'CAD', 'MXN'];

/// Settings sidebar panel – shared between search and results screens.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: SupplyMapColors.sidebarBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 24,
              offset: Offset(-4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.settings,
                      color: SupplyMapColors.textSecondary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Settings',
                    style: _outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: SupplyMapColors.textBlack,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: SupplyMapColors.textSecondary, size: 20),
                    tooltip: 'Close settings',
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            const Divider(color: SupplyMapColors.borderSubtle, height: 1),
            // ── Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                children: [
                  // Distance unit section
                  Row(
                    children: [
                      const Icon(Icons.straighten,
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
                  _SettingsRadio<DistanceUnit>(
                    value: DistanceUnit.mi,
                    groupValue: settings.distanceUnit,
                    label: 'Miles (mi)',
                    onChanged: (v) { if (v != null) settings.setDistanceUnit(v); },
                  ),
                  _SettingsRadio<DistanceUnit>(
                    value: DistanceUnit.km,
                    groupValue: settings.distanceUnit,
                    label: 'Kilometers (km)',
                    onChanged: (v) { if (v != null) settings.setDistanceUnit(v); },
                  ),
                  const SizedBox(height: 24),
                  const Divider(
                      color: SupplyMapColors.borderSubtle, height: 1),
                  const SizedBox(height: 24),
                  // Currency section
                  Row(
                    children: [
                      const Icon(Icons.attach_money,
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
                      border:
                          Border.all(color: SupplyMapColors.borderSubtle),
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
      ),
    );
  }
}

class _SettingsRadio<T> extends StatelessWidget {
  const _SettingsRadio({
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
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
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
