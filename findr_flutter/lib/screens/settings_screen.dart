import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

const _currencies = ['USD', 'EUR', 'GBP', 'CAD', 'MXN'];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
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
            leading: Icon(Icons.attach_money, color: Theme.of(context).colorScheme.primary),
            title: const Text('Currency', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              value: settings.currency,
              isExpanded: true,
              items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => settings.setCurrency(v ?? 'USD'),
            ),
          ),
        ],
      ),
    );
  }
}
