import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_state.dart';
import 'net.dart';
import 'player_screen.dart' show fitLabels;
import 'theme.dart';
import 'updater.dart';
import 'widgets.dart';
import 'xtream.dart';

class SettingsScreen extends StatelessWidget {
  final AppState state;
  final VoidCallback? onFullScreen;
  const SettingsScreen({super.key, required this.state, this.onFullScreen});

  Widget _head(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 6),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2, color: AppColors.accent)),
      );

  Widget _choice<T>(String title, String? sub, Map<T, String> options, T value, ValueChanged<T> onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(sub, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in options.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: e.key == value,
              showCheckmark: false,
              onSelected: (_) => onChanged(e.key),
              selectedColor: AppColors.accent,
              backgroundColor: AppColors.surface,
              side: BorderSide.none,
              labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: e.key == value ? Colors.white : AppColors.textSecondary),
            ),
        ]),
      ]),
    );
  }

  Widget _switch(String title, String? sub, bool v, ValueChanged<bool> on) => SwitchListTile(
        title: Text(title),
        subtitle: sub == null ? null : Text(sub),
        value: v,
        activeColor: AppColors.accent,
        onChanged: on,
      );

  String _when(int ms) {
    if (ms <= 0) return 'mai';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String t(int n) => n.toString().padLeft(2, '0');
    return '${t(d.day)}/${t(d.month)} alle ${t(d.hour)}:${t(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state;
        return Scaffold(
          appBar: AppBar(title: const Text('Impostazioni')),
          body: ListView(padding: const EdgeInsets.only(bottom: 48), children: [
            _head('Home e anteprime'),
            _choice<int>('Cosa mostrare in primo piano', 'Nella scheda TV, appena entri', const {
              0: 'Automatico',
              1: 'Eventi e miei canali',
              2: 'Solo miei canali',
            }, s.heroMode, s.setHeroMode),
            ListTile(
              title: const Text('I miei canali in primo piano'),
              subtitle: Text(s.heroIds.isEmpty ? 'Nessun canale scelto' : '${s.heroIds.length} selezionati (massimo 8)'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => HeroChannelsScreen(state: s))),
            ),
            _switch('Anteprime video', 'Disattivale se l\'app è lenta', s.previews, s.setPreviews),
            _switch('Audio nelle anteprime', 'Di norma partono senza audio', s.heroSound, s.setHeroSound),
            _choice<int>('Durata della locandina', 'Prima che parta l\'anteprima', const {
              3: '3 secondi',
              5: '5 secondi',
              8: '8 secondi',
            }, s.posterSecs, s.setPosterSecs),
            _head('Riproduzione'),
            _choice<int>('Formato video predefinito', 'Lo cambi anche durante la visione',
                {for (var i = 0; i < fitLabels.length; i++) i: fitLabels[i]}, s.fitMode, s.setFitMode),
            _choice<int>('Buffer', 'Più buffer significa meno blocchi, ma una partenza un po\' più lenta', const {
              0: 'Standard',
              1: 'Ampio',
              2: 'Massimo',
            }, s.bufferMode, s.setBufferMode),
            _switch('Avvisa se la connessione è lenta',
                'Propone una versione del canale a risoluzione più bassa', s.slowWarn, s.setSlowWarn),
            _head('Aspetto'),
            _choice<int>('Dimensione dell\'interfaccia', null, const {
              0: 'Piccola',
              1: 'Normale',
              2: 'Grande',
              3: 'Molto grande',
            }, s.uiSize, s.setUiSize),
            _head('Playlist'),
            _choice<int>('Aggiorna la playlist', 'All\'apertura l\'app usa i dati salvati e aggiorna in secondo piano', const {
              0: 'Ad ogni apertura',
              6: 'Ogni 6 ore',
              24: 'Ogni giorno',
              -1: 'Solo manualmente',
            }, s.refreshHours, s.setRefreshHours),
            ListTile(
              title: const Text('Aggiorna ora'),
              subtitle: Text(s.loading
                  ? 'Aggiornamento in corso…'
                  : (s.refreshError ?? 'Ultimo aggiornamento: ${_when(s.cacheTime)}')),
              trailing: s.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                  : const Icon(Icons.refresh_rounded),
              onTap: s.loading ? null : () => s.reload(),
            ),
            ListTile(
              title: const Text('Diagnostica connessione'),
              subtitle: const Text('Utile se la playlist non si carica, ad esempio con la VPN'),
              trailing: const Icon(Icons.network_check_rounded),
              onTap: () => showDialog(context: context, builder: (_) => DiagnosticsDialog(state: s)),
            ),
            _head('Dati'),
            ListTile(
              title: const Text('Cancella cronologia e posizioni'),
              subtitle: const Text('Visti di recente e punto in cui eri arrivato'),
              onTap: () {
                s.clearHistory();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Cronologia cancellata')));
              },
            ),
            ListTile(
              title: const Text('Cancella copia locale della playlist'),
              onTap: () async {
                await s.clearPlaylistCache();
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Copia locale cancellata')));
                }
              },
            ),
            _head('App'),
            if (onFullScreen != null)
              ListTile(
                leading: const Icon(Icons.fullscreen_rounded),
                title: const Text('Schermo intero (F11)'),
                onTap: onFullScreen,
              ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Esci dal servizio'),
              onTap: () {
                Navigator.pop(context);
                s.logout();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text('Versione 0.7${kBuild > 0 ? ' (build $kBuild)' : ''}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
            ),
          ]),
        );
      },
    );
  }
}

