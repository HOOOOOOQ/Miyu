class MiyuRoutes {
  MiyuRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const chat = '/chat';
  static const newChat = '/new-chat';
  static const newGroup = '/new-group';
  static const group = '/group';
  static const profile = '/profile';
  static const userProfile = '/user';
  static const settings = '/settings';
  static const about = '/settings/about';
  static const blocked = '/settings/blocked';
  static const storage = '/settings/storage';
  static const call = '/call';

  static String chatFor(String chatId) => '$chat/$chatId';
  static String groupFor(String groupId) => '$group/$groupId';
  static String userProfileFor(String userId) => '$userProfile/$userId';
}
