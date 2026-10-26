import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const Notifilter());

class Notifilter extends StatelessWidget {
  const Notifilter({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Notifilter',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xff326454),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorSchemeSeed: const Color(0xff70c6a5),
      brightness: Brightness.dark,
      useMaterial3: true,
    ),
    home: const Workspace(),
  );
}

class Workspace extends StatefulWidget {
  const Workspace({super.key});
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> with WidgetsBindingObserver {
  static const bridge = MethodChannel('notifilter/native');
  Map<String, dynamic> state = {};
  List<Map<String, dynamic>> history = [], rules = [];
  String? error;
  int page = 0;
  String filter = 'ALL';
  final sample = TextEditingController();
  Map<String, dynamic>? prediction;
  bool busy = false;
  final titles = const [
    'Overview',
    'History',
    'App rules',
    'AI & test lab',
    'Privacy & access',
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sample.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) refresh();
  }

  Future<dynamic> invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      return await bridge.invokeMethod<dynamic>(method, args);
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.message);
      return null;
    } on MissingPluginException {
      if (mounted) {
        setState(() => error = 'Native Android integration is required.');
      }
      return null;
    }
  }

  Future<void> refresh() async {
    final s = await invoke('state');
    final h = await invoke('history');
    final r = await invoke('rules');
    if (!mounted) return;
    setState(() {
      if (s is Map) state = Map<String, dynamic>.from(s);
      if (h is List) {
        history = h.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (r is List) {
        rules = r.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    });
  }

  Future<void> setting(String key, bool value) async {
    await invoke('setting', {'key': key, 'value': value});
    await refresh();
  }

  Widget card(String title, String body, {Widget? trailing}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(body),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
  Widget toggle(String title, String description, String key) =>
      SwitchListTile.adaptive(
        title: Text(title),
        subtitle: Text(description),
        value: state[key] == true,
        onChanged: (v) => setting(key, v),
      );
  @override
  Widget build(BuildContext context) {
    if (state['onboarded'] == false) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, size: 60),
                    const SizedBox(height: 28),
                    Text(
                      'Your attention.\nYour device.',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Notifilter sorts notifications into High, Normal and Low priority, entirely on your phone. No account. No uploads.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Notification access lets this app read notifications, including private messages. Bodies are processed in memory and never saved. Metadata history is optional.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Monitoring does not silence other apps. Android delivers notifications before a listener can classify them. Quiet Mode is not yet device-verified and stays unavailable.',
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: () => setting('onboarded', true),
                      child: const Text('Continue to setup'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifilter · ${titles[page]}'),
        actions: [
          IconButton(
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh actual device state',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (error != null)
              MaterialBanner(
                content: Text(error!),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => error = null),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ...switch (page) {
              0 => dashboard(),
              1 => timeline(),
              2 => appRules(),
              3 => laboratory(),
              _ => privacy(),
            },
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: page,
        onDestinationSelected: (i) => setState(() => page = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            label: 'Home',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Rules'),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            label: 'Test lab',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            label: 'Privacy',
          ),
        ],
      ),
    );
  }

  List<Widget> dashboard() => [
    card(
      'Less noise. More awareness.',
      'Monitoring mode · originals remain unchanged',
      trailing: const Icon(Icons.notifications_none),
    ),
    toggle(
      'Enable monitoring',
      'Required: notification access. Background processing is native Android.',
      'enabled',
    ),
    if (state['access'] != true)
      card(
        'Notification access required',
        'Read the privacy explanation, then grant access in Android settings.',
        trailing: TextButton(
          onPressed: () => setState(() => page = 4),
          child: const Text('Set up'),
        ),
      ),
    card(
      'Device & listener',
      '${state['interactive'] == true ? 'Interactive' : 'Non-interactive'} · Listener ${state['connected'] == true ? 'connected' : 'not connected'}',
    ),
    card(
      'Today · retained metadata',
      '${state['analyzed'] ?? 0} analyzed · ${state['high'] ?? 0} High · ${state['low'] ?? 0} Low\nCounts reflect retained history, capped at 500 displayed records.',
    ),
    card(
      'Confirmed notification actions',
      '${state['quieted'] ?? 0} quieted · ${state['alerts'] ?? 0} companion alerts\nMonitoring never cancels or changes original notifications.',
    ),
    card(
      'Intelligent Quiet Mode · unavailable',
      'Priority delivery, combined DND policies and user overrides require real-device validation. Monitoring is the safe fallback.',
    ),
  ];
  List<Widget> timeline() => [
    const Text('Metadata only. Notification bodies are never stored.'),
    const SizedBox(height: 12),
    Wrap(
      spacing: 6,
      children: ['ALL', 'HIGH', 'NORMAL', 'LOW']
          .map(
            (v) => ChoiceChip(
              label: Text(v),
              selected: filter == v,
              onSelected: (_) => setState(() => filter = v),
            ),
          )
          .toList(),
    ),
    if (history.isEmpty)
      card(
        'No history yet',
        'Grant access, enable monitoring, and receive notifications while the screen is off. Enable always-on monitoring to test while interactive.',
      ),
    ...history
        .where((e) => filter == 'ALL' || e['priority'] == filter)
        .map(
          (e) => Card(
            child: ListTile(
              leading: Icon(
                e['priority'] == 'HIGH'
                    ? Icons.priority_high
                    : Icons.notifications_outlined,
              ),
              title: Text('${e['app']} · ${e['priority']}'),
              subtitle: Text(
                '${DateTime.fromMillisecondsSinceEpoch(e['at'] as int).toLocal()}\n${e['source']} · ${e['explanation']}\nOriginal unchanged',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (p) async {
                  await invoke('rule', {'pkg': e['pkg'], 'priority': p});
                  await refresh();
                },
                itemBuilder: (_) => ['HIGH', 'NORMAL', 'LOW']
                    .map(
                      (p) => PopupMenuItem(
                        value: p,
                        child: Text('Always assign $p to this app'),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
  ];
  Future<void> addRule() async {
    final pkg = TextEditingController();
    String priority = 'HIGH';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('App priority rule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pkg,
                decoration: const InputDecoration(
                  labelText: 'Exact Android package',
                  hintText: 'com.example.app',
                ),
              ),
              DropdownButton<String>(
                value: priority,
                items: ['HIGH', 'NORMAL', 'LOW']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (p) => update(() => priority = p!),
              ),
              const Text(
                'Low is a classification preference. It does not mute the original app. Calls and alarms remain protected.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final name = pkg.text.trim();
    pkg.dispose();
    if (accepted == true && name.isNotEmpty) {
      await invoke('rule', {'pkg': name, 'priority': priority});
      await refresh();
    }
  }

  List<Widget> appRules() => [
    card(
      'Three priorities. Clear precedence.',
      'System protection → explicit app rules → safety phrases → local model → Normal fallback. Low never silently suppresses notifications.',
    ),
    FilledButton.icon(
      onPressed: addRule,
      icon: const Icon(Icons.add),
      label: const Text('Add app rule'),
    ),
    const SizedBox(height: 12),
    const Text(
      'Apps appear after being observed. No broad installed-package permission is requested.',
    ),
    ...rules.map(
      (r) => Card(
        child: SwitchListTile(
          title: Text(r['pkg'] as String),
          subtitle: Text('${r['priority'] ?? 'Default'} · monitoring'),
          value: r['enabled'] == true,
          onChanged: (v) async {
            await invoke('rule', {
              'pkg': r['pkg'],
              'priority': r['priority'],
              'enabled': v,
            });
            await refresh();
          },
        ),
      ),
    ),
    ...history
        .map((e) => e['pkg'] as String)
        .toSet()
        .where((p) => !rules.any((r) => r['pkg'] == p))
        .map(
          (p) => ListTile(
            title: Text(p),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                await invoke('rule', {'pkg': p, 'priority': v});
                await refresh();
              },
              itemBuilder: (_) => [
                'HIGH',
                'NORMAL',
                'LOW',
              ].map((v) => PopupMenuItem(value: v, child: Text(v))).toList(),
            ),
          ),
        ),
  ];
  List<Widget> laboratory() => [
    card(
      'Local classifier',
      state['model'] as String? ?? 'Checking model status',
    ),
    card(
      'Language & performance',
      'English/Hindi/Hinglish safety phrases only; multilingual model accuracy is unverified. No trained model is bundled.\nRule evaluation in retained samples (µs): P50 ${state['p50'] ?? '—'}, P95 ${state['p95'] ?? '—'}, P99 ${state['p99'] ?? '—'}. Not end-to-end latency.\nClassifier memory and cold-start latency: unmeasured.\nSince process start: ${state['queueDrops'] ?? 0} queue drops, ${state['processingFailures'] ?? 0} processing failures.',
    ),
    toggle(
      'Always-on classification',
      'By default, only process when PowerManager reports non-interactive.',
      'always',
    ),
    const SizedBox(height: 20),
    Text(
      'Notification test lab',
      style: Theme.of(context).textTheme.titleLarge,
    ),
    const Text(
      'Simulation only. Does not create or silence a system notification. Test text is not stored.',
    ),
    const SizedBox(height: 12),
    TextField(
      controller: sample,
      minLines: 3,
      maxLines: 6,
      maxLength: 2048,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: 'Sample notification text',
      ),
    ),
    FilledButton(
      onPressed: busy
          ? null
          : () async {
              setState(() => busy = true);
              final p = await invoke('classify', {'text': sample.text});
              if (mounted) {
                setState(() {
                  busy = false;
                  if (p is Map) prediction = Map<String, dynamic>.from(p);
                });
              }
            },
      child: Text(busy ? 'Classifying…' : 'Classify locally'),
    ),
    if (prediction != null)
      card(
        '${prediction!['priority']} priority',
        'Source: ${prediction!['source']}\nConfidence: ${prediction!['confidence'] ?? 'Not applicable (deterministic rule)'}\n${prediction!['explanation']} · ${prediction!['micros']} µs\nHandling: ${prediction!['decision']}',
      ),
  ];
  List<Widget> privacy() => [
    card(
      'Private by construction',
      'Release builds have no Internet permission. No analytics, accounts or message uploads. Only app identity, priority, reason and timing are retained. No notification body, title or sender is stored. Android backup is disabled.',
    ),
    card(
      'Notification access · required',
      'Allows reading permitted incoming notifications, which may include private content. Android may redact sensitive messages. Current status: ${state['access'] == true ? 'granted' : 'not granted'}',
      trailing: TextButton(
        onPressed: () => invoke('openAccess'),
        child: const Text('Settings'),
      ),
    ),
    card(
      'Post notifications · optional',
      'Status: ${state['posting'] == true ? 'granted' : 'not granted'}. Not needed for monitoring.',
      trailing: TextButton(
        onPressed: () => invoke('requestPosting'),
        child: const Text('Request'),
      ),
    ),
    card(
      'DND access · optional',
      'Status: ${state['policy'] == true ? 'granted' : 'not granted'}. Granting access does not enable Quiet Mode.',
      trailing: TextButton(
        onPressed: () => invoke('openPolicy'),
        child: const Text('Settings'),
      ),
    ),
    toggle(
      'Store metadata history',
      'Turning this off immediately deletes retained metadata.',
      'history',
    ),
    ListTile(
      title: const Text('Metadata retention'),
      trailing: DropdownButton<int>(
        value: state['retention'] as int? ?? 7,
        items: [1, 7, 30]
            .map((n) => DropdownMenuItem(value: n, child: Text('$n days')))
            .toList(),
        onChanged: (n) async {
          await invoke('retention', {'days': n});
          await refresh();
        },
      ),
    ),
    OutlinedButton.icon(
      onPressed: () async {
        await invoke('clear');
        await refresh();
      },
      icon: const Icon(Icons.delete_outline),
      label: const Text('Delete all history now'),
    ),
    card(
      'Android limitations',
      'Listener access is post-delivery: cancellation cannot guarantee pre-alert suppression. Other apps’ channels cannot be edited. Combined DND policies may block companion alerts. OEM lifecycle restrictions apply. No background-exemption permission is requested.',
    ),
  ];
}
