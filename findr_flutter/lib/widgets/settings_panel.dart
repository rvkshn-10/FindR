import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'design_system.dart';

const _currencies = ['USD', 'EUR', 'GBP', 'CAD', 'MXN'];

/// Settings sidebar panel – shared between search and results screens.
class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final ac = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: ac.sidebarBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          boxShadow: const [
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
                  Icon(Icons.settings,
                      color: ac.textSecondary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Settings',
                    style: outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: ac.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: ac.textSecondary, size: 20),
                    tooltip: 'Close settings',
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Divider(color: ac.borderSubtle, height: 1),
            // ── Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                children: [
                  // Distance unit section
                  Row(
                    children: [
                      Icon(Icons.straighten,
                          color: ac.blue, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Distance unit',
                        style: outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ac.textPrimary,
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
                  Divider(color: ac.borderSubtle, height: 1),
                  const SizedBox(height: 24),
                  // Theme section
                  Row(
                    children: [
                      Icon(Icons.dark_mode_outlined,
                          color: ac.purple, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Theme',
                        style: outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ac.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SettingsRadio<ThemeModeSetting>(
                    value: ThemeModeSetting.light,
                    groupValue: settings.themeMode,
                    label: 'Light',
                    onChanged: (v) { if (v != null) settings.setThemeMode(v); },
                  ),
                  _SettingsRadio<ThemeModeSetting>(
                    value: ThemeModeSetting.dark,
                    groupValue: settings.themeMode,
                    label: 'Dark',
                    onChanged: (v) { if (v != null) settings.setThemeMode(v); },
                  ),
                  _SettingsRadio<ThemeModeSetting>(
                    value: ThemeModeSetting.system,
                    groupValue: settings.themeMode,
                    label: 'System',
                    onChanged: (v) { if (v != null) settings.setThemeMode(v); },
                  ),
                  const SizedBox(height: 24),
                  Divider(color: ac.borderSubtle, height: 1),
                  const SizedBox(height: 24),
                  // Currency section
                  Row(
                    children: [
                      Icon(Icons.attach_money,
                          color: ac.accentGreen, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Currency',
                        style: outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ac.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: ac.glass,
                      borderRadius: BorderRadius.circular(kRadiusSm),
                      border: Border.all(color: ac.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currencies.contains(settings.currency)
                            ? settings.currency
                            : 'USD',
                        dropdownColor: ac.sidebarBg,
                        isExpanded: true,
                        style: outfit(
                            color: ac.textPrimary, fontSize: 14),
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
    final ac = AppColors.of(context);
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
                      ? ac.accentGreen
                      : ac.borderStrong,
                  width: 2,
                ),
                color: selected
                    ? ac.accentGreen
                    : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: outfit(
                fontSize: 14,
                color: ac.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
