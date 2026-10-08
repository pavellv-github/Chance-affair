import 'dart:math';

import '../domain/activity.dart';
import '../domain/user_profile.dart';
import 'activity_generator.dart';

/// Подбор без интернета и без ключа: случайная идея из встроенного каталога
/// с учётом машины, бюджета и увлечений.
class OfflineActivityGenerator implements ActivityGenerator {
  OfflineActivityGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  Future<Activity> suggest(ActivityRequest request) async {
    final p = request.profile;
    final excluded = request.excludeTitles.toSet();
    var pool = catalog
        .where((e) => !e.needsCar || p.hasCar)
        .where((e) => p.budget != Budget.free || e.free)
        .where((e) => !excluded.contains(e.activity.title))
        .toList();
    // Всё перебрали — начинаем круг заново.
    if (pool.isEmpty) {
      pool = catalog
          .where((e) => !e.needsCar || p.hasCar)
          .where((e) => p.budget != Budget.free || e.free)
          .toList();
    }

    final hobbies = p.hobbies.map((h) => h.toLowerCase()).toList();
    final matching = pool
        .where((e) => e.tags.any((t) => hobbies.any((h) => h.contains(t))))
        .toList();
    // Увлечения в приоритете, но иногда — что-то новое.
    final source = matching.isNotEmpty && _random.nextDouble() < 0.7
        ? matching
        : pool;
    return source[_random.nextInt(source.length)].activity;
  }

  static const catalog = <CatalogEntry>[
    CatalogEntry(
      Activity(
        title: 'Прогулка по новому району',
        description:
            'Выберите район, где вы почти не бывали, и пройдитесь '
            'без маршрута. Загляните во дворы и найдите новую кофейню.',
        category: 'Прогулка',
        emoji: '🚶',
        durationMinutes: 90,
        preferredStartHour: 16,
      ),
      tags: ['прогул', 'ходьб', 'город', 'фото'],
    ),
    CatalogEntry(
      Activity(
        title: 'Поход в музей',
        description:
            'Посетите музей, в котором ещё не были. Возьмите '
            'аудиогид или экскурсию — так интереснее.',
        category: 'Культура',
        emoji: '🏛️',
        durationMinutes: 150,
        preferredStartHour: 12,
      ),
      tags: ['искусств', 'истор', 'музе', 'культур'],
      free: false,
    ),
    CatalogEntry(
      Activity(
        title: 'Покормить уток за городом',
        description:
            'Съездите на машине к ближайшему озеру или пруду. '
            'Возьмите овсянку или зерно (хлеб уткам вреден) и термос с чаем.',
        category: 'Природа',
        emoji: '🦆',
        durationMinutes: 180,
        preferredStartHour: 11,
      ),
      tags: ['природ', 'животн', 'птиц', 'машин'],
      needsCar: true,
    ),
    CatalogEntry(
      Activity(
        title: 'Пикник в парке',
        description:
            'Соберите простой перекус, плед и книгу. Найдите '
            'тихое место в парке и проведите пару часов без телефона.',
        category: 'Отдых',
        emoji: '🧺',
        durationMinutes: 120,
        preferredStartHour: 13,
      ),
      tags: ['природ', 'книг', 'чтени', 'еда'],
    ),
    CatalogEntry(
      Activity(
        title: 'Новый рецепт',
        description:
            'Приготовьте блюдо кухни, которую никогда не пробовали '
            'готовить. Позовите друзей на дегустацию.',
        category: 'Еда',
        emoji: '🍳',
        durationMinutes: 120,
        preferredStartHour: 18,
      ),
      tags: ['готов', 'кулинар', 'еда', 'кухн'],
    ),
    CatalogEntry(
      Activity(
        title: 'Велопрогулка',
        description:
            'Возьмите велосипед или прокатный самокат и проедьте '
            'по набережной или парковой дорожке.',
        category: 'Спорт',
        emoji: '🚴',
        durationMinutes: 90,
        preferredStartHour: 17,
      ),
      tags: ['спорт', 'велос', 'актив'],
      free: false,
    ),
    CatalogEntry(
      Activity(
        title: 'Закат на смотровой',
        description:
            'Узнайте, где в вашем городе лучшая смотровая '
            'площадка, и приезжайте туда к закату.',
        category: 'Прогулка',
        emoji: '🌇',
        durationMinutes: 60,
        preferredStartHour: 18,
      ),
      tags: ['фото', 'прогул', 'город'],
    ),
    CatalogEntry(
      Activity(
        title: 'Поездка в соседний город',
        description:
            'Сядьте за руль и съездите в небольшой город '
            'неподалёку: прогуляйтесь по центру и пообедайте в местном кафе.',
        category: 'Путешествие',
        emoji: '🚗',
        durationMinutes: 360,
        preferredStartHour: 10,
      ),
      tags: ['путешеств', 'машин', 'истор'],
      needsCar: true,
      free: false,
    ),
    CatalogEntry(
      Activity(
        title: 'Настольные игры',
        description:
            'Позовите друзей на вечер настолок или сходите в '
            'антикафе, где можно сыграть во что-то новое.',
        category: 'Друзья',
        emoji: '🎲',
        durationMinutes: 180,
        preferredStartHour: 19,
      ),
      tags: ['игр', 'настол', 'друз'],
    ),
    CatalogEntry(
      Activity(
        title: 'Кино на последнем ряду',
        description:
            'Сходите на фильм, который выбрали бы не сами: '
            'например, первый сеанс в афише ближайшего кинотеатра.',
        category: 'Культура',
        emoji: '🎬',
        durationMinutes: 150,
        preferredStartHour: 19,
      ),
      tags: ['кино', 'фильм', 'сериал'],
      free: false,
    ),
    CatalogEntry(
      Activity(
        title: 'Пробежка с новым маршрутом',
        description:
            'Проложите в картах новую трассу на 3–5 км и '
            'пробегите её в комфортном темпе.',
        category: 'Спорт',
        emoji: '🏃',
        durationMinutes: 60,
        preferredStartHour: 8,
      ),
      tags: ['бег', 'спорт', 'актив'],
    ),
    CatalogEntry(
      Activity(
        title: 'Фотоохота',
        description:
            'Выберите тему — двери, тени, вывески — и соберите '
            'серию из 10 снимков на прогулке.',
        category: 'Творчество',
        emoji: '📷',
        durationMinutes: 90,
        preferredStartHour: 15,
      ),
      tags: ['фото', 'творч', 'искусств'],
    ),
  ];
}

/// Запись встроенного каталога занятий.
class CatalogEntry {
  const CatalogEntry(
    this.activity, {
    this.tags = const [],
    this.needsCar = false,
    this.free = true,
  });

  final Activity activity;

  /// Корни слов для сопоставления с увлечениями.
  final List<String> tags;
  final bool needsCar;
  final bool free;
}
