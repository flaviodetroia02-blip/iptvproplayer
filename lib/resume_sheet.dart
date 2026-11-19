import 'package:flutter/material.dart';
import 'app_state.dart';
import 'models.dart';
import 'screens.dart';
import 'theme.dart';
import 'widgets.dart';

void showResumeSheet(BuildContext context, AppState state) {
  final list = state.resumeList;
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Riprendi visione', style: Theme.of(ctx).textTheme.titleMedium),
              ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Text('Nessun contenuto recente.'),
                )
              else
                Flexible(
                  child: ListView(shrinkWrap: true, children: [
                    for (final it in list)
                      ListTile(
                        leading: SizedBox(
                          width: 56,
                          height: 56,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Art(
                                url: it.image,
                                title: it.name,
                                contain: it.kind == Kind.live),
                          ),
                        ),
                        title: Text(it.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: it.kind == Kind.live
                            ? const Text('Diretta')
                            : Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: LinearProgressIndicator(
                                  value: state.progressOf(it.url),
                                  backgroundColor: AppColors.surfaceHigh,
                                  color: AppColors.accent,
                                ),
                              ),
                        onTap: () {
                          Navigator.pop(ctx);
                          openItem(context, state, it);
                        },
                      ),
                  ]),
                ),
            ]),
      ),
    ),
  );
}
