import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../domain/schedule.dart';
import '../../data/live_review_repository.dart';
import '../../notifications/review_notifications.dart';
import 'review_controller.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.controller,
    required this.notifications,
    this.onSignOut,
  });
  final ReviewController controller;
  final ReviewNotifications notifications;
  final Future<void> Function()? onSignOut;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int tab = 0;
  bool notifying = false;
  bool _starting = true;
  bool _signingOut = false;
  ReviewController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    widget.notifications.openedReview.addListener(_notificationOpened);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await widget.notifications.initialize();
    } catch (_) {
      // Review choices remain available when Android notification setup fails.
      if (mounted) {
        _message('Notificações indisponíveis. A análise continua acessível.');
      }
    } finally {
      _starting = false;
      if (mounted) {
        await controller.load(
          reviewId: widget.notifications.openedReview.value,
        );
      }
    }
  }

  void _notificationOpened() {
    final id = widget.notifications.openedReview.value;
    if (id == null || !mounted) return;
    setState(() => tab = 0);
    if (_starting) return;
    if (controller.isLive) {
      unawaited(controller.load(reviewId: id));
      return;
    }
    if (controller.review != null && controller.review!.id != id) {
      _message(
        'Esta notificação é de outra análise. Exibindo a demonstração atual.',
      );
    }
  }

  @override
  void dispose() {
    widget.notifications.openedReview.removeListener(_notificationOpened);
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _testNotification() async {
    final review = controller.review;
    if (review == null || notifying) return;
    setState(() => notifying = true);
    try {
      final sent = await widget.notifications.showTest(
        review.id,
        controller.pendingGroups,
        demo: !controller.isLive,
      );
      if (!mounted) return;
      _message(
        sent
            ? 'Teste enviado. Toque na notificação para abrir suas escolhas.'
            : widget.notifications.supported
            ? 'Permita notificações nas configurações do Android para testar.'
            : 'O teste de notificação está disponível no aplicativo Android.',
      );
    } catch (_) {
      if (mounted) _message('Não foi possível exibir a notificação de teste.');
    } finally {
      if (mounted) setState(() => notifying = false);
    }
  }

  Future<void> _openBroadcast(Broadcast broadcast) async {
    final uri = broadcast.url;
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        _message('Não foi possível abrir o destino de transmissão.');
      }
    } catch (_) {
      if (mounted) _message('Não foi possível abrir o destino de transmissão.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final review = controller.review;
      return Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.sports_soccer, color: accent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Soccer Schedule',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          actions: [
            if (widget.onSignOut != null)
              IconButton(
                tooltip: 'Sair',
                icon: const Icon(Icons.logout),
                onPressed: _signingOut
                    ? null
                    : () async {
                        setState(() => _signingOut = true);
                        try {
                          await widget.onSignOut!();
                        } catch (_) {
                          if (mounted) {
                            _message(
                              'Não foi possível concluir a saída. Tente novamente.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _signingOut = false);
                        }
                      },
              ),
            IconButton(
              tooltip: controller.isLive
                  ? 'Sobre o aplicativo'
                  : 'Sobre a demonstração',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Uma escolha por dia'),
                  content: Text(
                    controller.isLive
                        ? 'Receba uma análise diária e escolha os jogos com conflito. Os lembretes ficam no Google Calendar. Depois que o servidor aceita suas escolhas, elas ficam bloqueadas para esta análise.'
                        : 'O plano é receber uma análise diária, escolher os jogos com conflito e deixar os lembretes com o Google Calendar.\n\n'
                              'Esta versão usa partidas fictícias e salva apenas neste aparelho. Não recebe push remoto nem altera seu Calendar. '
                              'Links são destinos ilustrativos, não transmissões confirmadas.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entendi'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : review == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(controller.error ?? 'Nenhuma análise disponível.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: controller.load,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: RefreshIndicator(
                      onRefresh: controller.load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        children: [
                          if (!controller.isLive) _demoNotice(),
                          const SizedBox(height: 24),
                          Text(
                            tab == 0
                                ? 'Seu dia de futebol.\nVocê decide os jogos.'
                                : 'Sua agenda de jogos.',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(saoPaulo(review.fixtures.isEmpty ? review.generatedAt : review.fixtures.first.kickoff))} · São Paulo',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                          const SizedBox(height: 24),
                          if (controller.error != null) ...[
                            Text(
                              controller.error!,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (tab == 0) ..._choices(review) else ..._agenda(),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: notifying || controller.saving
                                ? null
                                : _testNotification,
                            icon: const Icon(Icons.notifications_outlined),
                            label: Text(
                              notifying
                                  ? 'Enviando teste…'
                                  : 'Testar notificação local',
                            ),
                          ),
                          if (!controller.isLive)
                            TextButton(
                              onPressed: controller.saving
                                  ? null
                                  : () async {
                                      final reset = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text(
                                            'Limpar escolhas de demonstração?',
                                          ),
                                          content: const Text(
                                            'Você poderá escolher os jogos novamente.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Limpar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (reset == true) {
                                        await controller.reset();
                                      }
                                    },
                              child: const Text('Recomeçar demonstração'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (index) => setState(() => tab = index),
          destinations: [
            NavigationDestination(
              icon: Badge(
                isLabelVisible: controller.pendingGroups > 0,
                label: Text('${controller.pendingGroups}'),
                child: const Icon(Icons.tune),
              ),
              label: 'Escolhas',
            ),
            const NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              label: 'Agenda',
            ),
          ],
        ),
      );
    },
  );

  Future<void> _saveChoices() async {
    if (controller.isLive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar jogos?'),
          content: const Text(
            'O servidor adicionará os jogos escolhidos ao Google Calendar. Depois de aceitas, as escolhas ficam bloqueadas para esta análise.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Revisar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await controller.save();
  }

  String _liveStatusTitle() => switch (controller.syncStatus) {
    ReviewSyncStatus.synced => 'Google Calendar atualizado.',
    ReviewSyncStatus.failed => 'A sincronização será tentada novamente.',
    ReviewSyncStatus.processing => 'Atualizando Google Calendar…',
    _ => 'Escolhas recebidas pelo servidor.',
  };
  String _liveStatusBody() => controller.syncStatus == ReviewSyncStatus.synced
      ? 'O servidor confirmou a sincronização. Os lembretes ficam com o Calendar.'
      : 'Suas escolhas estão bloqueadas enquanto o servidor conclui a sincronização.';

  Widget _demoNotice() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accent.withValues(alpha: 0.25)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.science_outlined, size: 18, color: accent),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'DEMONSTRAÇÃO · Partidas fictícias. Escolhas salvas só neste aparelho; sem sincronização com Calendar.',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
      ],
    ),
  );

  List<Widget> _choices(DailyReview review) => [
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          label: Text('${controller.pendingGroups} grupos pendentes'),
          avatar: const Icon(Icons.alt_route, size: 18),
        ),
        Chip(
          label: Text('${review.automaticFixtures.length} sem conflito'),
          avatar: const Icon(Icons.check, size: 18),
        ),
      ],
    ),
    const SizedBox(height: 16),
    const Text(
      'Escolha jogos que não se sobreponham. Cada partida reserva 2h15. Você pode pular um grupo inteiro.',
      style: TextStyle(color: Colors.white70, height: 1.5),
    ),
    const SizedBox(height: 24),
    if (controller.groups.isEmpty)
      const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Tudo livre! Nenhum conflito nesta análise.'),
        ),
      ),
    for (final (index, group) in controller.groups.indexed) ...[
      _groupCard(index, group),
      const SizedBox(height: 20),
    ],
    if (controller.saved) ...[
      Row(
        children: [
          Icon(
            controller.isLive &&
                    controller.syncStatus != ReviewSyncStatus.synced
                ? Icons.hourglass_bottom
                : Icons.check_circle,
            color: accent,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              controller.isLive
                  ? _liveStatusTitle()
                  : 'Escolhas salvas neste aparelho.',
              style: const TextStyle(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        controller.isLive ? _liveStatusBody() : 'Demonstração concluída. Nenhum evento foi enviado ao Google Calendar.',
        style: const TextStyle(color: Colors.white70),
      ),
    ] else ...[
      FilledButton.icon(
        onPressed: controller.canSave ? _saveChoices : null,
        icon: controller.saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check),
        label: Text(
          controller.saving
              ? 'Enviando…'
              : controller.isLive
              ? 'Confirmar escolhas'
              : 'Salvar escolhas no aparelho',
        ),
      ),
      if (controller.pendingGroups > 0)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
            'Escolha ou pule os ${controller.pendingGroups} grupos pendentes para continuar.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ),
    ],
  ];

  Widget _groupCard(int index, ConflictGroup group) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                controller.isResolved(group)
                    ? Icons.check_circle_outline
                    : Icons.alt_route,
                color: controller.isResolved(group)
                    ? accent
                    : Colors.orangeAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Grupo ${index + 1} · ${group.fixtures.length} jogos',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final fixture in group.fixtures) ...[
            _fixtureTile(fixture, selectable: true),
            const SizedBox(height: 8),
          ],
          TextButton.icon(
            onPressed: controller.saving || controller.locked
                ? null
                : () => controller.skip(group),
            icon: Icon(
              controller.isSkipped(group) ? Icons.undo : Icons.block,
              size: 18,
            ),
            label: Text(
              controller.isSkipped(group)
                  ? 'Grupo pulado · desfazer'
                  : 'Não acompanhar este grupo',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _fixtureTile(Fixture fixture, {bool selectable = false}) {
    final selected = controller.selectedIds.contains(fixture.fixtureId);
    final enabled = !selectable || controller.canSelect(fixture);
    final broadcast = fixture.broadcast;
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? accent : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            onTap: selectable && enabled
                ? () => controller.toggle(fixture)
                : null,
            leading: selectable
                ? Checkbox(
                    key: ValueKey('select-${fixture.fixtureId}'),
                    value: selected,
                    onChanged: enabled
                        ? (_) => controller.toggle(fixture)
                        : null,
                    semanticLabel:
                        'Selecionar ${fixture.home} x ${fixture.away}',
                  )
                : const Icon(Icons.sports_soccer, color: accent),
            title: Text(
              '${fixture.home}\nx ${fixture.away}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.white : Colors.white38,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${fixture.competition}\n${DateFormat.Hm().format(saoPaulo(fixture.kickoff))} – ${DateFormat.Hm().format(saoPaulo(fixture.endsAt))}',
                style: const TextStyle(height: 1.6, fontSize: 12),
              ),
            ),
            isThreeLine: true,
          ),
          if (!enabled)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                controller.locked
                    ? 'Escolhas enviadas para esta análise.'
                    : controller.isLive &&
                          !fixture.kickoff.isAfter(DateTime.now())
                    ? 'Este jogo já começou.'
                    : 'Sobrepõe um jogo selecionado. Desmarque-o para escolher este.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.orangeAccent,
                ),
              ),
            ),
          if (broadcast != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (broadcast.free)
                    const Text(
                      'GRÁTIS',
                      style: TextStyle(
                        fontSize: 10,
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  TextButton.icon(
                    onPressed: broadcast.url == null
                        ? null
                        : () => _openBroadcast(broadcast),
                    icon: const Icon(Icons.open_in_new, size: 13),
                    label: Text(
                      controller.isLive
                          ? broadcast.name
                          : '${broadcast.name} · destino ilustrativo',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _agenda() => [
    Text(
      controller.isLive
          ? 'Os jogos sem conflito já estão no Google Calendar. A confirmação do servidor abaixo indica quando suas escolhas também foram sincronizadas.'
          : 'Prévia local · os jogos sem conflito entram automaticamente no plano. Suas escolhas completam a agenda.',
      style: const TextStyle(color: Colors.white70, height: 1.5),
    ),
    if (!controller.saved)
      const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Escolhas ainda não confirmadas.',
          style: TextStyle(color: Colors.orangeAccent),
        ),
      ),
    if (controller.isLive && controller.saved)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('${_liveStatusTitle()} · ${_liveStatusBody()}'),
      ),
    const SizedBox(height: 20),
    if (controller.agenda.isEmpty) const Text('Nenhum jogo selecionado.'),
    for (final fixture in controller.agenda) ...[
      _fixtureTile(fixture),
      const SizedBox(height: 12),
    ],
  ];
}
