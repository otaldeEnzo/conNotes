import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connotes_app/theme/moscaro_v2_tokens.dart';
import 'package:connotes_app/widgets/svg_icon.dart';
import 'proposed_pdf_search_engine.dart';
import 'proposed_pdf_text_search_models.dart';

/// In-pill expandable text search component adhering to Moscaro v2 design rules.
/// Features:
/// - Smooth animated horizontal expansion from search icon into integrated search bar.
/// - Keyboard shortcut Ctrl + F automatically expands and focuses input when card is selected.
/// - Circular match navigation with [chevron_up] (prev) and [chevron_down] (next).
/// - Dynamic match counter formatted as "[ 3 / 14 ]" or "[ 0 / 0 ]".
/// - Enter / Shift+Enter for keyboard search navigation; Esc for collapse.
/// - 100% SVG iconography, zero emojis.
class PdfSearchPillInput extends StatefulWidget {
  final PdfSearchEngine searchEngine;
  final String pdfPath;
  final List<int> excludedPageIndices;
  final bool isCardSelected;
  final VoidCallback? onSearchOpened;
  final VoidCallback? onSearchClosed;

  const PdfSearchPillInput({
    super.key,
    required this.searchEngine,
    required this.pdfPath,
    this.excludedPageIndices = const <int>[],
    this.isCardSelected = false,
    this.onSearchOpened,
    this.onSearchClosed,
  });

  @override
  State<PdfSearchPillInput> createState() => PdfSearchPillInputState();
}

