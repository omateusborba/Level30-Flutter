import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

/// C4 — resultado do bottom sheet de conclusão do dia.
class CompleteChoice {
  final String? note;
  const CompleteChoice(this.note);
}

/// Oferece uma nota opcional ao concluir o dia. Nunca bloqueante: o botão
/// "Concluir dia" fecha com a nota (ou `null`). Fechar por gesto = cancela.
Future<CompleteChoice?> showCompleteNoteSheet(BuildContext context) {
  return showModalBottomSheet<CompleteChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _NoteSheet(),
  );
}

class _NoteSheet extends StatefulWidget {
  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Como foi hoje?',
              style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          const Text('Anote algo se quiser — é opcional.',
              style: TextStyle(color: AppColors.textSecond, fontSize: 12)),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLength: 280,
            maxLines: 3,
            minLines: 2,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Ex.: li 15 páginas, difícil manter o foco…',
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final t = _controller.text.trim();
                Navigator.pop(context, CompleteChoice(t.isEmpty ? null : t));
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Concluir dia'),
            ),
          ),
        ],
      ),
    );
  }
}
