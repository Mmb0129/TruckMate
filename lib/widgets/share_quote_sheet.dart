import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/quote_model.dart';
import '../services/firestore_service.dart';
import '../services/quote_pdf.dart';

/// Lets the user pick how to send the quote, sends it, and marks a draft as Sent.
Future<void> showShareQuoteSheet(BuildContext context, QuoteModel q) async {
  final via = await showModalBottomSheet<String>(
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
            'Send Quotation ${q.quoteNoText}',
            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.email_rounded, color: Colors.deepOrange),
            title: const Text('Email'),
            subtitle: Text(
              q.customerEmail.isEmpty
                  ? 'No email on quote - type it in the mail app'
                  : 'To ${q.customerEmail}'
                        '${q.ccEmail.isEmpty ? '' : ', CC ${q.ccEmail}'}',
            ),
            onTap: () => Navigator.pop(ctx, 'email'),
          ),
          ListTile(
            leading: const Icon(Icons.image_rounded, color: Colors.blue),
            title: const Text('Image (JPG)'),
            subtitle: const Text('Opens directly in WhatsApp chat'),
            onTap: () => Navigator.pop(ctx, 'jpg'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
            title: const Text('PDF'),
            subtitle: const Text('Formal copy for companies'),
            onTap: () => Navigator.pop(ctx, 'pdf'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_rounded, color: Colors.green),
            title: const Text('Text message'),
            subtitle: const Text('Quick rate reply, no attachment'),
            onTap: () => Navigator.pop(ctx, 'text'),
          ),
          ListTile(
            leading: const Icon(Icons.print_rounded),
            title: const Text('View / Print / Save PDF'),
            subtitle: const Text('Save to phone to attach in a Gmail reply'),
            onTap: () => Navigator.pop(ctx, 'print'),
          ),
        ],
      ),
    ),
  );
  if (via == null) return;

  bool sent = true;
  try {
    switch (via) {
      case 'email':
        final opened = await emailQuote(q);
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No mail app found - choose one from the share list')),
          );
        }
      case 'jpg':
        sent = await shareQuoteJpg(q);
      case 'pdf':
        sent = await shareQuotePdf(q);
      case 'text':
        sent = await shareQuoteText(q);
      case 'print':
        await Printing.layoutPdf(
          name: quoteFileName(q),
          onLayout: (_) => buildQuotePdf(q),
        );
        return; // viewing is not sending
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send quote: $e'), backgroundColor: Colors.red),
      );
    }
    return;
  }

  // Gmail/WhatsApp don't report whether Send was pressed; an app being chosen is the best signal.
  if (!sent || q.id.isEmpty) return;
  q
    ..sentVia = via
    ..sentAt = DateTime.now();
  if (q.status == QuoteStatus.draft) q.status = QuoteStatus.sent;
  try {
    await FirestoreService().updateQuote(q);
  } catch (_) {
    // Status is cosmetic; the quote itself is already saved.
  }
}
