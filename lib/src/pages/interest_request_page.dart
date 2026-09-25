import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../api/queries.dart';
import '../models/dashboard.dart';
import '../property_edit_context.dart';

/// An applicant's request: details, accept / refuse, and visit planning.
class InterestRequestPage extends StatefulWidget {
  const InterestRequestPage(
      {required this.request, required this.editContext, super.key});

  final InterestRequestItem request;
  final PropertyEditContext editContext;

  @override
  State<InterestRequestPage> createState() => _InterestRequestPageState();
}

class _InterestRequestPageState extends State<InterestRequestPage> {
  late String status = widget.request.status;
  bool responding = false;
  String? error;

  InterestRequestItem get request => widget.request;
  bool get answered =>
      const {'accepted', 'rejected'}.contains(status.toLowerCase());

  Future<void> _respond({required bool accept}) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _ResponseDialog(accept: accept, request: request),
    );
    if (note == null || !mounted) return;
    setState(() {
      responding = true;
      error = null;
    });
    try {
      final data = await widget.editContext.client.query(
        widget.editContext.endpoint,
        widget.editContext.token,
        respondToInterestMutation,
        variables: {'id': request.id, 'accept': accept, 'message': note},
      );
      final updated = (data['respondToPropertyInterest']
          as Map<String, dynamic>)['interestRequest'] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => status = updated['status'] as String? ?? status);
      widget.editContext.onUpdated();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accept
              ? 'Demande acceptée — ${request.applicantName} est notifié.'
              : 'Demande refusée — ${request.applicantName} est notifié.')));
    } catch (exception) {
      if (mounted) setState(() => error = describeError(exception));
    } finally {
      if (mounted) setState(() => responding = false);
    }
  }

  void _openChat({String messageType = 'message'}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => InterestChatPage(
        interestRequestId: request.id,
        propertyTitle: request.propertyTitle,
        endpoint: widget.editContext.endpoint,
        token: widget.editContext.token,
        isManager: true,
        initialMessageType: messageType,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demande de location')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(
                      backgroundColor: IvoryColors.green.withOpacity(0.12),
                      child: const Icon(Icons.person, color: IvoryColors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(request.applicantName,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w900)),
                          Text(request.propertyTitle,
                              style: const TextStyle(color: IvoryColors.muted)),
                        ],
                      ),
                    ),
                    InterestStatusChip(status,
                        expired: request.isExpired &&
                            status == widget.request.status),
                  ]),
                  const Divider(height: 28),
                  _Detail(Icons.work_outline, 'Profession', request.profession),
                  if (request.employer.isNotEmpty)
                    _Detail(Icons.business, 'Employeur', request.employer),
                  _Detail(Icons.payments_outlined, 'Revenus mensuels',
                      request.salaryRange),
                  _Detail(Icons.groups_outlined, 'Occupants',
                      '${request.occupantsCount}'),
                  _Detail(Icons.event_available, 'Entrée souhaitée',
                      request.leaseStartDate),
                  if (request.message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: IvoryColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('« ${request.message} »',
                          style: const TextStyle(fontStyle: FontStyle.italic)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!answered) ...[
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: responding ? null : () => _respond(accept: true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Accepter'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: responding ? null : () => _respond(accept: false),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Refuser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: () => _openChat(messageType: 'visit_proposal'),
            icon: const Icon(Icons.event),
            label: const Text('Proposer une visite'),
            style: OutlinedButton.styleFrom(
              foregroundColor: IvoryColors.green,
              side: const BorderSide(color: IvoryColors.green),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openChat,
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Conversation'),
            style: OutlinedButton.styleFrom(
              foregroundColor: IvoryColors.ink,
              side: const BorderSide(color: IvoryColors.border),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            ErrorCard(error!),
          ],
        ],
      ),
    );
  }
}

class InterestStatusChip extends StatelessWidget {
  const InterestStatusChip(this.status, {this.expired = false, super.key});

  final String status;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final color = interestStatusColor(status, expired: expired);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(interestStatusLabel(status, expired: expired),
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 18, color: IvoryColors.green),
        const SizedBox(width: 10),
        Text('$label : ', style: const TextStyle(color: IvoryColors.muted)),
        Expanded(
          child:
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

/// Confirms accept/refuse and lets the landlord add a note for the applicant.
/// Pops with the note ('' when empty), or null when cancelled.
class _ResponseDialog extends StatefulWidget {
  const _ResponseDialog({required this.accept, required this.request});

  final bool accept;
  final InterestRequestItem request;

  @override
  State<_ResponseDialog> createState() => _ResponseDialogState();
}

class _ResponseDialogState extends State<_ResponseDialog> {
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.accept ? 'Accepter la demande ?' : 'Refuser la demande ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.request.applicantName} sera notifié.'),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Message (facultatif)',
              hintText: widget.accept
                  ? 'Ex. : je vous propose une visite samedi.'
                  : 'Ex. : le bien vient d’être loué.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(note.text.trim()),
          style: widget.accept
              ? null
              : FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          child: Text(widget.accept ? 'Accepter' : 'Refuser'),
        ),
      ],
    );
  }
}
