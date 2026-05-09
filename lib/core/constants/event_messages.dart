/// Centralized text keys for event lifecycle restrictions.
///
/// The project does not yet use ARB localization, so we keep related
/// messages in one place to make future localization migration straightforward.
abstract class EventMessages {
  static const String eventFinishedParticipationUnavailable =
      'Событие уже завершено, участие недоступно';

  static const String eventFinishedActionBlocked =
      'Событие завершено, участие недоступно';

  static const String eventFinishedButtonTitle = 'Событие завершено';

  static const String eventFinishedMatchesUnavailable =
      'Событие завершено, метчи недоступны';

  static const String eventFinishedMatchesTitle = 'Это событие завершено';

  static const String eventFinishedMatchesDescription =
      'Для завершенных событий участие в матчах недоступно';
}