/// Scelta dei canali da mostrare in primo piano appena si entra.
class HeroChannelsScreen extends StatefulWidget {
  final AppState state;
  const HeroChannelsScreen({super.key, required this.state});

  @override
  State<HeroChannelsScreen> createState() => _HeroChannelsScreenState();
}

class _HeroChannelsScreenState extends State<HeroChannelsScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final chosen = s.heroIds;
        final list = (q.length < 2
                ? s.heroChannels
                : s.live.where((c) => c.name.toLowerCase().contains(q)).take(300).toList())
            .toList();
        return Scaffold(
          appBar: AppBar(title: Text('Canali in primo piano (${chosen.length}/8)')),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Cerca un canale da aggiungere',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                          q.length < 2 ? 'Scrivi almeno due lettere per cercare.' : 'Nessun risultato.',
                          style: Theme.of(context).textTheme.bodySmall))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final c = list[i];
                        final on = chosen.contains(c.id);
                        return CheckboxListTile(
                          value: on,
                          activeColor: AppColors.accent,
                          secondary: SizedBox(
                            width: 56,
                            height: 40,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Art(url: c.image, title: c.name, contain: true),
                            ),
                          ),
                          title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(c.group, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onChanged: (v) {
                            final ids = [...chosen];
                            if (v == true) {
                              if (ids.length >= 8) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Puoi sceglierne al massimo 8.')));
                                return;
                              }
                              ids.add(c.id);
                            } else {
                              ids.remove(c.id);
                            }
                            s.setHeroIds(ids);
                          },
                        );
                      },
                    ),
            ),
          ]),
        );
      },
    );
  }
}

class _Step {
  String text;
  int status; // 0 in corso, 1 ok, 2 problema
  _Step(this.text, this.status);
}

/// Controlla internet, raggiungibilità del servizio e velocità, con consigli.
class DiagnosticsDialog extends StatefulWidget {
  final AppState state;
  const DiagnosticsDialog({super.key, required this.state});

  @override
  State<DiagnosticsDialog> createState() => _DiagnosticsDialogState();
}

class _DiagnosticsDialogState extends State<DiagnosticsDialog> {
  final List<_Step> steps = [];
  String? advice;
  bool done = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  _Step _add(String t) {
    final s = _Step(t, 0);
    if (mounted) setState(() => steps.add(s));
    return s;
  }

  void _set(_Step s, bool ok, String text) {
    if (!mounted) return;
    setState(() {
      s.status = ok ? 1 : 2;
      s.text = text;
    });
  }

  Future<void> _run() async {
    var internetOk = false, serviceOk = false, slow = false;

    final a = _add('Controllo la connessione a internet…');
    try {
      final r = await http
          .get(Uri.parse('https://www.cloudflare.com/cdn-cgi/trace'))
          .timeout(const Duration(seconds: 10));
      final loc = RegExp(r'loc=(\w+)').firstMatch(r.body)?.group(1);
      _set(a, true, 'Internet raggiungibile${loc != null ? ' (paese rilevato: $loc)' : ''}');
      internetOk = true;
    } catch (e) {
      _set(a, false, 'Internet non raggiungibile. ${explain(e)}');
    }

    final b = _add('Controllo il tuo servizio IPTV…');
    final sw = Stopwatch()..start();
    try {
      final src = widget.state.source;
      if (src == null) throw const NetError('Nessun servizio collegato.');
      if (src['type'] == 'm3u') {
        final r = await http
            .get(Uri.parse(src['url'] as String), headers: {'Range': 'bytes=0-2047'})
            .timeout(const Duration(seconds: 20));
        if (r.statusCode >= 400) throw NetError('Il server ha risposto con errore ${r.statusCode}.');
      } else {
        await XtreamClient(src['server'] as String, src['user'] as String, src['pass'] as String)
            .checkLogin(tries: 1);
      }
      _set(b, true, 'Servizio raggiungibile in ${sw.elapsedMilliseconds} ms');
      serviceOk = true;
    } catch (e) {
      _set(b, false, explain(e));
    }

    final c = _add('Misuro la velocità…');
    final v = await widget.state.measureSpeed(force: true);
    if (v == null) {
      _set(c, false, 'Velocità non misurabile');
    } else {
      slow = v < 8;
      _set(c, !slow, 'Velocità circa ${v.toStringAsFixed(1)} Mbps${slow ? ' (bassa per l\'alta risoluzione)' : ''}');
    }

    if (!mounted) return;
    setState(() {
      done = true;
      if (internetOk && !serviceOk) {
        advice = 'Internet funziona ma il tuo servizio non risponde con questa connessione. '
            'Se hai la VPN attiva, probabilmente il servizio blocca gli indirizzi VPN: cambia server o Paese '
            '(meglio l\'Italia), prova un altro protocollo, oppure escludi PRIMA dalla VPN '
            '(funzione "split tunneling") e usa la VPN solo per il resto.';
      } else if (!internetOk) {
        advice = 'Controlla la rete o la VPN: al momento nessun sito è raggiungibile.';
      } else if (slow) {
        advice = 'La connessione è lenta: scegli canali HD o SD, oppure aumenta il buffer nelle impostazioni.';
      } else {
        advice = 'Tutto a posto. Se un canale non parte, il problema è probabilmente del canale stesso.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Diagnostica connessione'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final s in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  s.status == 0
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                      : Icon(s.status == 1 ? Icons.check_circle_rounded : Icons.error_rounded,
                          size: 20, color: s.status == 1 ? Colors.green : AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s.text)),
                ]),
              ),
            if (done && advice != null) ...[
              const Divider(),
              const SizedBox(height: 6),
              Text(advice!, style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi'))],
    );
  }
}
