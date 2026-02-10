import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/liquid_glass_background.dart';

const _currencies = ['USD', 'EUR', 'GBP', 'CAD', 'MXN'];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final topPadding = MediaQuery.paddingOf(context).top + kToolbarHeight + 20;
    return Scaffold(
      backgroundColor: LiquidGlassColors.surfaceLight,
      appBar: AppBar(
        backgroundColor: LiquidGlassColors.surfaceLight,
        title: const Text('Settings'),
      ),
      body: ColoredBox(
        color: LiquidGlassColors.surfaceLight,
        child: ListView(
        padding: EdgeInsets.fromLTRB(20, topPadding, 20, 40),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.straighten, color: Theme.of(context).colorScheme.primary),
                    title: const Text('Distance unit', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  RadioGroup<DistanceUnit>(
                    groupValue: settings.distanceUnit,
                    onChanged: (v) => settings.setDistanceUnit(v!),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<DistanceUnit>(
                          title: Text('Miles (mi)'),
                          value: DistanceUnit.mi,
                        ),
                        RadioListTile<DistanceUnit>(
                          title: Text('Kilometers (km)'),
                          value: DistanceUnit.km,
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.attach_money, color: Theme.of(context).colorScheme.primary),
                    title: const Text('Currency', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: settings.currency,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    isExpanded: true,
                    items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => settings.setCurrency(v ?? 'USD'),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
