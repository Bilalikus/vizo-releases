import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/constants.dart';

/// Changelog entries per version.
const Map<String, List<_ChangeEntry>> _changelog = {
  '1.9.5': [
    _ChangeEntry(Icons.chat_rounded, 'Telegram-стиль',
        'Интерфейс чатов полностью переработан — как в Telegram/WhatsApp.'),
    _ChangeEntry(Icons.call_rounded, 'Входящие звонки',
        'Полноэкранный оверлей при входящем звонке с рингтоном — видно из любого экрана.'),
    _ChangeEntry(Icons.tab_rounded, 'Навигация',
        'Убрана вкладка Контакты — теперь 4 вкладки: Чаты, Группы, Звонки, Профиль.'),
    _ChangeEntry(Icons.music_note_rounded, 'Рингтон',
        'Добавлен рингтон для входящих звонков.'),
  ],
  '1.9.4': [
    _ChangeEntry(Icons.visibility_off_rounded, 'Сообщества и каналы скрыты',
        'Вкладки сообществ и каналов временно отключены для доработки.'),
    _ChangeEntry(Icons.space_bar_rounded, 'Белое пространство убрано',
        'Вкладка «Чаты» полностью переписана — никакого пустого места.'),
    _ChangeEntry(Icons.bug_report_rounded, 'Исправления багов',
        'Убраны deprecated-предупреждения, неиспользуемый код, лишние импорты.'),
    _ChangeEntry(Icons.archive_rounded, 'Фильтр архивных',
        'Архивные чаты теперь не показываются в основном списке.'),
  ],
  '1.9.3': [
    _ChangeEntry(Icons.mic_rounded, 'Голосовые исправлены',
        'Запись и воспроизведение голосовых полностью переработаны — теперь стабильно.'),
    _ChangeEntry(Icons.space_bar_rounded, 'Убрана пустота',
        'Пустое пространство под списками чатов, групп и контактов убрано.'),
    _ChangeEntry(Icons.text_fields_rounded, 'Компактная шапка',
        'Убран огромный заголовок «Чаты» — теперь всё компактно, как в Telegram.'),
    _ChangeEntry(Icons.volume_off_rounded, 'Иконка мьюта',
        'Замьюченные чаты теперь показывают 🔇 рядом с временем.'),
    _ChangeEntry(Icons.account_circle_rounded, 'Аватар в чате',
        'Аватар собеседника теперь корректно передаётся в экран чата.'),
    _ChangeEntry(Icons.touch_app_rounded, 'Запись одним тапом',
        'Нажмите на 🎤 один раз — начнётся запись. Зажатие тоже работает.'),
  ],
  '1.9.0': [
    _ChangeEntry(Icons.search_rounded, 'Универсальный поиск',
        'Поиск людей, групп и сообществ по @Имени, номеру телефона или названию.'),
    _ChangeEntry(Icons.qr_code_2_rounded, 'Настоящие QR-коды',
        'QR-код профиля теперь реальный — сканируйте для мгновенного добавления контакта.'),
    _ChangeEntry(Icons.reply_rounded, 'Ответы в группах',
        'Свайп по сообщению → ответ с превью. Нажмите на цитату → скролл к оригиналу.'),
    _ChangeEntry(Icons.edit_rounded, 'Редактирование в группах',
        'Редактируйте свои сообщения в групповых чатах — помечается значком «ред.»'),
    _ChangeEntry(Icons.emoji_emotions_rounded, 'Реакции в группах',
        'Двойной тап или меню → поставьте реакцию-эмодзи на любое сообщение в группе.'),
    _ChangeEntry(Icons.emoji_symbols_rounded, 'Стикеры в группах',
        'Отправляйте стикеры из 4 встроенных паков прямо в групповые чаты.'),
    _ChangeEntry(Icons.attach_file_rounded, 'Файлы в группах',
        'Прикрепляйте и отправляйте файлы в групповые чаты — кнопка 📎.'),
    _ChangeEntry(Icons.delete_outline_rounded, 'Удаление в группах',
        'Удаляйте свои сообщения в группах через длинное нажатие.'),
    _ChangeEntry(Icons.content_copy_rounded, 'Копирование в группах',
        'Копируйте текст любого сообщения в группе одним нажатием.'),
    _ChangeEntry(Icons.push_pin_rounded, 'Скролл к закреплённому',
        'Нажмите на панель закреплённого сообщения → автоматическая прокрутка к нему.'),
    _ChangeEntry(Icons.shortcut_rounded, 'Скролл к ответу',
        'Нажмите на цитату в личном чате → прокрутка к оригинальному сообщению.'),
    _ChangeEntry(Icons.wallpaper_rounded, 'Исправлены обои',
        'Исправлена ошибка с индексами обоев — выбор обоев теперь стабилен.'),
    _ChangeEntry(Icons.layers_rounded, 'Реакции не растягивают пузыри',
        'Реакции-эмодзи теперь отображаются как оверлей снизу, не растягивая пузырь.'),
  ],
  '1.8.0': [
    _ChangeEntry(Icons.group_rounded, 'Группы',
        'Создавайте групповые чаты — приглашайте участников, управляйте группой.'),
    _ChangeEntry(Icons.public_rounded, 'Сообщества',
        'Открытые сообщества доступны всем — вступайте одним нажатием.'),
    _ChangeEntry(Icons.admin_panel_settings_rounded, 'Админ-панель',
        'Панель администратора: статистика, управление пользователями, баны.'),
    _ChangeEntry(Icons.analytics_rounded, 'Статистика приложения',
        'Общее кол-во пользователей, онлайн, чаты, группы, установки.'),
    _ChangeEntry(Icons.block_rounded, 'Система банов',
        'Администратор может банить/разбанивать пользователей с указанием причины.'),
    _ChangeEntry(Icons.image_rounded, 'Исправлены фото/видео',
        'Фотографии теперь видны у обоих собеседников — данные передаются через Firestore.'),
    _ChangeEntry(Icons.people_outline_rounded, 'Управление группами',
        'Добавление участников, выход из группы, удаление группы (для создателя).'),
    _ChangeEntry(Icons.explore_rounded, 'Обзор сообществ',
        'Горизонтальная лента с доступными сообществами — вступайте в один тап.'),
  ],
  '1.7.0': [
    _ChangeEntry(Icons.chat_bubble_outline_rounded, 'Чат полностью переписан',
        'Исправлена критическая проблема с прокруткой — чат больше НЕ перескакивает наверх.'),
    _ChangeEntry(Icons.photo_rounded, 'Исправлены фотографии',
        'Фото теперь корректно отображаются — поддержка base64, локальных файлов и URL.'),
    _ChangeEntry(Icons.play_circle_rounded, 'Видеоплеер',
        'Полноценный видеоплеер с управлением — play/pause, прогресс-бар, полный экран.'),
    _ChangeEntry(Icons.high_quality_rounded, 'Адаптивное качество видеозвонков',
        'Алгоритм автоматически подстраивает качество видео под сеть: HD → 480p → 360p → 240p.'),
    _ChangeEntry(Icons.speed_rounded, 'Улучшение видеозвонков',
        'Мониторинг потери пакетов и RTT — автоматическое повышение/понижение битрейта.'),
    _ChangeEntry(Icons.attach_file_rounded, 'Исправлена панель вложений',
        'Панель предпросмотра файла теперь корректно исчезает после отправки.'),
    _ChangeEntry(Icons.image_rounded, 'Полноэкранный просмотр фото',
        'Нажмите на фото в чате → полноэкранный просмотр с зумом и жестами.'),
    _ChangeEntry(Icons.mic_rounded, 'Голосовые сообщения',
        'Улучшена визуальная анимация воспроизведения голосовых сообщений.'),
    _ChangeEntry(Icons.memory_rounded, 'Оптимизация памяти',
        'Фото больше не кодируются в base64 — экономия памяти и трафика.'),
    _ChangeEntry(Icons.network_check_rounded, 'Мониторинг сети',
        'Видеозвонки отслеживают RTT, потерю пакетов и битрейт каждые 4 секунды.'),
  ],
  '1.6.0': [
    _ChangeEntry(Icons.videocam_rounded, 'Видеозвонки',
        'Звоните с видео — переключайте камеру, включайте/выключайте видео.'),
    _ChangeEntry(Icons.screen_share_rounded, 'Демонстрация экрана',
        'Показывайте свой экран во время звонка — идеально для работы.'),
    _ChangeEntry(Icons.emoji_emotions_rounded, 'Стикеры',
        'Отправляйте стикеры из 4 встроенных стикер-паков: эмоции, жесты, животные, еда.'),
    _ChangeEntry(Icons.attach_file_rounded, 'Отправка файлов',
        'Прикрепляйте файлы к сообщениям — кнопка 📎 рядом с полем ввода.'),
    _ChangeEntry(Icons.mic_rounded, 'Голосовые сообщения',
        'Зажмите микрофон для записи голосового сообщения.'),
    _ChangeEntry(Icons.history_rounded, 'История звонков исправлена',
        'Вкладка «Звонки» теперь стабильно отображает всю историю.'),
    _ChangeEntry(Icons.search_rounded, 'Поиск в чате',
        'Быстрый поиск по сообщениям внутри конкретного чата.'),
    _ChangeEntry(Icons.schedule_rounded, 'Отложенные сообщения',
        'Запланируйте отправку сообщения на нужное время.'),
    _ChangeEntry(Icons.swipe_rounded, 'Свайп для ответа',
        'Свайп вправо по сообщению → быстрый ответ.'),
    _ChangeEntry(Icons.photo_library_rounded, 'Медиа-галерея',
        'Просмотр всех изображений и файлов чата в одном месте.'),
    _ChangeEntry(Icons.archive_rounded, 'Архив чатов',
        'Архивируйте чаты — они скрываются, но не удаляются.'),
    _ChangeEntry(Icons.timer_outlined, 'Индикатор исчезновения',
        'Визуальный таймер на сообщениях с автоудалением.'),
    _ChangeEntry(Icons.signal_cellular_alt_rounded, 'Качество связи',
        'Индикатор качества WebRTC-соединения во время звонка.'),
    _ChangeEntry(Icons.verified_user_rounded, 'Статус доставки',
        'Три состояния: отправлено ✓, доставлено ✓✓, прочитано (синие ✓✓).'),
    _ChangeEntry(Icons.notifications_active_rounded, 'Звук входящего звонка',
        'Простой рингтон при входящем звонке.'),
    _ChangeEntry(Icons.format_size_rounded, 'Размер пузырей',
        'Адаптивный размер пузырей сообщений под контент.'),
    _ChangeEntry(Icons.group_rounded, 'Групповые чаты (бета)',
        'Создавайте групповые беседы — до 10 участников.'),
    _ChangeEntry(Icons.translate_rounded, 'Авто-перевод',
        'Перевод сообщений одним нажатием на 10+ языков.'),
    _ChangeEntry(Icons.dark_mode_rounded, 'Тёмная тема',
        'Оптимизированная тёмная тема с AMOLED чёрным фоном.'),
    _ChangeEntry(Icons.lock_clock_rounded, 'Блокировка приложения',
        'PIN-код или биометрия для входа в приложение.'),
    _ChangeEntry(Icons.backup_rounded, 'Бэкап чатов',
        'Резервное копирование переписок в облако.'),
    _ChangeEntry(Icons.speed_rounded, 'Оптимизация',
        'Ускорена загрузка чатов и звонков — меньше задержек.'),
    _ChangeEntry(Icons.bug_report_rounded, 'Исправление бага дёрганья',
        'Чат больше не дёргается при открытии клавиатуры или новых сообщениях.'),
    _ChangeEntry(Icons.palette_rounded, 'Цвета пузырей',
        'Настройка цвета пузырей сообщений в настройках.'),
    _ChangeEntry(Icons.text_snippet_rounded, 'Цитирование текста',
        'Выделяйте часть текста для цитирования в ответе.'),
    _ChangeEntry(Icons.campaign_rounded, 'Каналы (бета)',
        'Создавайте каналы для рассылки — как в Telegram.'),
    _ChangeEntry(Icons.auto_fix_high_rounded, 'UI-полировка v2',
        'Обновлённые анимации, иконки, микроэффекты — ещё красивее.'),
    _ChangeEntry(Icons.contact_page_rounded, 'Отправка контактов',
        'Делитесь контактами Vizo прямо в чате.'),
    _ChangeEntry(Icons.location_on_rounded, 'Геолокация',
        'Отправляйте своё местоположение в чат.'),
    _ChangeEntry(Icons.poll_rounded, 'Опросы в чатах',
        'Создавайте голосования прямо в чате.'),
  ],
  '1.5.0': [
    _ChangeEntry(Icons.push_pin_rounded, 'Закрепление сообщений',
        'Закрепляйте важные сообщения в чате — видны вверху.'),
    _ChangeEntry(Icons.link_rounded, 'Превью ссылок',
        'URL-адреса в сообщениях автоматически подсвечиваются.'),
    _ChangeEntry(Icons.check_box_outlined, 'Мульти-выбор',
        'Долгое нажатие → режим выбора нескольких сообщений для удаления.'),
    _ChangeEntry(Icons.flash_on_rounded, 'Быстрые ответы',
        'Создавайте шаблоны ответов и вставляйте одним нажатием ⚡.'),
    _ChangeEntry(Icons.folder_rounded, 'Папки чатов',
        'Организуйте чаты по папкам: Работа, Друзья, Семья.'),
    _ChangeEntry(Icons.wallpaper_rounded, 'Обои чата',
        '12 градиентных обоев для фона чата — выберите свой стиль.'),
    _ChangeEntry(Icons.search_rounded, 'Глобальный поиск',
        'Поиск сообщений сразу по ВСЕМ чатам.'),
    _ChangeEntry(Icons.zoom_in_rounded, 'Просмотр медиа',
        'Полноэкранный просмотр изображений с зумом.'),
    _ChangeEntry(Icons.qr_code_rounded, 'QR-код профиля',
        'Ваш уникальный QR-код — делитесь контактом легко.'),
    _ChangeEntry(Icons.bar_chart_rounded, 'Статистика',
        'Аналитика: сколько сообщений, звонков, активность по дням.'),
    _ChangeEntry(Icons.note_rounded, 'Заметки о контактах',
        'Приватные заметки о каждом контакте — видны только вам.'),
    _ChangeEntry(Icons.mark_email_unread_rounded, 'Фильтр непрочитанных',
        'Быстрая кнопка для показа только непрочитанных чатов.'),
    _ChangeEntry(Icons.swipe_rounded, 'Свайп в чатах',
        'Свайп влево по чату → быстрый мьют/анмьют.'),
    _ChangeEntry(Icons.do_not_disturb_on_rounded, 'Не беспокоить',
        'Режим DND — отключите все уведомления разом.'),
    _ChangeEntry(Icons.chat_bubble_rounded, 'Стиль пузырей',
        'Выбирайте стиль сообщений: скруглённый, острый, минимальный.'),
    _ChangeEntry(Icons.palette_rounded, 'Обои в настройках',
        'Управление обоями перенесено в настройки.'),
    _ChangeEntry(Icons.bookmark_add_rounded, 'Закреплённые в инфо',
        'Раздел «Закреплённые сообщения» в информации о чате.'),
    _ChangeEntry(Icons.settings_rounded, 'Расширенные настройки',
        'Папки, быстрые ответы, обои, стиль — всё в настройках.'),
    _ChangeEntry(Icons.people_rounded, 'QR + Статистика в профиле',
        'Две новые быстрые кнопки на экране профиля.'),
    _ChangeEntry(Icons.auto_awesome_rounded, 'UI-полировка',
        'Улучшенная анимация, новые иконки, обновлённый дизайн.'),
  ],
  '1.4.0': [
    _ChangeEntry(Icons.settings_rounded, 'Настройки',
        'Полноценный экран настроек: уведомления, приватность, шрифт, удаление аккаунта.'),
    _ChangeEntry(Icons.block_rounded, 'Заблокированные пользователи',
        'Управление заблокированными — просмотр и разблокировка.'),
    _ChangeEntry(Icons.info_outline_rounded, 'Инфо о чате',
        'Детали чата: мьют, пин, поиск по сообщениям, экспорт истории.'),
    _ChangeEntry(Icons.search_rounded, 'Поиск в чате',
        'Мгновенный поиск по всем сообщениям внутри чата.'),
    _ChangeEntry(Icons.star_rounded, 'Избранные сообщения',
        'Помечайте важные сообщения звёздочкой и находите их.'),
    _ChangeEntry(Icons.bookmark_rounded, 'Заметки (Saved Messages)',
        'Личный блокнот — сохраняйте заметки, идеи, ссылки.'),
    _ChangeEntry(Icons.emoji_emotions_outlined, 'Реакции на сообщения',
        'Двойной тап или меню → добавьте эмодзи-реакцию. ❤️👍😂'),
    _ChangeEntry(Icons.calendar_today_rounded, 'Разделители по датам',
        'Сообщения группируются по дням — Сегодня, Вчера, дата.'),
    _ChangeEntry(Icons.keyboard_arrow_down_rounded, 'Прокрутка вниз',
        'FAB-кнопка для мгновенной прокрутки к последнему сообщению.'),
    _ChangeEntry(Icons.star_border_rounded, 'Избранные контакты',
        'Отмечайте контакты звёздочкой — они всегда вверху списка.'),
    _ChangeEntry(Icons.notifications_off_rounded, 'Тонкая настройка уведомлений',
        'Включение/выключение push, звук, вибрация — в настройках.'),
    _ChangeEntry(Icons.visibility_off_rounded, 'Приватность',
        'Отчёты о прочтении, последний визит, индикатор набора — всё настраивается.'),
    _ChangeEntry(Icons.timer_rounded, 'Исчезающие сообщения',
        'Выберите таймер: 5 мин, 1 ч, 24 ч или 7 дней — сообщения удалятся.'),
    _ChangeEntry(Icons.text_fields_rounded, 'Размер шрифта',
        'Маленький, средний или большой текст — настройте под себя.'),
    _ChangeEntry(Icons.delete_forever_rounded, 'Удаление аккаунта',
        'Полное удаление всех данных с подтверждением.'),
    _ChangeEntry(Icons.badge_rounded, 'Бейдж непрочитанных',
        'Красный счётчик непрочитанных на вкладке Чаты.'),
    _ChangeEntry(Icons.bookmark_add_rounded, 'Пин заметок',
        'Закрепляйте важные заметки наверх списка.'),
    _ChangeEntry(Icons.cleaning_services_rounded, 'Очистка истории чата',
        'Удаление всех сообщений с подтверждением.'),
    _ChangeEntry(Icons.file_download_rounded, 'Экспорт чата',
        'Экспортируйте историю переписки в текстовый формат.'),
    _ChangeEntry(Icons.link_rounded, 'Привязка контактов',
        'Контакты автоматически связываются с аккаунтами Vizo.'),
    _ChangeEntry(Icons.touch_app_rounded, 'Двойной тап → реакция',
        'Быстрый жест для добавления реакции на сообщение.'),
  ],
  '1.3.0': [
    _ChangeEntry(Icons.edit_rounded, 'Редактирование сообщений',
        'Долгое нажатие → Редактировать. Отредактированные помечаются.'),
    _ChangeEntry(Icons.delete_outline_rounded, 'Удаление сообщений',
        'Удаляйте свои сообщения — они заменяются заглушкой.'),
    _ChangeEntry(Icons.reply_rounded, 'Ответ на сообщение',
        'Свайп вправо или долгое нажатие → Ответить. Видно превью.'),
    _ChangeEntry(Icons.forward_rounded, 'Пересылка сообщений',
        'Перешлите сообщение любому контакту из Vizo.'),
    _ChangeEntry(Icons.copy_rounded, 'Копирование текста',
        'Скопируйте текст сообщения в буфер обмена.'),
    _ChangeEntry(Icons.keyboard_rounded, 'Индикатор набора',
        'Видно когда собеседник печатает сообщение.'),
    _ChangeEntry(Icons.circle, 'Онлайн-статус в чате',
        'Зелёная точка и текст «в сети» в шапке чата.'),
    _ChangeEntry(Icons.auto_awesome_rounded, 'LiquidGlass UI',
        'Полупрозрачные панели и кнопки с блюром — стиль iOS.'),
  ],
};

