/// Picks a playful emoji for a plan: first from keywords in its title (a chai
/// walk gets ☕, a trek gets ⛰️), falling back to its category.
class PlanEmoji {
  const PlanEmoji._();

  static const _keywords = <String, String>{
    'chai': '☕',
    'coffee': '☕',
    'cafe': '☕',
    'breakfast': '🥐',
    'brunch': '🥞',
    'street food': '🍜',
    'food': '🍜',
    'pizza': '🍕',
    'dinner': '🍽️',
    'trek': '🥾',
    'hike': '🥾',
    'sunrise': '🌅',
    'sunset': '🌇',
    'beach': '🏖️',
    'picnic': '🧺',
    'thrift': '🛍️',
    'market': '🛍️',
    'badminton': '🏸',
    'volleyball': '🏐',
    'cricket': '🏏',
    'football': '⚽',
    'run': '🏃',
    'yoga': '🧘',
    'cycl': '🚴',
    'swim': '🏊',
    'board game': '🎲',
    'game': '🎮',
    'film': '🎬',
    'movie': '🍿',
    'photo': '📸',
    'sketch': '✏️',
    'art': '🎨',
    'paint': '🎨',
    'open mic': '🎤',
    'karaoke': '🎤',
    'jam': '🎸',
    'music': '🎶',
    'dance': '💃',
    'startup': '🚀',
    'network': '🤝',
    'mixer': '🥂',
    'getaway': '🧳',
    'trip': '🧳',
    'camp': '⛺',
    'walk': '🚶',
  };

  static const _byCategory = <String, String>{
    'food': '🍜',
    'outings': '🎡',
    'travel': '🧳',
    'hiking': '⛰️',
    'games': '🎲',
    'sports': '🏅',
    'photography': '📸',
    'music': '🎶',
    'movies': '🎬',
    'networking': '🤝',
    'art': '🎨',
    'explore': '🧭',
  };

  // Keywords match at the start of a word, so "art" doesn't fire on "startup".
  static final _patterns = [
    for (final e in _keywords.entries)
      (RegExp('\\b${RegExp.escape(e.key)}'), e.value),
  ];

  static String of(String title, String category) {
    final t = title.toLowerCase();
    for (final (pattern, emoji) in _patterns) {
      if (pattern.hasMatch(t)) return emoji;
    }
    return forCategory(category);
  }

  static String forCategory(String category) => _byCategory[category] ?? '✨';
}
