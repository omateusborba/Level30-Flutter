import 'package:flutter/material.dart';

Future<bool> showDeleteConfirmDialog({
  required BuildContext context,
  required String challengeTitle,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF111328),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFFF8B00), size: 24),
              SizedBox(width: 8),
              Text(
                'Excluir Desafio',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"$challengeTitle"',
                style: const TextStyle(
                  color: Color(0xFF00FF9C),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tem certeza que deseja excluir este desafio?\n\nTodo o progresso, XP acumulado e streak serão perdidos permanentemente.',
                style: TextStyle(
                    color: Color(0xFF8892A4), fontSize: 13, height: 1.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar',
                  style: TextStyle(color: Color(0xFF8892A4))),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.delete_forever, size: 16),
              label: const Text('Excluir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDE350B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ) ??
      false;
}
