import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/services/geocoding_service.dart';

class CitySelection {
  const CitySelection({
    required this.cityName,
    this.latitude,
    this.longitude,
    this.address,
  });

  final String cityName;
  final double? latitude;
  final double? longitude;
  final String? address;
}

class FeedCityPickerSheet extends StatefulWidget {
  const FeedCityPickerSheet({
    super.key,
    required this.cityOptions,
    required this.selectedCity,
  });

  final List<String> cityOptions;
  final String selectedCity;

  @override
  State<FeedCityPickerSheet> createState() => _FeedCityPickerSheetState();
}

class _CitySuggestion {
  const _CitySuggestion({
    required this.cityName,
    required this.address,
    this.latitude,
    this.longitude,
    this.fromApi = false,
  });

  final String cityName;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool fromApi;
}

class _FeedCityPickerSheetState extends State<FeedCityPickerSheet> {
  late final TextEditingController _citySearchController;
  final GeocodingService _geocodingService = GeocodingService();
  Timer? _debounce;

  String _query = '';
  bool _isSearching = false;
  int _requestId = 0;
  List<_CitySuggestion> _apiSuggestions = const <_CitySuggestion>[];

  @override
  void initState() {
    super.initState();
    _citySearchController = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _citySearchController.dispose();
    super.dispose();
  }

  String _normalizeForCompare(String value) {
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
  }

  String _cityNameFromAddress(String address) {
    final parts = address
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return address;

    if (_normalizeForCompare(parts.first) == 'россия' && parts.length > 1) {
      return parts[1];
    }

    return parts.first;
  }

  Future<void> _searchRussianCities(String rawQuery) async {
    final query = rawQuery.trim();

    if (query.length < 2) {
      if (!mounted) return;
      setState(() {
        _apiSuggestions = const <_CitySuggestion>[];
        _isSearching = false;
      });
      return;
    }

    final int requestId = ++_requestId;
    setState(() {
      _isSearching = true;
    });

    try {
      final List<GeocodingResult> results =
          await _geocodingService.searchAddresses('$query, Россия');

      if (!mounted || requestId != _requestId) return;

      final Set<String> dedupe = <String>{};
      final List<_CitySuggestion> parsed = <_CitySuggestion>[];

      for (final result in results) {
        final cityName = _cityNameFromAddress(result.address);
        final dedupeKey =
            '${_normalizeForCompare(cityName)}:${result.latitude.toStringAsFixed(4)}:${result.longitude.toStringAsFixed(4)}';
        if (dedupe.contains(dedupeKey)) continue;
        dedupe.add(dedupeKey);

        parsed.add(
          _CitySuggestion(
            cityName: cityName,
            address: result.address,
            latitude: result.latitude,
            longitude: result.longitude,
            fromApi: true,
          ),
        );
      }

      setState(() {
        _apiSuggestions = parsed;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _apiSuggestions = const <_CitySuggestion>[];
        _isSearching = false;
      });
    }
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
    });

    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _searchRussianCities(value),
    );
  }

  List<_CitySuggestion> _localSuggestions() {
    final normalizedQuery = _normalizeForCompare(_query);
    final Iterable<String> filtered = widget.cityOptions.where((city) {
      if (_query.trim().isEmpty) return true;
      return _normalizeForCompare(city).contains(normalizedQuery);
    });

    return filtered
        .map(
          (city) => _CitySuggestion(
            cityName: city,
            address: city == 'Все города'
                ? 'Показывать события по всей России'
                : city,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<_CitySuggestion> local = _localSuggestions();
    final List<_CitySuggestion> suggestions = _query.trim().isEmpty
        ? local
        : <_CitySuggestion>[..._apiSuggestions, ...local];

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.78,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  AppColors.surface.withValues(alpha: 0.98),
                  AppColors.accent.withValues(alpha: 0.82),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
            ),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Города России',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark.withValues(alpha: 0.86),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: AppColors.dark.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _citySearchController,
                    onChanged: _onQueryChanged,
                    decoration: InputDecoration(
                      hintText: 'Начните вводить город: Москва, Тверь, Омск...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.dark.withValues(alpha: 0.58),
                      ),
                      suffixIcon: _query.trim().isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _citySearchController.clear();
                                _onQueryChanged('');
                              },
                            ),
                      filled: true,
                      fillColor: AppColors.surface.withValues(alpha: 0.84),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                Expanded(
                  child: suggestions.isNotEmpty
                      ? ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          itemCount: suggestions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final suggestion = suggestions[index];
                            final isSelected =
                                suggestion.cityName == widget.selectedCity;

                            return Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  Navigator.pop(
                                    context,
                                    CitySelection(
                                      cityName: suggestion.cityName,
                                      latitude: suggestion.latitude,
                                      longitude: suggestion.longitude,
                                      address: suggestion.address,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface.withValues(alpha: 0.66),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary.withValues(alpha: 0.34)
                                          : AppColors.primary.withValues(alpha: 0.14),
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: AppColors.dark.withValues(alpha: 0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: suggestion.fromApi
                                              ? AppColors.primary.withValues(alpha: 0.14)
                                              : AppColors.accent.withValues(alpha: 0.94),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          suggestion.fromApi
                                              ? Icons.location_city
                                              : Icons.location_on_outlined,
                                          size: 15,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              suggestion.cityName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected
                                                    ? FontWeight.w800
                                                    : FontWeight.w700,
                                                color: AppColors.dark
                                                    .withValues(alpha: 0.84),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              suggestion.address,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.dark
                                                    .withValues(alpha: 0.58),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: AppColors.primary,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: <Widget>[
                            ListTile(
                              contentPadding: const EdgeInsets.all(0),
                              leading: Icon(
                                Icons.search_off,
                                color: AppColors.primary.withValues(alpha: 0.64),
                              ),
                              title: Text(
                                'Город не найден',
                                style: TextStyle(
                                  color: AppColors.dark.withValues(alpha: 0.84),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Проверьте написание или введите другой запрос',
                                style: TextStyle(
                                  color: AppColors.dark.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

