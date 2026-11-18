import 'package:flutter/material.dart';

import '../models/memo_model.dart';
import '../services/memo_pdf.dart';

/// Asks whether to share the memo as a PDF or a JPG image, then shares it.
/// Returns false if the user closed the sheet without choosing.
Future<bool> showShareMemoSheet(BuildContext context, MemoModel memo) async {
  final asImage = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Share Memo No. ${memo.memoNoText} as',
            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
            title: const Text('PDF'),
            subtitle: const Text('Best for printing and records'),
            onTap: () => Navigator.pop(ctx, false),
          ),
          ListTile(
            leading: const Icon(Icons.image_rounded, color: Colors.blue),
            title: const Text('Image (JPG)'),
            subtitle: const Text('Opens directly in WhatsApp chat'),
            onTap: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    ),
  );
  if (asImage == null) return false;

  try {
    if (asImage) {
      await shareMemoJpg(memo);
    } else {
      await shareMemoPdf(memo);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share memo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  return true;
}
