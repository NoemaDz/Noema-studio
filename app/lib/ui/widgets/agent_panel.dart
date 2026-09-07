import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../main.dart'; // for global `noema`
import '../../presentation/state/agent_state.dart';

class AgentPanel extends StatefulWidget {
  const AgentPanel({super.key});

  @override
  State<AgentPanel> createState() => _AgentPanelState();
}

class _AgentPanelState extends State<AgentPanel> {
  final TextEditingController _goalController = TextEditingController();

  void _submitGoal() {
    final goal = _goalController.text.trim();
    if (goal.isNotEmpty) {
      final project = noema.bootstrap.projectState.project;
      if (project == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please open or create a project first.'),
          ),
        );
        return;
      }
      noema.bootstrap.agentState.startTask(project, goal);
      _goalController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: Listenable.merge([
          noema.bootstrap.agentState,
          noema.bootstrap.projectState,
        ]),
        builder: (context, _) {
          final state = noema.bootstrap.agentState;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.isRunning || state.isWaitingForJobs
                          ? Icons.smart_toy
                          : Icons.smart_toy_outlined,
                      color: state.isRunning
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "AI Assistant",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (state.isRunning || state.isWaitingForJobs)
                      IconButton(
                        icon: const Icon(
                          Icons.stop,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        onPressed: state.stopTask,
                        tooltip: "Stop Task",
                      ),
                  ],
                ),
              ),

              // Chat History
              Expanded(
                child: _buildChatArea(context, state),
              ),

              // Permission Request Overlay
              if (state.pendingPermission != null)
                _buildPermissionCard(context, state),

              // Input Area
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _goalController,
                        enabled:
                            noema.bootstrap.projectState.project != null &&
                            !state.isRunning &&
                            !state.isWaitingForJobs &&
                            state.pendingPermission == null,
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: noema.bootstrap.projectState.project == null
                              ? 'Open a project first...'
                              : 'Ask agent to do something...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _submitGoal(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed:
                          (noema.bootstrap.projectState.project != null &&
                              !state.isRunning &&
                              !state.isWaitingForJobs &&
                              state.pendingPermission == null)
                          ? _submitGoal
                          : null,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
  }

  Widget _buildChatArea(BuildContext context, AgentState state) {
    final items = _buildChatList(context, state);
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade700),
              const SizedBox(height: 16),
              const Text("How can I help you?", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              const Text("Ask me to generate characters, edit scenes, or brainstorm ideas.", style: TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return ListView(
      reverse: true,
      padding: const EdgeInsets.all(16.0),
      children: items,
    );
  }

  List<Widget> _buildChatList(BuildContext context, AgentState state) {
    final session = noema.bootstrap.agentOrchestratorService.currentSession;
    final List<Widget> items = [];

    // System Messages (Newest, at bottom)
    if (state.isRunning || state.isWaitingForJobs) {
      items.add(_buildThinkingIndicator(context, state.currentStatus));
    } else if (state.currentStatus == "Completed") {
      items.add(_buildSystemMessage(context, "Task completed successfully.", isError: false));
    } else if (state.currentStatus == "Failed") {
      items.add(_buildSystemMessage(context, "Task failed.", isError: true));
    } else if (state.currentStatus == "Stopped") {
      items.add(_buildSystemMessage(context, "Task cancelled by user.", isError: false));
    }

    // Assistant Messages (from newest to oldest)
    // state.history is already returned in reverse order (newest-first)
    for (final obs in state.history) {
      items.add(_AssistantMessageCard(obs: obs));
    }

    // User Message (Oldest, at top)
    if (session != null && session.currentGoal.isNotEmpty) {
      items.add(_buildUserMessage(context, session.currentGoal));
    }

    return items;
  }

  Widget _buildUserMessage(BuildContext context, String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, left: 32),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context, String text, {required bool isError}) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isError ? Colors.redAccent.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isError ? Colors.redAccent.withValues(alpha: 0.3) : Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isError ? Icons.error_outline : Icons.info_outline, size: 14, color: isError ? Colors.redAccent : Colors.grey),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontSize: 11, color: isError ? Colors.redAccent : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator(BuildContext context, String status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, right: 32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            child: Icon(Icons.smart_toy, size: 14, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  status,
                  style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(BuildContext context, AgentState state) {
    final req = state.pendingPermission!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.security, color: Colors.orangeAccent, size: 18),
              SizedBox(width: 8),
              Text(
                "Permission Required",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Tool: ${req.action.toolId}",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          const Text(
            "The agent wants to execute this tool. Do you allow this?",
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => state.resolvePermission(false, stop: true),
                child: const Text(
                  "Stop Task",
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => state.resolvePermission(false),
                child: const Text("Deny"),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => state.resolvePermission(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                ),
                child: const Text("Allow"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssistantMessageCard extends StatefulWidget {
  final UIObservation obs;
  const _AssistantMessageCard({required this.obs});

  @override
  State<_AssistantMessageCard> createState() => _AssistantMessageCardState();
}

class _AssistantMessageCardState extends State<_AssistantMessageCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    String title = "Executed ${widget.obs.description.replaceAll('Used ', '')}";
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, right: 32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.build, size: 12, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: widget.obs.isError ? Colors.redAccent.withValues(alpha: 0.3) : Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.obs.isError ? Icons.error : (widget.obs.isPending ? Icons.hourglass_top : Icons.check_circle),
                        size: 14,
                        color: widget.obs.isError ? Colors.redAccent : (widget.obs.isPending ? Colors.orangeAccent : Colors.green),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(widget.obs.timestamp),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (widget.obs.resultText != null) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            const Text("Technical Details", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    if (_expanded)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: SelectableText(
                          widget.obs.resultText!,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: widget.obs.isError ? Colors.redAccent : Colors.grey[400],
                          ),
                        ),
                      ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

