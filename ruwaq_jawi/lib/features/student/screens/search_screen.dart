import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import 'search_screen/managers/search_manager.dart';
import 'search_screen/widgets/search_app_bar_widget.dart';
import 'search_screen/widgets/search_filter_chips_widget.dart';
import 'search_screen/widgets/search_suggestions_widget.dart';
import 'search_screen/widgets/search_results_widget.dart';
import 'search_screen/widgets/search_empty_state_widget.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  late SearchManager _searchManager;
  bool _showFilter = true;

  @override
  void initState() {
    super.initState();

    // Initialize search manager
    _searchManager = SearchManager(onStateChanged: () => setState(() {}));

    // Auto focus on search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });

    // Add listener to update UI when text changes
    _searchController.addListener(() {
      setState(() {}); // Rebuild to update clear button visibility
    });

    // Add scroll listener for filter visibility
    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && _showFilter) {
        setState(() => _showFilter = false);
      } else if (_scrollController.offset <= 10 && !_showFilter) {
        setState(() => _showFilter = true);
      }
    });
  }

  @override
  void dispose() {
    _searchManager.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kitabProvider = context.watch<KitabProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: SearchAppBarWidget(
        searchController: _searchController,
        searchFocusNode: _searchFocusNode,
        onSearch: () => _performSearch(kitabProvider),
        onClear: _clearSearch,
        onChanged: (value) {
          setState(() {}); // Update to show/hide X button
          _performSearch(kitabProvider);
        },
      ),
      body: Stack(
        children: [
          // Main content dengan padding top untuk filter
          Padding(
            padding: EdgeInsets.only(top: _showFilter ? 45 : 0),
            child: _buildContent(kitabProvider),
          ),
          // Filter sticky di atas dengan animation
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showFilter ? 0 : -45,
            left: 0,
            right: 0,
            child: SearchFilterChipsWidget(
              searchManager: _searchManager,
              onFilterChanged: (filter) {
                _searchManager.updateFilter(filter);
                if (_searchController.text.isNotEmpty) {
                  _performSearch(kitabProvider);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(KitabProvider kitabProvider) {
    // Show suggestions when no search query
    if (_searchController.text.isEmpty) {
      return SearchSuggestionsWidget(
        searchManager: _searchManager,
        scrollController: _scrollController,
        onSuggestionSelected: _selectSuggestion,
        onRecentRemoved: (search) => _searchManager.removeRecentSearch(search),
      );
    }

    // Show empty state when no results
    if (!_searchManager.isSearching && _searchManager.searchResults.isEmpty) {
      return const SearchEmptyStateWidget();
    }

    // Show search results
    return SearchResultsWidget(
      searchManager: _searchManager,
      scrollController: _scrollController,
    );
  }

  void _performSearch(KitabProvider kitabProvider) {
    _searchManager.performSearch(_searchController.text, kitabProvider);
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    final kitabProvider = context.read<KitabProvider>();
    _searchManager.performSearch(suggestion, kitabProvider);
    _searchManager.addToRecentSearches(suggestion);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchManager.clearSearch();
  }
}
