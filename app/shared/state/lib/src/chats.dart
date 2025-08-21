import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:semaia_models/semaia_models.dart';
import 'package:ksuid/ksuid.dart';

final _logger = Logger('Chats');

class Chats with ChangeNotifier, Iterable<Chat> implements SignOutStateSentry {
  final _chats = <ThreadId, (bool, Chat)>{};
  final _chatHeartbeat = ValueNotifier<int>(0);
  final ChatService _service;
  bool isInitialized = false;
  bool _inListView = true;
  double _currentTemperature = .7;
  LLM _model = LLM.gpt4o;

  double get currentTemperature => _currentTemperature;

  ValueNotifier<int> get heartbeat => _chatHeartbeat; // pulses when a new stream chunk comes in

  set currentTemperature(double value) {
    _currentTemperature = value;
    assert(_currentTemperature <= 2 && _currentTemperature >= 0);
    notifyListeners();
  }

  LLM get model => _model;

  set model(LLM value) {
    _model = value;
    notifyListeners();
  }

  bool get inListView => _inListView;

  set inListView(bool value) {
    _inListView = value;
    notifyListeners();
  }

  ThreadId? _selectedThread;

  ThreadId? get selectedThread => _selectedThread;

  (ThreadId, String)? _stream;

  set selectedThread(ThreadId? value) {
    _selectedThread = value;
    notifyListeners();
  }

  Chats({required ChatService service}) : _service = service;

  @override
  void onSignOut() {
    _chats.clear();
    isInitialized = false;
  }

  @override
  Iterator<Chat> get iterator => _chats.values.map((e) => e.$2).iterator;

  static Chats of(BuildContext context) {
    return Provider.of<Chats>(context, listen: false);
  }

  static Chats watch(BuildContext context) {
    return Provider.of<Chats>(context, listen: true);
  }

  (bool, Chat)? thread(ThreadId? threadId) => _chats[threadId];

  Future<void> init() async {
    final threads = await _service.getChats();

    for (var each in threads ?? <Chat>[]) {
      _chats[each.id] = (true, each);
    }
    isInitialized = true;
    notifyListeners();
  }

  Future<void> startEmptyThread({required String query}) async {
    final bead = EmptyBead(sqlQuery: query);
    final thread = Chat.start(bead);
    _chats[thread.id] = (true, thread);
    notifyListeners();
  }

  Future<void> initializeThread({required String connectorId, required String prompt}) async {
    if (removeEmptyThread() case (_, Chat(:String initialQuery))) {
      _service
          .startChat(connectorId: connectorId, prompt: prompt, query: initialQuery)
          .listen(
            (event) {
              switch (event) {
                // request will return the chat ID first
                case (:String chatId, token: _):
                  final thread = Chat.empty(id: chatId);
                  final bead = Bead(
                    sqlQuery: initialQuery,
                    id: KSUID.generate().asString,
                    threadId: chatId,
                    prompt: prompt,
                    model: _model.name,
                  );

                  thread.string(bead);

                  _chats[thread.id] = (true, thread);
                  _stream = (chatId, bead.id);
                  selectedThread = thread.id;

                  notifyListeners();
                // after that, LLM response will be streamed
                case (chatId: _, :String token):
                  switch (_stream) {
                    case (String threadId, String beadId):
                      if (_chats[threadId] case (_, Chat thread)) {
                        thread.where((bead) => bead.id == beadId).forEach(
                          (bead) {
                            bead.addChunk(token);
                            _chatHeartbeat.value++;
                            notifyListeners();
                          },
                        );
                      }
                  }
                // end of stream
                case (chatId: null, token: null):
                // refetch
              }
            },
            onError: (error) => _logger.shout("SSE Error: $error"),
            onDone: () => _logger.info("SSE Connection Closed"),
          );
    }
  }

  Future<void> addToThread(ThreadId threadId, {required String prompt}) async {
    final bead = Bead(
      id: KSUID.generate().asString,
      threadId: threadId,
      prompt: prompt,
      model: model.name,
    );

    _chats[threadId]?.$2.string(bead);

    _service
        .sendMessageToChat(chatId: threadId, message: prompt)
        .listen(
          (event) {
            switch (event) {
              case String chunk:
                bead.addChunk(chunk);
                _chats[threadId]?.$2.where((b) => b.id == bead.id).forEach(
                  (b) {
                    b.addChunk(chunk);
                    _chatHeartbeat.value++;
                    notifyListeners();
                  },
                );
              case null:
              //
            }
          },
        )
        .onError(
          (error) {
            _logger.shout('On sendMessageToChat: ${error.runtimeType} - $error');
          },
        );
  }

  Future<void> deleteThread(ThreadId threadId) async {
    _chats.remove(threadId);
    notifyListeners();
    return _service.deleteChat(threadId);
  }

  Future<void> getThread(ThreadId threadId) async {
    //
  }

  (bool, Chat)? removeEmptyThread() {
    return _chats.remove(emptyThreadId);
  }

  Future<bool> renameThread(ThreadId threadId, String name) async {
    //
    return false;
  }

  static Color temperatureColor(double value) {
    if (value < 1) {
      return Color.lerp(Colors.blue[900], Colors.yellow, value)!;
    } else {
      return Color.lerp(Colors.yellow, Colors.red, value - 1)!;
    }
  }

  Color get currentTemperatureColor {
    return temperatureColor(_currentTemperature);
  }
}