class PdfSearchPillInputState extends State<PdfSearchPillInput>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final TextEditingController _textController;
  late final FocusNode _focusNode;

  bool _isSearchButtonHovered = false;
  bool _isPrevHovered = false;
  bool _isNextHovered = false;
  bool _isCloseHovered = false;

  bool get isExpanded => _isExpanded;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.onKeyEvent = _handleTextFieldKeyEvent;
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyboardShortcut);
  }

  @override
  void didUpdateWidget(covariant PdfSearchPillInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isCardSelected && oldWidget.isCardSelected && _isExpanded) {
      // Auto-collapse when parent card loses selection
      collapse();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyboardShortcut);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  bool _handleGlobalKeyboardShortcut(KeyEvent event) {
    if (!widget.isCardSelected || !mounted) return false;

    // Detect Ctrl+F or Meta+F to open search
    final isCtrlOrMeta = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (isCtrlOrMeta &&
        event.logicalKey == LogicalKeyboardKey.keyF &&
        event is KeyDownEvent) {
      expandAndFocus();
      return true; // Handled
    }

    return false;
  }

  KeyEventResult _handleTextFieldKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      collapse();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        widget.searchEngine.prevMatch();
      } else {
        widget.searchEngine.nextMatch();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Expands the search field and focuses the text input.
  void expandAndFocus() {
    if (!mounted) return;
    setState(() {
      _isExpanded = true;
    });
    widget.onSearchOpened?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  /// Collapses the search field, clears query text, and clears highlight markers.
  void collapse() {
    if (!mounted) return;
    setState(() {
      _isExpanded = false;
      _textController.clear();
    });
    widget.searchEngine.clearSearch();
    _focusNode.unfocus();
    widget.onSearchClosed?.call();
  }

  void _onQueryChanged(String query) {
    widget.searchEngine.search(
      filePath: widget.pdfPath,
      rawQuery: query,
      excludedPageIndices: widget.excludedPageIndices,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerLeft,
      child: _isExpanded ? _buildExpandedSearchBar() : _buildCollapsedSearchButton(),
    );
  }

  /// Collapsed pill icon button with hover feedback.
  Widget _buildCollapsedSearchButton() {
    return Tooltip(
      message: 'Buscar no documento (Ctrl+F)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isSearchButtonHovered = true),
        onExit: (_) => setState(() => _isSearchButtonHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: expandAndFocus,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 28.0,
            height: 28.0,
            decoration: BoxDecoration(
              color: _isSearchButtonHovered
                  ? MoscaroTokens.auroraBlue.withValues(alpha: 0.16)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgIcon(
                name: 'search',
                size: 15.0,
                color: _isSearchButtonHovered
                    ? MoscaroTokens.auroraBlue
                    : MoscaroTokens.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded in-pill search bar with query field, match counter, and chevron buttons.
  Widget _buildExpandedSearchBar() {
    return ValueListenableBuilder<PdfSearchResult>(
      valueListenable: widget.searchEngine.resultsNotifier,
      builder: (context, result, _) {
        final hasMatches = result.hasMatches;

        return Container(
          height: 28.0,
          padding: const EdgeInsets.only(left: 8.0, right: 4.0),
          decoration: BoxDecoration(
            color: MoscaroTokens.backgroundSurface.withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(MoscaroTokens.radiusPill),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? MoscaroTokens.auroraBlue
                  : MoscaroTokens.borderGlowActive.withValues(alpha: 0.40),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Search Icon
              SvgIcon(
                name: 'search',
                size: 13.0,
                color: MoscaroTokens.auroraBlue,
              ),
              const SizedBox(width: 6.0),

              // 2. Query Text Input Field
              SizedBox(
                width: 130.0,
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  autofocus: true,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: MoscaroTokens.textPrimary,
                    letterSpacing: 0.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar no PDF...',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.0,
                      fontWeight: FontWeight.w400,
                      color: MoscaroTokens.textMuted,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  onChanged: _onQueryChanged,
                ),
              ),
              const SizedBox(width: 4.0),

              // 3. Match Counter Indicator or Loading Spinner
              if (result.isSearching)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: SizedBox(
                    width: 10.0,
                    height: 10.0,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: MoscaroTokens.auroraBlue,
                    ),
                  ),
                )
              else if (result.query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Text(
                    result.counterText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.0,
                      fontWeight: FontWeight.w600,
                      color: hasMatches
                          ? MoscaroTokens.auroraBlue
                          : MoscaroTokens.textMuted,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),

              const SizedBox(width: 2.0),

              // 4. Previous Match Button (chevron_up)
              _buildNavButton(
                iconName: 'chevron_up',
                tooltip: 'Ocorrência anterior (Shift+Enter)',
                isEnabled: hasMatches,
                isHovered: _isPrevHovered,
                onHoverChange: (val) => setState(() => _isPrevHovered = val),
                onTap: hasMatches ? widget.searchEngine.prevMatch : null,
              ),

              // 5. Next Match Button (chevron_down)
              _buildNavButton(
                iconName: 'chevron_down',
                tooltip: 'Próxima ocorrência (Enter)',
                isEnabled: hasMatches,
                isHovered: _isNextHovered,
                onHoverChange: (val) => setState(() => _isNextHovered = val),
                onTap: hasMatches ? widget.searchEngine.nextMatch : null,
              ),

              const SizedBox(width: 2.0),

              // 6. Close / Collapse Button (close)
              Tooltip(
                message: 'Fechar busca (Esc)',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _isCloseHovered = true),
                  onExit: (_) => setState(() => _isCloseHovered = false),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: collapse,
                    child: Container(
                      width: 20.0,
                      height: 20.0,
                      decoration: BoxDecoration(
                        color: _isCloseHovered
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgIcon(
                          name: 'close',
                          size: 11.0,
                          color: _isCloseHovered
                              ? MoscaroTokens.textPrimary
                              : MoscaroTokens.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavButton({
    required String iconName,
    required String tooltip,
    required bool isEnabled,
    required bool isHovered,
    required ValueChanged<bool> onHoverChange,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => onHoverChange(true),
        onExit: (_) => onHoverChange(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 20.0,
            height: 20.0,
            decoration: BoxDecoration(
              color: isHovered && isEnabled
                  ? MoscaroTokens.auroraBlue.withValues(alpha: 0.18)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgIcon(
                name: iconName,
                size: 12.0,
                color: isEnabled
                    ? (isHovered
                        ? MoscaroTokens.auroraBlue
                        : MoscaroTokens.textPrimary)
                    : MoscaroTokens.textMuted.withValues(alpha: 0.40),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
