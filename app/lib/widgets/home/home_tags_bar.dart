import 'package:flutter/material.dart';
import '../../services/workspace_storage_service.dart';
import '../../theme/moscaro_v2_tokens.dart';
import '../svg_icon.dart';

/// Barra de filtros e tags dinâmicas agregadas de todas as notas do Workspace.
/// Possui alternador de visualização Grid ↔ List e ações de filtro inteligente.
class HomeTagsBar extends StatelessWidget {
  final String? selectedTag;
  final bool isGridView;
  final ValueChanged<String?> onTagSelected;
  final ValueChanged<bool> onViewModeChanged;
  final VoidCallback? onAddTagPressed;
  final VoidCallback? onAiSuggestTagsPressed;

  const HomeTagsBar({
    super.key,
    required this.selectedTag,
    required this.isGridView,
    required this.onTagSelected,
    required this.onViewModeChanged,
    this.onAddTagPressed,
    this.onAiSuggestTagsPressed,
  });

  Map<String, int> _extractTagCounts() {
    final notes = WorkspaceStorageService.instance.allNotes;
    final map = <String, int>{};
    for (final note in notes) {
      for (final tag in note.tags) {
        final clean = tag.trim();
        if (clean.isNotEmpty) {
          map[clean] = (map[clean] ?? 0) + 1;
        }
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: WorkspaceStorageService.instance,
      builder: (context, _) {
        final allNotes = WorkspaceStorageService.instance.allNotes;
        final totalNotesCount = allNotes.length;
        final tagCounts = _extractTagCounts();
        final sortedTags = tagCounts.keys.toList()..sort();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildTagPill(
                        context: context,
                        label: 'Todos',
                        count: totalNotesCount,
                        isSelected: selectedTag == null,
                        onTap: () => onTagSelected(null),
                      ),
                      const SizedBox(width: 8),
                      ...sortedTags.map((tag) {
                        final count = tagCounts[tag] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildTagPill(
                            context: context,
                            label: tag,
                            count: count,
                            isSelected: selectedTag == tag,
                            onTap: () => onTagSelected(tag),
                          ),
                        );
                      }),
                      if (onAiSuggestTagsPressed != null) ...[
                        const SizedBox(width: 4),
                        _buildActionButton(
                          icon: 'sparkle',
                          tooltip: 'Sugerir Tags com IA',
                          onTap: onAiSuggestTagsPressed!,
                          accentColor: MoscaroTokens.auroraBlue,
                        ),
                      ],
                      if (onAddTagPressed != null) ...[
                        const SizedBox(width: 6),
                        _buildActionButton(
                          icon: 'plus',
                          tooltip: 'Nova Tag',
                          onTap: onAddTagPressed!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildViewModeToggle(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTagPill({
    required BuildContext context,
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isLight = MoscaroTokens.isLight;
    final activeBg = MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.22 : 0.28);
    final inactiveBg = isLight ? const Color(0x120F172A) : const Color(0x1A1E2433);

    final activeBorder = MoscaroTokens.auroraBlue.withValues(alpha: 0.85);
    final inactiveBorder = isLight ? const Color(0x1F0F172A) : const Color(0x2A3B4A6B);

    final activeTextColor = isLight ? const Color(0xFF0284C7) : MoscaroTokens.auroraBlue;
    final inactiveTextColor = isLight ? const Color(0xFF475569) : const Color(0xFF94A3B8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeBorder : inactiveBorder,
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: MoscaroTokens.auroraBlue.withValues(alpha: 0.25),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != 'Todos') ...[
              SvgIcon(
                name: 'tag',
                size: 13,
                color: isSelected ? activeTextColor : inactiveTextColor.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeTextColor : inactiveTextColor,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? MoscaroTokens.auroraBlue.withValues(alpha: 0.3)
                    : (isLight ? const Color(0x180F172A) : const Color(0x28334155)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? activeTextColor : inactiveTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? accentColor,
  }) {
    final isLight = MoscaroTokens.isLight;
    final col = accentColor ?? (isLight ? const Color(0xFF64748B) : const Color(0xFF94A3B8));

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLight ? const Color(0x120F172A) : const Color(0x1A1E2433),
            border: Border.all(
              color: isLight ? const Color(0x1F0F172A) : const Color(0x2A3B4A6B),
              width: 1.0,
            ),
          ),
          child: Center(
            child: SvgIcon(
              name: icon,
              size: 14,
              color: col,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeToggle() {
    final isLight = MoscaroTokens.isLight;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isLight ? const Color(0x120F172A) : const Color(0x1A1E2433),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLight ? const Color(0x1F0F172A) : const Color(0x2A3B4A6B),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleItem(
            icon: 'grid',
            tooltip: 'Visualização em Grade',
            isActive: isGridView,
            onTap: () => onViewModeChanged(true),
          ),
          const SizedBox(width: 2),
          _buildToggleItem(
            icon: 'list',
            tooltip: 'Visualização em Lista',
            isActive: !isGridView,
            onTap: () => onViewModeChanged(false),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required String icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isLight = MoscaroTokens.isLight;
    final activeBg = MoscaroTokens.auroraBlue.withValues(alpha: isLight ? 0.25 : 0.35);
    final activeColor = isLight ? const Color(0xFF0284C7) : MoscaroTokens.auroraBlue;
    final inactiveColor = isLight ? const Color(0xFF64748B) : const Color(0xFF64748B);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: isActive
                ? Border.all(color: MoscaroTokens.auroraBlue.withValues(alpha: 0.6), width: 1.0)
                : null,
          ),
          child: Center(
            child: SvgIcon(
              name: icon,
              size: 15,
              color: isActive ? activeColor : inactiveColor,
            ),
          ),
        ),
      ),
    );
  }
}