class _ChangeEntry {
  final IconData icon;
  final String title;
  final String description;
  const _ChangeEntry(this.icon, this.title, this.description);
}

/// Shows "What's new" dialog if user hasn't seen this version yet.
Future<void> showWhatsNewIfNeeded(BuildContext context, String currentVersion) async {
  final prefs = await SharedPreferences.getInstance();
  final seenVersion = prefs.getString('whats_new_seen') ?? '';
  if (seenVersion == currentVersion) return;
  if (!context.mounted) return;

  final entries = _changelog[currentVersion];
  if (entries == null || entries.isEmpty) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WhatsNewSheet(version: currentVersion, entries: entries),
  );

  await prefs.setString('whats_new_seen', currentVersion);
}

class _WhatsNewSheet extends StatelessWidget {
  const _WhatsNewSheet({required this.version, required this.entries});
  final String version;
  final List<_ChangeEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Text(
                '🎉  Что нового',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vizo v$version',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.accentLight.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              // Entries
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Icon(e.icon,
                                color: AppColors.accentLight, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  e.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.7),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Close button
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accent.withValues(alpha: 0.6),
                              AppColors.accentLight.withValues(alpha: 0.4),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 0.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(14),
                            child: const Center(
                              child: Text(
                                'Отлично!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }
}
