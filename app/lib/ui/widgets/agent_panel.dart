import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../main.dart'; // for global `noema`
import '../../presentation/state/agent_state.dart';
import 'glass_container.dart';

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
          const SnackBar(content: Text('Please open or create a project first.')),
        );
        return;
      }
      noema.bootstrap.agentState.startTask(project, goal);
      _goalController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      width: 320,
      color: Theme.of(context).colorScheme.surface,
      opacity: 0.12,
      border: const Border(
        left: BorderSide(color: Colors.white10, width: 1.0),
      ),
      child: ListenableBuilder(
        listenable: noema.bootstrap.agentState,
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
                      color: state.isRunning ? Theme.of(context).colorScheme.primary : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "AI Agent",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (state.isRunning || state.isWaitingForJobs)
                      IconButton(
                        icon: const Icon(Icons.stop, color: Colors.redAccent, size: 20),
                        onPressed: state.stopTask,
                        tooltip: "Stop Task",
                      )
                  ],
                ),
              ),
              
              // Status Indicator
              if (state.currentStatus != "Inactive" && state.currentStatus != "Idle")
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      if (state.isRunning || state.isWaitingForJobs)
                        const SizedBox(
                          width: 12, 
                          height: 12, 
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (state.isRunning || state.isWaitingForJobs)
                        const SizedBox(width: 8),
                      Text(
                        state.currentStatus,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // Activity History
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: state.history.length,
                  itemBuilder: (context, index) {
                    final obs = state.history[index];
                    return _buildObservationTile(context, obs);
                  },
                ),
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
                        enabled: !state.isRunning && !state.isWaitingForJobs && state.pendingPermission == null,
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: 'Ask agent to do something...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _submitGoal(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: (!state.isRunning && !state.isWaitingForJobs && state.pendingPermission == null)
                          ? _submitGoal
                          : null,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  ],
                ),
              )
            ],
          );
        }
      ),
    );
  }

  Widget _buildObservationTile(BuildContext context, UIObservation obs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            obs.isError ? Icons.error_outline : (obs.isPending ? Icons.hourglass_empty : Icons.check_circle_outline),
            size: 16,
            color: obs.isError ? Colors.redAccent : (obs.isPending ? Colors.orangeAccent : Colors.green),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  obs.description,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                if (obs.resultText != null)
                  Text(
                    obs.resultText!,
                    style: TextStyle(
                      fontSize: 12,
                      color: obs.isError ? Colors.redAccent : Colors.grey[400],
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('HH:mm:ss').format(obs.timestamp),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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
              Text("Permission Required", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
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
                child: const Text("Stop Task", style: TextStyle(color: Colors.redAccent)),
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
          )
        ],
      ),
    );
  }
}
