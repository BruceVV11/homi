import 'package:flutter/material.dart';

import '../domain/emergency_region.dart';
import '../services/emergency_region_service.dart';
import '../theme/homi_theme.dart';

Future<EmergencyRegion?> showEmergencyRegionPicker(BuildContext context) {
  return showModalBottomSheet<EmergencyRegion>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const EmergencyRegionPickerSheet(),
  );
}

class EmergencyRegionPickerSheet extends StatefulWidget {
  const EmergencyRegionPickerSheet({super.key});

  @override
  State<EmergencyRegionPickerSheet> createState() =>
      _EmergencyRegionPickerSheetState();
}

class _EmergencyRegionPickerSheetState
    extends State<EmergencyRegionPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _select(EmergencyRegion region) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await EmergencyRegionService.instance.select(region);
      if (mounted) Navigator.pop(context, region);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = EmergencyRegionService.instance.current;
    final query = _query.trim().toLowerCase();
    final regions = EmergencyRegionCatalog.sortedRegions
        .where((region) =>
            query.isEmpty ||
            region.countryName.toLowerCase().contains(query) ||
            region.isoCode.toLowerCase().contains(query))
        .toList(growable: false);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.84,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 18 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Emergency region',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Choose the country or region whose emergency numbers Homi should show. This choice stays on this phone and can be changed at any time.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                autofocus: false,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search countries or region code',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: regions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No bundled emergency region matches that search.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: regions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final region = regions[index];
                          final selected = current?.isoCode == region.isoCode;
                          final primary = region.primaryContact;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            enabled: !_saving,
                            onTap: () => _select(region),
                            leading: Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: HomiColors.peach.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                region.isoCode,
                                style: const TextStyle(
                                  color: HomiColors.coral,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            title: Text(
                              region.countryName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            subtitle: Text(
                              primary == null
                                  ? '${region.contacts.length} emergency service numbers'
                                  : 'Primary emergency ${primary.number}',
                            ),
                            trailing: selected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: HomiColors.coral,
                                  )
                                : const Icon(Icons.chevron_right_rounded),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
