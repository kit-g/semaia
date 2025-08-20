import 'package:semaia_models/semaia_models.dart';

abstract class ChatService {
  Stream<({String? token, String? chatId})> startChat({
    required String connectorId,
    required String prompt,
    required String query,
  });

  Future<Iterable<Chat>?> getChats();

  Future<void> deleteChat(String chatId);

  Stream<String?> sendMessageToChat({required String chatId, required String message});
}
