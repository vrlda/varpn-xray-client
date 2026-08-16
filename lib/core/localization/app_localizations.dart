import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const supportedLocales = [
    Locale('ru'),
    Locale('en'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  static Locale localeFromCode(String code) {
    return code.toLowerCase() == 'en' ? const Locale('en') : const Locale('ru');
  }

  bool get _isEnglish => locale.languageCode == 'en';

  String get appTitle => 'VarPN';
  String get settingsTitle => _text(en: 'Settings', ru: 'Настройки');
  String get interfaceSection => _text(en: 'Interface', ru: 'Интерфейс');
  String get language => _text(en: 'Language', ru: 'Язык');
  String get appearanceTheme => _text(en: 'Appearance', ru: 'Тема оформления');
  String get detailsSection => _text(en: 'More', ru: 'Подробнее');
  String get statistics => _text(en: 'Statistics', ru: 'Статистика');
  String get currentSessionSection =>
      _text(en: 'Current session', ru: 'Текущая сессия');
  String get lifetimeSection =>
      _text(en: 'Usage history', ru: 'История использования');
  String get statusLabel => _text(en: 'Status', ru: 'Статус');
  String get serverLabel => _text(en: 'Server', ru: 'Сервер');
  String get currentSessionLabel =>
      _text(en: 'Session time', ru: 'Время сессии');
  String get sessionTrafficLabel =>
      _text(en: 'Session traffic', ru: 'Трафик сессии');
  String get totalTrafficLabel =>
      _text(en: 'Total traffic', ru: 'Общий трафик');
  String get uploadedLabel => _text(en: 'Uploaded', ru: 'Отправлено');
  String get downloadedLabel => _text(en: 'Downloaded', ru: 'Получено');
  String get connectionAttemptsLabel =>
      _text(en: 'Connection attempts', ru: 'Попытки подключения');
  String get successfulConnectionsLabel =>
      _text(en: 'Successful sessions', ru: 'Успешные сессии');
  String get failedConnectionsLabel =>
      _text(en: 'Failed attempts', ru: 'Неудачные попытки');
  String get totalConnectedTimeLabel =>
      _text(en: 'Total connected time', ru: 'Общее время подключения');
  String get lastSessionLabel =>
      _text(en: 'Last session', ru: 'Последняя сессия');
  String get lastConnectedLabel =>
      _text(en: 'Last connected', ru: 'Последнее подключение');
  String get notConnectedLabel =>
      _text(en: 'Not connected', ru: 'Не подключено');
  String get neverLabel => _text(en: 'Never', ru: 'Никогда');
  String get faq => _text(en: 'FAQ', ru: 'FAQ');
  String get aboutApp => _text(en: 'About', ru: 'О приложении');
  String get reset => _text(en: 'Reset', ru: 'Сброс');
  String get developerMode => _text(en: 'Pro mode', ru: 'Pro режим');
  String get developerToolsUnlocked => _text(
        en: 'Pro tools unlocked',
        ru: 'Pro инструменты разблокированы',
      );
  String get advancedSettings =>
      _text(en: 'Advanced settings', ru: 'Расширенные настройки');
  String get connections => _text(en: 'Connections', ru: 'Подключения');
  String get activeLabel => _text(en: 'Active', ru: 'Активно');
  String get noConnectionsAdded => _text(
        en: 'No connection sources added yet. Use the plus button to add a subscription, a config link, or a Pro manual connection.',
        ru: 'Источники подключений ещё не добавлены. Используйте кнопку плюс, чтобы добавить подписку, ссылку-конфиг или ручное Pro подключение.',
      );
  String get subscriptionSourceLabel =>
      _text(en: 'Subscription URL', ru: 'Ссылка подписки');
  String get subscriptionSourceHint => _text(
        en: 'HTTP or HTTPS link that returns a subscription list.',
        ru: 'Ссылка HTTP или HTTPS, которая возвращает список подписки.',
      );
  String get configSourceLabel => _text(en: 'Config link', ru: 'Ссылка-конфиг');
  String get configSourceHint => _text(
        en: 'Single VLESS, VMess, Trojan, or Shadowsocks link.',
        ru: 'Одна ссылка VLESS, VMess, Trojan или Shadowsocks.',
      );
  String get manualSourceLabel =>
      _text(en: 'Manual Pro connection', ru: 'Ручное Pro подключение');
  String get manualSourceHint => _text(
        en: 'Fill the node fields manually and save them as a reusable source.',
        ru: 'Заполните поля узла вручную и сохраните их как переиспользуемый источник.',
      );
  String get sourceNameLabel => _text(en: 'Name', ru: 'Имя');
  String get sourceNameHint =>
      _text(en: 'Visible name', ru: 'Отображаемое имя');
  String get sourceInputLabel => _text(en: 'Input', ru: 'Входные данные');
  String get saveAction => _text(en: 'Save', ru: 'Сохранить');
  String get removeConnectionTitle =>
      _text(en: 'Remove connection?', ru: 'Удалить подключение?');
  String removeConnectionMessage(String name) => _text(
        en: 'The source "$name" will be removed from the list.',
        ru: 'Источник "$name" будет удалён из списка.',
      );
  String get protocolLabel => _text(en: 'Protocol', ru: 'Протокол');
  String get networkLabel => _text(en: 'Network', ru: 'Сеть');
  String get securityLabel => _text(en: 'Security', ru: 'Безопасность');
  String get encryptionLabel => _text(en: 'Encryption', ru: 'Шифрование');
  String get serverAddressLabel =>
      _text(en: 'Server address', ru: 'Адрес сервера');
  String get portLabel => _text(en: 'Port', ru: 'Порт');
  String get credentialLabel => _text(en: 'Credential', ru: 'Учётные данные');
  String get credentialHint => _text(
        en: 'UUID, password, or token',
        ru: 'UUID, пароль или токен',
      );
  String get flowLabel => _text(en: 'Flow', ru: 'Flow');
  String get sniLabel => 'SNI';
  String get pathLabel => _text(en: 'Path / Service', ru: 'Path / Service');
  String get hostLabel => _text(en: 'Host / Authority', ru: 'Host / Authority');
  String get publicKeyLabel =>
      _text(en: 'Reality public key', ru: 'Публичный ключ Reality');
  String get publicKeyHint => _text(
        en: 'Only for Reality',
        ru: 'Только для Reality',
      );
  String get shortIdLabel =>
      _text(en: 'Reality short ID', ru: 'Short ID Reality');
  String get fingerprintLabel => _text(en: 'Fingerprint', ru: 'Fingerprint');
  String get alpnLabel => 'ALPN';
  String get extraJsonLabel => _text(en: 'Extra JSON', ru: 'Доп. JSON');
  String get extraJsonHint => _text(
        en: 'Optional raw Xray fields in JSON format',
        ru: 'Необязательные raw-поля Xray в формате JSON',
      );
  String get routesAndRules =>
      _text(en: 'Routes & Rules', ru: 'Маршруты & Правила');
  String get useRouting => _text(en: 'Use routing', ru: 'Использовать роутинг');
  String get routingDescription => _text(
        en: 'Routing rules let you distribute traffic between Proxy, Direct, and Block modes.',
        ru: 'Правила маршрутизации позволяют гибко управлять трафиком между режимами Proxy, Direct и Block.',
      );
  String get selectRoutingPreset =>
      _text(en: 'Choose routing preset', ru: 'Выбрать настройки роутинга');
  String get routingPresets =>
      _text(en: 'Routing presets', ru: 'Пресеты роутинга');
  String get edit => _text(en: 'Edit', ru: 'Редактировать');
  String get addPreset => _text(en: 'Add preset', ru: 'Добавить пресет');
  String get newPreset => _text(en: 'New preset', ru: 'Новый пресет');
  String get presetName => _text(en: 'Preset name', ru: 'Имя пресета');
  String get remove => _text(en: 'Remove', ru: 'Удалить');
  String get cannotRemoveLastPreset => _text(
        en: 'At least one preset must remain',
        ru: 'Должен остаться хотя бы один пресет',
      );
  String get presetAdded => _text(en: 'Preset added', ru: 'Пресет добавлен');
  String get presetRemoved => _text(en: 'Preset removed', ru: 'Пресет удалён');
  String get auto => _text(en: 'Auto', ru: 'Авто');
  String get off => _text(en: 'Off', ru: 'Выкл');
  String get tunnel => _text(en: 'Tunnel', ru: 'Туннель');
  String get tunnelSettingsTitle =>
      _text(en: 'Tunnel settings', ru: 'Настройки туннеля');
  String get tunnelBehavior =>
      _text(en: 'Tunnel behavior', ru: 'Поведение туннеля');
  String get mtuLabel => 'MTU';
  String get ipv6Label => _text(en: 'IPv6', ru: 'IPv6');
  String get bypassLocalNetworks => _text(
        en: 'Bypass local networks',
        ru: 'Обход локальных сетей',
      );
  String get strictRoutingLabel =>
      _text(en: 'Strict routing', ru: 'Строгий роутинг');
  String get dnsModeLabel => _text(en: 'DNS mode', ru: 'Режим DNS');
  String get dnsServersLabel => _text(en: 'DNS servers', ru: 'DNS серверы');
  String get systemDnsMode => _text(en: 'System', ru: 'Системный');
  String get customDnsMode => _text(en: 'Custom', ru: 'Свой');
  String get dnsServersDialogTitle =>
      _text(en: 'Custom DNS servers', ru: 'Свои DNS серверы');
  String get dnsServersHint => _text(
        en: 'One server per line or comma separated',
        ru: 'По одному серверу на строку или через запятую',
      );
  String get tunnelHealthSection =>
      _text(en: 'Tunnel health', ru: 'Состояние туннеля');
  String get tunnelHealthUnavailable => _text(
        en: 'No native health snapshot yet',
        ru: 'Снимок состояния пока недоступен',
      );
  String get helperInstalledLabel =>
      _text(en: 'Helper installed', ru: 'Хелпер установлен');
  String get helperReachableLabel =>
      _text(en: 'Helper reachable', ru: 'Хелпер доступен');
  String get routesConfiguredLabel =>
      _text(en: 'Routes applied', ru: 'Маршруты применены');
  String get dnsConfiguredLabel =>
      _text(en: 'DNS applied', ru: 'DNS применён');
  String get utunInterfaceLabel =>
      _text(en: 'utun interface', ru: 'Интерфейс utun');
  String get lastRepairActionLabel =>
      _text(en: 'Last repair action', ru: 'Последнее исправление');
  String get memoryUsageLabel =>
      _text(en: 'Memory usage', ru: 'Использование памяти');
  String get memoryPressureLabel =>
      _text(en: 'Memory pressure', ru: 'Нагрузка по памяти');
  String get nativeStateLabel =>
      _text(en: 'Native state', ru: 'Состояние системы');
  String get updatedAtLabel => _text(en: 'Updated', ru: 'Обновлено');
  String get lastRecoveryReasonLabel =>
      _text(en: 'Last recovery', ru: 'Последнее восстановление');
  String get lastCrashReasonLabel =>
      _text(en: 'Last crash reason', ru: 'Последняя причина сбоя');
  String get xray => 'Xray';
  String get xraySettingsTitle =>
      _text(en: 'Xray settings', ru: 'Настройки Xray');
  String get coreBehavior => _text(en: 'Core behavior', ru: 'Поведение ядра');
  String get logLevelLabel => _text(en: 'Log level', ru: 'Уровень логов');
  String get sniffingLabel => _text(en: 'Sniffing', ru: 'Sniffing');
  String get allowInsecureLabel =>
      _text(en: 'Allow insecure TLS', ru: 'Разрешить insecure TLS');
  String get transportOverrideLabel => _text(
        en: 'Transport override',
        ru: 'Переопределение транспорта',
      );
  String get autoTransport => _text(en: 'Auto', ru: 'Авто');
  String get tcpTransport => 'TCP';
  String get grpcTransport => 'gRPC';
  String get xhttpTransport => 'xHTTP';
  String get errorLogLevel => _text(en: 'Error', ru: 'Ошибка');
  String get warningLogLevel => _text(en: 'Warning', ru: 'Предупреждение');
  String get infoLogLevel => _text(en: 'Info', ru: 'Инфо');
  String get debugLogLevel => _text(en: 'Debug', ru: 'Debug');
  String get subscriptions => _text(en: 'Subscriptions', ru: 'Подписки');
  String get ping => _text(en: 'Ping', ru: 'Пинг');
  String get logs => _text(en: 'Logs', ru: 'Логи');
  String get clear => _text(en: 'Clear', ru: 'Очистить');
  String get refresh => _text(en: 'Refresh', ru: 'Обновить');
  String get updateSubscriptionsAction => _text(
        en: 'Update subscriptions',
        ru: 'Обновить подписки',
      );
  String get pingProtocols =>
      _text(en: 'Ping protocols', ru: 'Протоколы пинга');
  String get proxyGetMethod =>
      _text(en: 'Through proxy (GET)', ru: 'Через прокси(GET)');
  String get proxyHeadMethod =>
      _text(en: 'Through proxy (HEAD)', ru: 'Через прокси(HEAD)');
  String get tcpMethod => 'TCP';
  String get icmpMethod => 'ICMP';
  String get urlTestSettings =>
      _text(en: 'URL test settings', ru: 'Настройки URL-теста');
  String get urlTestLink => _text(en: 'Test URL', ru: 'URL-тест');
  String get displayMode => _text(en: 'Display mode', ru: 'Способ отображения');
  String get timeDisplayMode => _text(en: 'Time', ru: 'Время');
  String get pingRefreshHint => _text(
        en: 'Ping is measured on startup, before you connect, and once per hour while the app stays open.',
        ru: 'Пинг измеряется при запуске, перед подключением и затем раз в час, пока приложение открыто.',
      );
  String get noLogsYet => _text(en: 'No logs yet', ru: 'Логи пока пусты');
  String get logsCleared => _text(en: 'Logs cleared', ru: 'Логи очищены');
  String get proxySettings =>
      _text(en: 'Proxy settings', ru: 'Настройки прокси');
  String get globalProxyServer =>
      _text(en: 'Global proxy server', ru: 'Глобальный прокси-сервер');
  String get globalProxyDescription => _text(
        en: 'If global proxy is disabled, traffic stays direct unless it matches your routing rules.',
        ru: 'Если опция «Глобальный прокси» отключена, весь трафик будет проходить в обход прокси-сервера, за исключением указанных вами настроек маршрута.',
      );
  String get routingDistributionSettings =>
      _text(en: 'Distribution settings', ru: 'Настройки распределения');
  String get throughProxy => _text(en: 'Through proxy', ru: 'Через прокси');
  String get direct => _text(en: 'Direct', ru: 'Напрямую');
  String get block => _text(en: 'Block', ru: 'Заблокировать');
  String get proxyRuleInputLabel =>
      _text(en: 'Proxy URL or IP', ru: 'Проксировать URL или IP');
  String get directRuleInputLabel =>
      _text(en: 'Route direct URL or IP', ru: 'Направить напрямую URL или IP');
  String get blockRuleInputLabel =>
      _text(en: 'Block URL or IP', ru: 'Заблокировать URL или IP');
  String get showGeositeTags =>
      _text(en: 'Show geosite tags', ru: 'Показать теги geosite');
  String get showGeoipTags =>
      _text(en: 'Show geoip tags', ru: 'Показать теги geoip');
  String get geositeTagsTitle => _text(en: 'Geosite tags', ru: 'Теги geosite');
  String get geoipTagsTitle => _text(en: 'GeoIP tags', ru: 'Теги geoip');
  String get resourcesSection => _text(en: 'Resources', ru: 'Основное');
  String get geodataUpdated =>
      _text(en: 'Geodata updated', ru: 'Геофайлы обновлены');
  String get trimGeofiles => _text(en: 'Trim geofiles', ru: 'Урезать геофайлы');
  String get editRules => _text(en: 'Edit rules', ru: 'Редактировать правила');
  String get domainSettings =>
      _text(en: 'Domain settings', ru: 'Настройки домена');
  String get enableFakeDns =>
      _text(en: 'Enable Fake DNS', ru: 'Вкл. поддельный DNS');
  String get domainStrategyLabel =>
      _text(en: 'Domain strategy', ru: 'Стратегия доменов');
  String get remoteDns => _text(en: 'Remote DNS', ru: 'Remote DNS');
  String get domesticDns => _text(en: 'Domestic DNS', ru: 'Domestic DNS');
  String get dnsType => _text(en: 'DNS type', ru: 'Тип DNS');
  String get dnsAddress => _text(en: 'DNS address', ru: 'DNS адрес');
  String get dnsBootstrapIp => _text(en: 'DoH IP', ru: 'DoH IP');
  String get save => _text(en: 'Save', ru: 'Сохранить');
  String get saved => _text(en: 'Saved', ru: 'Сохранено');
  String get notAdded => _text(en: 'Not added', ru: 'Не добавлено');
  String get linkLabel => _text(en: 'Link', ru: 'Ссылка');
  String get configLabel => _text(en: 'Config', ru: 'Конфиг');
  String get addConnection =>
      _text(en: 'Add a connection', ru: 'Добавьте подключение');
  String get pasteLink => _text(en: 'Paste\nlink', ru: 'Вставить\nссылку');
  String get loadingSavedSubscription => _text(
        en: 'Loading saved subscription...',
        ru: 'Загружаем сохраненную подписку...',
      );
  String get importPrompt => _text(
        en: 'Press the switch to paste or manually add a subscription',
        ru: 'Нажмите на переключатель, чтобы вставить или\nвручную добавить подписку',
      );
  String get chooseConnection =>
      _text(en: 'Choose a connection', ru: 'Выбрать подключение');
  String get noConnections =>
      _text(en: 'No connections available', ru: 'Нет доступных подключений');
  String get automatic => _text(en: 'Automatic', ru: 'Автоматически');
  String get disconnected => _text(en: 'Disconnected', ru: 'Отключено');
  String get connecting => _text(en: 'Connecting...', ru: 'Подключение...');
  String get connected => _text(en: 'Connected', ru: 'Подключено');
  String get error => _text(en: 'Error', ru: 'Ошибка');
  String get proxyRepairWarning => _text(
        en: 'System proxy needs repair. Some apps may bypass VarPN until it is restored.',
        ru: 'Системный прокси требует восстановления. Некоторые приложения могут обходить VarPN, пока он не будет восстановлен.',
      );
  String get proxyTrafficWarning => _text(
        en: 'VarPN is running, but traffic is not passing through the proxy right now.',
        ru: 'VarPN запущен, но трафик сейчас не проходит через прокси.',
      );
  String get helperInstallWarning => _text(
        en: 'VarPN background helper is not installed yet.',
        ru: 'Фоновый хелпер VarPN ещё не установлен.',
      );
  String get helperUnavailableWarning => _text(
        en: 'VarPN background helper is not reachable right now.',
        ru: 'Фоновый хелпер VarPN сейчас недоступен.',
      );
  String get utunRoutesWarning => _text(
        en: 'VarPN is connected, but the utun routes are not fully applied.',
        ru: 'VarPN подключён, но маршруты utun применены не полностью.',
      );
  String get utunDnsWarning => _text(
        en: 'VarPN is connected, but DNS is not routed through the tunnel.',
        ru: 'VarPN подключён, но DNS не направлен через туннель.',
      );
  String get iosTunnelRecoveryWarning => _text(
        en: 'VarPN is restoring the iPhone tunnel in the background.',
        ru: 'VarPN восстанавливает туннель iPhone в фоне.',
      );
  String get iosMemoryPressureWarning => _text(
        en: 'VarPN is under high memory pressure on iPhone and may reconnect to stay alive.',
        ru: 'VarPN испытывает высокую нагрузку по памяти на iPhone и может переподключиться, чтобы продолжить работу.',
      );
  String get iosMemoryCriticalWarning => _text(
        en: 'VarPN is near the iPhone tunnel memory limit and is recovering automatically.',
        ru: 'VarPN близок к лимиту памяти туннеля на iPhone и восстанавливается автоматически.',
      );
  String get importSubscription =>
      _text(en: 'Import subscription', ru: 'Импорт подписки');
  String get importSubscriptionHint => _text(
        en: 'Paste a subscription link or a single Xray config: VLESS, VMess, Trojan, or Shadowsocks.',
        ru: 'Вставьте ссылку подписки или один Xray-конфиг: VLESS, VMess, Trojan или Shadowsocks.',
      );
  String get paste => _text(en: 'Paste', ru: 'Вставить');
  String get cancel => _text(en: 'Cancel', ru: 'Отмена');
  String get importAction => _text(en: 'Import', ru: 'Импортировать');
  String get savedSubscriptionLoadFailed => _text(
        en: 'Could not load the saved subscription',
        ru: 'Не удалось загрузить сохранённую подписку',
      );
  String get languageSelectionTitle =>
      _text(en: 'Choose language', ru: 'Выберите язык');
  String get themeSelectionTitle =>
      _text(en: 'Choose theme', ru: 'Выберите тему');
  String get routingPresetSelectionTitle =>
      _text(en: 'Choose routing preset', ru: 'Выберите пресет роутинга');
  String get regularModeHelp => _text(
        en: 'Regular mode shows countries only and picks the best node when you connect.',
        ru: 'Обычный режим показывает только страны и выбирает лучший узел при подключении.',
      );
  String get developerToolsHiddenHint => _text(
        en: 'Pro tools stay hidden until you unlock them.',
        ru: 'Pro инструменты скрыты, пока вы их не разблокируете.',
      );
  String get faqConnectionsQuestion => _text(
        en: 'Why can one client say a node works while another says it does not?',
        ru: 'Почему один клиент считает узел рабочим, а другой нет?',
      );
  String get faqConnectionsAnswer => _text(
        en: 'Different apps validate nodes in different ways. VarPN ranks nodes before connect, but DNS, routing rules, or provider-side restrictions can still affect how a specific app behaves.',
        ru: 'Разные клиенты проверяют узлы по-разному. VarPN ранжирует узлы перед подключением, но на поведение конкретного приложения всё равно могут влиять DNS, правила маршрутизации и ограничения со стороны провайдера.',
      );
  String get faqProxyQuestion => _text(
        en: 'How does the current macOS build route traffic?',
        ru: 'Как текущая сборка для macOS направляет трафик?',
      );
  String get faqProxyAnswer => _text(
        en: 'This macOS build uses a background utun helper with tun2socks and Xray, so traffic is captured machine-wide instead of depending on per-app proxy support.',
        ru: 'Эта сборка для macOS использует фоновый utun-хелпер с tun2socks и Xray, поэтому трафик перехватывается на уровне всей системы, а не зависит от поддержки прокси в отдельных приложениях.',
      );
  String get faqLogsQuestion => _text(
        en: 'Where should I look when something breaks?',
        ru: 'Где смотреть, если что-то сломалось?',
      );
  String get faqLogsAnswer => _text(
        en: 'Open Logs in Settings. Connection, ping, geodata, helper, and tunnel recovery events are recorded there for troubleshooting.',
        ru: 'Откройте Логи в Настройках. Там сохраняются события подключения, пинга, геоданных, работы хелпера и восстановления туннеля для диагностики.',
      );
  String get faqDeveloperQuestion => _text(
        en: 'How do I unlock Pro tools?',
        ru: 'Как разблокировать Pro инструменты?',
      );
  String get faqDeveloperAnswer => _text(
        en: 'Tap the Settings title seven times. Pro mode stays hidden until you deliberately unlock it.',
        ru: 'Нажмите на заголовок Настройки семь раз. Pro режим остаётся скрытым, пока вы не разблокируете его вручную.',
      );
  String get aboutSummary => _text(
        en: 'VarPN stores subscriptions, routing presets, logs, traffic statistics, and utun helper state locally on this Mac for a fast private workflow.',
        ru: 'VarPN хранит подписки, пресеты роутинга, логи, статистику трафика и состояние utun-хелпера локально на этом Mac для быстрого и приватного рабочего процесса.',
      );
  String get aboutVersionLabel => _text(en: 'Version', ru: 'Версия');
  String get aboutRuntimeLabel =>
      _text(en: 'Connection mode', ru: 'Режим подключения');
  String get aboutStorageLabel =>
      _text(en: 'Data storage', ru: 'Хранение данных');
  String get aboutStorageValue =>
      _text(en: 'Local only', ru: 'Только локально');
  String get proxyModeLabel =>
      _text(en: 'Background utun helper', ru: 'Фоновый utun-хелпер');
  String get aboutDeveloperToolsLabel =>
      _text(en: 'Pro tools', ru: 'Pro инструменты');
  String get hiddenLabel => _text(en: 'Hidden', ru: 'Скрыты');
  String get unlockedLabel => _text(en: 'Unlocked', ru: 'Разблокированы');
  String get resetAppTitle =>
      _text(en: 'Reset app data?', ru: 'Сбросить данные приложения?');
  String get resetAppMessage => _text(
        en: 'This will disconnect VarPN, remove the saved subscription, clear logs, reset routing, ping, and Xray settings, and wipe local traffic statistics on this Mac.',
        ru: 'Это отключит VarPN, удалит сохранённую подписку, очистит логи, сбросит настройки роутинга, пинга и Xray, а также удалит локальную статистику трафика на этом Mac.',
      );
  String get resetAppAction =>
      _text(en: 'Reset app', ru: 'Сбросить приложение');
  String get resetCompleted =>
      _text(en: 'VarPN was reset', ru: 'VarPN сброшен');

  String languageName(String code) {
    switch (code.toLowerCase()) {
      case 'en':
        return _text(en: 'English', ru: 'Английский');
      case 'ru':
      default:
        return _text(en: 'Russian', ru: 'Русский');
    }
  }

  String themeName(String code) {
    switch (code.toLowerCase()) {
      case 'light':
        return _text(en: 'Light', ru: 'Светлая');
      case 'dark':
        return _text(en: 'Dark', ru: 'Тёмная');
      case 'system':
      default:
        return _text(en: 'System', ru: 'Система');
    }
  }

  String routingPresetName(String name) {
    if (name.toLowerCase() == 'custom') {
      return _text(en: 'Custom', ru: 'Свои');
    }
    return name;
  }

  String lastUpdatedLabel(String value) {
    return _text(
      en: 'Last updated: $value',
      ru: 'Последнее обновление: $value',
    );
  }

  String enabledSourcesLabel(int enabled, int total) {
    return _text(
      en: '$enabled of $total enabled',
      ru: 'Включено: $enabled из $total',
    );
  }

  String loadedConnections(int count) {
    return _text(
      en: 'Connections loaded: $count',
      ru: 'Загружено подключений: $count',
    );
  }

  String importFailed(Object error) {
    return _text(
      en: 'Could not import subscription: $error',
      ru: 'Не удалось импортировать подписку: $error',
    );
  }

  String refreshFailed(Object error) {
    return _text(
      en: 'Could not refresh geodata: $error',
      ru: 'Не удалось обновить геоданные: $error',
    );
  }

  String refreshSubscriptionsFailed(Object error) {
    return _text(
      en: 'Could not refresh subscriptions: $error',
      ru: 'Не удалось обновить подписки: $error',
    );
  }

  String get subscriptionsUpdated => _text(
        en: 'Subscriptions updated',
        ru: 'Подписки обновлены',
      );

  String get noSubscriptionsToUpdate => _text(
        en: 'No enabled subscriptions to update',
        ru: 'Нет включённых подписок для обновления',
      );

  String routingMessage(String? countryCode) {
    if (countryCode == null) {
      return '';
    }

    final enMessages = <String, String>{
      'RU': 'Optimized for Russia, local apps stay direct',
      'CN': 'Optimized for China, local apps stay direct',
      'IR': 'Optimized for Iran, local apps stay direct',
    };
    final ruMessages = <String, String>{
      'RU':
          'Оптимизировано для России - локальные приложения работают напрямую',
      'CN': 'Оптимизировано для Китая - локальные приложения работают напрямую',
      'IR': 'Оптимизировано для Ирана - локальные приложения работают напрямую',
    };

    return (_isEnglish ? enMessages : ruMessages)[countryCode] ?? '';
  }

  String countryName(String code) {
    const enNames = <String, String>{
      'RU': 'Russia',
      'DE': 'Germany',
      'US': 'USA',
      'GB': 'United Kingdom',
      'FR': 'France',
      'FI': 'Finland',
      'NL': 'Netherlands',
      'SE': 'Sweden',
      'LV': 'Latvia',
      'AT': 'Austria',
      'CH': 'Switzerland',
      'SG': 'Singapore',
      'JP': 'Japan',
      'XX': 'Other',
    };
    const ruNames = <String, String>{
      'RU': 'Россия',
      'DE': 'Германия',
      'US': 'США',
      'GB': 'Великобритания',
      'FR': 'Франция',
      'FI': 'Финляндия',
      'NL': 'Нидерланды',
      'SE': 'Швеция',
      'LV': 'Латвия',
      'AT': 'Австрия',
      'CH': 'Швейцария',
      'SG': 'Сингапур',
      'JP': 'Япония',
      'XX': 'Другие',
    };

    return (_isEnglish ? enNames : ruNames)[code] ??
        _text(en: 'Other', ru: 'Другие');
  }

  String _text({
    required String en,
    required String ru,
  }) {
    return _isEnglish ? en : ru;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
