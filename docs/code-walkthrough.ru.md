# Подробный разбор кода Movie Recommender

Снимок исходников: 16 октября 2026 года. Этот документ объясняет текущую локальную версию проекта, включая незакоммиченные изменения. В нём приведены исходники 89 файлов и объяснения 510 значимых конструкций и блоков. Это чтение кода, а не отчёт об успешном запуске тестов или внешнего API.

В проекте смешаны стандартные заготовки Rails, доработанная авторизация, интеграция TMDB и интерфейс будущих функций. Их происхождение и степень готовности различаются. Приведённые ниже существующие файлы не следует путать с предлагаемыми будущими моделями: Room, Movie, Rating и запуск подбора пока не реализованы.

## Как читать

Сначала прочитай словарь и цепочки запросов. Затем двигайся по оглавлению. В каждом разделе есть назначение файла, полный исходник на дату снимка и объяснения значимых строк с переходом к их месту в проекте. Повторяющиеся HTML-теги и CSS-классы объяснены один раз в словаре; отдельно разобрано, как они работают в конкретном компоненте. Английские комментарии генератора — пояснения, не выполняемые команды.

Копии исходников в этом документе не обновляются автоматически при дальнейшем редактировании приложения. Ссылки ведут к рабочим файлам, а кодовые блоки сохраняют снимок.

## Что уже работает и что пока является интерфейсом

| Часть | Фактическое поведение кода |
|---|---|
| Регистрация, вход и выход | Обрабатывают пользователя, Session и подписанную cookie |
| Сброс пароля | Проверяет токен и меняет пароль; фактическая доставка письма зависит от почтовых настроек и очереди |
| Каталог и страница фильма | Загружают данные из TMDB при корректном токене и доступной сети |
| Личный кабинет | Показывает пользователя; показатели 0/— пока статические |
| Выбор оценки | Меняет подпись в браузере; не сохраняет оценку |
| Создание комнаты и приглашение | Проверяют HTML-поля и показывают сообщение о недоступности |
| Переход к подбору | Открывает отдельный экран и сохраняет адрес возврата |
| Опрос, рекомендации, участники | Логика и постоянные записи пока отсутствуют |
| Action Cable | Есть основа авторизации соединения; канала комнаты и синхронизации ещё нет |
| PWA и push | Маршруты/подключение выключены, service worker содержит комментарии |

## Словарь Ruby и Rails

| Конструкция | Значение в этом проекте |
|---|---|
| `class User < ApplicationRecord` | Объявление класса с наследованием |
| `module Authentication` | Группировка повторно используемых методов; module Tmdb также служит пространством имён |
| `include` / `extend` | Подключение методов экземплярам класса / самому объекту или классу |
| `def … end` | Объявление метода |
| `do \|value\| … end` | Блок, переданный методу; value — параметр блока |
| `{ … }` | Либо хеш, либо короткий блок: смысл зависит от позиции |
| `:nickname` | Символ — имя атрибута/действия/ключа, не значение ника |
| `nickname: value` | Ключ-символ хеша или именованный аргумент |
| `"title" => value` | Явная форма пары хеша со строковым ключом |
| `@user` | Переменная экземпляра контроллера; Rails предоставляет её представлению запроса |
| `user` | Локальная переменная внутри метода или блока |
| `Current.user` | Метод контекста текущего выполнения; не глобальный пользователь сервера |
| `params` | Параметры текущего HTTP-запроса в контроллере. Аргумент params в сервисе — отдельный обычный локальный хеш |
| `nil` | Отсутствие значения |
| `if`, `elsif`, `else` | Выбор ветки выполнения |
| `unless condition` | Выполнить при ложном условии |
| `a || b` | Вернуть a, если он не nil/false; иначе вычислить b |
| `a && b` | Вычислить b, только если a истинно |
| `a ||= b` | Присвоить b, если a nil/false |
| `condition ? a : b` | Короткая форма выбора двух вариантов |
| `->(x) { … }` | Лямбда — вызываемый объект с кодом |
| `#{value}` | Подстановка в строку с двойными кавычками |
| `&.` | Вызвать метод, если получатель не nil |
| `*ARGV`, `**options` | Разворачивание позиционных / именованных аргументов |
| `private` | Следующие методы — внутренние помощники, не публичные действия |
| `raise` / `rescue` | Создать исключение / обработать исключение |
| `=> error` в rescue | Сохранить перехваченное исключение в переменную |
| Последняя строка метода | По умолчанию становится возвращаемым результатом |
| `?` в конце имени | Соглашение для проверки; не гарантирует буквальный Boolean, например authenticated? возвращает Session/nil |
| `!` в конце имени | Часть имени метода; часто строгий вариант, например create! бросает исключение при неуспехе |
| `present?` / `blank?` | Проверки непустоты/пустоты Rails, учитывающие nil и пустые строки/коллекции |
| `presence` | Само значение, если present?, иначе nil |
| `new` / `save` / `create!` | Объект в памяти / проверка и сохранение / создание с исключением при неудаче |
| `render` | Создать ответ из шаблона в текущем запросе |
| `redirect_to` | Вернуть браузеру инструкцию сделать новый запрос |
| `*_path` / `*_url` | Путь / полный URL, созданные helpers маршрутов |
| Модель / миграция / схема | Поведение данных / история изменений структуры / снимок текущей структуры |

## Словарь ERB, HTML и Tailwind

`<% code %>` выполняет Ruby без вставки результата. `<%= code %>` вставляет результат в HTML с обычным экранированием. `<%# comment %>` не выполняется. Частичный шаблон начинается с подчёркивания; `render "movie_card", movie: movie` передаёт ему локальную переменную. `yield` в layout — место для содержимого страницы; `content_for` заполняет именованную область, например title.

`main`, `header`, `nav`, `section`, `article`, `aside`, `fieldset`, `legend` описывают смысл частей документа. `div` и `span` — нейтральные контейнеры. Ссылка `a` выполняет переход; кнопка может отправлять форму или вызывать JS. `required`, `maxlength`, `readonly`, `disabled`, `hidden` — реальные HTML-атрибуты с поведением браузера, не слова для украшения. Ограничения формы проверяются и на сервере, когда появится реальное сохранение.

`aria-label` задаёт доступное имя, `aria-labelledby` ссылается на заголовок, `aria-describedby` — на пояснение, `aria-expanded` сообщает открытое состояние, `aria-invalid` — ошибку поля, `aria-live` — обновляемый текст. Эти атрибуты помогают вспомогательным технологиям; они не создают серверных проверок и не открывают окна сами.

| Семейство классов | Как читать |
|---|---|
| `flex`, `grid`, `block`, `inline-flex`, `hidden` | Тип раскладки/отображения |
| `flex-col`, `flex-wrap`, `grid-cols-2` | Направление, перенос, число колонок |
| `items-center`, `items-start`, `justify-between`, `place-items-center` | Выравнивание внутри flex/grid |
| `gap-*`, `space-y-*` | Расстояния между элементами |
| `p-*`, `px-*`, `py-*`, `pt-*`, `pb-*` | Внутренние отступы; x — горизонтально, y — вертикально |
| `m-*`, `mt-*`, `mb-*`, `mx-auto` | Внешние отступы; auto помогает центрировать ограниченный по ширине блок |
| `w-full`, `max-w-*`, `min-w-0`, `min-h-*`, `size-*` | Размеры; size задаёт сразу ширину и высоту |
| `min-w-0` | Разрешает flex/grid-элементу сжиматься при длинном содержимом |
| `bg-*`, `text-ink*`, `border-line*` | Фон, цвет текста, цвет рамки из темы |
| `text-sm`, `text-3xl`, `font-semibold`, `leading-*`, `tracking-*` | Размер, насыщенность, межстрочный и межбуквенный интервал |
| `border`, `border-t`, `border-dashed`, `rounded-*`, `shadow-*` | Рамка, верхняя рамка, пунктир, скругление, тень |
| `overflow-hidden`, `overflow-y-auto` | Обрезка или прокрутка |
| `truncate`, `break-words`, `line-clamp-*` | Обрезка многоточием, перенос длинных слов, ограничение числа строк |
| `aspect-[2/3]`, `object-cover` | Пропорция изображения и заполнение области |
| `relative`, `absolute`, `top-full`, `z-50` | Позиционирование панели и порядок наложения |
| `sm:`, `md:`, `lg:`, `xl:` | Применить правило начиная с соответствующей минимальной ширины; базовое правило действует и на узком экране |
| `hover:`, `focus:`, `focus-visible:` | Правило при наведении, фокусе и выделяемом клавиатурном фокусе |
| `disabled:`, `aria-invalid:`, `aria-expanded:` | Правило при состоянии/атрибуте элемента |
| `peer-checked:` | Зависимость от выбранного соседнего поля с class=peer |
| `group-hover:` | Зависимость от наведения на предка с class=group |
| `sr-only` | Визуально скрыть, сохранив доступность для чтения/фокуса по назначению |
| `transition`, `motion-safe:`, `motion-reduce:` | Переходы с учётом настройки уменьшенного движения |
| `bg-brand-soft/50` | Цвет с долей непрозрачности |
| `[...]` | Явное CSS-значение, например произвольные колонки сетки; подчёркивания внутри часто обозначают пробелы |

Числа обычных отступов/размеров читаются по шкале Tailwind, а не автоматически как пиксели. Повторяющиеся классы на десятках строк не являются десятками независимых алгоритмов: это декларация оформления.

## Словарь JavaScript и Stimulus

`import` подключает модуль, `export` делает значение доступным другим модулям. `extends Controller` наследует возможности Stimulus. `this.element` — DOM-элемент контроллера. `static targets = ["panel"]` создаёт доступ к `data-имя-target="panel"` через `this.panelTarget`; множественное `panelTargets` — массив, `hasPanelTarget` — проверка наличия. `static values` объявляет типизированные настройки из data-атрибутов.

`data-controller="rating pending-action"` подключает два класса к одному элементу. `data-action="change->rating#select"` связывает событие с методом. `@document` и `@window` направляют слушатель на весь документ/окно. `connect` и `disconnect` вызываются жизненным циклом Stimulus.

`event.target` — исходный элемент события, `event.currentTarget` — элемент текущего обработчика. `preventDefault` отменяет стандартное действие, `stopPropagation` останавливает дальнейшее распространение события. `textContent` задаёт обычный текст; `hidden` управляет видимостью. Строки между обратными кавычками используют `${value}` для подстановки. `const` запрещает переприсвоение переменной, `=>` создаёт функцию, `?.` безопасно обращается к отсутствующему значению. `return` немедленно завершает метод.

## Пять сквозных цепочек

1. **Регистрация.** GET формы → User.new в памяти → ERB form_with → POST user[...] → permit → нормализация и валидации User → INSERT → Session → подписанная cookie → redirect. При ошибке save возвращает false → render той же формы с тем же @user и errors.
2. **Защищённая страница.** before_action → чтение подписанной cookie → поиск Session → Current.session/Current.user → действие и шаблон. Без входа запоминается исходный адрес и выполняется redirect ко входу.
3. **Поиск.** GET /movies?query=... → index → MovieSearch.search → URI/HTTPS/Bearer → JSON.parse → @movies → each/render partial → HTML. Отдельным запросом браузер загружает постер по URL. При неудаче сервиса выполняется rescue и шаблон показывает сообщение.
4. **Выбор оценки.** radio change → rating#select → подпись N / 10. Submit → pending-action#submit → preventDefault → проверка полей → сообщение о недоступности. INSERT/UPDATE и серверного маршрута сохранения здесь нет.
5. **Переход к подбору комнаты.** show вычисляет destination → общая GET-форма отправляет пожелания в selection → selection вычисляет @room_path → две ссылки возвращают к исходному адресу. Серверного запуска, сохранения ответов и рассылки участникам пока нет.

## Оглавление файлов

- [1. Маршруты: какой запрос вызывает какой код](#file-001) — `config/routes.rb`
- [2. Общий контроллер](#file-002) — `app/controllers/application_controller.rb`
- [3. Общая модель Active Record](#file-003) — `app/models/application_record.rb`
- [4. Пользователь: пароль, связи, нормализация и проверки](#file-004) — `app/models/user.rb`
- [5. Запись входа в базу](#file-005) — `app/models/session.rb`
- [6. Текущий пользователь в рамках запроса](#file-006) — `app/models/current.rb`
- [7. Весь механизм авторизации](#file-007) — `app/controllers/concerns/authentication.rb`
- [8. Регистрация: обработка успешной и ошибочной формы](#file-008) — `app/controllers/registrations_controller.rb`
- [9. Вход и выход](#file-009) — `app/controllers/sessions_controller.rb`
- [10. Восстановление пароля](#file-010) — `app/controllers/passwords_controller.rb`
- [11. Личный кабинет](#file-011) — `app/controllers/profiles_controller.rb`
- [12. Поиск, популярные фильмы и подробности](#file-012) — `app/controllers/movies_controller.rb`
- [13. Клиент TMDB: подробный разбор каждой операции](#file-013) — `app/services/tmdb/movie_search.rb`
- [14. Контроллер экранов комнаты](#file-014) — `app/controllers/rooms_controller.rb`
- [15. Страница оценок](#file-015) — `app/controllers/ratings_controller.rb`
- [16. Страница персонального подбора](#file-016) — `app/controllers/recommendations_controller.rb`
- [17. Оболочка всех HTML-страниц](#file-017) — `app/views/layouts/application.html.erb`
- [18. Общая шапка и выход](#file-018) — `app/views/shared/_header.html.erb`
- [19. Сообщения после действий](#file-019) — `app/views/shared/_flash.html.erb`
- [20. Форма регистрации](#file-020) — `app/views/registrations/new.html.erb`
- [21. Форма входа](#file-021) — `app/views/sessions/new.html.erb`
- [22. Запрос письма восстановления](#file-022) — `app/views/passwords/new.html.erb`
- [23. Ввод нового пароля](#file-023) — `app/views/passwords/edit.html.erb`
- [24. Личный кабинет: реальные ссылки и статические показатели](#file-024) — `app/views/profiles/show.html.erb`
- [25. Каталог: форма, ошибка, пустой результат и карточки](#file-025) — `app/views/movies/index.html.erb`
- [26. Одна карточка фильма](#file-026) — `app/views/movies/_movie_card.html.erb`
- [27. Подробная страница фильма](#file-027) — `app/views/movies/show.html.erb`
- [28. Шкала личной оценки и два обработчика на одной форме](#file-028) — `app/views/movies/_rating_form.html.erb`
- [29. Указание источника данных](#file-029) — `app/views/movies/_tmdb_attribution.html.erb`
- [30. Список комнат: пока только пустое состояние](#file-030) — `app/views/rooms/index.html.erb`
- [31. Форма создания комнаты](#file-031) — `app/views/rooms/new.html.erb`
- [32. Комната: компоновка и переход к подбору](#file-032) — `app/views/rooms/show.html.erb`
- [33. Отдельный экран подбора и возврат](#file-033) — `app/views/rooms/selection.html.erb`
- [34. Модальное окно приглашения](#file-034) — `app/views/rooms/_invitation.html.erb`
- [35. Экран личных оценок](#file-035) — `app/views/ratings/index.html.erb`
- [36. Экран персонального подбора](#file-036) — `app/views/recommendations/show.html.erb`
- [37. Общая форма в двух режимах](#file-037) — `app/views/shared/_recommendation_form.html.erb`
- [38. Немодальная панель уведомлений](#file-038) — `app/views/shared/_notifications.html.erb`
- [39. Точка входа JavaScript](#file-039) — `app/javascript/application.js`
- [40. Запуск Stimulus](#file-040) — `app/javascript/controllers/application.js`
- [41. Автоматическая регистрация контроллеров](#file-041) — `app/javascript/controllers/index.js`
- [42. Обновление подписи выбранной оценки](#file-042) — `app/javascript/controllers/rating_controller.js`
- [43. Обработчик всех временных форм](#file-043) — `app/javascript/controllers/pending_action_controller.js`
- [44. Открытие и закрытие модального приглашения](#file-044) — `app/javascript/controllers/dialog_controller.js`
- [45. Позиционирование и доступность уведомлений](#file-045) — `app/javascript/controllers/notifications_controller.js`
- [46. Оставшийся учебный контроллер генератора](#file-046) — `app/javascript/controllers/hello_controller.js`
- [47. Общие кнопки, поля и SVG-иконки](#file-047) — `app/helpers/application_helper.rb`
- [48. Тема Tailwind](#file-048) — `app/assets/tailwind/application.css`
- [49. Прежняя точка CSS](#file-049) — `app/assets/stylesheets/application.css`
- [50. Как браузер находит JavaScript-модули](#file-050) — `config/importmap.rb`
- [51. Почему запуск через ruby bin/dev](#file-051) — `bin/dev`
- [52. Описание двух процессов разработки](#file-052) — `Procfile.dev`
- [53. Зависимости приложения](#file-053) — `Gemfile`
- [54. Какие файлы не должны попадать в Git](#file-054) — `.gitignore`
- [55. Миграция создания пользователей](#file-055) — `db/migrate/20260925111546_create_users.rb`
- [56. Миграция сессий входа](#file-056) — `db/migrate/20260925111549_create_sessions.rb`
- [57. Добавление обязательного уникального никнейма](#file-057) — `db/migrate/20261003000000_add_nickname_to_users.rb`
- [58. Снимок текущей структуры основной базы](#file-058) — `db/schema.rb`
- [59. Подключение SQLite и разделение окружений](#file-059) — `config/database.yml`
- [60. Авторизация соединения Action Cable](#file-060) — `app/channels/application_cable/connection.rb`
- [61. Адаптеры обмена Cable](#file-061) — `config/cable.yml`
- [62. Общая основа писем](#file-062) — `app/mailers/application_mailer.rb`
- [63. Формирование письма восстановления](#file-063) — `app/mailers/passwords_mailer.rb`
- [64. HTML-версия письма](#file-064) — `app/views/passwords_mailer/reset.html.erb`
- [65. Текстовая версия письма](#file-065) — `app/views/passwords_mailer/reset.text.erb`
- [66. HTML-оболочка почты](#file-066) — `app/views/layouts/mailer.html.erb`
- [67. Текстовая оболочка почты](#file-067) — `app/views/layouts/mailer.text.erb`
- [68. Базовый класс фоновых задач](#file-068) — `app/jobs/application_job.rb`
- [69. Параметры Solid Queue](#file-069) — `config/queue.yml`
- [70. Параметры Solid Cache](#file-070) — `config/cache.yml`
- [71. Общая подготовка тестов](#file-071) — `test/test_helper.rb`
- [72. Тестовые пользователи и текущая несовместимость](#file-072) — `test/fixtures/users.yml`
- [73. Как тесты имитируют вход](#file-073) — `test/test_helpers/session_test_helper.rb`
- [74. Проверки правил пользователя](#file-074) — `test/models/user_test.rb`
- [75. Интеграционные тесты регистрации](#file-075) — `test/controllers/registrations_controller_test.rb`
- [76. Тесты входа и выхода](#file-076) — `test/controllers/sessions_controller_test.rb`
- [77. Тесты восстановления пароля](#file-077) — `test/controllers/passwords_controller_test.rb`
- [78. Предпросмотр письма](#file-078) — `test/mailers/previews/passwords_mailer_preview.rb`
- [79. Фильтрация чувствительных параметров в логах](#file-079) — `config/initializers/filter_parameter_logging.rb`
- [80. Первый этап запуска Ruby-зависимостей](#file-080) — `config/boot.rb`
- [81. Создание приложения Rails](#file-081) — `config/application.rb`
- [82. Инициализация окружения](#file-082) — `config/environment.rb`
- [83. Вход в команды Rails](#file-083) — `bin/rails`
- [84. Последовательность локальных проверок](#file-084) — `config/ci.rb`
- [85. Проверки на GitHub](#file-085) — `.github/workflows/ci.yml`
- [86. Манифест устанавливаемого приложения](#file-086) — `app/views/pwa/manifest.json.erb`
- [87. Закомментированный пример push-обработчика](#file-087) — `app/views/pwa/service-worker.js`
- [88. Начальные данные](#file-088) — `db/seeds.rb`
- [89. Инструкция запуска и описание текущей готовности](#file-089) — `README.md`

<a id="file-001"></a>

## 1. Маршруты: какой запрос вызывает какой код

[Открыть config/routes.rb](C:/Ruby/movie_recommender/config/routes.rb)

Точка входа для браузерных запросов. Маршрутизатор учитывает одновременно HTTP-метод и путь; он не создаёт таблицы, объекты или бизнес-логику.

~~~~ruby
Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: [ :new, :create ]
  resource :profile, only: :show
  resources :movies, only: [ :index, :show ], param: :tmdb_id, constraints: { tmdb_id: /\d+/ }
  resources :rooms, only: [ :index, :new, :show ] do
    get :selection, on: :member
  end
  get "room", to: "rooms#show", as: :current_room
  get "room/selection", to: "rooms#selection", as: :current_room_selection
  resources :ratings, only: :index
  resource :recommendations, only: :show
  root "profiles#show"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/config/routes.rb:1) — `Rails.application.routes.draw do`. Открывает блок объявления маршрутов приложения. Внутри используются методы Rails: resource, resources, get, root. do/end ограничивают блок.

- [Строка 2](C:/Ruby/movie_recommender/config/routes.rb:2) — `resource :session`. Объявляет маршруты единственного логического ресурса без :id в адресе. Нужные реализованные действия — GET /session/new, POST /session и DELETE /session. Объявление без only также создаёт маршруты к стандартным действиям, которых в контроллере сейчас нет; наличие маршрута ещё не гарантирует работающий обработчик.

- [Строка 3](C:/Ruby/movie_recommender/config/routes.rb:3) — `resources :passwords, param: :token`. Создаёт маршруты восстановления пароля. В сегменте, который обычно назывался бы :id, используется :token: контроллер читает params[:token]. Это не таблица с паролями и не передача самого пароля в URL.

- [Строка 4](C:/Ruby/movie_recommender/config/routes.rb:4) — `resource :registration`. only ограничивает набор действий: new показывает форму, create принимает её. registration_path — адрес отправки, new_registration_path — адрес открытия формы. Символ :new обозначает имя действия, а не строку текста.

- [Строка 5](C:/Ruby/movie_recommender/config/routes.rb:5) — `resource :profile`. GET /profile показывает текущего пользователя без его ID в URL. root ниже ведёт в то же действие по адресу /.

- [Строка 6](C:/Ruby/movie_recommender/config/routes.rb:6) — `resources :movies`. Коллекция фильмов: GET /movies → index, GET /movies/:tmdb_id → show. only исключает создание и изменение фильмов. constraints с регулярным выражением /\d+/ ограничивает сегмент цифрами; param меняет имя параметра. movie_path(42) строит /movies/42. Для каждого фильма отдельный шаблон и отдельное объявление маршрута не требуются.

- [Строка 7](C:/Ruby/movie_recommender/config/routes.rb:7) — `resources :rooms`. Сейчас есть index, new и show, но нет create. get :selection, on: :member добавляет GET /rooms/:id/selection для одного элемента коллекции. Это переход к экрану, а не сохранение запуска подбора.

- [Строка 10](C:/Ruby/movie_recommender/config/routes.rb:10) — `get "room",`. Отдельный GET /room ведёт в тот же show без :id. as создаёт helper current_room_path. Название current_room пока условное: контроллер не ищет текущую комнату в базе.

- [Строка 11](C:/Ruby/movie_recommender/config/routes.rb:11) — `get "room/selection"`. Аналогичный экран подбора без ID. current_room_selection_path возвращает /room/selection.

- [Строка 12](C:/Ruby/movie_recommender/config/routes.rb:12) — `resources :ratings`. Только страница GET /ratings. POST-маршрута для сохранения оценки пока нет.

- [Строка 13](C:/Ruby/movie_recommender/config/routes.rb:13) — `resource :recommendations`. GET /recommendations → RecommendationsController#show. Английское имя во множественном числе не меняет того, что resource объявляет один логический ресурс без ID.

- [Строка 14](C:/Ruby/movie_recommender/config/routes.rb:14) — `root "profiles#show"`. Корневой адрес / направляется в ProfilesController#show. Запись controller#action обозначает контроллер и его публичный метод.

- [Строка 19](C:/Ruby/movie_recommender/config/routes.rb:19) — `get "up"`. Служебная проверка запуска Rails. Ответ об успешном старте не проверяет работу TMDB и будущего алгоритма рекомендаций. Закомментированные PWA-маршруты ниже не выполняются.


<a id="file-002"></a>

## 2. Общий контроллер

[Открыть app/controllers/application_controller.rb](C:/Ruby/movie_recommender/app/controllers/application_controller.rb)

Базовый класс остальных контроллеров; общие правила наследуются всеми страницами.

~~~~ruby
class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/controllers/application_controller.rb:1) — `class ApplicationController`. Символ < означает наследование. ActionController::Base предоставляет params, cookies, render, redirect_to и обработку HTTP-запроса.

- [Строка 2](C:/Ruby/movie_recommender/app/controllers/application_controller.rb:2) — `include Authentication`. Подключает общий модуль входа. Благодаря его before_action страницы закрыты для гостей, пока конкретный контроллер не разрешит исключение.

- [Строка 4](C:/Ruby/movie_recommender/app/controllers/application_controller.rb:4) — `allow_browser versions: :modern`. Включает проверку браузеров по набору возможностей/версий, заданному Rails. Это ограничение совместимости интерфейса, а не механизм определения пользователя.

- [Строка 7](C:/Ruby/movie_recommender/app/controllers/application_controller.rb:7) — `stale_when_importmap_changes`. Учитывает изменение importmap при проверке актуальности HTML-ответа через ETag. Нужно, чтобы обновление карты JavaScript не оставило клиенту устаревшую страницу.


<a id="file-003"></a>

## 3. Общая модель Active Record

[Открыть app/models/application_record.rb](C:/Ruby/movie_recommender/app/models/application_record.rb)

Базовый класс моделей базы данных.

~~~~ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/models/application_record.rb:1) — `class ApplicationRecord`. Наследование от ActiveRecord::Base даёт модели запросы find_by, связи, валидации и сохранение.

- [Строка 2](C:/Ruby/movie_recommender/app/models/application_record.rb:2) — `primary_abstract_class`. Помечает класс общей абстрактной основой. Для ApplicationRecord не нужна отдельная таблица application_records; User и Session используют свои таблицы.


<a id="file-004"></a>

## 4. Пользователь: пароль, связи, нормализация и проверки

[Открыть app/models/user.rb](C:/Ruby/movie_recommender/app/models/user.rb)

Модель описывает правила данных пользователя. Она используется и регистрацией, и входом, и сбросом пароля.

~~~~ruby
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :nickname, with: ->(nickname) { nickname.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :nickname, presence: true, uniqueness: true
  validates :password, presence: true, confirmation: true, length: { minimum: 8 }, on: :create
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/models/user.rb:2) — `has_secure_password`. Подключает стандартный механизм Rails с BCrypt. Присваивание password формирует password_digest; исходный пароль не является колонкой базы. Появляются проверка authenticate, поддержка подтверждения и токенов сброса. authenticate_by, вызываемый контроллером, — метод Active Record, работающий с этим механизмом.

- [Строка 3](C:/Ruby/movie_recommender/app/models/user.rb:3) — `has_many :sessions`. У пользователя может быть несколько записей входа. user.sessions возвращает связанную коллекцию; create! в ней сам подставит user_id. dependent: :destroy удаляет связанные записи при уничтожении пользователя через Active Record.

- [Строка 5](C:/Ruby/movie_recommender/app/models/user.rb:5) — `normalizes :email_address`. Лямбда ->(e) { ... } принимает значение, strip удаляет пробелы по краям, downcase приводит к нижнему регистру. Нормализация делает варианты ' USER@EXAMPLE.COM ' и 'user@example.com' одним значением для обычных операций модели.

- [Строка 6](C:/Ruby/movie_recommender/app/models/user.rb:6) — `normalizes :nickname`. Ник тоже очищается и переводится в нижний регистр. Поэтому исходное написание с заглавными буквами не сохраняется. Ограничений на допустимые символы и длину ника в этой модели пока нет.

- [Строка 8](C:/Ruby/movie_recommender/app/models/user.rb:8) — `validates :email_address`. presence запрещает пустое значение, uniqueness ищет существующее, format проверяет соответствие регулярному выражению. Формат не доказывает существование адреса или принадлежность пользователю. Уникальный индекс базы отдельно защищает от одновременных конфликтующих записей.

- [Строка 9](C:/Ruby/movie_recommender/app/models/user.rb:9) — `validates :nickname`. Ник обязателен и должен быть уникальным. Это правила модели, а NOT NULL и уникальный индекс в миграции — правила самой базы.

- [Строка 10](C:/Ruby/movie_recommender/app/models/user.rb:10) — `validates :password`. presence, confirmation и минимум 8 применяются здесь с on: :create. Поэтому именно пользовательское правило минимальной длины не работает на обновление пароля. Базовые проверки has_secure_password остаются отдельным механизмом. confirmation сравнивает переданное подтверждение; в совокупности с HTML required это не означает, что модель отдельно требует непустой password_confirmation при любом программном вызове.

- [Строка 10](C:/Ruby/movie_recommender/app/models/user.rb:10) — `on: :create`. Важное фактическое ограничение: при сбросе пароля обновляется существующий User, и новый пароль короче 8 символов этим правилом не отклоняется. Это подтверждается и намерением старого теста, который обновляет пароль на 'new'. Это описание текущего поведения, а не рекомендуемая политика.


<a id="file-005"></a>

## 5. Запись входа в базу

[Открыть app/models/session.rb](C:/Ruby/movie_recommender/app/models/session.rb)

Отдельная сессия авторизации пользователя. Не связана с будущим запуском совместного подбора.

~~~~ruby
class Session < ApplicationRecord
  belongs_to :user
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/models/session.rb:2) — `belongs_to :user`. Каждая Session ссылается на одного User через user_id. session.user возвращает владельца; user.sessions — обратная связь. Существование пользователя дополнительно обеспечивается внешним ключом базы.


<a id="file-006"></a>

## 6. Текущий пользователь в рамках запроса

[Открыть app/models/current.rb](C:/Ruby/movie_recommender/app/models/current.rb)

Удобный доступ к контексту текущего запроса без передачи пользователя через каждый метод.

~~~~ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/models/current.rb:1) — `ActiveSupport::CurrentAttributes`. Rails предоставляет изолированный контекст текущего выполнения и сбрасывает его в жизненном цикле запроса. Это не общая переменная одного пользователя для всего сервера.

- [Строка 2](C:/Ruby/movie_recommender/app/models/current.rb:2) — `attribute :session`. Объявляет Current.session. Значение устанавливает Authentication после поиска сессии.

- [Строка 3](C:/Ruby/movie_recommender/app/models/current.rb:3) — `delegate :user`. Перенаправляет Current.user к Current.session.user. allow_nil: true возвращает nil, если сессии нет, вместо ошибки вызова user у nil.


<a id="file-007"></a>

## 7. Весь механизм авторизации

[Открыть app/controllers/concerns/authentication.rb](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb)

Общий модуль: проверка входа, восстановление пользователя по cookie, создание и удаление сессии.

~~~~ruby
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:2) — `extend ActiveSupport::Concern`. Добавляет средства Rails для подключения модуля: included и class_methods. extend добавляет методы самому модулю; include Authentication затем добавляет его поведение контроллеру.

- [Строка 4](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:4) — `included do`. Блок выполняется в классе, который подключил модуль. before_action ставит проверку перед действиями контроллера; helper_method делает authenticated? доступным в представлениях.

- [Строка 9](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:9) — `class_methods do`. Внутри объявляются методы уровня класса контроллера. Поэтому allow_unauthenticated_access можно писать рядом с def, вне тела действия.

- [Строка 10](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:10) — `def allow_unauthenticated_access`. **options собирает именованные параметры, например only: [:new, :create], и передаёт их skip_before_action. Метод отменяет проверку только в выбранной области.

- [Строка 15](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:15) — `private`. Последующие вспомогательные методы не становятся публичными действиями контроллера.

- [Строка 16](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:16) — `def authenticated?`. Возвращает результат resume_session: объект Session или nil, а не обязательно буквальные true/false. В условиях Ruby объект считается истинным.

- [Строка 21](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:21) — `resume_session || request_authentication`. Короткое замыкание: если сессия найдена, правая часть не выполняется. Если нет — сохраняется адрес и выполняется перенаправление ко входу.

- [Строка 25](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:25) — `Current.session ||=`. Мемоизация в рамках текущего контекста: если сессия уже загружена, повторный поиск не нужен. Если значение nil, вызывается find_session_by_cookie.

- [Строка 29](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:29) — `Session.find_by(id: cookies.signed`. Читает подписанную cookie и ищет запись в базе по ID. Подпись позволяет обнаружить подмену значения; это не шифрование. Нет cookie или записи — нет восстановленного входа. Cookie сама не содержит пароль.

- [Строка 33](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:33) — `session[:return_to_after_authenticating]`. Здесь session — встроенное хранилище Rails для данных между запросами; оно отличается от модели Session и Current.session. Сохраняется URL, который гость пытался открыть.

- [Строка 38](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:38) — `session.delete(:return_to_after_authenticating)`. delete возвращает сохранённый URL и одновременно удаляет его. Если его нет, используется root_url. Это разовый возврат после входа.

- [Строка 42](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:42) — `user.sessions.create!`. Создаёт запись входа с user_id, IP и строкой браузера. Восклицательный знак означает исключение при неудачной записи вместо возврата false. IP и user_agent здесь записываются для контекста, но код не связывает вход жёстко с ними.

- [Строка 42](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:42) — `.tap do |session|`. tap передаёт созданный объект в блок и возвращает тот же объект после блока. Внутри устанавливается Current.session и cookie браузера.

- [Строка 44](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:44) — `cookies.signed.permanent`. В браузер уходит подписанный ID с длительным сроком хранения. Это не означает бессрочную действительность записи сервера: удаление Session прекращает такой вход.

- [Строка 44](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:44) — `httponly: true, same_site: :lax`. HttpOnly запрещает обычное чтение cookie JavaScript-кодом страницы. SameSite=Lax ограничивает её отправку в некоторых межсайтовых сценариях. Эти флаги не заменяют всю защиту приложения.

- [Строка 48](C:/Ruby/movie_recommender/app/controllers/concerns/authentication.rb:48) — `def terminate_session`. Удаляет серверную запись текущего входа и cookie. Удаление записи делает старый идентификатор бесполезным для дальнейшего поиска. Другие записи входа пользователя этот метод не уничтожает.


<a id="file-008"></a>

## 8. Регистрация: обработка успешной и ошибочной формы

[Открыть app/controllers/registrations_controller.rb](C:/Ruby/movie_recommender/app/controllers/registrations_controller.rb)

Создаёт пользователя и сразу выполняет вход.

~~~~ruby
class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      start_new_session_for @user
      redirect_to after_authentication_url, notice: "Welcome! You have signed up successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:nickname, :email_address, :password, :password_confirmation)
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/controllers/registrations_controller.rb:2) — `allow_unauthenticated_access`. Гость должен иметь возможность зарегистрироваться, поэтому наследованная проверка входа отключена.

- [Строка 3](C:/Ruby/movie_recommender/app/controllers/registrations_controller.rb:3) — `rate_limit`. Для create задан предел 10 обращений за 3 минуты. При превышении вызывается лямбда с redirect_to и alert. Это ограничение частоты запросов в настроенном хранилище Rails, не проверка корректности полей.

- [Строка 6](C:/Ruby/movie_recommender/app/controllers/registrations_controller.rb:6) — `@user = User.new`. В new создаётся объект в памяти для формы; INSERT в базу ещё нет.

- [Строка 10](C:/Ruby/movie_recommender/app/controllers/registrations_controller.rb:10) — `@user = User.new(registration_params)`. В create объект получает только разрешённые параметры. Форма с model: @user отправляет их внутри user: {...}.

- [Строка 12](C:/Ruby/movie_recommender/app/controllers/registrations_controller.rb:12) — `if @user.save`. save запускает проверки и пытается сохранить запись. При обычной ошибке валидации возвращает false и заполняет @user.errors; при успехе — true. Не все ошибки базы превращаются в false.

- [Строка 13](C:/Ruby/movie_recommender/app/controllers/registrations_controller.rb:13) — `start_new_session_for @user`. После создания аккаунта используется тот же механизм входа, что и при обычной авторизации.

- [Строка 14](C:/Ruby/movie_recommender/app/controllers/registrations_controller.rb:14) — `redirect_to after_authentication_url`. Успех ведёт на ранее запрошенный адрес либо корень. notice передаёт сообщение следующему запросу через flash.

- [Строка 16](C:/Ruby/movie_recommender/app/controllers/registrations_controller.rb:16) — `render :new, status: :unprocessable_entity`. При ошибке отрисовывается тот же шаблон на текущем запросе с кодом 422. Метод new заново не вызывается, поэтому @user сохраняет введённые значения и ошибки.

- [Строка 23](C:/Ruby/movie_recommender/app/controllers/registrations_controller.rb:23) — `params.require(:user).permit`. require требует внешний объект user. permit разрешает nickname, email_address, password и password_confirmation. Это список разрешённых для присваивания полей, не валидация их содержания.


<a id="file-009"></a>

## 9. Вход и выход

[Открыть app/controllers/sessions_controller.rb](C:/Ruby/movie_recommender/app/controllers/sessions_controller.rb)

Проверяет существующего пользователя, создаёт сессию и завершает текущий вход.

~~~~ruby
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/controllers/sessions_controller.rb:2) — `allow_unauthenticated_access only:`. %i[ new create ] — массив символов [:new, :create]. Для формы и входа авторизация не нужна; destroy остаётся защищённым.

- [Строка 3](C:/Ruby/movie_recommender/app/controllers/sessions_controller.rb:3) — `rate_limit`. Ограничивает частоту попыток входа тем же способом, что регистрация, с собственным обработчиком превышения.

- [Строка 5](C:/Ruby/movie_recommender/app/controllers/sessions_controller.rb:5) — `def new`. Пустой метод допустим: Rails по соглашению отрисует app/views/sessions/new.html.erb.

- [Строка 9](C:/Ruby/movie_recommender/app/controllers/sessions_controller.rb:9) — `if user = User.authenticate_by`. Один знак = — присваивание: результат поиска и проверки пароля записывается в локальную переменную user, затем проверяется условием. При успешной аутентификации это User, при неудаче — ложный результат. Контроллер не сравнивает пароль с password_digest вручную.

- [Строка 9](C:/Ruby/movie_recommender/app/controllers/sessions_controller.rb:9) — `params.permit(:email_address, :password)`. В форме входа нет model: @user, поэтому эти поля лежат на верхнем уровне params, а не внутри params[:user].

- [Строка 10](C:/Ruby/movie_recommender/app/controllers/sessions_controller.rb:10) — `start_new_session_for user`. Общий метод создаёт Session и cookie. После этого redirect отправляет браузер дальше.

- [Строка 13](C:/Ruby/movie_recommender/app/controllers/sessions_controller.rb:13) — `alert: "Try another`. Одинаковое сообщение используется для несуществующего email и неверного пароля.

- [Строка 18](C:/Ruby/movie_recommender/app/controllers/sessions_controller.rb:18) — `terminate_session`. В destroy удаляется именно текущая запись входа.

- [Строка 19](C:/Ruby/movie_recommender/app/controllers/sessions_controller.rb:19) — `status: :see_other`. Код 303 указывает перейти к странице входа следующим запросом GET после операции выхода.


<a id="file-010"></a>

## 10. Восстановление пароля

[Открыть app/controllers/passwords_controller.rb](C:/Ruby/movie_recommender/app/controllers/passwords_controller.rb)

Отправляет ссылку и по проверенному токену разрешает смену пароля.

~~~~ruby
class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists)."
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Password has been reset."
    else
      redirect_to edit_password_path(params[:token]), alert: "Passwords did not match."
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
    end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/controllers/passwords_controller.rb:2) — `allow_unauthenticated_access`. Сброс должен работать, когда пользователь не может войти.

- [Строка 3](C:/Ruby/movie_recommender/app/controllers/passwords_controller.rb:3) — `before_action :set_user_by_token`. Перед edit и update проверяется токен и находится пользователь. Для запроса письма токен ещё не нужен.

- [Строка 4](C:/Ruby/movie_recommender/app/controllers/passwords_controller.rb:4) — `rate_limit`. Ограничение применяется только к отправке запроса письма create; не следует описывать его как отдельное ограничение всех действий восстановления.

- [Строка 10](C:/Ruby/movie_recommender/app/controllers/passwords_controller.rb:10) — `User.find_by(email_address:`. Находит существующего пользователя. При неизвестном адресе письмо не ставится в очередь.

- [Строка 11](C:/Ruby/movie_recommender/app/controllers/passwords_controller.rb:11) — `PasswordsMailer.reset(user).deliver_later`. Поручает отправку Active Job. Постановка в очередь не равна подтверждённой доставке: нужны работающий обработчик очереди и почтовая конфигурация.

- [Строка 14](C:/Ruby/movie_recommender/app/controllers/passwords_controller.rb:14) — `notice: "Password reset instructions`. Ответ внешне одинаков при известном и неизвестном адресе, чтобы не раскрывать список аккаунтов.

- [Строка 17](C:/Ruby/movie_recommender/app/controllers/passwords_controller.rb:17) — `def edit`. После успешного before_action пустое действие отрисует форму нового пароля.

- [Строка 21](C:/Ruby/movie_recommender/app/controllers/passwords_controller.rb:21) — `@user.update(params.permit`. update присваивает только разрешённые пароль и подтверждение и сохраняет существующего пользователя. Здесь применяются проверки обновления; минимум 8, ограниченный on: :create в User, сюда не распространяется.

- [Строка 22](C:/Ruby/movie_recommender/app/controllers/passwords_controller.rb:22) — `@user.sessions.destroy_all`. После смены пароля удаляет все записи входа пользователя, в том числе с других браузеров. Это предотвращает дальнейшее использование прежних серверных сессий.

- [Строка 25](C:/Ruby/movie_recommender/app/controllers/passwords_controller.rb:25) — `redirect_to edit_password_path`. При неудаче идёт новый запрос формы с тем же токеном. Общий текст 'Passwords did not match' не перечисляет все возможные причины отказа модели.

- [Строка 31](C:/Ruby/movie_recommender/app/controllers/passwords_controller.rb:31) — `User.find_by_password_reset_token!`. Стандартный механизм Rails ищет пользователя по подписанному токену сброса с ограничением срока. Токен — не исходный пароль и не пользовательская Session.

- [Строка 32](C:/Ruby/movie_recommender/app/controllers/passwords_controller.rb:32) — `rescue ActiveSupport::MessageVerifier::InvalidSignature`. Недействительная либо просроченная подпись обрабатывается переходом к запросу новой ссылки.


<a id="file-011"></a>

## 11. Личный кабинет

[Открыть app/controllers/profiles_controller.rb](C:/Ruby/movie_recommender/app/controllers/profiles_controller.rb)

Получает пользователя, уже восстановленного общей авторизацией.

~~~~ruby
class ProfilesController < ApplicationController
  def show
    @user = Current.user
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 3](C:/Ruby/movie_recommender/app/controllers/profiles_controller.rb:3) — `@user = Current.user`. Пользователь берётся из серверного контекста входа, а не из произвольного user_id браузера. Контроллер пока не вычисляет статистику оценок и комнат.


<a id="file-012"></a>

## 12. Поиск, популярные фильмы и подробности

[Открыть app/controllers/movies_controller.rb](C:/Ruby/movie_recommender/app/controllers/movies_controller.rb)

Связывает запрос страницы с сервисом TMDB и представлениями.

~~~~ruby
class MoviesController < ApplicationController
  def index
    @query = params[:query].to_s.strip
    movie_search = Tmdb::MovieSearch.new

    if @query.present?
      @movies = movie_search.search(@query)
      @section_title = "Результаты поиска"
    else
      @movies = movie_search.popular
      @section_title = "Популярные сейчас"
    end
  rescue Tmdb::MovieSearch::ConfigurationError
    @error_message = "Для поиска нужно настроить TMDB API Read Access Token. Инструкция есть в README."
  rescue Tmdb::MovieSearch::AuthenticationError
    @error_message = "TMDB отклонил токен. Проверьте, что задан именно API Read Access Token без слова Bearer, затем перезапустите Rails."
  rescue Tmdb::MovieSearch::Error => error
    Rails.logger.warn("TMDB movie search failed: #{error.message}")
    @error_message = "Не удалось связаться с TMDB. Попробуйте ещё раз чуть позже."
  end

  def show
    @movie = Tmdb::MovieSearch.new.details(params[:tmdb_id])
  rescue Tmdb::MovieSearch::ConfigurationError
    @error_message = "Для просмотра фильма нужно настроить TMDB API Read Access Token. Инструкция есть в README."
  rescue Tmdb::MovieSearch::AuthenticationError
    @error_message = "TMDB отклонил токен. Проверьте, что задан именно API Read Access Token без слова Bearer, затем перезапустите Rails."
  rescue Tmdb::MovieSearch::NotFoundError
    @error_message = "Фильм не найден в каталоге TMDB."
  rescue Tmdb::MovieSearch::Error => error
    Rails.logger.warn("TMDB movie details failed: #{error.message}")
    @error_message = "Не удалось загрузить информацию о фильме. Попробуйте ещё раз чуть позже."
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 3](C:/Ruby/movie_recommender/app/controllers/movies_controller.rb:3) — `@query = params[:query].to_s.strip`. Читает query из адреса/формы, превращает nil в пустую строку и убирает краевые пробелы. @-переменная доступна шаблону этого действия.

- [Строка 4](C:/Ruby/movie_recommender/app/controllers/movies_controller.rb:4) — `movie_search = Tmdb::MovieSearch.new`. Создаёт объект сервиса. Эта локальная переменная нужна только контроллеру; сетевой запрос произойдёт при вызове search/popular.

- [Строка 6](C:/Ruby/movie_recommender/app/controllers/movies_controller.rb:6) — `if @query.present?`. present? считает непустую строку запросом. В этой ветке search получает строку и заголовок становится 'Результаты поиска'.

- [Строка 10](C:/Ruby/movie_recommender/app/controllers/movies_controller.rb:10) — `@movies = movie_search.popular`. Без запроса загружается популярное. Шаблон тот же, меняются массив и заголовок.

- [Строка 13](C:/Ruby/movie_recommender/app/controllers/movies_controller.rb:13) — `rescue Tmdb::MovieSearch::ConfigurationError`. rescue перехватывает исключение, возникшее в теле index, и записывает понятное сообщение. Шаблон сперва проверяет @error_message, поэтому ему не нужен успешно загруженный @movies.

- [Строка 15](C:/Ruby/movie_recommender/app/controllers/movies_controller.rb:15) — `rescue Tmdb::MovieSearch::AuthenticationError`. Отдельная подсказка для отклонённого токена. Более частные ошибки стоят до общего Error, иначе общий обработчик перехватил бы их первым.

- [Строка 17](C:/Ruby/movie_recommender/app/controllers/movies_controller.rb:17) — `rescue Tmdb::MovieSearch::Error => error`. => сохраняет перехваченное исключение в error. В журнал идёт техническое сообщение, человеку — общий текст о проблеме связи.

- [Строка 22](C:/Ruby/movie_recommender/app/controllers/movies_controller.rb:22) — `def show`. Другой метод того же контроллера обслуживает все /movies/:tmdb_id.

- [Строка 23](C:/Ruby/movie_recommender/app/controllers/movies_controller.rb:23) — `@movie = Tmdb::MovieSearch.new.details`. ID из маршрута передаётся сервису. Возвращённый хеш фильма сохраняется в @movie для show.html.erb.

- [Строка 28](C:/Ruby/movie_recommender/app/controllers/movies_controller.rb:28) — `rescue Tmdb::MovieSearch::NotFoundError`. Для карточки выделена ошибка отсутствия фильма. Здесь задаётся сообщение, но не вызывается head :not_found и не задаётся HTTP 404: текст 'не найден' не равен статусу ответа 404.


<a id="file-013"></a>

## 13. Клиент TMDB: подробный разбор каждой операции

[Открыть app/services/tmdb/movie_search.rb](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb)

Изолирует HTTPS, авторизацию, параметры, JSON и типы ошибок от контроллеров и вёрстки.

~~~~ruby
require "json"
require "net/http"
require "openssl"
require "timeout"
require "uri"

module Tmdb
  class MovieSearch
    API_BASE_URL = "https://api.themoviedb.org/3"

    class Error < StandardError; end
    class ConfigurationError < Error; end
    class AuthenticationError < Error; end
    class NotFoundError < Error; end

    def search(query)
      get_results("/search/movie", { query: query, language: "ru-RU", include_adult: false, page: 1 })
    end

    def popular
      get_results("/movie/popular", { language: "ru-RU", page: 1 })
    end

    def details(tmdb_id)
      movie_id = Integer(tmdb_id, 10)
      get("/movie/#{movie_id}", { language: "ru-RU" })
    rescue ArgumentError, TypeError
      raise NotFoundError, "Invalid TMDB movie ID"
    end

    private

    def get_results(path, params)
      get(path, params).fetch("results", [])
    end

    def get(path, params)
      token = ENV["TMDB_API_READ_ACCESS_TOKEN"]
      raise ConfigurationError, "TMDB_API_READ_ACCESS_TOKEN is not set" if token.to_s.strip.empty?

      uri = URI("#{API_BASE_URL}#{path}")
      uri.query = URI.encode_www_form(params)

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Accept"] = "application/json"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
        http.request(request)
      end

      if response.code == "401"
        raise AuthenticationError, "TMDB rejected the API Read Access Token"
      end
      raise NotFoundError, "TMDB movie was not found" if response.code == "404"

      raise Error, "TMDB responded with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue JSON::ParserError, Net::HTTPError, SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError => error
      raise Error, error.class.name
    end
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:1) — `require "json"`. Подключает JSON.parse. Остальные require подключают HTTP, SSL, классы тайм-аутов и разбор/кодирование URI из стандартных библиотек Ruby.

- [Строка 7](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:7) — `module Tmdb`. Пространство имён: Tmdb::MovieSearch. Соответствует пути app/services/tmdb/movie_search.rb для автозагрузки Rails. Это обычный Ruby-класс, не ActiveRecord-модель и не таблица.

- [Строка 9](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:9) — `API_BASE_URL`. Константа базового адреса API. #{...} в двойных кавычках подставляет Ruby-значения в строку.

- [Строка 11](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:11) — `class Error < StandardError`. Общий родитель прикладных ошибок сервиса. Остальные три класса наследуют Error, чтобы контроллер мог ловить конкретную причину либо всю группу. ; end записывает пустое тело класса в одну строку.

- [Строка 16](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:16) — `def search(query)`. Публичный метод принимает название и передаёт путь /search/movie плюс хеш параметров: запрос, русский язык, исключение adult-результатов и первую страницу. include_adult — параметр TMDB, не самостоятельная система возрастного доступа нашего сайта.

- [Строка 20](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:20) — `def popular`. Использует /movie/popular с языком и первой страницей. Пагинация последующих страниц в этом коде не реализована.

- [Строка 25](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:25) — `movie_id = Integer(tmdb_id, 10)`. Разбирает входной ID как целое в десятичной системе. Для строк маршрута это дополнительная проверка. В отличие от to_i некорректная строка не превращается молча в число.

- [Строка 26](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:26) — `get("/movie/#{movie_id}"`. Запрашивает один фильм. get возвращает весь JSON-объект; search/popular извлекают из ответа только results.

- [Строка 27](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:27) — `rescue ArgumentError, TypeError`. Ошибки преобразования ID переводятся в прикладной NotFoundError. Сигнатура с основанием 10 рассчитана на строковый вход, как в params.

- [Строка 31](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:31) — `private`. get и get_results — внутренние детали; снаружи предлагается пользоваться search, popular и details.

- [Строка 34](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:34) — `get(path, params).fetch("results", [])`. В Ruby последняя вычисленная строка метода является его результатом без return. fetch вернёт results, а при отсутствии ключа — []; это не полноценная проверка всей схемы ответа TMDB.

- [Строка 38](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:38) — `token = ENV[`. Читает токен из окружения процесса Rails. Наличие .env-файла само по себе не загружает его: dotenv-rails в Gemfile сейчас не подключён.

- [Строка 39](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:39) — `raise ConfigurationError`. raise прерывает обычное выполнение исключением. Проверяется token.to_s.strip.empty?, но исходное значение token не очищается перед заголовком; лишние пробелы в реально заданном токене следует убрать в настройке.

- [Строка 41](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:41) — `uri = URI(`. Собирает объект URI из базы и пути. URI хранит host, port, схему, путь и query отдельно.

- [Строка 42](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:42) — `uri.query = URI.encode_www_form(params)`. Корректно кодирует русские буквы, пробелы и спецсимволы параметров URL. Благодаря этому введённые '&' и '?' не ломают структуру запроса.

- [Строка 44](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:44) — `request = Net::HTTP::Get.new(uri)`. Создаёт GET-запрос, пока без отправки.

- [Строка 45](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:45) — `request["Authorization"]`. Добавляет Bearer перед токеном. Поэтому значение переменной окружения должно содержать сам токен без второго Bearer.

- [Строка 46](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:46) — `request["Accept"]`. Сообщает ожидаемый формат JSON. Это HTTP-заголовок, в отличие от language/page, которые находятся в строке параметров.

- [Строка 48](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:48) — `response = Net::HTTP.start`. Открывает HTTPS-соединение к host/port. open_timeout: 3 ограничивает ожидание открытия, read_timeout: 5 — ожидание чтения; это не жёсткий общий предел длительности всей операции.

- [Строка 49](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:49) — `http.request(request)`. Отправляет подготовленный запрос. do |http| даёт объект соединения внутри блока; результат блока возвращается Net::HTTP.start и присваивается response.

- [Строка 52](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:52) — `response.code == "401"`. HTTP-код Net::HTTP представлен строкой. 401 превращается в AuthenticationError, 404 — в NotFoundError.

- [Строка 57](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:57) — `unless response.is_a?(Net::HTTPSuccess)`. unless значит 'если условие ложно'. Любой другой неуспешный ответ превращается в общий Error. is_a? учитывает класс и его предков; проверяется группа успешных HTTP-ответов.

- [Строка 59](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:59) — `JSON.parse(response.body)`. Из тела ответа создаются хеши/массивы Ruby со строковыми ключами. Именно поэтому шаблон обращается к movie["title"], а не movie.title.

- [Строка 60](C:/Ruby/movie_recommender/app/services/tmdb/movie_search.rb:60) — `rescue JSON::ParserError`. Ошибки JSON, соединения, DNS/сокетов, тайм-аутов и TLS переводятся в единый Error. Новый текст содержит имя исходного класса, не тело ответа и не токен. Повторы, кэширование и постраничная загрузка в этом клиенте пока отсутствуют.


<a id="file-014"></a>

## 14. Контроллер экранов комнаты

[Открыть app/controllers/rooms_controller.rb](C:/Ruby/movie_recommender/app/controllers/rooms_controller.rb)

Пока управляет переходами и выбором обратного адреса, не данными комнаты.

~~~~ruby
class RoomsController < ApplicationController
  def index
  end

  def new
  end

  def show
    @selection_path = params[:id].present? ? selection_room_path(params[:id]) : current_room_selection_path
  end

  def selection
    @room_path = params[:id].present? ? room_path(params[:id]) : current_room_path
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/controllers/rooms_controller.rb:2) — `def index`. Пустой метод отрисовывает rooms/index.html.erb. Аналогично new отрисовывает rooms/new.html.erb. Здесь нет Room.all и Room.new.

- [Строка 9](C:/Ruby/movie_recommender/app/controllers/rooms_controller.rb:9) — `@selection_path`. Тернарное выражение условие ? вариант_да : вариант_нет. Если params[:id] есть, строится /rooms/:id/selection; иначе /room/selection. @selection_path передаётся общей форме.

- [Строка 13](C:/Ruby/movie_recommender/app/controllers/rooms_controller.rb:13) — `@room_path`. На экране подбора тем же способом выбирается адрес возврата в исходную комнату. ID сохраняется в ссылке; данные комнаты и право участия пока не проверяются.

- [Строка 8](C:/Ruby/movie_recommender/app/controllers/rooms_controller.rb:8) — `def show`. Наличие /rooms/42 сейчас не доказывает существование записи 42: в контроллере отсутствует поиск Room.find и самой модели Room пока нет.


<a id="file-015"></a>

## 15. Страница оценок

[Открыть app/controllers/ratings_controller.rb](C:/Ruby/movie_recommender/app/controllers/ratings_controller.rb)

Зарезервированный серверный вход для экрана списка.

~~~~ruby
class RatingsController < ApplicationController
  def index
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/controllers/ratings_controller.rb:2) — `def index`. Rails автоматически отрисует ratings/index.html.erb. Нет загрузки оценок, create/update и сохранения. Защита входом наследуется от ApplicationController.


<a id="file-016"></a>

## 16. Страница персонального подбора

[Открыть app/controllers/recommendations_controller.rb](C:/Ruby/movie_recommender/app/controllers/recommendations_controller.rb)

Серверный обработчик интерфейса будущих рекомендаций.

~~~~ruby
class RecommendationsController < ApplicationController
  def show
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/controllers/recommendations_controller.rb:2) — `def show`. Только отрисовка recommendations/show.html.erb. Алгоритм, выбор кандидатов и чтение параметров формы пока не реализованы.


<a id="file-017"></a>

## 17. Оболочка всех HTML-страниц

[Открыть app/views/layouts/application.html.erb](C:/Ruby/movie_recommender/app/views/layouts/application.html.erb)

Один общий документ с метаданными и подключением ресурсов. Rails вставляет в него выбранное представление.

~~~~erb
<!DOCTYPE html>
<html lang="ru">
  <head>
    <title><%= content_for(:title) || "Movie Recommender" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="color-scheme" content="dark">
    <meta name="theme-color" content="#0b1120">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="application-name" content="Movie Recommender">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <%# Enable PWA manifest for installable apps (make sure to enable in config/routes.rb too!) %>
    <%#= tag.link rel: "manifest", href: pwa_manifest_path(format: :json) %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <%# Includes all stylesheet files in app/assets/stylesheets %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="min-h-screen bg-canvas font-sans text-ink antialiased selection:bg-brand-soft selection:text-brand-ink-hover">
    <%= yield %>
  </body>
</html>
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/views/layouts/application.html.erb:1) — `<!DOCTYPE html>`. Указывает современный HTML. html lang='ru' задаёт язык документа; это помогает озвучиванию и обработке текста.

- [Строка 4](C:/Ruby/movie_recommender/app/views/layouts/application.html.erb:4) — `content_for(:title)`. Берёт заголовок, ранее заданный страницей через content_for :title. Если его нет, используется Movie Recommender. Это текст вкладки браузера, а не обязательный видимый h1.

- [Строка 5](C:/Ruby/movie_recommender/app/views/layouts/application.html.erb:5) — `name="viewport"`. Разрешает мобильному браузеру использовать реальную ширину экрана. Без viewport адаптивные классы могут давать неожиданный результат.

- [Строка 6](C:/Ruby/movie_recommender/app/views/layouts/application.html.erb:6) — `name="color-scheme"`. Указывает тёмную схему для встроенных элементов браузера. theme-color задаёт цвет оформления поддерживающего браузера. Метаданные mobile-web-app-capable сами по себе не подключают PWA.

- [Строка 11](C:/Ruby/movie_recommender/app/views/layouts/application.html.erb:11) — `csrf_meta_tags`. Добавляет метаданные CSRF-защиты для поддерживающего их клиентского кода Rails. Обычные формы также получают защитные поля при нужных HTTP-методах. Наличие этих метатегов не является авторизацией.

- [Строка 12](C:/Ruby/movie_recommender/app/views/layouts/application.html.erb:12) — `csp_meta_tag`. Выводит метатег политики/nonce, если это предусмотрено настройками Rails. Сам вызов не означает, что в приложении задана строгая Content Security Policy.

- [Строка 14](C:/Ruby/movie_recommender/app/views/layouts/application.html.erb:14) — `yield :head`. Место для дополнительных тегов head, которые конкретная страница может передать через content_for.

- [Строка 16](C:/Ruby/movie_recommender/app/views/layouts/application.html.erb:16) — `<%#`. ERB-комментарий: код внутри не выполняется. Поэтому ссылка на PWA manifest здесь выключена.

- [Строка 24](C:/Ruby/movie_recommender/app/views/layouts/application.html.erb:24) — `stylesheet_link_tag`. Подключает стили через систему ресурсов Rails. data-turbo-track='reload' позволяет Turbo учитывать изменение подключённого ресурса.

- [Строка 25](C:/Ruby/movie_recommender/app/views/layouts/application.html.erb:25) — `javascript_importmap_tags`. Выводит importmap и подключение модульной точки входа JavaScript. Браузер узнаёт, откуда брать именованные импорты.

- [Строка 28](C:/Ruby/movie_recommender/app/views/layouts/application.html.erb:28) — `<body class=`. Классы задают минимальную высоту экрана, общий фон, шрифт, цвет текста и выделения. Это оформление всей страницы.

- [Строка 29](C:/Ruby/movie_recommender/app/views/layouts/application.html.erb:29) — `<%= yield %>`. Место вставки HTML конкретного представления, например movies/index.html.erb.


<a id="file-018"></a>

## 18. Общая шапка и выход

[Открыть app/views/shared/_header.html.erb](C:/Ruby/movie_recommender/app/views/shared/_header.html.erb)

Повторно используется на внутренних страницах.

~~~~erb
<header class="mb-6 flex flex-wrap items-center justify-between gap-4 border-b border-line/80 pb-4">
  <%= link_to root_path, class: "flex items-center gap-2.5 text-sm font-bold tracking-tight text-ink", aria: { label: "MovieRecommender — главная" } do %>
    <span class="grid size-9 place-items-center rounded-xl bg-brand-600 text-white shadow-sm" aria-hidden="true">M</span>
    <span>MovieRecommender</span>
  <% end %>
  <nav class="order-3 flex w-full flex-wrap gap-1 sm:order-none sm:w-auto" aria-label="Главная навигация">
    <%= link_to "Обзор", root_path, class: class_names("rounded-lg px-3 py-2 text-sm font-medium transition hover:bg-brand-soft hover:text-brand-ink-hover", current_page?(root_path) ? "bg-brand-soft text-brand-ink" : "text-ink-muted"), aria: { current: current_page?(root_path) ? "page" : nil } %>
    <%= link_to "Фильмы", movies_path, class: class_names("rounded-lg px-3 py-2 text-sm font-medium transition hover:bg-brand-soft hover:text-brand-ink-hover", controller_name == "movies" ? "bg-brand-soft text-brand-ink" : "text-ink-muted"), aria: { current: current_page?(movies_path) ? "page" : nil } %>
    <%= link_to "Мои оценки", ratings_path, class: class_names("rounded-lg px-3 py-2 text-sm font-medium transition hover:bg-brand-soft hover:text-brand-ink-hover", controller_name == "ratings" ? "bg-brand-soft text-brand-ink" : "text-ink-muted"), aria: { current: current_page?(ratings_path) ? "page" : nil } %>
    <%= link_to "Комнаты", rooms_path, class: class_names("rounded-lg px-3 py-2 text-sm font-medium transition hover:bg-brand-soft hover:text-brand-ink-hover", controller_name == "rooms" ? "bg-brand-soft text-brand-ink" : "text-ink-muted"), aria: { current: current_page?(rooms_path) ? "page" : nil } %>
  </nav>
  <div class="flex items-center gap-2.5">
    <%= render "shared/notifications" %>
    <span class="grid size-9 place-items-center rounded-full bg-brand-soft text-sm font-semibold text-brand-ink" aria-hidden="true"><%= Current.user.nickname.first.upcase %></span>
    <span class="hidden max-w-32 truncate text-sm font-medium text-ink-secondary lg:inline"><%= Current.user.nickname %></span>
    <%= button_to "Выйти", session_path, method: :delete, class: ui_button_classes(:secondary) %>
  </div>
</header>
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/views/shared/_header.html.erb:2) — `link_to root_path`. Блочная форма link_to оборачивает значок и текст в одну ссылку. aria-label задаёт понятное доступное имя.

- [Строка 6](C:/Ruby/movie_recommender/app/views/shared/_header.html.erb:6) — `<nav`. Семантический блок навигации. order-3 и w-full ставят меню на отдельный ряд на узком экране; sm-варианты меняют расположение на более широком.

- [Строка 7](C:/Ruby/movie_recommender/app/views/shared/_header.html.erb:7) — `current_page?(root_path)`. Проверяет текущий адрес. class_names объединяет общие классы с выбранным вариантом активного/неактивного пункта.

- [Строка 8](C:/Ruby/movie_recommender/app/views/shared/_header.html.erb:8) — `controller_name == "movies"`. Подсвечивает раздел 'Фильмы' и на списке, и на странице фильма. aria-current здесь проверяет точное соответствие movies_path, поэтому подсветка раздела и признак текущей страницы не обязаны совпадать.

- [Строка 13](C:/Ruby/movie_recommender/app/views/shared/_header.html.erb:13) — `render "shared/notifications"`. Вставляет отдельный фрагмент колокольчика с собственной клиентской логикой.

- [Строка 14](C:/Ruby/movie_recommender/app/views/shared/_header.html.erb:14) — `Current.user.nickname.first.upcase`. Берёт первую букву нормализованного ника и делает заглавной для аватара. Шаблон предполагает наличие вошедшего пользователя с непустым ником; это обеспечивается текущим сценарием авторизации/валидаций.

- [Строка 15](C:/Ruby/movie_recommender/app/views/shared/_header.html.erb:15) — `hidden max-w-32 truncate`. Полный ник скрыт до lg, ограничен по ширине и обрезается многоточием. Это предотвращает переполнение шапки.

- [Строка 16](C:/Ruby/movie_recommender/app/views/shared/_header.html.erb:16) — `button_to "Выйти"`. Генерирует форму с кнопкой. method: :delete передаётся Rails через предусмотренный механизм подмены метода, поскольку стандартные HTML-формы не отправляют DELETE напрямую. Операция попадёт в SessionsController#destroy.


<a id="file-019"></a>

## 19. Сообщения после действий

[Открыть app/views/shared/_flash.html.erb](C:/Ruby/movie_recommender/app/views/shared/_flash.html.erb)

Общий вывод flash[:alert] и flash[:notice].

~~~~erb
<% if flash[:alert] %>
  <div class="mb-5 rounded-xl border border-rose-800/60 bg-rose-950/40 px-4 py-3 text-sm text-rose-200" role="alert"><%= flash[:alert] %></div>
<% end %>
<% if flash[:notice] %>
  <div class="mb-5 rounded-xl border border-emerald-800/60 bg-emerald-950/40 px-4 py-3 text-sm text-emerald-200" role="status"><%= flash[:notice] %></div>
<% end %>
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/views/shared/_flash.html.erb:1) — `if flash[:alert]`. Условно выводит сообщение об ошибке. role='alert' обозначает требующее внимания сообщение для вспомогательных технологий.

- [Строка 4](C:/Ruby/movie_recommender/app/views/shared/_flash.html.erb:4) — `if flash[:notice]`. Отдельный спокойный вариант уведомления с role='status'. Сам шаблон не создаёт flash: значения приходят из redirect_to и других серверных действий.


<a id="file-020"></a>

## 20. Форма регистрации

[Открыть app/views/registrations/new.html.erb](C:/Ruby/movie_recommender/app/views/registrations/new.html.erb)

Связывает модель @user, поля, ошибки и POST-запрос.

~~~~erb
<main class="mx-auto max-w-md px-5 py-12 sm:py-16">
  <div class="mb-8 text-center">
    <span class="mx-auto mb-5 grid size-12 place-items-center rounded-2xl bg-brand-600 text-xl font-bold text-white shadow-sm" aria-hidden="true">M</span>
    <h1 class="text-3xl font-bold tracking-tight">Ваш вкус. Ваше кино.</h1>
    <p class="mt-2 text-sm text-ink-muted">Создайте аккаунт и начните свою киноколлекцию.</p>
  </div>
  <%= render "shared/flash" %>
  <%= form_with model: @user, url: registration_path, class: "space-y-5 rounded-2xl border border-line bg-surface p-6 shadow-sm sm:p-8" do |form| %>
    <% if @user.errors.any? %>
      <div class="rounded-xl border border-rose-800/60 bg-rose-950/40 p-4 text-sm text-rose-200" role="alert">
        <h2 class="font-semibold">Проверьте данные</h2>
        <ul class="mt-2 list-disc space-y-1 pl-5">
          <% @user.errors.each do |error| %><li><%= error.full_message %></li><% end %>
        </ul>
      </div>
    <% end %>
    <div>
      <%= form.label :nickname, "Никнейм", class: ui_label_classes %>
      <%= form.text_field :nickname, required: true, autofocus: true, autocomplete: "nickname", placeholder: "Как вас называть?", class: ui_input_classes, aria: { invalid: @user.errors[:nickname].any? } %>
    </div>
    <div>
      <%= form.label :email_address, "Электронная почта", class: ui_label_classes %>
      <%= form.email_field :email_address, required: true, autocomplete: "email", placeholder: "you@example.com", class: ui_input_classes, aria: { invalid: @user.errors[:email_address].any? } %>
    </div>
    <div>
      <%= form.label :password, "Пароль", class: ui_label_classes %>
      <%= form.password_field :password, required: true, autocomplete: "new-password", placeholder: "Не менее 8 символов", maxlength: 72, class: ui_input_classes, aria: { invalid: @user.errors[:password].any? } %>
    </div>
    <div>
      <%= form.label :password_confirmation, "Повторите пароль", class: ui_label_classes %>
      <%= form.password_field :password_confirmation, required: true, autocomplete: "new-password", placeholder: "Ещё раз тот же пароль", maxlength: 72, class: ui_input_classes, aria: { invalid: @user.errors[:password_confirmation].any? } %>
    </div>
    <%= form.submit "Создать аккаунт", class: class_names(ui_button_classes, "w-full cursor-pointer") %>
  <% end %>
  <nav class="mt-6 text-center text-sm text-ink-muted" aria-label="Помощь с аккаунтом">
    Уже есть аккаунт? <%= link_to "Войти", new_session_path, class: "font-semibold text-brand-ink hover:text-brand-ink-hover" %>
  </nav>
</main>
~~~~

**Разбор значимых строк и блоков**

- [Строка 8](C:/Ruby/movie_recommender/app/views/registrations/new.html.erb:8) — `form_with model: @user`. Форма связана с объектом модели. Для нового объекта используется создание, а явный url направляет POST в registration_path. Имена полей получаются user[nickname], user[email_address] и т. д.

- [Строка 9](C:/Ruby/movie_recommender/app/views/registrations/new.html.erb:9) — `@user.errors.any?`. Показывает блок только после ошибок проверки. errors.each перебирает ошибки, full_message выводит сообщение с именем атрибута. Обычный ERB-вывод экранирует HTML.

- [Строка 18](C:/Ruby/movie_recommender/app/views/registrations/new.html.erb:18) — `form.label :nickname`. Создаёт подпись, связанную с ID поля. Нажатие подписи переводит фокус в поле.

- [Строка 19](C:/Ruby/movie_recommender/app/views/registrations/new.html.erb:19) — `form.text_field :nickname`. required включает проверку заполнения браузером, autofocus ставит фокус, autocomplete помогает автозаполнению. Серверная проверка всё равно нужна: браузерные ограничения можно обойти.

- [Строка 19](C:/Ruby/movie_recommender/app/views/registrations/new.html.erb:19) — `aria: { invalid: @user.errors[:nickname].any? }`. Серверные ошибки отмечаются aria-invalid; стили ui_input_classes реагируют на этот атрибут. Аналогично оформляются email и пароль.

- [Строка 23](C:/Ruby/movie_recommender/app/views/registrations/new.html.erb:23) — `form.email_field`. HTML-поле type=email даёт подходящий интерфейс и базовую браузерную проверку. Это не отправка подтверждения адреса.

- [Строка 27](C:/Ruby/movie_recommender/app/views/registrations/new.html.erb:27) — `form.password_field :password,`. Поле скрывает вводимые символы. autocomplete='new-password' указывает менеджеру паролей на создание нового секрета. maxlength: 72 — браузерный предел символов; серверное ограничение BCrypt относится к байтам, поэтому для Unicode это не одно и то же.

- [Строка 31](C:/Ruby/movie_recommender/app/views/registrations/new.html.erb:31) — `form.password_field :password_confirmation`. Отправляет отдельное подтверждение. Обе проверки — HTML required и модель — работают на разных уровнях.

- [Строка 33](C:/Ruby/movie_recommender/app/views/registrations/new.html.erb:33) — `form.submit`. Кнопка отправляет форму. class_names соединяет единые стили кнопки с шириной на всю форму.

- [Строка 36](C:/Ruby/movie_recommender/app/views/registrations/new.html.erb:36) — `new_session_path`. Ссылка открывает уже отдельный сценарий входа. render shared/flash выше обеспечивает вывод сообщений после перенаправлений.


<a id="file-021"></a>

## 21. Форма входа

[Открыть app/views/sessions/new.html.erb](C:/Ruby/movie_recommender/app/views/sessions/new.html.erb)

Отправляет email и пароль верхнего уровня в SessionsController#create.

~~~~erb
<main class="mx-auto max-w-md px-5 py-12 sm:py-20">
  <div class="mb-8 text-center">
    <span class="mx-auto mb-5 grid size-12 place-items-center rounded-2xl bg-brand-600 text-xl font-bold text-white shadow-sm" aria-hidden="true">M</span>
    <h1 class="text-3xl font-bold tracking-tight">С возвращением</h1>
    <p class="mt-2 text-sm text-ink-muted">Войдите, чтобы продолжить выбирать кино.</p>
  </div>
  <%= render "shared/flash" %>
  <%= form_with url: session_path, class: "space-y-5 rounded-2xl border border-line bg-surface p-6 shadow-sm sm:p-8" do |form| %>
    <div>
      <%= form.label :email_address, "Электронная почта", class: ui_label_classes %>
      <%= form.email_field :email_address, required: true, autofocus: true, autocomplete: "username", placeholder: "you@example.com", value: params[:email_address], class: ui_input_classes %>
    </div>
    <div>
      <div class="flex items-baseline justify-between gap-3">
        <%= form.label :password, "Пароль", class: ui_label_classes %>
        <%= link_to "Забыли пароль?", new_password_path, class: "text-xs font-medium text-brand-ink hover:text-brand-ink-hover" %>
      </div>
      <%= form.password_field :password, required: true, autocomplete: "current-password", placeholder: "Введите пароль", maxlength: 72, class: ui_input_classes %>
    </div>
    <%= form.submit "Войти", class: class_names(ui_button_classes, "w-full cursor-pointer") %>
  <% end %>
  <nav class="mt-6 text-center text-sm text-ink-muted" aria-label="Помощь с аккаунтом">
    Нет аккаунта? <%= link_to "Зарегистрироваться", new_registration_path, class: "font-semibold text-brand-ink hover:text-brand-ink-hover" %>
  </nav>
</main>
~~~~

**Разбор значимых строк и блоков**

- [Строка 8](C:/Ruby/movie_recommender/app/views/sessions/new.html.erb:8) — `form_with url: session_path`. Без model поля не оборачиваются в user. Метод по умолчанию POST для такой формы.

- [Строка 11](C:/Ruby/movie_recommender/app/views/sessions/new.html.erb:11) — `form.email_field`. required и autofocus управляют вводом; autocomplete='username' говорит менеджеру паролей, что email используется как логин.

- [Строка 11](C:/Ruby/movie_recommender/app/views/sessions/new.html.erb:11) — `value: params[:email_address]`. Подставит email, если он есть в параметрах текущего запроса. После ошибочного redirect контроллер не передаёт email в новый URL, поэтому эта строка сама по себе не сохраняет email между такими запросами.

- [Строка 16](C:/Ruby/movie_recommender/app/views/sessions/new.html.erb:16) — `new_password_path`. Ссылка к запросу письма восстановления.

- [Строка 18](C:/Ruby/movie_recommender/app/views/sessions/new.html.erb:18) — `autocomplete: "current-password"`. Указывает существующий пароль; отличается от new-password в регистрации и сбросе.

- [Строка 23](C:/Ruby/movie_recommender/app/views/sessions/new.html.erb:23) — `new_registration_path`. Ссылка к форме регистрации; остальная разметка — та же система карточки, отступов и цветов.


<a id="file-022"></a>

## 22. Запрос письма восстановления

[Открыть app/views/passwords/new.html.erb](C:/Ruby/movie_recommender/app/views/passwords/new.html.erb)

Собирает email и отправляет POST /passwords.

~~~~erb
<main class="mx-auto max-w-md px-5 py-12 sm:py-20">
  <h1 class="mb-2 text-3xl font-bold tracking-tight">Забыли пароль?</h1>
  <p class="mb-8 text-sm leading-6 text-ink-muted">Отправим ссылку для восстановления на вашу почту.</p>
  <%= render "shared/flash" %>
  <%= form_with url: passwords_path, class: "space-y-5 rounded-2xl border border-line bg-surface p-6 shadow-sm sm:p-8" do |form| %>
    <div>
      <%= form.label :email_address, "Электронная почта", class: ui_label_classes %>
      <%= form.email_field :email_address, required: true, autofocus: true, autocomplete: "username", placeholder: "you@example.com", value: params[:email_address], class: ui_input_classes %>
    </div>
    <%= form.submit "Отправить ссылку", class: class_names(ui_button_classes, "w-full cursor-pointer") %>
  <% end %>
  <nav class="mt-6 text-center text-sm" aria-label="Помощь с аккаунтом">
    <%= link_to "Вернуться ко входу", new_session_path, class: "font-medium text-brand-ink hover:text-brand-ink-hover" %>
  </nav>
</main>
~~~~

**Разбор значимых строк и блоков**

- [Строка 5](C:/Ruby/movie_recommender/app/views/passwords/new.html.erb:5) — `form_with url: passwords_path`. Один email без пароля. Контроллер решает, существует ли пользователь, и в обоих случаях показывает одинаковый результат.

- [Строка 8](C:/Ruby/movie_recommender/app/views/passwords/new.html.erb:8) — `form.email_field`. Стандартные required/autofocus/autocomplete, значение из текущих params и общий стиль поля.

- [Строка 10](C:/Ruby/movie_recommender/app/views/passwords/new.html.erb:10) — `form.submit`. Отправляет запрос ссылки. Текст кнопки не доказывает фактическую доставку письма: за неё отвечает отдельная инфраструктура.

- [Строка 13](C:/Ruby/movie_recommender/app/views/passwords/new.html.erb:13) — `new_session_path`. Возврат ко входу обычной ссылкой GET.


<a id="file-023"></a>

## 23. Ввод нового пароля

[Открыть app/views/passwords/edit.html.erb](C:/Ruby/movie_recommender/app/views/passwords/edit.html.erb)

Форма открывается только после серверной проверки токена.

~~~~erb
<main class="mx-auto max-w-md px-5 py-12 sm:py-20">
  <h1 class="mb-2 text-3xl font-bold tracking-tight">Новый пароль</h1>
  <p class="mb-8 text-sm text-ink-muted">Задайте новый пароль для вашего аккаунта.</p>
  <%= render "shared/flash" %>
  <%= form_with url: password_path(params[:token]), method: :put, class: "space-y-5 rounded-2xl border border-line bg-surface p-6 shadow-sm sm:p-8" do |form| %>
    <div>
      <%= form.label :password, "Новый пароль", class: ui_label_classes %>
      <%= form.password_field :password, required: true, autocomplete: "new-password", placeholder: "Введите новый пароль", maxlength: 72, class: ui_input_classes %>
    </div>
    <div>
      <%= form.label :password_confirmation, "Повторите пароль", class: ui_label_classes %>
      <%= form.password_field :password_confirmation, required: true, autocomplete: "new-password", placeholder: "Ещё раз тот же пароль", maxlength: 72, class: ui_input_classes %>
    </div>
    <%= form.submit "Сохранить пароль", class: class_names(ui_button_classes, "w-full cursor-pointer") %>
  <% end %>
  <nav class="mt-6 text-center text-sm" aria-label="Помощь с аккаунтом">
    <%= link_to "Вернуться ко входу", new_session_path, class: "font-medium text-brand-ink hover:text-brand-ink-hover" %>
  </nav>
</main>
~~~~

**Разбор значимых строк и блоков**

- [Строка 5](C:/Ruby/movie_recommender/app/views/passwords/edit.html.erb:5) — `password_path(params[:token]), method: :put`. Адрес содержит токен из ссылки, PUT направляется в update. Rails формирует нужный служебный параметр HTTP-метода для HTML-формы.

- [Строка 8](C:/Ruby/movie_recommender/app/views/passwords/edit.html.erb:8) — `form.password_field :password,`. Новый пароль передаётся в теле запроса; в URL находится только токен. autocomplete='new-password' помогает менеджеру паролей.

- [Строка 12](C:/Ruby/movie_recommender/app/views/passwords/edit.html.erb:12) — `form.password_field :password_confirmation`. Подтверждение передаётся рядом. Здесь нет minlength: 8, и минимальная длина модели ограничена созданием — поэтому текущий интерфейс и сервер не гарантируют минимум 8 при сбросе.

- [Строка 14](C:/Ruby/movie_recommender/app/views/passwords/edit.html.erb:14) — `form.submit`. Запускает update; общий flash над формой показывает сообщение при неудачном перенаправлении.


<a id="file-024"></a>

## 24. Личный кабинет: реальные ссылки и статические показатели

[Открыть app/views/profiles/show.html.erb](C:/Ruby/movie_recommender/app/views/profiles/show.html.erb)

Сводный интерфейс доступных сценариев после входа.

~~~~erb
<main class="mx-auto max-w-6xl px-5 py-6 sm:px-8">
  <%= render "shared/header" %>
  <%= render "shared/flash" %>
  <section class="rounded-3xl border border-brand-line bg-gradient-to-br from-surface via-brand-soft to-hero-end p-5 sm:p-6" id="overview">
    <p class="mb-2 text-xs font-semibold tracking-widest text-brand-ink">ВАШ КИНОВЕЧЕР</p>
    <h1 class="text-3xl font-bold tracking-tight">Что посмотрим сегодня?</h1>
    <p class="mt-2 max-w-2xl text-sm leading-6 text-ink-secondary">Создайте комнату и выберите фильм вместе. Оценки помогут учесть вкусы каждого.</p>
    <div class="mt-4 flex flex-col gap-3 sm:flex-row">
      <%= link_to new_room_path, class: ui_button_classes do %>
        <%= ui_icon(:plus) %> Создать комнату
      <% end %>
      <%= link_to movies_path, class: ui_button_classes(:secondary) do %>
        <%= ui_icon(:search) %> Найти фильм
      <% end %>
    </div>
  </section>
  <section class="my-4 grid grid-cols-3 gap-3" aria-label="Моя активность">
    <article class="flex items-center gap-3 rounded-2xl border border-line bg-surface p-3 sm:p-4">
      <span class="hidden size-10 shrink-0 place-items-center rounded-xl bg-brand-soft text-brand-ink sm:grid"><%= ui_icon(:star) %></span>
      <div class="min-w-0"><p class="text-xl font-semibold tabular-nums">0</p><p class="mt-1 text-xs leading-5 text-ink-muted">Оценено фильмов</p></div>
    </article>
    <article class="flex items-center gap-3 rounded-2xl border border-line bg-surface p-3 sm:p-4">
      <span class="hidden size-10 shrink-0 place-items-center rounded-xl bg-amber-950/40 text-amber-300 sm:grid"><%= ui_icon(:chart) %></span>
      <div class="min-w-0"><p class="text-xl font-semibold">—</p><p class="mt-1 text-xs leading-5 text-ink-muted">Средняя оценка</p></div>
    </article>
    <article class="flex items-center gap-3 rounded-2xl border border-line bg-surface p-3 sm:p-4">
      <span class="hidden size-10 shrink-0 place-items-center rounded-xl bg-emerald-950/40 text-emerald-300 sm:grid"><%= ui_icon(:users) %></span>
      <div class="min-w-0"><p class="text-xl font-semibold tabular-nums">0</p><p class="mt-1 text-xs leading-5 text-ink-muted">Комнат</p></div>
    </article>
  </section>
  <div class="grid gap-4 lg:grid-cols-2">
    <section class="flex flex-col rounded-2xl border border-line bg-surface p-5" id="ratings">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h2 class="text-lg font-semibold tracking-tight">Мои оценки</h2>
        <%= link_to "Все оценки →", ratings_path, class: "inline-flex min-h-11 items-center text-sm font-medium text-brand-ink hover:text-brand-ink-hover" %>
      </div>
      <div class="mb-4 mt-3 flex items-start gap-3">
        <span class="grid size-10 shrink-0 place-items-center rounded-xl bg-brand-soft text-brand-ink"><%= ui_icon(:film) %></span>
        <div>
          <h3 class="text-sm font-semibold">Здесь будет ваша киноколлекция</h3>
          <p class="mt-1 text-sm leading-6 text-ink-muted">Оцените знакомые фильмы — рекомендации станут точнее.</p>
        </div>
      </div>
      <div class="mt-auto flex flex-wrap items-center gap-3">
        <%= link_to "Оценить фильм", movies_path, class: ui_button_classes(:secondary) %>
        <%= link_to "Подобрать фильмы", recommendations_path, class: "inline-flex min-h-11 items-center text-sm font-medium text-brand-ink hover:text-brand-ink-hover" %>
      </div>
    </section>
    <section class="flex flex-col rounded-2xl border border-line bg-surface p-5" id="rooms">
      <div class="flex flex-wrap items-center justify-between gap-2">
        <h2 class="text-lg font-semibold tracking-tight">Мои комнаты</h2>
        <%= link_to "Все комнаты →", rooms_path, class: "inline-flex min-h-11 items-center text-sm font-medium text-brand-ink hover:text-brand-ink-hover" %>
      </div>
      <div class="mb-4 mt-3 flex items-start gap-3">
        <span class="grid size-10 shrink-0 place-items-center rounded-xl bg-brand-soft text-brand-ink"><%= ui_icon(:users) %></span>
        <div>
          <h3 class="text-sm font-semibold">Выбор фильма всей компанией</h3>
          <p class="mt-1 text-sm leading-6 text-ink-muted">Пригласите друзей и найдите фильм для всей компании.</p>
        </div>
      </div>
      <div class="mt-auto">
        <%= link_to "Перейти в комнату", current_room_path, class: ui_button_classes(:secondary) %>
      </div>
    </section>
  </div>
  <footer class="mt-5 flex flex-wrap justify-between gap-2 text-xs text-ink-muted">
    <span>MovieRecommender</span><span>Хорошее кино — ещё лучше вместе</span>
  </footer>
</main>
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/views/profiles/show.html.erb:2) — `render "shared/header"`. Подключает навигацию и текущего пользователя. shared/flash показывает сообщения, например после регистрации.

- [Строка 9](C:/Ruby/movie_recommender/app/views/profiles/show.html.erb:9) — `new_room_path`. Кнопка 'Создать комнату' пока открывает форму, а не создаёт запись.

- [Строка 12](C:/Ruby/movie_recommender/app/views/profiles/show.html.erb:12) — `movies_path`. Кнопка поиска ведёт в уже работающий каталог TMDB.

- [Строка 17](C:/Ruby/movie_recommender/app/views/profiles/show.html.erb:17) — `aria-label="Моя активность"`. Три карточки статистики. 0, тире и 0 написаны буквально в шаблоне; здесь нет Current.user.ratings.count или расчёта среднего.

- [Строка 32](C:/Ruby/movie_recommender/app/views/profiles/show.html.erb:32) — `id="ratings"`. Блок объясняет будущую киноколлекцию. ratings_path открывает отдельное пустое состояние; recommendations_path — экран формы подбора.

- [Строка 49](C:/Ruby/movie_recommender/app/views/profiles/show.html.erb:49) — `id="rooms"`. Блок будущих комнат. rooms_path ведёт к списку, current_room_path — к экрану без загрузки записи.

- [Строка 31](C:/Ruby/movie_recommender/app/views/profiles/show.html.erb:31) — `lg:grid-cols-2`. На достаточно широком экране два смысловых блока располагаются рядом; на узком остаются одной колонкой.


<a id="file-025"></a>

## 25. Каталог: форма, ошибка, пустой результат и карточки

[Открыть app/views/movies/index.html.erb](C:/Ruby/movie_recommender/app/views/movies/index.html.erb)

Одно представление для популярных фильмов и результатов поиска.

~~~~erb
<main class="mx-auto max-w-6xl px-5 py-6 sm:px-8 sm:py-10">
  <%= render "shared/header" %>
  <%= render "shared/flash" %>
  <header class="mb-7">
    <p class="mb-3 text-xs font-semibold tracking-widest text-brand-ink">КАТАЛОГ ФИЛЬМОВ</p>
    <h1 class="text-3xl font-bold tracking-tight sm:text-4xl">Найдём, что посмотреть</h1>
    <p class="mt-3 text-sm leading-6 text-ink-muted">Выберите что-нибудь из популярных фильмов или найдите фильм по названию.</p>
  </header>
  <%= form_with url: movies_path, method: :get, class: "rounded-2xl border border-line bg-surface p-5 shadow-sm" do |form| %>
    <%= form.label :query, "Название фильма", class: ui_label_classes %>
    <div class="flex flex-col gap-3 sm:flex-row">
      <%= form.search_field :query, value: @query, required: true, autofocus: true, placeholder: "Например, Интерстеллар", autocomplete: "off", class: class_names(ui_input_classes, "min-w-0 sm:flex-1") %>
      <%= form.submit "Найти фильмы", class: class_names(ui_button_classes, "shrink-0 cursor-pointer") %>
    </div>
  <% end %>
  <% if @error_message %>
    <p class="mt-6 rounded-xl border border-rose-800/60 bg-rose-950/40 p-4 text-sm text-rose-200" role="alert"><%= @error_message %></p>
  <% elsif @movies.blank? %>
    <section class="mt-6 rounded-2xl border border-dashed border-line-strong bg-surface px-5 py-12 text-center">
      <%= ui_icon(:search, classes: "mx-auto size-8 text-brand-ink") %>
      <h2 class="mt-3 text-lg font-semibold"><%= @query.present? ? "Ничего не найдено" : "Фильмы пока не загрузились" %></h2>
      <p class="mt-2 text-sm text-ink-muted"><%= @query.present? ? "По запросу «#{@query}» нет результатов. Попробуйте другое название." : "Попробуйте открыть каталог чуть позже." %></p>
    </section>
  <% else %>
    <div class="mb-4 mt-8">
      <h2 class="text-xl font-semibold tracking-tight"><%= @section_title %></h2>
      <% if @query.present? %><p class="mt-1 text-sm text-ink-muted">Запрос: «<%= @query %>»</p><% end %>
    </div>
    <section class="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-5 lg:grid-cols-4" aria-label="Результаты поиска фильмов">
      <% @movies.each do |movie| %>
        <%= render "movie_card", movie: movie %>
      <% end %>
    </section>
  <% end %>
  <%= render "tmdb_attribution" %>
</main>
~~~~

**Разбор значимых строк и блоков**

- [Строка 9](C:/Ruby/movie_recommender/app/views/movies/index.html.erb:9) — `form_with url: movies_path, method: :get`. Отправляет строку query параметром адреса. Название метода get соответствует чтению, поэтому ссылку можно повторно открыть.

- [Строка 12](C:/Ruby/movie_recommender/app/views/movies/index.html.erb:12) — `form.search_field`. Поле поиска с введённым @query. required не позволяет обычной отправкой послать пустое поле, но прямой GET /movies всё равно показывает популярное.

- [Строка 16](C:/Ruby/movie_recommender/app/views/movies/index.html.erb:16) — `if @error_message`. Первой проверяется ошибка: в этом случае не пытаемся обходить незагруженный массив.

- [Строка 18](C:/Ruby/movie_recommender/app/views/movies/index.html.erb:18) — `elsif @movies.blank?`. blank? истинно для nil и пустого массива. Пустой результат поиска отличается от не загрузившегося списка популярных через @query.present?.

- [Строка 26](C:/Ruby/movie_recommender/app/views/movies/index.html.erb:26) — `@section_title`. Заголовок определяется контроллером и отражает источник списка.

- [Строка 30](C:/Ruby/movie_recommender/app/views/movies/index.html.erb:30) — `@movies.each do |movie|`. Перебирает массив хешей TMDB. movie — локальная переменная одной итерации.

- [Строка 31](C:/Ruby/movie_recommender/app/views/movies/index.html.erb:31) — `render "movie_card", movie: movie`. Передаёт текущий хеш в частичный шаблон. Повторно используется структура одной карточки.

- [Строка 29](C:/Ruby/movie_recommender/app/views/movies/index.html.erb:29) — `grid-cols-2`. Адаптивная сетка: базово 2 колонки, sm — 3, lg — 4. gap задаёт расстояние между карточками.

- [Строка 35](C:/Ruby/movie_recommender/app/views/movies/index.html.erb:35) — `render "tmdb_attribution"`. Внизу общий блок источника данных.


<a id="file-026"></a>

## 26. Одна карточка фильма

[Открыть app/views/movies/_movie_card.html.erb](C:/Ruby/movie_recommender/app/views/movies/_movie_card.html.erb)

Получает локальный movie из render и строит ссылку на подробности.

~~~~erb
<article class="group overflow-hidden rounded-2xl border border-line bg-surface shadow-xs transition hover:shadow-md motion-safe:hover:-translate-y-1 motion-reduce:transition-none">
  <%= link_to movie_path(movie["id"]), class: "block h-full focus-visible:outline-2 focus-visible:outline-offset-[-2px] focus-visible:outline-brand-300" do %>
    <% if movie["poster_path"].present? %>
      <%= image_tag "https://image.tmdb.org/t/p/w342#{movie['poster_path']}", alt: "Постер фильма «#{movie['title']}»", class: "block aspect-[2/3] w-full bg-surface-raised object-cover", loading: "lazy" %>
    <% else %>
      <div class="grid aspect-[2/3] w-full place-content-center bg-gradient-to-br from-surface-raised to-brand-soft p-3 text-center text-sm text-ink-muted" aria-label="Постер отсутствует">Постер<br>отсутствует</div>
    <% end %>
    <div class="p-3 sm:p-4">
      <h3 class="line-clamp-2 text-sm font-semibold leading-5 text-ink group-hover:text-brand-ink-hover sm:text-base"><%= movie["title"].presence || movie["original_title"] %></h3>
      <% year = movie["release_date"].to_s.first(4) %>
      <div class="mt-2 flex flex-wrap items-center gap-2 text-xs text-ink-muted">
        <% if year.present? %><span><%= year %></span><% end %>
        <% if movie["vote_average"].to_s.to_f.positive? %><span class="inline-flex items-center gap-1 rounded-md bg-amber-950/40 px-1.5 py-0.5 font-medium text-amber-200"><%= ui_icon(:star, classes: "size-3.5") %> <%= number_with_precision(movie["vote_average"], precision: 1) %></span><% end %>
      </div>
      <p class="mt-3 line-clamp-3 text-xs leading-5 text-ink-muted sm:text-sm"><%= movie["overview"].presence || "Описание пока недоступно." %></p>
    </div>
  <% end %>
</article>
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/views/movies/_movie_card.html.erb:1) — `class="group`. group позволяет дочерним элементам реагировать на наведение на всю карточку. motion-safe ограничивает декоративное движение настройкой пользователя, motion-reduce отключает переход.

- [Строка 2](C:/Ruby/movie_recommender/app/views/movies/_movie_card.html.erb:2) — `link_to movie_path(movie["id"])`. Вся карточка становится ссылкой на ID из ответа TMDB. movie_path берёт внешний ID; локальной записи Movie пока нет.

- [Строка 3](C:/Ruby/movie_recommender/app/views/movies/_movie_card.html.erb:3) — `movie["poster_path"].present?`. Проверяет путь постера. При наличии собирается URL изображения w342; иначе показывается текстовая заглушка.

- [Строка 4](C:/Ruby/movie_recommender/app/views/movies/_movie_card.html.erb:4) — `loading: "lazy"`. Разрешает браузеру отложить загрузку изображения вне ближайшей видимой области. aspect-[2/3] резервирует пропорции; object-cover заполняет область с возможной обрезкой.

- [Строка 9](C:/Ruby/movie_recommender/app/views/movies/_movie_card.html.erb:9) — `movie["title"].presence ||`. presence возвращает значение, если оно не пустое, иначе nil. || выбирает запасное оригинальное название.

- [Строка 10](C:/Ruby/movie_recommender/app/views/movies/_movie_card.html.erb:10) — `movie["release_date"].to_s.first(4)`. Для обычной строки даты YYYY-MM-DD берёт год. to_s не даёт упасть при nil; полноценного разбора даты здесь нет.

- [Строка 13](C:/Ruby/movie_recommender/app/views/movies/_movie_card.html.erb:13) — `to_s.to_f.positive?`. Показывает рейтинг только при положительном числовом значении. Это значение TMDB, не личная оценка.

- [Строка 13](C:/Ruby/movie_recommender/app/views/movies/_movie_card.html.erb:13) — `number_with_precision`. Форматирует рейтинг с одним знаком после разделителя. line-clamp ограничивает число строк текста, чтобы длинное описание не растягивало карточку.

- [Строка 15](C:/Ruby/movie_recommender/app/views/movies/_movie_card.html.erb:15) — `movie["overview"].presence`. При отсутствии описания выводит запасной текст.


<a id="file-027"></a>

## 27. Подробная страница фильма

[Открыть app/views/movies/show.html.erb](C:/Ruby/movie_recommender/app/views/movies/show.html.erb)

Один шаблон отображает любой фильм, загруженный действием show.

~~~~erb
<main class="mx-auto max-w-6xl px-5 py-6 sm:px-8 sm:py-10">
  <%= render "shared/header" %>
  <%= render "shared/flash" %>
  <%= link_to "← Назад к фильмам", movies_path, class: "mb-6 inline-flex min-h-11 items-center text-sm font-medium text-ink-muted hover:text-brand-ink-hover" %>
  <% if @error_message %>
    <p class="rounded-xl border border-rose-800/60 bg-rose-950/40 p-4 text-sm text-rose-200" role="alert"><%= @error_message %></p>
  <% else %>
    <article class="grid items-start gap-7 rounded-3xl border border-line bg-surface p-5 shadow-sm sm:p-8 md:grid-cols-[minmax(200px,300px)_minmax(0,1fr)]">
      <% if @movie["poster_path"].present? %>
        <%= image_tag "https://image.tmdb.org/t/p/w500#{@movie['poster_path']}", alt: "Постер фильма «#{@movie['title']}»", class: "mx-auto block aspect-[2/3] w-full max-w-72 rounded-2xl bg-surface-raised object-cover md:max-w-none" %>
      <% else %>
        <div class="mx-auto grid aspect-[2/3] w-full max-w-72 place-content-center rounded-2xl bg-gradient-to-br from-surface-raised to-brand-soft text-center text-sm text-ink-muted md:max-w-none" aria-label="Постер отсутствует">Постер<br>отсутствует</div>
      <% end %>
      <div class="min-w-0">
        <p class="mb-3 text-xs font-semibold tracking-widest text-brand-ink">ИНФОРМАЦИЯ О ФИЛЬМЕ</p>
        <h1 class="break-words text-3xl font-bold tracking-tight sm:text-4xl"><%= @movie["title"] %></h1>
        <% if @movie["original_title"].present? && @movie["original_title"] != @movie["title"] %>
          <p class="mt-2 text-sm text-ink-muted"><%= @movie["original_title"] %></p>
        <% end %>
        <div class="mt-5 flex flex-wrap items-center gap-3 text-sm text-ink-muted">
          <% year = @movie["release_date"].to_s.first(4) %>
          <% if year.present? %><span><%= year %></span><% end %>
          <% if @movie["runtime"].present? %><span><%= @movie["runtime"] %> мин.</span><% end %>
          <% if @movie["vote_average"].to_s.to_f.positive? %>
            <span class="inline-flex items-center gap-1.5 rounded-lg bg-amber-950/40 px-2.5 py-1 font-medium text-amber-200"><%= ui_icon(:star, classes: "size-4") %> <%= number_with_precision(@movie["vote_average"], precision: 1) %> / 10 на TMDB</span>
          <% end %>
        </div>
        <% if @movie["genres"].present? %>
          <ul class="mt-5 flex flex-wrap gap-2" aria-label="Жанры">
            <% @movie["genres"].each do |genre| %><li class="rounded-full bg-brand-soft px-3 py-1.5 text-xs font-medium text-brand-ink"><%= genre["name"] %></li><% end %>
          </ul>
        <% end %>
        <section class="mt-8 border-t border-line pt-6">
          <h2 class="text-lg font-semibold">Описание</h2>
          <p class="mt-3 text-sm leading-7 text-ink-secondary sm:text-base"><%= @movie["overview"].presence || "Описание пока недоступно." %></p>
        </section>
        <%= render "rating_form" %>
      </div>
    </article>
  <% end %>
  <%= render "tmdb_attribution" %>
</main>
~~~~

**Разбор значимых строк и блоков**

- [Строка 5](C:/Ruby/movie_recommender/app/views/movies/show.html.erb:5) — `if @error_message`. При ошибке выводится сообщение, остальная карточка не строится. Без этой ветки чтение @movie[...] могло бы упасть при незагруженном фильме.

- [Строка 8](C:/Ruby/movie_recommender/app/views/movies/show.html.erb:8) — `md:grid-cols-[minmax(200px,300px)_minmax(0,1fr)]`. На широком экране две колонки: постер от 200 до 300 px и оставшаяся часть. minmax(0,1fr) разрешает текстовой колонке сжиматься без переполнения.

- [Строка 10](C:/Ruby/movie_recommender/app/views/movies/show.html.erb:10) — `@movie['poster_path']`. Детальная страница использует больший вариант постера w500. Заглушка сохраняет то же соотношение сторон.

- [Строка 17](C:/Ruby/movie_recommender/app/views/movies/show.html.erb:17) — `@movie["original_title"].present? &&`. && требует одновременно непустое оригинальное название и отличие от локализованного. Это убирает бессмысленное повторение одинаковых названий.

- [Строка 21](C:/Ruby/movie_recommender/app/views/movies/show.html.erb:21) — `@movie["release_date"].to_s.first(4)`. Год берётся тем же приёмом, что в карточке.

- [Строка 23](C:/Ruby/movie_recommender/app/views/movies/show.html.erb:23) — `@movie["runtime"].present?`. Показывает длительность, если поле считается непустым. Это не проверка положительного числа: 0 в Rails present?.

- [Строка 25](C:/Ruby/movie_recommender/app/views/movies/show.html.erb:25) — `number_with_precision`. Общий рейтинг подписан '/ 10 на TMDB', чтобы не смешивать с собственной оценкой пользователя.

- [Строка 30](C:/Ruby/movie_recommender/app/views/movies/show.html.erb:30) — `@movie["genres"].each`. Массив жанров превращается в список ul/li; genre["name"] берётся из вложенного хеша.

- [Строка 35](C:/Ruby/movie_recommender/app/views/movies/show.html.erb:35) — `@movie["overview"].presence`. Описание с запасным текстом. ERB экранирует внешний текст как обычную строку.

- [Строка 37](C:/Ruby/movie_recommender/app/views/movies/show.html.erb:37) — `render "rating_form"`. Вставляет отдельный компонент своей оценки. Он отображается только при успешно загруженном фильме.


<a id="file-028"></a>

## 28. Шкала личной оценки и два обработчика на одной форме

[Открыть app/views/movies/_rating_form.html.erb](C:/Ruby/movie_recommender/app/views/movies/_rating_form.html.erb)

Выбор 1–10 уже работает в браузере, серверное сохранение отсутствует.

~~~~erb
<section class="mt-8 rounded-2xl border border-brand-line bg-brand-soft/50 p-4 sm:p-5" aria-labelledby="personal-rating-heading">
  <div class="mb-4 flex flex-wrap items-center justify-between gap-2">
    <h2 id="personal-rating-heading" class="text-lg font-semibold">Ваша оценка</h2>
    <span class="text-xs text-ink-muted">Личный вкус, а не рейтинг TMDB</span>
  </div>
  <%= form_with url: "#", method: :get, data: { controller: "rating pending-action", action: "submit->pending-action#submit input->pending-action#clear", pending_action_message_value: "Сохранение оценок пока недоступно.", turbo: false } do |form| %>
    <fieldset>
      <legend class="mb-3 text-sm text-ink-secondary">Как вам этот фильм? Выберите от 1 до 10.</legend>
      <div class="grid grid-cols-4 gap-2 sm:grid-cols-5 xl:grid-cols-10">
        <% (1..10).each do |score| %>
          <div class="min-w-0">
            <%= form.radio_button :score, score, required: true, class: "peer sr-only", data: { action: "change->rating#select" } %>
            <%= form.label :score, score, value: score, class: "grid min-h-11 cursor-pointer place-items-center rounded-lg border border-line bg-surface text-sm font-semibold text-ink-secondary transition hover:border-brand-300 hover:bg-brand-soft peer-checked:border-brand-600 peer-checked:bg-brand-600 peer-checked:text-white peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-brand-300" %>
          </div>
        <% end %>
      </div>
    </fieldset>
    <div class="mt-4 flex flex-wrap items-center justify-between gap-3">
      <p class="text-sm font-medium text-ink-secondary" aria-live="polite" data-rating-target="value">Оценка не выбрана</p>
      <%= form.button "Сохранить оценку", type: :submit, disabled: true, class: class_names(ui_button_classes, "cursor-pointer"), data: { pending_action_target: "submit" } %>
    </div>
    <p hidden class="mt-4 rounded-xl border border-amber-800/60 bg-amber-950/40 px-4 py-3 text-sm text-amber-200" role="status" data-pending-action-target="status"></p>
  <% end %>
</section>
~~~~

**Разбор значимых строк и блоков**

- [Строка 6](C:/Ruby/movie_recommender/app/views/movies/_rating_form.html.erb:6) — `form_with url: "#"`. Временный адрес, GET и turbo:false. Это не готовый маршрут сохранения. pending-action перехватывает отправку.

- [Строка 6](C:/Ruby/movie_recommender/app/views/movies/_rating_form.html.erb:6) — `controller: "rating pending-action"`. На одном DOM-элементе подключены два Stimulus-контроллера. rating отвечает за подпись выбранного числа, pending-action — за сообщение при отправке.

- [Строка 6](C:/Ruby/movie_recommender/app/views/movies/_rating_form.html.erb:6) — `submit->pending-action#submit input->pending-action#clear`. submit вызывает обработчик заглушки; изменение ввода скрывает старое сообщение. Эти строки превращаются Rails в HTML data-action.

- [Строка 7](C:/Ruby/movie_recommender/app/views/movies/_rating_form.html.erb:7) — `<fieldset>`. Группирует радиокнопки, legend задаёт доступный общий вопрос. required требует выбрать вариант.

- [Строка 10](C:/Ruby/movie_recommender/app/views/movies/_rating_form.html.erb:10) — `(1..10).each do |score|`. Диапазон Ruby включает обе границы. Из одного блока генерируются десять вариантов, а не десять вручную написанных полей.

- [Строка 12](C:/Ruby/movie_recommender/app/views/movies/_rating_form.html.erb:12) — `form.radio_button :score`. Все radio имеют одно имя score и разные значения; браузер даёт выбрать только один. sr-only скрывает визуальное представление, сохраняя доступность.

- [Строка 12](C:/Ruby/movie_recommender/app/views/movies/_rating_form.html.erb:12) — `change->rating#select`. При выборе конкретного radio вызывается select с событием. event.target.value содержит выбранное значение.

- [Строка 13](C:/Ruby/movie_recommender/app/views/movies/_rating_form.html.erb:13) — `peer-checked:`. Классы label зависят от состояния соседнего radio с class=peer. Это CSS-состояние, не отдельный JavaScript, который раскрашивает каждую кнопку.

- [Строка 19](C:/Ruby/movie_recommender/app/views/movies/_rating_form.html.erb:19) — `data-rating-target="value"`. Именованная цель value доступна контроллеру как this.valueTarget. aria-live='polite' позволяет озвучивать обновление.

- [Строка 20](C:/Ruby/movie_recommender/app/views/movies/_rating_form.html.erb:20) — `disabled: true`. Кнопка отключена до подключения pending-action. connect() этого контроллера включает её. Без JavaScript временная форма не должна отправляться.

- [Строка 22](C:/Ruby/movie_recommender/app/views/movies/_rating_form.html.erb:22) — `data-pending-action-target="status"`. Скрытый абзац для сообщения. hidden снимается JavaScript после отправки; role=status обозначает изменение статуса.


<a id="file-029"></a>

## 29. Указание источника данных

[Открыть app/views/movies/_tmdb_attribution.html.erb](C:/Ruby/movie_recommender/app/views/movies/_tmdb_attribution.html.erb)

Общий информационный блок о происхождении каталога и постеров.

~~~~erb
<section class="mt-10 flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-line pt-5 text-xs leading-5 text-ink-muted" aria-labelledby="tmdb-credits-heading">
  <h2 id="tmdb-credits-heading" class="w-full text-sm font-semibold text-ink-secondary">Источники данных</h2>
  <%= image_tag "https://www.themoviedb.org/assets/2/v4/logos/blue_long_1.svg", alt: "The Movie Database (TMDB)", class: "h-auto w-24" %>
  <strong class="font-medium">Данные и изображения предоставлены TMDB.</strong>
  <span>This website uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB.</span>
  <%= link_to "The Movie Database", "https://www.themoviedb.org", target: "_blank", rel: "noopener", class: "font-semibold text-brand-ink hover:text-brand-ink-hover" %>
</section>
~~~~

**Разбор значимых строк и блоков**

- [Строка 3](C:/Ruby/movie_recommender/app/views/movies/_tmdb_attribution.html.erb:3) — `image_tag`. Загружает логотип по внешнему адресу и задаёт alt. Это изображение оформления, не вызов API с токеном.

- [Строка 4](C:/Ruby/movie_recommender/app/views/movies/_tmdb_attribution.html.erb:4) — `Данные и изображения`. Статический текст и английское уведомление об отсутствии одобрения со стороны TMDB. В этом разделе объясняется существующая разметка; актуальные условия использования отдельно здесь не проверялись.

- [Строка 6](C:/Ruby/movie_recommender/app/views/movies/_tmdb_attribution.html.erb:6) — `target: "_blank", rel: "noopener"`. Открывает внешний сайт в новой вкладке и ограничивает доступ открытой страницы к исходному окну.


<a id="file-030"></a>

## 30. Список комнат: пока только пустое состояние

[Открыть app/views/rooms/index.html.erb](C:/Ruby/movie_recommender/app/views/rooms/index.html.erb)

Готовая композиция списка, в которой ещё нет цикла по записям Room.

~~~~erb
<% content_for :title, "Мои комнаты — MovieRecommender" %>
<main class="mx-auto max-w-6xl px-5 py-6 sm:px-8 sm:py-10">
  <%= render "shared/header" %>
  <%= render "shared/flash" %>
  <header class="mb-8 flex flex-wrap items-end justify-between gap-5">
    <div>
      <p class="mb-3 text-xs font-semibold tracking-widest text-brand-ink">СМОТРИТЕ ВМЕСТЕ</p>
      <h1 class="text-3xl font-bold tracking-tight sm:text-4xl">Мои комнаты</h1>
      <p class="mt-3 max-w-xl text-sm leading-6 text-ink-muted">Одно место для друзей, ваших вкусов и выбора фильма на вечер.</p>
    </div>
    <%= link_to "Создать комнату", new_room_path, class: ui_button_classes %>
  </header>
  <section class="flex min-h-64 flex-col items-center justify-center rounded-3xl border border-dashed border-line-strong bg-surface px-6 py-8 text-center">
    <span class="grid size-12 place-items-center rounded-2xl bg-brand-soft text-brand-ink"><%= ui_icon(:users, classes: "size-6") %></span>
    <h2 class="mt-4 text-xl font-semibold tracking-tight">Вашей компании нужно место</h2>
    <p class="mt-3 max-w-md text-sm leading-6 text-ink-muted">Создайте комнату, пригласите друзей и выбирайте кино, которое понравится всем.</p>
    <div class="mt-6 flex flex-wrap justify-center gap-3">
      <%= link_to "Создать комнату", new_room_path, class: ui_button_classes(:secondary) %>
      <%= link_to "Перейти в комнату", current_room_path, class: ui_button_classes(:secondary) %>
    </div>
  </section>
</main>
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/views/rooms/index.html.erb:1) — `content_for :title`. Задаёт заголовок вкладки через layout. Этот вызов не выводит отдельную строку в тело страницы.

- [Строка 11](C:/Ruby/movie_recommender/app/views/rooms/index.html.erb:11) — `new_room_path`. Обе кнопки создания открывают форму new. Дублирование основной возможности в шапке и пустом состоянии помогает найти действие.

- [Строка 13](C:/Ruby/movie_recommender/app/views/rooms/index.html.erb:13) — `border-dashed`. Пунктирная карточка обозначает пустое состояние. Внутри статические пояснения, а не проверка @rooms.empty?.

- [Строка 19](C:/Ruby/movie_recommender/app/views/rooms/index.html.erb:19) — `current_room_path`. Переход к готовому экрану /room без создания записи и без выбора реальной 'текущей комнаты'.


<a id="file-031"></a>

## 31. Форма создания комнаты

[Открыть app/views/rooms/new.html.erb](C:/Ruby/movie_recommender/app/views/rooms/new.html.erb)

Представляет будущие данные name/description; отправку обслуживает заглушка.

~~~~erb
<% content_for :title, "Создать комнату — MovieRecommender" %>
<main class="mx-auto max-w-6xl px-5 py-6 sm:px-8 sm:py-10">
  <%= render "shared/header" %>
  <%= link_to "← Мои комнаты", rooms_path, class: "mb-6 inline-flex min-h-11 items-center text-sm font-medium text-ink-muted hover:text-brand-ink-hover" %>
  <div class="mx-auto max-w-2xl">
    <header class="mb-7">
      <p class="mb-3 text-xs font-semibold tracking-widest text-brand-ink">ВЕЧЕР НАЧИНАЕТСЯ ЗДЕСЬ</p>
      <h1 class="text-3xl font-bold tracking-tight sm:text-4xl">Создать комнату</h1>
      <p class="mt-3 text-sm leading-6 text-ink-muted">Дайте вашей компании место для совместного выбора кино.</p>
    </header>
    <%= form_with url: "#", method: :get, class: "space-y-6 rounded-3xl border border-line bg-surface p-6 shadow-sm sm:p-8", data: { controller: "pending-action", action: "submit->pending-action#submit input->pending-action#clear", pending_action_message_value: "Создание комнат пока недоступно.", turbo: false } do |form| %>
      <div>
        <%= form.label :name, "Название комнаты", class: ui_label_classes %>
        <%= form.text_field :name, required: true, maxlength: 80, placeholder: "Например, Кино по пятницам", class: ui_input_classes, aria: { describedby: "room-name-help" } %>
        <p id="room-name-help" class="mt-2 text-xs text-ink-muted">Название, которое узнают ваши друзья. До 80 символов.</p>
      </div>
      <div>
        <%= form.label :description, "Описание", class: ui_label_classes %>
        <%= form.text_area :description, rows: 4, maxlength: 300, placeholder: "Что вы любите смотреть вместе?", class: class_names(ui_input_classes, "resize-y"), aria: { describedby: "room-description-help" } %>
        <p id="room-description-help" class="mt-2 text-xs text-ink-muted">Необязательно. До 300 символов.</p>
      </div>
      <div class="rounded-2xl bg-brand-soft p-4">
        <h2 class="text-sm font-semibold text-brand-ink-hover">Дальше — приглашение друзей</h2>
        <p class="mt-2 text-sm leading-6 text-brand-ink">В комнате вы сможете собрать участников и подобрать фильмы с учётом вкусов всей компании.</p>
      </div>
      <div class="flex flex-col-reverse gap-3 border-t border-line pt-5 sm:flex-row sm:justify-end">
        <%= link_to "Отмена", rooms_path, class: ui_button_classes(:secondary) %>
        <%= form.button "Создать комнату", type: :submit, disabled: true, class: class_names(ui_button_classes, "cursor-pointer"), data: { pending_action_target: "submit" } %>
      </div>
      <p hidden class="rounded-xl border border-amber-800/60 bg-amber-950/40 px-4 py-3 text-sm leading-6 text-amber-200" role="status" data-pending-action-target="status"></p>
    <% end %>
    <%= link_to "Перейти на страницу комнаты →", current_room_path, class: "mt-5 inline-flex min-h-11 items-center text-sm font-medium text-brand-ink hover:text-brand-ink-hover" %>
  </div>
</main>
~~~~

**Разбор значимых строк и блоков**

- [Строка 11](C:/Ruby/movie_recommender/app/views/rooms/new.html.erb:11) — `form_with url: "#"`. Адрес временный, method:get и turbo:false. Подключён pending-action с собственным сообщением. В контроллере нет create, поэтому серверное создание здесь не выполняется.

- [Строка 14](C:/Ruby/movie_recommender/app/views/rooms/new.html.erb:14) — `form.text_field :name`. Обязательное имя с браузерным maxlength:80. aria-describedby связывает поле с пояснением room-name-help. Серверной модели с этими проверками пока нет.

- [Строка 19](C:/Ruby/movie_recommender/app/views/rooms/new.html.erb:19) — `form.text_area :description`. Необязательное многострочное описание до 300 символов на уровне HTML. rows определяет исходную высоту, resize-y разрешает изменение высоты.

- [Строка 23](C:/Ruby/movie_recommender/app/views/rooms/new.html.erb:23) — `Дальше — приглашение друзей`. Информационный блок о будущем сценарии, а не вызов отправки приглашений.

- [Строка 27](C:/Ruby/movie_recommender/app/views/rooms/new.html.erb:27) — `link_to "Отмена"`. Простой GET к списку. Ничего откатывать в базе не нужно: запись не создавалась.

- [Строка 28](C:/Ruby/movie_recommender/app/views/rooms/new.html.erb:28) — `form.button "Создать комнату"`. После включения JavaScript кнопка запускает сообщение pending-action. Она не переводит в новую сохранённую комнату.

- [Строка 30](C:/Ruby/movie_recommender/app/views/rooms/new.html.erb:30) — `data-pending-action-target="status"`. Здесь появится сообщение заглушки.

- [Строка 32](C:/Ruby/movie_recommender/app/views/rooms/new.html.erb:32) — `current_room_path`. Отдельная ссылка открывает экран комнаты для просмотра интерфейса. Это не результат успешного submit.


<a id="file-032"></a>

## 32. Комната: компоновка и переход к подбору

[Открыть app/views/rooms/show.html.erb](C:/Ruby/movie_recommender/app/views/rooms/show.html.erb)

Собирает общие элементы, форму пожеланий, место результатов и боковую колонку.

~~~~erb
<% content_for :title, "Кинокомната — MovieRecommender" %>
<main class="mx-auto max-w-6xl px-5 py-6 sm:px-8 sm:py-10">
  <%= render "shared/header" %>
  <%= link_to "← Мои комнаты", rooms_path, class: "mb-6 inline-flex min-h-11 items-center text-sm font-medium text-ink-muted hover:text-brand-ink-hover" %>
  <header class="mb-7 flex flex-wrap items-end justify-between gap-5">
    <div>
      <p class="mb-3 text-xs font-semibold tracking-widest text-brand-ink">ХОРОШЕЕ КИНО — ЛУЧШЕ ВМЕСТЕ</p>
      <h1 class="text-3xl font-bold tracking-tight sm:text-4xl">Кинокомната</h1>
      <p class="mt-3 text-sm leading-6 text-ink-muted">Соберите друзей и найдите фильм для всей компании.</p>
    </div>
    <%= render "invitation" %>
  </header>
  <div class="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_300px]">
    <div class="min-w-0 space-y-6">
      <section class="rounded-3xl border border-line bg-surface p-6 shadow-sm sm:p-8" aria-labelledby="room-selection-heading">
        <p class="mb-2 text-xs font-semibold tracking-widest text-brand-ink">ВАШ ОБЩИЙ КИНОВЕЧЕР</p>
        <h2 id="room-selection-heading" class="text-2xl font-semibold tracking-tight">Что посмотрим?</h2>
        <p class="mb-6 mt-3 text-sm leading-6 text-ink-muted">Задайте пожелания на вечер. Подбор будет учитывать оценки участников комнаты.</p>
        <%= render "shared/recommendation_form", destination: @selection_path %>
      </section>
      <section class="rounded-3xl border border-line bg-surface p-6 sm:p-8" aria-labelledby="room-results-heading">
        <h2 id="room-results-heading" class="text-xl font-semibold tracking-tight">Фильмы для компании</h2>
        <div class="flex min-h-40 flex-col items-center justify-center py-6 text-center">
          <span class="grid size-12 place-items-center rounded-2xl bg-brand-soft text-brand-ink"><%= ui_icon(:film, classes: "size-6") %></span>
          <h3 class="mt-4 font-semibold">Впереди — совместный выбор</h3>
          <p class="mt-2 max-w-sm text-sm leading-6 text-ink-muted">Здесь появятся фильмы, подходящие вашей компании. Начните с приглашения участников.</p>
        </div>
      </section>
    </div>
    <aside class="space-y-5">
      <section class="rounded-2xl border border-line bg-surface p-5" aria-labelledby="participants-heading">
        <h2 id="participants-heading" class="text-lg font-semibold">Участники</h2>
        <div class="py-7 text-center">
          <span class="mx-auto grid size-11 place-items-center rounded-full bg-surface-raised text-ink-muted"><%= ui_icon(:users) %></span>
          <p class="mt-3 text-sm font-medium text-ink-secondary">Пока никого нет</p>
          <p class="mt-2 text-xs leading-5 text-ink-muted">Пригласите друзей, чтобы выбирать кино вместе.</p>
        </div>
      </section>
      <section class="rounded-2xl border border-brand-line bg-brand-soft p-5">
        <h2 class="text-sm font-semibold text-brand-ink-hover">Больше оценок — точнее подбор</h2>
        <p class="mt-2 text-sm leading-6 text-brand-ink">Оцените знакомые фильмы, чтобы выбор учитывал ваши предпочтения.</p>
        <%= link_to "Найти фильм →", movies_path, class: "mt-4 inline-flex min-h-11 items-center text-sm font-semibold text-brand-ink hover:text-brand-ink-hover" %>
      </section>
    </aside>
  </div>
</main>
~~~~

**Разбор значимых строк и блоков**

- [Строка 11](C:/Ruby/movie_recommender/app/views/rooms/show.html.erb:11) — `render "invitation"`. Подключает rooms/_invitation.html.erb — окно приглашения и его кнопку.

- [Строка 13](C:/Ruby/movie_recommender/app/views/rooms/show.html.erb:13) — `lg:grid-cols-[minmax(0,1fr)_300px]`. На большом экране основная колонка занимает оставшееся место, боковая — 300 px. До lg блоки идут вертикально.

- [Строка 19](C:/Ruby/movie_recommender/app/views/rooms/show.html.erb:19) — `destination: @selection_path`. Передаёт общей форме адрес, вычисленный RoomsController#show. Это меняет её режим: она действительно переходит на экран selection вместо сообщения заглушки.

- [Строка 22](C:/Ruby/movie_recommender/app/views/rooms/show.html.erb:22) — `Фильмы для компании`. Результаты пока представлены статическим пустым состоянием. Нет массива рекомендаций и цикла по нему.

- [Строка 30](C:/Ruby/movie_recommender/app/views/rooms/show.html.erb:30) — `<aside`. Семантически отдельная боковая информация. Участники здесь не загружаются и не считаются; 'Пока никого нет' записано буквально.

- [Строка 42](C:/Ruby/movie_recommender/app/views/rooms/show.html.erb:42) — `movies_path`. Ссылка помогает перейти к каталогу. Пока пользователь может выбрать значение оценки на странице фильма, но постоянного накопления оценок ещё нет.


<a id="file-033"></a>

## 33. Отдельный экран подбора и возврат

[Открыть app/views/rooms/selection.html.erb](C:/Ruby/movie_recommender/app/views/rooms/selection.html.erb)

Оболочка будущего опроса внутри комнаты.

~~~~erb
<% content_for :title, "Подбор фильма в комнате — MovieRecommender" %>
<main class="mx-auto max-w-6xl px-5 py-6 sm:px-8 sm:py-10">
  <%= render "shared/header" %>
  <%= link_to "← Вернуться в комнату", @room_path, class: "mb-6 inline-flex min-h-11 items-center text-sm font-medium text-ink-muted hover:text-brand-ink-hover" %>
  <header class="mb-6">
    <p class="mb-3 text-xs font-semibold tracking-widest text-brand-ink">ВЫБИРАЕМ ВМЕСТЕ</p>
    <h1 class="text-3xl font-bold tracking-tight sm:text-4xl">Подбор фильма</h1>
    <p class="mt-3 text-sm leading-6 text-ink-muted">Найдём кино для вашей компании.</p>
  </header>
  <section class="flex min-h-64 flex-col items-center justify-center rounded-3xl border border-line bg-surface px-6 py-8 text-center sm:p-10" aria-labelledby="room-survey-heading">
    <span class="grid size-12 place-items-center rounded-2xl bg-brand-soft text-brand-ink"><%= ui_icon(:sparkles, classes: "size-6") %></span>
    <h2 id="room-survey-heading" class="mt-4 text-xl font-semibold tracking-tight">Что посмотрим вместе?</h2>
    <p class="mt-2 max-w-md text-sm leading-6 text-ink-muted">Здесь появится опрос о пожеланиях участников комнаты.</p>
    <%= link_to @room_path, class: class_names(ui_button_classes(:secondary), "mt-6") do %>
      <%= ui_icon(:close) %> Выйти из подбора
    <% end %>
  </section>
</main>
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/views/rooms/selection.html.erb:1) — `content_for :title`. Заголовок вкладки для экрана подбора.

- [Строка 4](C:/Ruby/movie_recommender/app/views/rooms/selection.html.erb:4) — `@room_path`. Обе ссылки используют адрес возврата из контроллера: либо /room, либо /rooms/:id. Поэтому сохраняется ID в переходе.

- [Строка 13](C:/Ruby/movie_recommender/app/views/rooms/selection.html.erb:13) — `Здесь появится опрос`. Сейчас вопросов, ответов, таймера и сохранённого состояния подбора нет. Перезагрузка возвращает ту же оболочку.

- [Строка 15](C:/Ruby/movie_recommender/app/views/rooms/selection.html.erb:15) — `Выйти из подбора`. Это ссылка GET назад. Она не отменяет серверную Selection и не отправляет сообщение другим участникам, потому что такой сущности пока нет.


<a id="file-034"></a>

## 34. Модальное окно приглашения

[Открыть app/views/rooms/_invitation.html.erb](C:/Ruby/movie_recommender/app/views/rooms/_invitation.html.erb)

Соединяет нативный dialog, Stimulus и форму будущего приглашения.

~~~~erb
<div data-controller="dialog" data-action="turbo:before-cache@document->dialog#close">
  <button type="button" class="<%= ui_button_classes %> cursor-pointer" data-action="dialog#open">Пригласить друзей</button>
  <dialog class="m-auto max-h-[calc(100dvh_-_2rem)] w-[calc(100%_-_2rem)] max-w-lg overflow-y-auto rounded-3xl border border-line bg-surface p-0 text-ink shadow-2xl backdrop:bg-black/60 backdrop:backdrop-blur-sm" aria-labelledby="invite-heading" data-dialog-target="panel" data-action="click->dialog#dismissBackdrop close->dialog#restoreFocus">
    <div class="flex items-start justify-between gap-4 border-b border-line p-6">
      <div>
        <h2 id="invite-heading" class="text-xl font-semibold tracking-tight">Пригласить в комнату</h2>
        <p class="mt-2 text-sm leading-6 text-ink-muted">Соберите компанию для совместного выбора кино.</p>
      </div>
      <button type="button" class="grid size-11 shrink-0 cursor-pointer place-items-center rounded-xl text-ink-muted hover:bg-surface-hover focus-visible:outline-2 focus-visible:outline-brand-300" aria-label="Закрыть приглашение" data-action="dialog#close"><%= ui_icon(:close) %></button>
    </div>
    <div class="space-y-6 p-6">
      <%= form_with url: "#", method: :get, class: "space-y-4", data: { controller: "pending-action", action: "submit->pending-action#submit input->pending-action#clear", pending_action_message_value: "Отправка приглашений пока недоступна.", turbo: false } do |form| %>
        <div>
          <%= form.label :nickname, "Никнейм друга", class: ui_label_classes %>
          <%= form.text_field :nickname, required: true, autocomplete: "off", placeholder: "Введите никнейм", class: ui_input_classes %>
        </div>
        <%= form.button "Отправить приглашение", type: :submit, disabled: true, class: class_names(ui_button_classes, "w-full cursor-pointer"), data: { pending_action_target: "submit" } %>
        <p hidden class="rounded-xl border border-amber-800/60 bg-amber-950/40 px-4 py-3 text-sm text-amber-200" role="status" data-pending-action-target="status"></p>
      <% end %>
      <div class="border-t border-line pt-5">
        <label for="invitation-link" class="<%= ui_label_classes %>">Ссылка приглашения</label>
        <div class="flex flex-col gap-3 sm:flex-row">
          <input id="invitation-link" type="text" readonly placeholder="Ссылка пока недоступна" class="<%= ui_input_classes %> min-w-0 sm:flex-1" aria-describedby="invitation-link-help">
          <button type="button" class="<%= ui_button_classes(:secondary) %> shrink-0" disabled>Копировать</button>
        </div>
        <p id="invitation-link-help" class="mt-2 text-xs leading-5 text-ink-muted">Ссылка появится после создания комнаты.</p>
      </div>
    </div>
  </dialog>
</div>
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/views/rooms/_invitation.html.erb:1) — `data-controller="dialog"`. Подключает dialog_controller.js. Событие turbo:before-cache закрывает окно перед сохранением страницы в кэш Turbo.

- [Строка 2](C:/Ruby/movie_recommender/app/views/rooms/_invitation.html.erb:2) — `data-action="dialog#open"`. Для кнопки Stimulus использует событие click по умолчанию. type=button предотвращает случайную отправку формы.

- [Строка 3](C:/Ruby/movie_recommender/app/views/rooms/_invitation.html.erb:3) — `<dialog`. Нативный элемент вызывается через showModal(). Он создаёт модальное поведение и фон backdrop, а не просто появляется за счёт CSS display.

- [Строка 3](C:/Ruby/movie_recommender/app/views/rooms/_invitation.html.erb:3) — `aria-labelledby="invite-heading"`. Имя окна берётся из видимого заголовка. data-dialog-target=panel предоставляет this.panelTarget контроллеру.

- [Строка 3](C:/Ruby/movie_recommender/app/views/rooms/_invitation.html.erb:3) — `click->dialog#dismissBackdrop close->dialog#restoreFocus`. Нажатие вне прямоугольника окна закрывает его; событие close возвращает фокус на открывшую кнопку. Escape поддерживается нативным dialog.

- [Строка 12](C:/Ruby/movie_recommender/app/views/rooms/_invitation.html.erb:12) — `form_with url: "#"`. Внутри отдельная форма pending-action с сообщением 'Отправка приглашений пока недоступна'. Она не вызывает API приглашений.

- [Строка 15](C:/Ruby/movie_recommender/app/views/rooms/_invitation.html.erb:15) — `form.text_field :nickname`. Вводится ник друга. Поле пока не ищет User и не создаёт приглашение.

- [Строка 23](C:/Ruby/movie_recommender/app/views/rooms/_invitation.html.erb:23) — `id="invitation-link"`. readonly-поле с placeholder без value. Реальная ссылка не генерируется. aria-describedby связывает пояснение.

- [Строка 24](C:/Ruby/movie_recommender/app/views/rooms/_invitation.html.erb:24) — `disabled>Копировать`. Кнопка намеренно недоступна: копировать пока нечего, логики Clipboard API здесь нет.


<a id="file-035"></a>

## 35. Экран личных оценок

[Открыть app/views/ratings/index.html.erb](C:/Ruby/movie_recommender/app/views/ratings/index.html.erb)

Показывает будущий раздел и переход к каталогу.

~~~~erb
<% content_for :title, "Мои оценки — MovieRecommender" %>
<main class="mx-auto max-w-6xl px-5 py-6 sm:px-8 sm:py-10">
  <%= render "shared/header" %>
  <header class="mb-8 flex flex-wrap items-end justify-between gap-5">
    <div>
      <p class="mb-3 text-xs font-semibold tracking-widest text-brand-ink">ВАШ ВКУС</p>
      <h1 class="text-3xl font-bold tracking-tight sm:text-4xl">Мои оценки</h1>
      <p class="mt-3 max-w-xl text-sm leading-6 text-ink-muted">Ваша личная киноколлекция. Оценивайте фильмы от 1 до 10.</p>
    </div>
    <%= link_to "Подобрать фильмы", recommendations_path, class: ui_button_classes(:secondary) %>
  </header>
  <section class="flex min-h-64 flex-col items-center justify-center rounded-3xl border border-dashed border-line-strong bg-surface px-6 py-8 text-center">
    <span class="grid size-12 place-items-center rounded-2xl bg-amber-950/40 text-amber-300"><%= ui_icon(:star, classes: "size-6") %></span>
    <h2 class="mt-4 text-xl font-semibold tracking-tight">Какие фильмы вам нравятся?</h2>
    <p class="mt-3 max-w-md text-sm leading-6 text-ink-muted">Начните со знакомого фильма. Ваши оценки помогут находить новые истории по вашему вкусу.</p>
    <%= link_to "Найти и оценить фильм", movies_path, class: class_names(ui_button_classes, "mt-6") %>
  </section>
</main>
~~~~

**Разбор значимых строк и блоков**

- [Строка 10](C:/Ruby/movie_recommender/app/views/ratings/index.html.erb:10) — `recommendations_path`. Переход к форме персонального подбора.

- [Строка 14](C:/Ruby/movie_recommender/app/views/ratings/index.html.erb:14) — `Какие фильмы вам нравятся?`. Это статическое пустое состояние, а не результат запроса текущих оценок. В файле нет @ratings.each.

- [Строка 16](C:/Ruby/movie_recommender/app/views/ratings/index.html.erb:16) — `movies_path`. Основное действие ведёт к поиску фильма; данные оценок пока не сохраняются.


<a id="file-036"></a>

## 36. Экран персонального подбора

[Открыть app/views/recommendations/show.html.erb](C:/Ruby/movie_recommender/app/views/recommendations/show.html.erb)

Использует ту же форму пожеланий, что и комната, в режиме заглушки.

~~~~erb
<% content_for :title, "Подбор фильмов — MovieRecommender" %>
<main class="mx-auto max-w-6xl px-5 py-6 sm:px-8 sm:py-10">
  <%= render "shared/header" %>
  <header class="mb-8">
    <p class="mb-3 text-xs font-semibold tracking-widest text-brand-ink">КИНО ПО ВАШЕМУ ВКУСУ</p>
    <h1 class="text-3xl font-bold tracking-tight sm:text-4xl">Что посмотреть сегодня?</h1>
    <p class="mt-3 max-w-2xl text-sm leading-6 text-ink-muted">Выберите жанр и время, которое готовы провести за фильмом. Ваши оценки помогут сделать подбор точнее.</p>
  </header>
  <section class="rounded-3xl border border-line bg-surface p-6 shadow-sm sm:p-8" aria-labelledby="selection-heading">
    <h2 id="selection-heading" class="mb-5 text-xl font-semibold tracking-tight">Пожелания на вечер</h2>
    <%= render "shared/recommendation_form" %>
  </section>
  <section class="mt-6 rounded-3xl border border-line bg-surface p-6 sm:p-8" aria-labelledby="recommendations-heading">
    <h2 id="recommendations-heading" class="text-xl font-semibold tracking-tight">Подходит вам</h2>
    <div class="flex min-h-44 flex-col items-center justify-center py-6 text-center">
      <span class="grid size-12 place-items-center rounded-2xl bg-brand-soft text-brand-ink"><%= ui_icon(:sparkles, classes: "size-6") %></span>
      <h3 class="mt-4 font-semibold">Следующий любимый фильм — впереди</h3>
      <p class="mt-2 max-w-md text-sm leading-6 text-ink-muted">Здесь появится ваша подборка. А пока можно найти знакомые фильмы и оценить их.</p>
      <%= link_to "Перейти к фильмам", movies_path, class: class_names(ui_button_classes(:secondary), "mt-5") %>
    </div>
  </section>
</main>
~~~~

**Разбор значимых строк и блоков**

- [Строка 11](C:/Ruby/movie_recommender/app/views/recommendations/show.html.erb:11) — `render "shared/recommendation_form"`. Здесь destination не передаётся, поэтому общая форма выбирает pending-action вместо настоящего перехода.

- [Строка 14](C:/Ruby/movie_recommender/app/views/recommendations/show.html.erb:14) — `Подходит вам`. Место для результатов пока статическое. Нет ранжирования и обращения к сервису рекомендаций.

- [Строка 19](C:/Ruby/movie_recommender/app/views/recommendations/show.html.erb:19) — `movies_path`. Ссылка выводит из пустого результата обратно в каталог.


<a id="file-037"></a>

## 37. Общая форма в двух режимах

[Открыть app/views/shared/_recommendation_form.html.erb](C:/Ruby/movie_recommender/app/views/shared/_recommendation_form.html.erb)

Один компонент применяется в персональном подборе и в комнате.

~~~~erb
<% destination = local_assigns[:destination] %>
<% form_data = destination.present? ? {} : { controller: "pending-action", action: "submit->pending-action#submit input->pending-action#clear", pending_action_message_value: "Подбор фильмов пока недоступен. Попробуйте позже.", turbo: false } %>
<%= form_with url: destination.presence || "#", method: :get, class: "space-y-5", data: form_data do |form| %>
  <div class="grid gap-4 sm:grid-cols-2">
    <div>
      <%= form.label :genre, "Жанр", class: ui_label_classes %>
      <%= form.select :genre, [ [ "Любой жанр", "" ], [ "Комедия", "comedy" ], [ "Драма", "drama" ], [ "Фантастика", "science_fiction" ], [ "Триллер", "thriller" ], [ "Приключения", "adventure" ], [ "Мультфильм", "animation" ] ], {}, class: ui_input_classes %>
    </div>
    <div>
      <%= form.label :duration, "Продолжительность", class: ui_label_classes %>
      <%= form.select :duration, [ [ "Неважно", "" ], [ "До 90 минут", "90" ], [ "До 2 часов", "120" ], [ "До 3 часов", "180" ] ], {}, class: ui_input_classes %>
    </div>
  </div>
  <label class="flex items-start gap-3 text-sm leading-6 text-ink-secondary">
    <%= form.check_box :exclude_watched, { checked: true, class: "mt-1 size-4 shrink-0 accent-brand-600" }, "1", "0" %>
    Не показывать просмотренные фильмы
  </label>
  <%= form.button "Подобрать фильмы", type: :submit, disabled: destination.blank?, class: class_names(ui_button_classes, "w-full cursor-pointer sm:w-auto"), data: destination.present? ? {} : { pending_action_target: "submit" } %>
  <% if destination.blank? %>
    <p hidden class="rounded-xl border border-amber-800/60 bg-amber-950/40 px-4 py-3 text-sm leading-6 text-amber-200" role="status" data-pending-action-target="status"></p>
  <% end %>
<% end %>
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/views/shared/_recommendation_form.html.erb:1) — `destination = local_assigns[:destination]`. local_assigns — хеш локальных параметров partial. При отсутствии ключа получим nil. Это позволяет не требовать destination от каждого вызова render.

- [Строка 2](C:/Ruby/movie_recommender/app/views/shared/_recommendation_form.html.erb:2) — `form_data = destination.present? ?`. Тернарное выражение выбирает data-атрибуты. При адресе назначения — пустой хеш; без адреса — подключение pending-action, действия и сообщение.

- [Строка 3](C:/Ruby/movie_recommender/app/views/shared/_recommendation_form.html.erb:3) — `destination.presence || "#"`. Форма использует переданный адрес либо временный #. method:get означает переход с параметрами. turbo:false задан только в режиме заглушки.

- [Строка 7](C:/Ruby/movie_recommender/app/views/shared/_recommendation_form.html.erb:7) — `form.select :genre`. Массив пар ['Комедия','comedy']: первое — видимый текст, второе — отправляемое значение. Это наши условные строки, не числовые genre ID TMDB; преобразования в параметры TMDB пока нет.

- [Строка 11](C:/Ruby/movie_recommender/app/views/shared/_recommendation_form.html.erb:11) — `form.select :duration`. Видимые ограничения представлены значениями '90', '120', '180' и пустой строкой. Сейчас они никуда не применяются.

- [Строка 15](C:/Ruby/movie_recommender/app/views/shared/_recommendation_form.html.erb:15) — `form.check_box :exclude_watched`. Значения '1' и '0' передаются для выбранного и невыбранного состояния. Rails генерирует и служебное скрытое поле, чтобы невыбранный checkbox тоже имел значение в отправке.

- [Строка 18](C:/Ruby/movie_recommender/app/views/shared/_recommendation_form.html.erb:18) — `disabled: destination.blank?`. Без destination кнопка стартует отключённой и включается pending-action. При destination сразу доступна и форма идёт на реальный экран.

- [Строка 19](C:/Ruby/movie_recommender/app/views/shared/_recommendation_form.html.erb:19) — `if destination.blank?`. Абзац status создаётся только для режима заглушки. В режиме перехода он не нужен.

- [Строка 18](C:/Ruby/movie_recommender/app/views/shared/_recommendation_form.html.erb:18) — `data: destination.present?`. Так же условно добавляется submit-target. Это сохраняет одну разметку формы для двух сценариев. Но будущий настоящий запуск, создающий запись, должен получить серверный обработчик изменения данных, а не оставаться этим GET-переходом.


<a id="file-038"></a>

## 38. Немодальная панель уведомлений

[Открыть app/views/shared/_notifications.html.erb](C:/Ruby/movie_recommender/app/views/shared/_notifications.html.erb)

Колокольчик открывает управляемую с клавиатуры панель; настоящих приглашений в ней пока нет.

~~~~erb
<div class="relative" data-controller="notifications" data-action="click@document->notifications#dismissOutside focusin@document->notifications#dismissOutside keydown.esc@document->notifications#dismissWithEscape resize@window->notifications#position turbo:before-cache@document->notifications#close">
  <button type="button" class="grid size-11 cursor-pointer place-items-center rounded-xl border border-line bg-surface text-ink-secondary transition hover:bg-surface-hover hover:text-brand-ink-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-300 aria-expanded:border-brand-300 aria-expanded:bg-brand-soft aria-expanded:text-brand-ink" aria-label="Уведомления" aria-haspopup="dialog" aria-expanded="false" aria-controls="notifications-panel" data-notifications-target="trigger" data-action="notifications#toggle">
    <%= ui_icon(:bell) %>
  </button>
  <section id="notifications-panel" hidden role="dialog" aria-modal="false" aria-labelledby="notifications-heading" tabindex="-1" class="absolute top-full z-50 mt-3 w-[min(24rem,calc(100vw_-_2rem))] overflow-hidden rounded-2xl border border-line bg-surface text-ink shadow-xl shadow-black/30 focus:outline-none" data-notifications-target="panel">
    <div class="flex items-center justify-between gap-3 border-b border-line px-5 py-3">
      <h2 id="notifications-heading" class="text-base font-semibold">Уведомления</h2>
      <button type="button" class="grid size-11 shrink-0 cursor-pointer place-items-center rounded-xl text-ink-muted hover:bg-surface-hover focus-visible:outline-2 focus-visible:outline-brand-300" aria-label="Закрыть уведомления" data-action="notifications#dismiss"><%= ui_icon(:close) %></button>
    </div>
    <div class="max-h-[min(24rem,60dvh)] overflow-y-auto px-5 py-8 text-center">
      <p class="text-sm font-semibold text-ink">Пока нет приглашений</p>
      <p class="mt-2 text-sm leading-6 text-ink-muted">Здесь появятся приглашения в комнаты. Вы сможете принять или отклонить приглашение.</p>
    </div>
  </section>
</div>
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/views/shared/_notifications.html.erb:1) — `data-controller="notifications"`. На контейнер навешиваются обработчики: click и focusin всего документа, Escape, resize окна и событие кэширования Turbo. @document/@window меняют источник события.

- [Строка 2](C:/Ruby/movie_recommender/app/views/shared/_notifications.html.erb:2) — `aria-haspopup="dialog"`. Кнопка объявляет наличие панели, aria-controls указывает её ID, aria-expanded отражает открытое состояние. CSS aria-expanded: меняет вид активной кнопки.

- [Строка 2](C:/Ruby/movie_recommender/app/views/shared/_notifications.html.erb:2) — `data-action="notifications#toggle"`. click по кнопке вызывает toggle. data-notifications-target=trigger даёт доступ к ней из JavaScript.

- [Строка 5](C:/Ruby/movie_recommender/app/views/shared/_notifications.html.erb:5) — `hidden role="dialog" aria-modal="false"`. Это section, а не нативный dialog. Панель немодальная: не блокирует всю страницу и закрывается при уходе взаимодействия наружу. tabindex=-1 позволяет программно сфокусировать контейнер.

- [Строка 5](C:/Ruby/movie_recommender/app/views/shared/_notifications.html.erb:5) — `w-[min(24rem,calc(100vw_-_2rem))]`. Произвольное CSS-значение Tailwind: ширина не больше 24rem и не больше ширины экрана минус 2rem. max-height и overflow-y-auto ограничивают высоту и включают прокрутку.

- [Строка 11](C:/Ruby/movie_recommender/app/views/shared/_notifications.html.erb:11) — `Пока нет приглашений`. Текст написан в шаблоне без чтения базы, подписки на канал или fetch-запросов.

- [Строка 1](C:/Ruby/movie_recommender/app/views/shared/_notifications.html.erb:1) — `notifications#dismiss`. Кнопка закрытия скрывает панель и возвращает фокус на колокольчик.


<a id="file-039"></a>

## 39. Точка входа JavaScript

[Открыть app/javascript/application.js](C:/Ruby/movie_recommender/app/javascript/application.js)

Модуль, с которого браузер подключает клиентское поведение.

~~~~javascript
// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/javascript/application.js:2) — `import "@hotwired/turbo-rails"`. Подключает Turbo для переходов и форм без обязательной полной перезагрузки документа. Это не преобразует серверные шаблоны в React.

- [Строка 3](C:/Ruby/movie_recommender/app/javascript/application.js:3) — `import "controllers"`. Загружает модуль регистрации Stimulus-контроллеров через importmap.


<a id="file-040"></a>

## 40. Запуск Stimulus

[Открыть app/javascript/controllers/application.js](C:/Ruby/movie_recommender/app/javascript/controllers/application.js)

Создаёт одно клиентское приложение Stimulus.

~~~~javascript
import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

export { application }
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/javascript/controllers/application.js:1) — `import { Application }`. Именованный импорт класса Application из библиотеки.

- [Строка 3](C:/Ruby/movie_recommender/app/javascript/controllers/application.js:3) — `Application.start()`. Запускает наблюдение за DOM и подключение контроллеров по data-controller.

- [Строка 6](C:/Ruby/movie_recommender/app/javascript/controllers/application.js:6) — `application.debug = false`. Отключает подробный режим отладочных сообщений Stimulus.

- [Строка 7](C:/Ruby/movie_recommender/app/javascript/controllers/application.js:7) — `window.Stimulus`. Публикует ссылку в браузерном window для диагностики; это не токен и не пользовательская авторизация.

- [Строка 9](C:/Ruby/movie_recommender/app/javascript/controllers/application.js:9) — `export { application }`. Позволяет index.js импортировать тот же запущенный экземпляр.


<a id="file-041"></a>

## 41. Автоматическая регистрация контроллеров

[Открыть app/javascript/controllers/index.js](C:/Ruby/movie_recommender/app/javascript/controllers/index.js)

Связывает файлы *_controller.js и имена в HTML.

~~~~javascript
// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/javascript/controllers/index.js:2) — `import { application }`. Берёт запущенный экземпляр из предыдущего файла.

- [Строка 4](C:/Ruby/movie_recommender/app/javascript/controllers/index.js:4) — `eagerLoadControllersFrom("controllers", application)`. Загружает и регистрирует контроллеры пространства controllers из importmap. rating_controller.js получает имя rating, pending_action_controller.js — pending-action. Поэтому отдельный ручной import каждой новой формы не нужен.


<a id="file-042"></a>

## 42. Обновление подписи выбранной оценки

[Открыть app/javascript/controllers/rating_controller.js](C:/Ruby/movie_recommender/app/javascript/controllers/rating_controller.js)

Самый маленький пример связи HTML и Stimulus.

~~~~javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["value"]

  select(event) {
    this.valueTarget.textContent = `${event.target.value} / 10`
  }
}
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/javascript/controllers/rating_controller.js:1) — `import { Controller }`. Базовый класс Stimulus даёт element, targets, values и жизненный цикл.

- [Строка 3](C:/Ruby/movie_recommender/app/javascript/controllers/rating_controller.js:3) — `export default class extends Controller`. Экспортирует класс по умолчанию для автозагрузки. extends — наследование JavaScript.

- [Строка 4](C:/Ruby/movie_recommender/app/javascript/controllers/rating_controller.js:4) — `static targets = ["value"]`. Объявляет именованную DOM-цель: элемент data-rating-target=value становится this.valueTarget.

- [Строка 6](C:/Ruby/movie_recommender/app/javascript/controllers/rating_controller.js:6) — `select(event)`. Метод получает событие от radio. event.target — поле, вызвавшее change.

- [Строка 7](C:/Ruby/movie_recommender/app/javascript/controllers/rating_controller.js:7) — `this.valueTarget.textContent`. Присваивает текст, не HTML. Шаблонная строка с ${...} вставляет значение поля. Здесь нет fetch, обращения к Rails и сохранения оценки.


<a id="file-043"></a>

## 43. Обработчик всех временных форм

[Открыть app/javascript/controllers/pending_action_controller.js](C:/Ruby/movie_recommender/app/javascript/controllers/pending_action_controller.js)

Повторно используемая заглушка отправки с проверкой полей и собственным сообщением.

~~~~javascript
import { Controller } from "@hotwired/stimulus"

// The form is ready for a backend action; no data is saved at this stage.
export default class extends Controller {
  static targets = ["status", "submit"]
  static values = { message: String }

  connect() {
    this.submitTargets.forEach(button => { button.disabled = false })
  }

  submit(event) {
    event.preventDefault()
    if (!this.element.reportValidity()) return
    this.statusTarget.textContent = this.messageValue
    this.statusTarget.hidden = false
  }

  clear() {
    this.statusTarget.hidden = true
    this.statusTarget.textContent = ""
  }
}
~~~~

**Разбор значимых строк и блоков**

- [Строка 5](C:/Ruby/movie_recommender/app/javascript/controllers/pending_action_controller.js:5) — `static targets`. status — место сообщения; submit — одна или несколько кнопок. this.submitTargets — массив, this.statusTarget — одна цель.

- [Строка 6](C:/Ruby/movie_recommender/app/javascript/controllers/pending_action_controller.js:6) — `static values = { message: String }`. Объявляет строковую настройку. В HTML data-pending-action-message-value задаёт this.messageValue. Разные формы используют один код с разными текстами.

- [Строка 8](C:/Ruby/movie_recommender/app/javascript/controllers/pending_action_controller.js:8) — `connect()`. Stimulus вызывает метод, когда контроллер подключается к элементу, в том числе после навигации Turbo.

- [Строка 9](C:/Ruby/movie_recommender/app/javascript/controllers/pending_action_controller.js:9) — `this.submitTargets.forEach`. Для каждой найденной кнопки снимает disabled. Стрелочная функция получает button; это не отправка формы.

- [Строка 13](C:/Ruby/movie_recommender/app/javascript/controllers/pending_action_controller.js:13) — `event.preventDefault()`. Останавливает стандартную отправку. Поэтому временные формы не выполняют GET на #.

- [Строка 14](C:/Ruby/movie_recommender/app/javascript/controllers/pending_action_controller.js:14) — `this.element.reportValidity()`. Просит браузер проверить required, формат и другие ограничения и показать подсказки. При false return немедленно завершает метод.

- [Строка 15](C:/Ruby/movie_recommender/app/javascript/controllers/pending_action_controller.js:15) — `this.statusTarget.textContent`. Вставляет настроенное сообщение как текст; hidden=false делает его видимым.

- [Строка 19](C:/Ruby/movie_recommender/app/javascript/controllers/pending_action_controller.js:19) — `clear()`. При новом вводе скрывает предыдущее сообщение и очищает его. Никакие серверные записи этот файл не меняет.


<a id="file-044"></a>

## 44. Открытие и закрытие модального приглашения

[Открыть app/javascript/controllers/dialog_controller.js](C:/Ruby/movie_recommender/app/javascript/controllers/dialog_controller.js)

Небольшая оболочка над нативным элементом dialog.

~~~~javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  open(event) {
    this.opener = event.currentTarget
    this.panelTarget.showModal()
  }

  close() {
    this.panelTarget.close()
  }

  restoreFocus() {
    this.opener?.focus()
  }

  dismissBackdrop(event) {
    if (event.target !== this.panelTarget) return
    const bounds = this.panelTarget.getBoundingClientRect()
    if (event.clientX < bounds.left || event.clientX > bounds.right ||
        event.clientY < bounds.top || event.clientY > bounds.bottom) this.close()
  }

  disconnect() {
    if (this.hasPanelTarget && this.panelTarget.open) this.panelTarget.close()
  }
}
~~~~

**Разбор значимых строк и блоков**

- [Строка 4](C:/Ruby/movie_recommender/app/javascript/controllers/dialog_controller.js:4) — `static targets`. panel — сам dialog, а не кнопка открытия.

- [Строка 7](C:/Ruby/movie_recommender/app/javascript/controllers/dialog_controller.js:7) — `this.opener = event.currentTarget`. Запоминает элемент с обработчиком, а не случайный дочерний значок, по которому попали мышью. Поэтому используется currentTarget, а не target.

- [Строка 8](C:/Ruby/movie_recommender/app/javascript/controllers/dialog_controller.js:8) — `this.panelTarget.showModal()`. Открывает нативный модальный dialog. Браузер обеспечивает модальную область и стандартное поведение Escape.

- [Строка 12](C:/Ruby/movie_recommender/app/javascript/controllers/dialog_controller.js:12) — `this.panelTarget.close()`. Закрывает dialog. Это создаёт событие close, связанное в HTML с restoreFocus.

- [Строка 16](C:/Ruby/movie_recommender/app/javascript/controllers/dialog_controller.js:16) — `this.opener?.focus()`. ?. — безопасный доступ: focus вызывается, только если opener существует. Возвращает управление клавиатурой к кнопке приглашения.

- [Строка 20](C:/Ruby/movie_recommender/app/javascript/controllers/dialog_controller.js:20) — `if (event.target !== this.panelTarget)`. Если нажали на содержимое окна, метод сразу выходит. Нельзя закрывать окно от любого клика внутри.

- [Строка 21](C:/Ruby/movie_recommender/app/javascript/controllers/dialog_controller.js:21) — `getBoundingClientRect()`. Возвращает границы прямоугольника в координатах видимой области. clientX/clientY сравниваются с ними: нажатие снаружи закрывает окно, нажатие внутри его отступов — нет.

- [Строка 26](C:/Ruby/movie_recommender/app/javascript/controllers/dialog_controller.js:26) — `disconnect()`. При отключении Stimulus-контроллера закрывает открытое окно, если цель ещё есть. hasPanelTarget предотвращает обращение к отсутствующему элементу.


<a id="file-045"></a>

## 45. Позиционирование и доступность уведомлений

[Открыть app/javascript/controllers/notifications_controller.js](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js)

Управляет немодальной панелью рядом с колокольчиком.

~~~~javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "panel"]

  toggle() {
    if (!this.panelTarget.hidden) return this.dismiss()

    this.panelTarget.hidden = false
    this.triggerTarget.setAttribute("aria-expanded", "true")
    this.position()
    this.panelTarget.focus({ preventScroll: true })
  }

  position() {
    if (this.panelTarget.hidden) return

    const anchor = this.element.getBoundingClientRect()
    const viewportWidth = document.documentElement.clientWidth
    this.panelTarget.style.maxWidth = `${viewportWidth - 32}px`
    const width = this.panelTarget.getBoundingClientRect().width
    const left = Math.max(16, Math.min(anchor.right - width, viewportWidth - width - 16))
    this.panelTarget.style.left = `${left - anchor.left}px`
  }

  close() {
    this.panelTarget.hidden = true
    this.triggerTarget.setAttribute("aria-expanded", "false")
  }

  dismiss() {
    this.close()
    this.triggerTarget.focus({ preventScroll: true })
  }

  dismissOutside(event) {
    if (!this.panelTarget.hidden && !this.element.contains(event.target)) this.close()
  }

  dismissWithEscape(event) {
    if (this.panelTarget.hidden) return

    event.preventDefault()
    event.stopPropagation()
    this.dismiss()
  }
}
~~~~

**Разбор значимых строк и блоков**

- [Строка 4](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js:4) — `static targets`. trigger — кнопка, panel — скрываемая секция.

- [Строка 7](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js:7) — `if (!this.panelTarget.hidden)`. ! отрицает условие. Если панель уже видна, toggle вызывает dismiss и выходит.

- [Строка 9](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js:9) — `this.panelTarget.hidden = false`. Открывает панель, aria-expanded=true синхронизирует доступное состояние и CSS.

- [Строка 11](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js:11) — `this.position()`. После открытия размеры уже можно измерить. Затем фокус ставится на панель без прокрутки страницы.

- [Строка 16](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js:16) — `if (this.panelTarget.hidden) return`. Позиционировать невидимую панель не требуется.

- [Строка 18](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js:18) — `const anchor`. Измеряет контейнер. document.documentElement.clientWidth берёт ширину доступной области документа.

- [Строка 20](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js:20) — `style.maxWidth`. Дополнительно ограничивает панель шириной viewport минус 32 px, оставляя по 16 px с краёв.

- [Строка 22](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js:22) — `const left = Math.max`. Выбирает левую координату: стремится прижать правый край панели к правому краю контейнера, но ограничивает её границами экрана. Math.min ограничивает сверху, Math.max — снизу.

- [Строка 23](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js:23) — `left - anchor.left`. Переводит экранную координату в смещение относительно контейнера с position:relative.

- [Строка 26](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js:26) — `close()`. Скрывает панель и сбрасывает aria-expanded, не меняя фокус. Это подходит для закрытия при клике на другой элемент.

- [Строка 7](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js:7) — `dismiss()`. Закрывает и возвращает фокус на trigger. Используется для явного закрытия и Escape.

- [Строка 36](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js:36) — `dismissOutside(event)`. Если панель открыта и целевой элемент события не содержится внутри контейнера, скрывает панель. Так обрабатываются и клики снаружи, и переход фокуса.

- [Строка 40](C:/Ruby/movie_recommender/app/javascript/controllers/notifications_controller.js:40) — `dismissWithEscape(event)`. Для открытой панели останавливает стандартное действие и распространение этого события, затем закрывает панель с восстановлением фокуса.


<a id="file-046"></a>

## 46. Оставшийся учебный контроллер генератора

[Открыть app/javascript/controllers/hello_controller.js](C:/Ruby/movie_recommender/app/javascript/controllers/hello_controller.js)

Пример Stimulus, а не часть рекомендаций.

~~~~javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.textContent = "Hello World!"
  }
}
~~~~

**Разбор значимых строк и блоков**

- [Строка 4](C:/Ruby/movie_recommender/app/javascript/controllers/hello_controller.js:4) — `connect()`. При подключении заменяет текст своего элемента на Hello World!. В текущих прочитанных шаблонах data-controller=hello не используется; файл сам по себе не меняет страницу.


<a id="file-047"></a>

## 47. Общие кнопки, поля и SVG-иконки

[Открыть app/helpers/application_helper.rb](C:/Ruby/movie_recommender/app/helpers/application_helper.rb)

Повторяющееся оформление вынесено в Ruby-методы, доступные шаблонам.

~~~~ruby
module ApplicationHelper
  UI_ICON_PATHS = {
    bell: [ "M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9", "M10 21h4" ],
    star: [ "m12 3 2.8 5.7 6.3.9-4.55 4.45 1.07 6.28L12 17.36l-5.62 2.97 1.07-6.28L2.9 9.6l6.3-.9L12 3Z" ],
    chart: [ "M4 4v16h16", "M9 16v-4M14 16V8M19 16V4" ],
    users: [ "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", "M13 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0Z", "M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" ],
    film: [ "M4 3h16v18H4V3Z", "M8 3v18M16 3v18M4 8h4M4 16h4M16 8h4M16 16h4M8 12h8" ],
    sparkles: [ "m12 3 2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5L12 3Z", "M4 3v4M2 5h4M20 17v4M18 19h4" ],
    search: [ "M19 11a8 8 0 1 1-16 0 8 8 0 0 1 16 0Z", "m17 17 4 4" ],
    plus: [ "M12 5v14M5 12h14" ],
    close: [ "m6 6 12 12M18 6 6 18" ]
  }.freeze

  def ui_icon(name, classes: "size-5")
    tag.svg(class: classes, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": 1.75, "stroke-linecap": "round", "stroke-linejoin": "round", aria: { hidden: true }, focusable: false) do
      safe_join(UI_ICON_PATHS.fetch(name).map { |path| tag.path(d: path) })
    end
  end

  def ui_button_classes(variant = :primary)
    base = "inline-flex min-h-11 items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold transition focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-300 disabled:cursor-not-allowed disabled:opacity-50"
    variants = {
      primary: "bg-brand-600 text-white shadow-sm hover:bg-brand-700 disabled:hover:bg-brand-600",
      secondary: "border border-line bg-surface text-ink-secondary hover:bg-surface-hover disabled:hover:bg-surface"
    }
    class_names(base, variants.fetch(variant))
  end

  def ui_input_classes
    "block min-h-11 w-full rounded-xl border border-line-strong bg-surface-raised px-3.5 py-2.5 text-base text-ink shadow-xs placeholder:text-ink-muted focus:border-brand-300 focus:outline-2 focus:outline-brand-300/40 disabled:cursor-not-allowed disabled:bg-surface disabled:text-ink-muted aria-invalid:border-rose-400 aria-invalid:focus:outline-rose-400/40"
  end

  def ui_label_classes
    "mb-2 block text-sm font-medium text-ink-secondary"
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/helpers/application_helper.rb:2) — `UI_ICON_PATHS = {`. Хеш: ключи-символы bell, star, chart и т. д. соответствуют массивам SVG-путей. Координаты описывают геометрию значка, не прикладную логику. Несколько строк у одного имени дают несколько path.

- [Строка 12](C:/Ruby/movie_recommender/app/helpers/application_helper.rb:12) — `}.freeze`. Запрещает менять верхнеуровневый хеш. Это поверхностная заморозка: вложенные массивы/строки от этого не становятся автоматически неизменяемыми.

- [Строка 14](C:/Ruby/movie_recommender/app/helpers/application_helper.rb:14) — `def ui_icon(name, classes: "size-5")`. Принимает имя значка и именованный параметр CSS-классов со значением по умолчанию. Вызов ui_icon(:star, classes: 'size-4') выбирает размер.

- [Строка 15](C:/Ruby/movie_recommender/app/helpers/application_helper.rb:15) — `tag.svg(`. Rails-helper формирует SVG-тег. viewBox задаёт систему координат 0..24; fill:none оставляет контуры; stroke:currentColor берёт текущий CSS-цвет текста; общие параметры задают одинаковую толщину и форму линий.

- [Строка 15](C:/Ruby/movie_recommender/app/helpers/application_helper.rb:15) — `aria: { hidden: true }, focusable: false`. Декоративная иконка не озвучивается отдельно и не становится лишней точкой фокуса. У кнопки-иконки доступное имя задаётся через aria-label.

- [Строка 16](C:/Ruby/movie_recommender/app/helpers/application_helper.rb:16) — `UI_ICON_PATHS.fetch(name)`. Достаёт массив по имени и явно падает при неизвестном ключе, вместо молчаливой пустоты. map превращает каждый путь в tag.path(d:path).

- [Строка 16](C:/Ruby/movie_recommender/app/helpers/application_helper.rb:16) — `safe_join`. Объединяет HTML-фрагменты Rails без опасного ручного склеивания необработанных строк. Здесь геометрия берётся из статического собственного набора.

- [Строка 20](C:/Ruby/movie_recommender/app/helpers/application_helper.rb:20) — `def ui_button_classes`. Метод возвращает строку CSS-классов; он не создаёт саму кнопку и не назначает URL.

- [Строка 21](C:/Ruby/movie_recommender/app/helpers/application_helper.rb:21) — `base =`. Общие размеры, отступы, расположение, шрифт, фокус и disabled-состояние всех кнопок. min-h-11 даёт достаточно крупную область нажатия при стандартной шкале.

- [Строка 22](C:/Ruby/movie_recommender/app/helpers/application_helper.rb:22) — `variants =`. primary — акцентная заливка; secondary — спокойная рамка и поверхность. Единый метод облегчает изменение всех одинаковых элементов.

- [Строка 26](C:/Ruby/movie_recommender/app/helpers/application_helper.rb:26) — `class_names(base, variants.fetch(variant))`. Складывает общую и выбранную части. fetch требует известный вариант; опечатка не создаст кнопку со случайным неполным стилем.

- [Строка 29](C:/Ruby/movie_recommender/app/helpers/application_helper.rb:29) — `def ui_input_classes`. Возвращает оформление поля: ширина, рамка, фон, текст, placeholder, focus, disabled и aria-invalid. Условия реализованы CSS-вариантами Tailwind, не Ruby-ветками.

- [Строка 33](C:/Ruby/movie_recommender/app/helpers/application_helper.rb:33) — `def ui_label_classes`. Единый отступ снизу, размер и цвет подписи. Отделение helper полезно для действительно повторяющегося набора, но не обязывает выносить каждую одиночную строку классов в Ruby.


<a id="file-048"></a>

## 48. Тема Tailwind

[Открыть app/assets/tailwind/application.css](C:/Ruby/movie_recommender/app/assets/tailwind/application.css)

Исходный CSS: подключение Tailwind, имена цветов/шрифта и базовые правила.

~~~~css
@import "tailwindcss";

@theme {
  --font-sans: "Segoe UI", ui-sans-serif, system-ui, sans-serif;
  --color-canvas: #0b1120;
  --color-surface: #111b2e;
  --color-surface-raised: #19263b;
  --color-surface-hover: #223149;
  --color-line: #2b3b53;
  --color-line-strong: #61718b;
  --color-ink: #f1f5f9;
  --color-ink-secondary: #cbd5e1;
  --color-ink-muted: #a0aec3;
  --color-brand-soft: #202445;
  --color-brand-line: #414477;
  --color-brand-ink: #c7d2fe;
  --color-brand-ink-hover: #e0e7ff;
  --color-hero-end: #302449;
  --color-brand-300: var(--color-indigo-300);
  --color-brand-500: var(--color-indigo-500);
  --color-brand-600: var(--color-indigo-600);
  --color-brand-700: var(--color-indigo-700);
}

@layer base {
  html {
    color-scheme: dark;
    @apply bg-canvas;
  }

  .field_with_errors {
    @apply contents;
  }
}
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/assets/tailwind/application.css:1) — `@import "tailwindcss"`. Подключает инструменты Tailwind на этапе сборки. Результат — обычный CSS, который браузер применяет к HTML.

- [Строка 3](C:/Ruby/movie_recommender/app/assets/tailwind/application.css:3) — `@theme`. Объявляет дизайн-переменные. --color-surface даёт цвет, используемый классом bg-surface; --color-ink — text-ink; --font-sans — font-sans. Это общий словарь оформления.

- [Строка 4](C:/Ruby/movie_recommender/app/assets/tailwind/application.css:4) — `--font-sans:`. Приоритет Segoe UI, затем системные и универсальный sans-serif. Если первого шрифта нет, браузер использует следующий.

- [Строка 5](C:/Ruby/movie_recommender/app/assets/tailwind/application.css:5) — `--color-canvas:`. Фон всей страницы. surface — карточки, surface-raised — приподнятые элементы, surface-hover — состояния наведения. Разные значения создают визуальную иерархию.

- [Строка 9](C:/Ruby/movie_recommender/app/assets/tailwind/application.css:9) — `--color-line:`. Рамки и усиленные рамки. ink, ink-secondary, ink-muted задают уровни текста; brand-переменные — акцент и мягкие поверхности.

- [Строка 19](C:/Ruby/movie_recommender/app/assets/tailwind/application.css:19) — `--color-brand-300:`. Ссылка на готовые indigo-значения Tailwind позволяет использовать собственное семантическое имя brand. Это не отдельный второй CSS-фреймворк.

- [Строка 25](C:/Ruby/movie_recommender/app/assets/tailwind/application.css:25) — `@layer base`. Базовые правила встроены в порядок слоёв CSS, чтобы согласованно сочетаться с утилитами.

- [Строка 27](C:/Ruby/movie_recommender/app/assets/tailwind/application.css:27) — `color-scheme: dark`. Просит браузер рисовать встроенные элементы в тёмной схеме. @apply bg-canvas подставляет правило фона из утилиты.

- [Строка 31](C:/Ruby/movie_recommender/app/assets/tailwind/application.css:31) — `.field_with_errors`. Rails может оборачивать ошибочное поле дополнительным элементом. display:contents через @apply contents убирает собственный прямоугольник обёртки, сохраняя дочерние элементы в раскладке.


<a id="file-049"></a>

## 49. Прежняя точка CSS

[Открыть app/assets/stylesheets/application.css](C:/Ruby/movie_recommender/app/assets/stylesheets/application.css)

Содержит только пояснение, где теперь находится исходник стилей.

~~~~css
/* Application styles are built from app/assets/tailwind/application.css. */
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/assets/stylesheets/application.css:1) — `/*`. CSS-комментарий не создаёт правила. Старое оформление заменено темой и утилитами Tailwind; реальный собранный CSS подключается системой ресурсов Rails.


<a id="file-050"></a>

## 50. Как браузер находит JavaScript-модули

[Открыть config/importmap.rb](C:/Ruby/movie_recommender/config/importmap.rb)

Сопоставляет имена import и реальные ресурсы.

~~~~ruby
# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
~~~~

**Разбор значимых строк и блоков**

- [Строка 3](C:/Ruby/movie_recommender/config/importmap.rb:3) — `pin "application"`. Регистрирует точку входа приложения.

- [Строка 4](C:/Ruby/movie_recommender/config/importmap.rb:4) — `pin "@hotwired/turbo-rails"`. Привязывает имя импорта к ресурсу turbo.min.js. Аналогичные строки подключают Stimulus и загрузчик его контроллеров.

- [Строка 7](C:/Ruby/movie_recommender/config/importmap.rb:7) — `pin_all_from`. Регистрирует все файлы app/javascript/controllers в пространстве controllers. Вместе с eagerLoadControllersFrom это даёт автоматическое подключение.

- [Строка 1](C:/Ruby/movie_recommender/config/importmap.rb:1) — `# Pin npm packages`. Комментарий показывает способ добавления пакетов. Для имеющегося браузерного модульного кода отдельная сборка JavaScript через Node сейчас не обязательна.


<a id="file-051"></a>

## 51. Почему запуск через ruby bin/dev

[Открыть bin/dev](C:/Ruby/movie_recommender/bin/dev)

Наш последовательный запуск: собрать Tailwind, затем запустить Rails.

~~~~ruby
#!/usr/bin/env ruby.exe
require "rbconfig"

# Use Ruby explicitly so development works in PowerShell as well as Unix shells.
abort "Tailwind build failed" unless system(RbConfig.ruby, "bin/rails", "tailwindcss:build")
exec RbConfig.ruby, "bin/rails", "server", *ARGV
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/bin/dev:1) — `#!/usr/bin/env ruby.exe`. Shebang для сред, которые его понимают. Явный префикс ruby в PowerShell надёжно запускает файл без расширения .rb.

- [Строка 2](C:/Ruby/movie_recommender/bin/dev:2) — `require "rbconfig"`. Подключает информацию о текущей установке Ruby. RbConfig.ruby возвращает путь к тому же интерпретатору.

- [Строка 5](C:/Ruby/movie_recommender/bin/dev:5) — `abort "Tailwind build failed"`. unless system(...) завершает запуск, если сборка не удалась. system получает программу и аргументы отдельно; запускается bin/rails tailwindcss:build.

- [Строка 6](C:/Ruby/movie_recommender/bin/dev:6) — `exec RbConfig.ruby`. Запускает сервер с переданными дополнительными аргументами *ARGV. * разворачивает массив аргументов. Этот скрипт не запускает tailwindcss:watch.


<a id="file-052"></a>

## 52. Описание двух процессов разработки

[Открыть Procfile.dev](C:/Ruby/movie_recommender/Procfile.dev)

Декларация web и css для инструментов, понимающих Procfile.

~~~~text
web: ruby bin/rails server
css: ruby bin/rails tailwindcss:watch
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/Procfile.dev:1) — `web:`. Команда сервера. Имя web — название процесса.

- [Строка 2](C:/Ruby/movie_recommender/Procfile.dev:2) — `css:`. Отдельный процесс наблюдения Tailwind за изменениями. Текущий bin/dev этот файл не читает, поэтому наличие Procfile.dev не означает автоматический watcher при ruby bin/dev.


<a id="file-053"></a>

## 53. Зависимости приложения

[Открыть Gemfile](C:/Ruby/movie_recommender/Gemfile)

Описывает нужные библиотеки; Bundler разрешает и устанавливает совместимые версии.

~~~~ruby
source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Compile Tailwind CSS for the server-rendered interface.
gem "tailwindcss-rails", "~> 4.0"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/Gemfile:1) — `source`. Источник gem-пакетов. Это адрес получения зависимостей, не API нашего приложения.

- [Строка 3](C:/Ruby/movie_recommender/Gemfile:3) — `gem "rails"`. ~> 8.1.4 задаёт совместимый диапазон в пределах 8.1 с нижней границей 8.1.4. Точные разрешённые версии записывает Gemfile.lock.

- [Строка 6](C:/Ruby/movie_recommender/Gemfile:6) — `gem "propshaft"`. Система ресурсов: подготовка и адресация CSS, JavaScript и изображений приложения.

- [Строка 8](C:/Ruby/movie_recommender/Gemfile:8) — `gem "tailwindcss-rails"`. Интеграция Tailwind с задачами Rails. Стили собираются локально; в браузер не передаётся компилятор Tailwind.

- [Строка 10](C:/Ruby/movie_recommender/Gemfile:10) — `gem "sqlite3"`. Драйвер SQLite для Active Record. >= 2.1 — нижняя граница версии зависимости.

- [Строка 12](C:/Ruby/movie_recommender/Gemfile:12) — `gem "puma"`. HTTP-сервер Ruby, который принимает браузерные соединения и передаёт запросы Rails.

- [Строка 14](C:/Ruby/movie_recommender/Gemfile:14) — `gem "importmap-rails"`. Сопоставление браузерных import с ресурсами без обязательного JS-бандлера.

- [Строка 16](C:/Ruby/movie_recommender/Gemfile:16) — `gem "turbo-rails"`. Серверная интеграция Turbo; stimulus-rails подключает Stimulus.

- [Строка 20](C:/Ruby/movie_recommender/Gemfile:20) — `gem "jbuilder"`. Средство формирования JSON-представлений. Его наличие в Gemfile не означает, что в проекте уже написан отдельный JSON API.

- [Строка 23](C:/Ruby/movie_recommender/Gemfile:23) — `gem "bcrypt"`. Библиотека для хеширования паролей, используемая has_secure_password.

- [Строка 26](C:/Ruby/movie_recommender/Gemfile:26) — `gem "tzinfo-data"`. Данные часовых поясов для указанных платформ. platforms ограничивает применение зависимости.

- [Строка 29](C:/Ruby/movie_recommender/Gemfile:29) — `gem "solid_cache"`. Группа solid_cache, solid_queue, solid_cable поддерживает хранение кэша, очереди и обмена Cable в базе. Это инфраструктура, не готовая логика комнат.

- [Строка 34](C:/Ruby/movie_recommender/Gemfile:34) — `gem "bootsnap"`. Кэширование затратных операций старта; require:false означает, что Bundler не должен автоматически требовать библиотеку — boot.rb подключает её сам.

- [Строка 37](C:/Ruby/movie_recommender/Gemfile:37) — `gem "kamal"`. Инструмент развёртывания. Его установка сама по себе ничего не публикует.

- [Строка 40](C:/Ruby/movie_recommender/Gemfile:40) — `gem "thruster"`. HTTP-ускорение/обслуживание перед приложением при соответствующем запуске. Это часть подготовленной инфраструктуры.

- [Строка 43](C:/Ruby/movie_recommender/Gemfile:43) — `gem "image_processing"`. Поддержка преобразований изображений в сценариях Active Storage. Постеры сейчас отображаются внешними URL, а не обрабатываются этим кодом.

- [Строка 45](C:/Ruby/movie_recommender/Gemfile:45) — `group :development, :test`. Зависимости только для разработки и тестирования: debug, аудит библиотек, Brakeman и RuboCop. Их функции различаются: отладка, проверка известных уязвимостей, статический анализ и стиль.

- [Строка 59](C:/Ruby/movie_recommender/Gemfile:59) — `group :development do`. web-console даёт интерактивную диагностику в разработке. Это не доступная всем пользователям функция продукта.

- [Строка 64](C:/Ruby/movie_recommender/Gemfile:64) — `group :test do`. capybara и selenium-webdriver предназначены для браузерных тестов. Наличие библиотек не означает, что на все экраны написаны такие тесты.


<a id="file-054"></a>

## 54. Какие файлы не должны попадать в Git

[Открыть .gitignore](C:/Ruby/movie_recommender/.gitignore)

Исключает локальные настройки, временные результаты, базы и ключи.

~~~~text
# See https://help.github.com/articles/ignoring-files for more about ignoring files.
#
# Temporary files generated by your text editor or operating system
# belong in git's global ignore instead:
# `$XDG_CONFIG_HOME/git/ignore` or `~/.config/git/ignore`

# Ignore bundler config.
/.bundle

# Ignore all environment files.
/.env*

# Ignore all logfiles and tempfiles.
/log/*
/tmp/*
!/log/.keep
!/tmp/.keep

# Ignore pidfiles, but keep the directory.
/tmp/pids/*
!/tmp/pids/
!/tmp/pids/.keep

# Ignore storage (uploaded files in development and any SQLite databases).
/storage/*
!/storage/.keep
/tmp/storage/*
!/tmp/storage/
!/tmp/storage/.keep

/public/assets

# Ignore key files for decrypting credentials and more.
/config/*.key

/app/assets/builds/*
!/app/assets/builds/.keep
~~~~

**Разбор значимых строк и блоков**

- [Строка 11](C:/Ruby/movie_recommender/.gitignore:11) — `/.env*`. Игнорирует файлы окружения в корне. Это не загружает их автоматически в Rails и не удаляет из истории файлы, уже отслеживаемые Git.

- [Строка 14](C:/Ruby/movie_recommender/.gitignore:14) — `/log/*`. Логи и tmp игнорируются, а !.../.keep сохраняет пустые каталоги в репозитории. ! отменяет соответствующее исключение для указанного файла.

- [Строка 25](C:/Ruby/movie_recommender/.gitignore:25) — `/storage/*`. Игнорирует локальные базы SQLite и загруженные файлы. Структура базы сохраняется миграциями и schema.rb, а не копированием персональной development-базы.

- [Строка 31](C:/Ruby/movie_recommender/.gitignore:31) — `/public/assets`. Исключает собранные публичные ресурсы.

- [Строка 34](C:/Ruby/movie_recommender/.gitignore:34) — `/config/*.key`. Исключает ключи расшифровки. Само наличие правила не заменяет проверку истории репозитория.

- [Строка 36](C:/Ruby/movie_recommender/.gitignore:36) — `/app/assets/builds/*`. Собранные стили генерируются заново. .keep остаётся, чтобы существовал каталог сборки.


<a id="file-055"></a>

## 55. Миграция создания пользователей

[Открыть db/migrate/20260925111546_create_users.rb](C:/Ruby/movie_recommender/db/migrate/20260925111546_create_users.rb)

Изменяет структуру базы, а не описывает HTML или поведение модели.

~~~~ruby
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/db/migrate/20260925111546_create_users.rb:1) — `ActiveRecord::Migration[8.1]`. Фиксирует API миграций Rails 8.1 для этой миграции.

- [Строка 2](C:/Ruby/movie_recommender/db/migrate/20260925111546_create_users.rb:2) — `def change`. Описывает автоматически обратимые операции. Rails знает, как откатить создание таблицы и индекса.

- [Строка 3](C:/Ruby/movie_recommender/db/migrate/20260925111546_create_users.rb:3) — `create_table :users`. Создаёт таблицу и стандартный первичный ключ id. t — объект описания колонок внутри блока.

- [Строка 4](C:/Ruby/movie_recommender/db/migrate/20260925111546_create_users.rb:4) — `t.string :email_address, null: false`. Строковая колонка с запретом SQL NULL. NULL не равен пустой строке, поэтому presence модели всё ещё нужен.

- [Строка 5](C:/Ruby/movie_recommender/db/migrate/20260925111546_create_users.rb:5) — `t.string :password_digest`. Хранит результат хеширования, не пароль.

- [Строка 7](C:/Ruby/movie_recommender/db/migrate/20260925111546_create_users.rb:7) — `t.timestamps`. Добавляет created_at и updated_at. Их значения обычно поддерживает Active Record.

- [Строка 9](C:/Ruby/movie_recommender/db/migrate/20260925111546_create_users.rb:9) — `add_index :users, :email_address, unique: true`. Индекс помогает поиску и запрещает повторное значение email на уровне базы, включая конкурентные записи.


<a id="file-056"></a>

## 56. Миграция сессий входа

[Открыть db/migrate/20260925111549_create_sessions.rb](C:/Ruby/movie_recommender/db/migrate/20260925111549_create_sessions.rb)

Хранит отдельные входы пользователя.

~~~~ruby
class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 3](C:/Ruby/movie_recommender/db/migrate/20260925111549_create_sessions.rb:3) — `create_table :sessions`. Отдельная таблица с собственным id; именно её ID отправляется в cookie.

- [Строка 4](C:/Ruby/movie_recommender/db/migrate/20260925111549_create_sessions.rb:4) — `t.references :user`. Добавляет user_id и индекс. null:false требует ссылку, foreign_key:true требует существование пользователя.

- [Строка 5](C:/Ruby/movie_recommender/db/migrate/20260925111549_create_sessions.rb:5) — `t.string :ip_address`. Запоминает IP; user_agent хранит строку клиента. По текущему коду они не используются как дополнительные факторы входа.

- [Строка 8](C:/Ruby/movie_recommender/db/migrate/20260925111549_create_sessions.rb:8) — `t.timestamps`. Время создания и последнего обновления записи.


<a id="file-057"></a>

## 57. Добавление обязательного уникального никнейма

[Открыть db/migrate/20261003000000_add_nickname_to_users.rb](C:/Ruby/movie_recommender/db/migrate/20261003000000_add_nickname_to_users.rb)

Последовательно меняет существующую базу с уже созданными пользователями.

~~~~ruby
class AddNicknameToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :nickname, :string

    execute("SELECT id FROM users ORDER BY id").each do |row|
      id = row.fetch("id")
      execute("UPDATE users SET nickname = #{connection.quote("user#{id}")} WHERE id = #{connection.quote(id)}")
    end

    change_column_null :users, :nickname, false
    add_index :users, :nickname, unique: true
  end

  def down
    remove_index :users, :nickname
    remove_column :users, :nickname
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/db/migrate/20261003000000_add_nickname_to_users.rb:2) — `def up`. Явное описание применения, а down отдельно описывает откат. Это удобно для изменения со своим заполнением данных.

- [Строка 3](C:/Ruby/movie_recommender/db/migrate/20261003000000_add_nickname_to_users.rb:3) — `add_column :users, :nickname, :string`. Сначала добавляет временно допускающую NULL колонку: существующие записи ещё не имеют ника.

- [Строка 5](C:/Ruby/movie_recommender/db/migrate/20261003000000_add_nickname_to_users.rb:5) — `execute("SELECT id FROM users ORDER BY id")`. Прямой SQL выбирает ID существующих пользователей. Используется база, а не актуальная модель User, чтобы миграция меньше зависела от последующих изменений модели.

- [Строка 6](C:/Ruby/movie_recommender/db/migrate/20261003000000_add_nickname_to_users.rb:6) — `id = row.fetch("id")`. Из каждой строки берётся ID. fetch явно сигнализирует, если ожидаемого поля нет.

- [Строка 7](C:/Ruby/movie_recommender/db/migrate/20261003000000_add_nickname_to_users.rb:7) — `connection.quote("user#{id}")`. Создаёт значение user1, user2 и т. д. quote корректно оформляет SQL-литерал. Это не общее разрешение вставлять непроверенные строки SQL вручную.

- [Строка 10](C:/Ruby/movie_recommender/db/migrate/20261003000000_add_nickname_to_users.rb:10) — `change_column_null`. После заполнения всех строк включает NOT NULL. Такой порядок не ломает существующие записи.

- [Строка 11](C:/Ruby/movie_recommender/db/migrate/20261003000000_add_nickname_to_users.rb:11) — `add_index :users, :nickname, unique: true`. Гарантирует уникальность в базе. Нормализацию регистра делает модель; этот обычный индекс сам по себе не является специальным правилом приведения к нижнему регистру.

- [Строка 14](C:/Ruby/movie_recommender/db/migrate/20261003000000_add_nickname_to_users.rb:14) — `def down`. Убирает индекс, затем колонку. Откат уничтожает сохранённые значения nickname.


<a id="file-058"></a>

## 58. Снимок текущей структуры основной базы

[Открыть db/schema.rb](C:/Ruby/movie_recommender/db/schema.rb)

Автоматический результат применённых миграций.

~~~~ruby
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_03_000000) do
  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "nickname", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["nickname"], name: "index_users_on_nickname", unique: true
  end

  add_foreign_key "sessions", "users"
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 13](C:/Ruby/movie_recommender/db/schema.rb:13) — `ActiveRecord::Schema[8.1].define`. version указывает последнюю применённую миграцию. Файл можно использовать для создания новой базы по текущей структуре, не проигрывая всю историю.

- [Строка 14](C:/Ruby/movie_recommender/db/schema.rb:14) — `create_table "sessions"`. Описание сессий с user_id, IP, браузером, датами и индексом. force:cascade в контексте загрузки схемы разрешает пересоздание; чтение файла само по себе базу не удаляет.

- [Строка 23](C:/Ruby/movie_recommender/db/schema.rb:23) — `create_table "users"`. Описание пользователя с email, digest и nickname. По этой схеме видно, что таблиц movies, ratings, rooms и подборов ещё нет.

- [Строка 33](C:/Ruby/movie_recommender/db/schema.rb:33) — `add_foreign_key`. Отражает связь sessions.user_id → users.id. Схему обычно не правят вручную: создают миграцию и обновляют снимок.


<a id="file-059"></a>

## 59. Подключение SQLite и разделение окружений

[Открыть config/database.yml](C:/Ruby/movie_recommender/config/database.yml)

Определяет, какие файлы баз использует Rails.

~~~~yaml
# SQLite. Versions 3.8.0 and up are supported.
#   gem install sqlite3
#
#   Ensure the SQLite 3 gem is defined in your Gemfile
#   gem "sqlite3"
#
default: &default
  adapter: sqlite3
  max_connections: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000

development:
  <<: *default
  database: storage/development.sqlite3

# Warning: The database defined as "test" will be erased and
# re-generated from your development database when you run "rake".
# Do not set this db to the same as development or production.
test:
  <<: *default
  database: storage/test.sqlite3

# Store production database in the storage/ directory, which by default
# is mounted as a persistent Docker volume in config/deploy.yml.
production:
  primary:
    <<: *default
    database: storage/production.sqlite3
  cache:
    <<: *default
    database: storage/production_cache.sqlite3
    migrations_paths: db/cache_migrate
  queue:
    <<: *default
    database: storage/production_queue.sqlite3
    migrations_paths: db/queue_migrate
  cable:
    <<: *default
    database: storage/production_cable.sqlite3
    migrations_paths: db/cable_migrate
~~~~

**Разбор значимых строк и блоков**

- [Строка 7](C:/Ruby/movie_recommender/config/database.yml:7) — `default: &default`. YAML-якорь задаёт общие параметры. <<: *default подмешивает их в окружение.

- [Строка 8](C:/Ruby/movie_recommender/config/database.yml:8) — `adapter: sqlite3`. Выбирает драйвер SQLite; база хранится в файле.

- [Строка 9](C:/Ruby/movie_recommender/config/database.yml:9) — `max_connections:`. Число соединений берётся из RAILS_MAX_THREADS либо 5. ENV.fetch с блоком задаёт значение по умолчанию при отсутствии переменной.

- [Строка 10](C:/Ruby/movie_recommender/config/database.yml:10) — `timeout: 5000`. Ожидание при блокировке SQLite в миллисекундах; это не тайм-аут запросов TMDB.

- [Строка 12](C:/Ruby/movie_recommender/config/database.yml:12) — `development:`. Рабочая локальная база отделена от storage/test.sqlite3. Тестовую базу можно пересоздавать, не стирая пользовательскую development-базу.

- [Строка 25](C:/Ruby/movie_recommender/config/database.yml:25) — `production:`. В конфигурации предусмотрены primary, cache, queue и cable — отдельные SQLite-файлы по назначению. Наличие этих настроек не доказывает, что production уже запущен.

- [Строка 32](C:/Ruby/movie_recommender/config/database.yml:32) — `migrations_paths:`. Служебные базы используют свои пути миграций; их схемы лежат в db/cache_schema.rb, db/queue_schema.rb и db/cable_schema.rb.


<a id="file-060"></a>

## 60. Авторизация соединения Action Cable

[Открыть app/channels/application_cable/connection.rb](C:/Ruby/movie_recommender/app/channels/application_cable/connection.rb)

Основа подключения по WebSocket, но ещё не канал конкретной комнаты.

~~~~ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
      def set_current_user
        if session = Session.find_by(id: cookies.signed[:session_id])
          self.current_user = session.user
        end
      end
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 3](C:/Ruby/movie_recommender/app/channels/application_cable/connection.rb:3) — `identified_by :current_user`. Объявляет идентификатор пользователя на соединении Cable.

- [Строка 5](C:/Ruby/movie_recommender/app/channels/application_cable/connection.rb:5) — `def connect`. Вызывается при установлении соединения. Если set_current_user вернул ложный результат, reject_unauthorized_connection отклоняет подключение.

- [Строка 11](C:/Ruby/movie_recommender/app/channels/application_cable/connection.rb:11) — `Session.find_by(id: cookies.signed[:session_id])`. Использует тот же подписанный ID входа, что HTTP-контроллеры.

- [Строка 12](C:/Ruby/movie_recommender/app/channels/application_cable/connection.rb:12) — `self.current_user = session.user`. Устанавливает пользователя соединения. self требуется для вызова метода-присваивания свойства. Здесь нет stream_for комнаты и проверки членства — их ещё предстоит реализовать.


<a id="file-061"></a>

## 61. Адаптеры обмена Cable

[Открыть config/cable.yml](C:/Ruby/movie_recommender/config/cable.yml)

Выбирает техническое средство доставки сообщений между процессами.

~~~~yaml
# Async adapter only works within the same process, so for manually triggering cable updates from a console,
# and seeing results in the browser, you must do so from the web console (running inside the dev process),
# not a terminal started via bin/rails console! Add "console" to any action or any ERB template view
# to make the web console appear.
development:
  adapter: async

test:
  adapter: test

production:
  adapter: solid_cable
  connects_to:
    database:
      writing: cable
  polling_interval: 0.1.seconds
  message_retention: 1.day
~~~~

**Разбор значимых строк и блоков**

- [Строка 6](C:/Ruby/movie_recommender/config/cable.yml:6) — `adapter: async`. В development сообщения живут в текущем процессе; отдельная консоль не становится тем же процессом сервера.

- [Строка 9](C:/Ruby/movie_recommender/config/cable.yml:9) — `adapter: test`. В тестах используется тестовый адаптер.

- [Строка 12](C:/Ruby/movie_recommender/config/cable.yml:12) — `adapter: solid_cable`. Production-конфигурация использует базу cable для обмена. polling_interval и message_retention управляют внутренним опросом и хранением сообщений; это не опрос квиза и не срок жизни комнаты.


<a id="file-062"></a>

## 62. Общая основа писем

[Открыть app/mailers/application_mailer.rb](C:/Ruby/movie_recommender/app/mailers/application_mailer.rb)

Настройки, наследуемые почтовыми классами.

~~~~ruby
class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/mailers/application_mailer.rb:2) — `default from:`. Адрес from@example.com является шаблонной настройкой отправителя. Для реальной доставки нужны подходящие настройки почты и отправителя; код не подтверждает их готовность.

- [Строка 3](C:/Ruby/movie_recommender/app/mailers/application_mailer.rb:3) — `layout "mailer"`. Письмо получает HTML- или текстовую оболочку mailer в зависимости от формата.


<a id="file-063"></a>

## 63. Формирование письма восстановления

[Открыть app/mailers/passwords_mailer.rb](C:/Ruby/movie_recommender/app/mailers/passwords_mailer.rb)

Готовит получателя, тему и данные для шаблонов.

~~~~ruby
class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Reset your password", to: user.email_address
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/mailers/passwords_mailer.rb:2) — `def reset(user)`. Принимает пользователя от контроллера или preview.

- [Строка 3](C:/Ruby/movie_recommender/app/mailers/passwords_mailer.rb:3) — `@user = user`. Делает пользователя доступным ERB-шаблонам reset.html.erb и reset.text.erb.

- [Строка 4](C:/Ruby/movie_recommender/app/mailers/passwords_mailer.rb:4) — `mail subject:`. Задаёт тему и адрес назначения. Создание сообщения отделено от фактической отправки deliver_later.


<a id="file-064"></a>

## 64. HTML-версия письма

[Открыть app/views/passwords_mailer/reset.html.erb](C:/Ruby/movie_recommender/app/views/passwords_mailer/reset.html.erb)

Ссылка на смену пароля с токеном.

~~~~erb
<p>
  You can reset your password on
  <%= link_to "this password reset page", edit_password_url(@user.password_reset_token) %>.

  This link will expire in <%= distance_of_time_in_words(0, @user.password_reset_token_expires_in) %>.
</p>
~~~~

**Разбор значимых строк и блоков**

- [Строка 3](C:/Ruby/movie_recommender/app/views/passwords_mailer/reset.html.erb:3) — `edit_password_url(@user.password_reset_token)`. Использует полный URL, а не относительный path: письмо открывается вне сайта. Токен создаётся механизмом has_secure_password.

- [Строка 5](C:/Ruby/movie_recommender/app/views/passwords_mailer/reset.html.erb:5) — `distance_of_time_in_words`. Преобразует срок действия, возвращённый password_reset_token_expires_in, в читаемый текст. Само истечение проверяется на сервере, не этим предложением письма.


<a id="file-065"></a>

## 65. Текстовая версия письма

[Открыть app/views/passwords_mailer/reset.text.erb](C:/Ruby/movie_recommender/app/views/passwords_mailer/reset.text.erb)

Тот же смысл для почтовых клиентов без HTML.

~~~~erb
You can reset your password on
<%= edit_password_url(@user.password_reset_token) %>

This link will expire in <%= distance_of_time_in_words(0, @user.password_reset_token_expires_in) %>.
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/views/passwords_mailer/reset.text.erb:2) — `edit_password_url`. Полный адрес вставляется как текст, без link_to.

- [Строка 4](C:/Ruby/movie_recommender/app/views/passwords_mailer/reset.text.erb:4) — `distance_of_time_in_words`. Сообщает тот же срок. Две версии дают альтернативные форматы одного письма, не две независимые отправки.


<a id="file-066"></a>

## 66. HTML-оболочка почты

[Открыть app/views/layouts/mailer.html.erb](C:/Ruby/movie_recommender/app/views/layouts/mailer.html.erb)

Минимальный HTML-документ для писем.

~~~~erb
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <style>
      /* Email styles need to be inline */
    </style>
  </head>

  <body>
    <%= yield %>
  </body>
</html>
~~~~

**Разбор значимых строк и блоков**

- [Строка 4](C:/Ruby/movie_recommender/app/views/layouts/mailer.html.erb:4) — `charset=utf-8`. Позволяет корректно интерпретировать текст. В style пока только комментарий, реального оформления письма там нет.

- [Строка 11](C:/Ruby/movie_recommender/app/views/layouts/mailer.html.erb:11) — `<%= yield %>`. Содержимое reset вставляется сюда. Это отдельный layout, не основной интерфейс приложения.


<a id="file-067"></a>

## 67. Текстовая оболочка почты

[Открыть app/views/layouts/mailer.text.erb](C:/Ruby/movie_recommender/app/views/layouts/mailer.text.erb)

Не добавляет HTML к plain-text версии.

~~~~erb
<%= yield %>
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/views/layouts/mailer.text.erb:1) — `<%= yield %>`. Пропускает текст выбранного шаблона письма.


<a id="file-068"></a>

## 68. Базовый класс фоновых задач

[Открыть app/jobs/application_job.rb](C:/Ruby/movie_recommender/app/jobs/application_job.rb)

Основа для собственных задач Active Job.

~~~~ruby
class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/app/jobs/application_job.rb:1) — `class ApplicationJob < ActiveJob::Base`. Позволяет создавать задачи, выполняемые через адаптер очереди. Письма deliver_later используют Active Job, даже если своих классов задач пока нет.

- [Строка 3](C:/Ruby/movie_recommender/app/jobs/application_job.rb:3) — `# retry_on`. Закомментированный пример не включает автоматические повторы. Аналогично discard_on ниже — только подсказка генератора, не активное поведение.


<a id="file-069"></a>

## 69. Параметры Solid Queue

[Открыть config/queue.yml](C:/Ruby/movie_recommender/config/queue.yml)

Конфигурация диспетчеров и обработчиков фоновых задач.

~~~~yaml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY", 1) %>
      polling_interval: 1

development:
  <<: *default

test:
  <<: *default

production:
  <<: *default
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/config/queue.yml:2) — `dispatchers:`. Периодически подготавливают доступные задачи пакетами; polling_interval задаёт интервал, batch_size — размер партии.

- [Строка 5](C:/Ruby/movie_recommender/config/queue.yml:5) — `workers:`. Обработчики берут очереди '*', работают указанным числом потоков и процессов. JOB_CONCURRENCY задаёт процессы; при отсутствии переменной используется 1.

- [Строка 11](C:/Ruby/movie_recommender/config/queue.yml:11) — `development:`. Окружения наследуют YAML default. Файл описывает параметры, но сам по себе не запускает обработчик очереди и не меняет адаптер Active Job.


<a id="file-070"></a>

## 70. Параметры Solid Cache

[Открыть config/cache.yml](C:/Ruby/movie_recommender/config/cache.yml)

Настройки служебного кэша.

~~~~yaml
default: &default
  store_options:
    # Cap age of oldest cache entry to fulfill retention policies
    # max_age: <%= 60.days.to_i %>
    max_size: <%= 256.megabytes %>
    namespace: <%= Rails.env %>

development:
  <<: *default

test:
  <<: *default

production:
  database: cache
  <<: *default
~~~~

**Разбор значимых строк и блоков**

- [Строка 5](C:/Ruby/movie_recommender/config/cache.yml:5) — `max_size:`. Ограничение размера хранится в байтах, вычисленных Rails из 256.megabytes. max_age закомментирован и не включён.

- [Строка 6](C:/Ruby/movie_recommender/config/cache.yml:6) — `namespace:`. Разделяет имена записей по окружению.

- [Строка 15](C:/Ruby/movie_recommender/config/cache.yml:15) — `database: cache`. В production указывает соединение cache. В MovieSearch сейчас нет Rails.cache.fetch, поэтому наличие конфигурации не означает кэширование запросов TMDB.


<a id="file-071"></a>

## 71. Общая подготовка тестов

[Открыть test/test_helper.rb](C:/Ruby/movie_recommender/test/test_helper.rb)

Поднимает Rails в тестовом окружении и подключает вспомогательные средства.

~~~~ruby
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors, with: :threads)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/test/test_helper.rb:1) — `ENV["RAILS_ENV"] ||= "test"`. Устанавливает test, если переменная ещё не задана. ||=: присвоить только при nil/false. Для запуска тестов важно действительно использовать тестовую базу.

- [Строка 2](C:/Ruby/movie_recommender/test/test_helper.rb:2) — `require_relative`. Подключает окружение Rails по относительному пути; rails/test_help добавляет тестовые классы и утверждения.

- [Строка 4](C:/Ruby/movie_recommender/test/test_helper.rb:4) — `test_helpers/session_test_helper`. Загружает собственный помощник входа.

- [Строка 9](C:/Ruby/movie_recommender/test/test_helper.rb:9) — `parallelize`. Разрешает параллельные тесты по числу процессоров с потоками. Это настройка тестового выполнения, не пользовательская многопоточность комнаты.

- [Строка 12](C:/Ruby/movie_recommender/test/test_helper.rb:12) — `fixtures :all`. Перед тестами подготавливаются все фикстуры из test/fixtures. Устаревшие фикстуры могут помешать тестам ещё до проверки конкретного сценария.


<a id="file-072"></a>

## 72. Тестовые пользователи и текущая несовместимость

[Открыть test/fixtures/users.yml](C:/Ruby/movie_recommender/test/fixtures/users.yml)

Фикстуры — подготовленные данные отдельной тестовой базы.

~~~~yaml
<% password_digest = BCrypt::Password.create("password") %>

one:
  email_address: one@example.com
  password_digest: <%= password_digest %>

two:
  email_address: two@example.com
  password_digest: <%= password_digest %>
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/test/fixtures/users.yml:1) — `BCrypt::Password.create`. ERB генерирует digest известного тестового пароля 'password'. Это тестовое значение, не пароль реального аккаунта.

- [Строка 3](C:/Ruby/movie_recommender/test/fixtures/users.yml:3) — `one:`. Имя фикстуры; email и digest задают колонки. У записи нет nickname, а текущая схема требует NOT NULL. Поэтому эти данные необходимо обновить перед корректным полным прогоном.

- [Строка 7](C:/Ruby/movie_recommender/test/fixtures/users.yml:7) — `two:`. Второй тестовый пользователь имеет ту же проблему. Фикстуры загружаются не обычным User.create! с валидациями, но ограничения самой базы всё равно действуют.


<a id="file-073"></a>

## 73. Как тесты имитируют вход

[Открыть test/test_helpers/session_test_helper.rb](C:/Ruby/movie_recommender/test/test_helpers/session_test_helper.rb)

Позволяет проверять защищённые действия без повторения формы входа в каждом тесте.

~~~~ruby
module SessionTestHelper
  def sign_in_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/test/test_helpers/session_test_helper.rb:2) — `def sign_in_as(user)`. Создаёт сессию связанной коллекцией пользователя и сохраняет в Current.

- [Строка 5](C:/Ruby/movie_recommender/test/test_helpers/session_test_helper.rb:5) — `ActionDispatch::TestRequest.create.cookie_jar.tap`. Получает Rails cookie jar, чтобы сформировать настоящую подписанную cookie, а не просто записать голый ID.

- [Строка 6](C:/Ruby/movie_recommender/test/test_helpers/session_test_helper.rb:6) — `cookie_jar.signed[:session_id]`. Записывает значение с подписью; затем сырая подписанная строка переносится в cookies тестового клиента.

- [Строка 12](C:/Ruby/movie_recommender/test/test_helpers/session_test_helper.rb:12) — `Current.session&.destroy!`. &. в Ruby вызывает destroy! только если сессия не nil. cookies.delete убирает клиентскую часть.

- [Строка 17](C:/Ruby/movie_recommender/test/test_helpers/session_test_helper.rb:17) — `ActiveSupport.on_load`. Подключает методы к интеграционным тестам, когда соответствующий тестовый компонент загружен.


<a id="file-074"></a>

## 74. Проверки правил пользователя

[Открыть test/models/user_test.rb](C:/Ruby/movie_recommender/test/models/user_test.rb)

Тестирует модель напрямую, без браузерной страницы.

~~~~ruby
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "requires email_address" do
    user = User.new(password: "password", password_confirmation: "password")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "requires unique email_address" do
    User.create!(email_address: "test@example.com", password: "password", password_confirmation: "password")
    user = User.new(email_address: "test@example.com", password: "password", password_confirmation: "password")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "has already been taken"
  end

  test "requires valid email format" do
    user = User.new(email_address: "invalid", password: "password", password_confirmation: "password")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "is invalid"
  end

  test "requires password on create" do
    user = User.new(email_address: "test@example.com")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "requires password confirmation" do
    user = User.new(email_address: "test@example.com", password: "password", password_confirmation: "different")
    assert_not user.valid?
    assert_includes user.errors[:password_confirmation], "doesn't match Password"
  end

  test "requires password minimum length of 8" do
    user = User.new(email_address: "test@example.com", password: "short", password_confirmation: "short")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "accepts valid registration" do
    user = User.new(email_address: "test@example.com", password: "password123", password_confirmation: "password123")
    assert user.valid?
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 3](C:/Ruby/movie_recommender/test/models/user_test.rb:3) — `class UserTest < ActiveSupport::TestCase`. Базовый класс Rails для тестирования моделей. test 'описание' do объявляет отдельный сценарий.

- [Строка 4](C:/Ruby/movie_recommender/test/models/user_test.rb:4) — `downcases and strips`. Создаёт пользователя в памяти и сравнивает нормализованный email с ожидаемым через assert_equal.

- [Строка 9](C:/Ruby/movie_recommender/test/models/user_test.rb:9) — `requires email_address`. valid? запускает валидации без сохранения. assert_not требует ложный результат; assert_includes проверяет конкретную ошибку атрибута.

- [Строка 15](C:/Ruby/movie_recommender/test/models/user_test.rb:15) — `requires unique email_address`. Сначала создаёт существующую запись create!, затем проверяет дубликат. Сейчас первый create! не передаёт обязательный nickname и не дойдёт до задуманной проверки.

- [Строка 22](C:/Ruby/movie_recommender/test/models/user_test.rb:22) — `requires valid email format`. Проверяет наличие format-ошибки email. У объекта могут быть и другие ошибки, поэтому отрицательный valid? сам по себе не доказывает проверяемую причину; дополнительный assert_includes полезен.

- [Строка 28](C:/Ruby/movie_recommender/test/models/user_test.rb:28) — `requires password on create`. Проверяет сообщение отсутствующего пароля. Сценарий confirmation ниже передаёт несовпадающие значения и проверяет ошибку подтверждения.

- [Строка 40](C:/Ruby/movie_recommender/test/models/user_test.rb:40) — `requires password minimum length`. Проверяет текст ошибки слишком короткого пароля при создании.

- [Строка 46](C:/Ruby/movie_recommender/test/models/user_test.rb:46) — `accepts valid registration`. Намерение — принять корректную регистрацию, но объект не содержит nickname и сейчас невалиден. Отдельных тестов нормализации/уникальности nickname в этом файле нет. Здесь описан код и выявленная несогласованность, а не утверждение об успешном запуске.


<a id="file-075"></a>

## 75. Интеграционные тесты регистрации

[Открыть test/controllers/registrations_controller_test.rb](C:/Ruby/movie_recommender/test/controllers/registrations_controller_test.rb)

Отправляют HTTP-запросы через Rails и проверяют ответ, базу и cookie.

~~~~ruby
require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_registration_path
    assert_response :success
  end

  test "create with valid registration" do
    assert_difference("User.count") do
      post registration_path, params: { user: { email_address: "new@example.com", password: "password123", password_confirmation: "password123" } }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
    follow_redirect!
    assert_match "Welcome! You have signed up successfully.", response.body
  end

  test "create with invalid email" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: { email_address: "invalid", password: "password123", password_confirmation: "password123" } }
    end

    assert_response :unprocessable_entity
    assert_match "is invalid", response.body
    assert_nil cookies[:session_id]
  end

  test "create with taken email" do
    User.create!(email_address: "existing@example.com", password: "password123", password_confirmation: "password123")

    assert_no_difference("User.count") do
      post registration_path, params: { user: { email_address: "existing@example.com", password: "password123", password_confirmation: "password123" } }
    end

    assert_response :unprocessable_entity
    assert_match "has already been taken", response.body
    assert_nil cookies[:session_id]
  end

  test "create with mismatched password confirmation" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: { email_address: "new@example.com", password: "password123", password_confirmation: "different" } }
    end

    assert_response :unprocessable_entity
    assert_match "doesn&#39;t match Password", response.body
    assert_nil cookies[:session_id]
  end

  test "create with too short password" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: { email_address: "new@example.com", password: "short", password_confirmation: "short" } }
    end

    assert_response :unprocessable_entity
    assert_match "is too short", response.body
    assert_nil cookies[:session_id]
  end

  test "create with missing password" do
    assert_no_difference("User.count") do
      post registration_path, params: { user: { email_address: "new@example.com", password: "", password_confirmation: "" } }
    end

    assert_response :unprocessable_entity
    assert_match "can&#39;t be blank", response.body
    assert_nil cookies[:session_id]
  end

end
~~~~

**Разбор значимых строк и блоков**

- [Строка 5](C:/Ruby/movie_recommender/test/controllers/registrations_controller_test.rb:5) — `get new_registration_path`. Проверяет успешное открытие формы через assert_response :success.

- [Строка 10](C:/Ruby/movie_recommender/test/controllers/registrations_controller_test.rb:10) — `assert_difference("User.count")`. Ожидает увеличение количества пользователей на 1 внутри блока. Затем проверяются перенаправление и наличие cookie.

- [Строка 11](C:/Ruby/movie_recommender/test/controllers/registrations_controller_test.rb:11) — `post registration_path`. Отправляет вложенный user-хеш, как форма model: @user. Во всех старых примерах отсутствует nickname, поэтому успешный сценарий требует обновления.

- [Строка 16](C:/Ruby/movie_recommender/test/controllers/registrations_controller_test.rb:16) — `follow_redirect!`. Выполняет следующий запрос по Location и позволяет проверить сообщение на итоговой странице.

- [Строка 21](C:/Ruby/movie_recommender/test/controllers/registrations_controller_test.rb:21) — `assert_no_difference`. Для некорректных данных число пользователей не должно измениться; затем проверяются 422, текст и отсутствие cookie.

- [Строка 31](C:/Ruby/movie_recommender/test/controllers/registrations_controller_test.rb:31) — `User.create!`. Подготовка занятого email сейчас сама невалидна из-за отсутствующего nickname.

- [Строка 42](C:/Ruby/movie_recommender/test/controllers/registrations_controller_test.rb:42) — `mismatched password confirmation`. Проверяется ошибка подтверждения; HTML-апостроф в ответе экранирован, поэтому ожидается doesn&#39;t.

- [Строка 52](C:/Ruby/movie_recommender/test/controllers/registrations_controller_test.rb:52) — `too short password`. Последующие сценарии проверяют короткий и отсутствующий пароль. Важно не считать отрицательные тесты полностью актуальными только потому, что они получают ошибку: обязательный ник добавил новую независимую причину отказа.


<a id="file-076"></a>

## 76. Тесты входа и выхода

[Открыть test/controllers/sessions_controller_test.rb](C:/Ruby/movie_recommender/test/controllers/sessions_controller_test.rb)

Проверяют HTTP-поведение SessionsController.

~~~~ruby
require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 4](C:/Ruby/movie_recommender/test/controllers/sessions_controller_test.rb:4) — `setup { @user = User.take }`. Перед каждым тестом выбирается тестовый пользователь. Работоспособность зависит от корректной загрузки фикстур.

- [Строка 6](C:/Ruby/movie_recommender/test/controllers/sessions_controller_test.rb:6) — `test "new"`. Форма входа должна отвечать успешно.

- [Строка 12](C:/Ruby/movie_recommender/test/controllers/sessions_controller_test.rb:12) — `password: "password"`. Верный пароль совпадает со значением, digest которого создан в fixtures. Проверяются корневое перенаправление и session_id cookie.

- [Строка 19](C:/Ruby/movie_recommender/test/controllers/sessions_controller_test.rb:19) — `password: "wrong"`. Неверные данные должны вернуть к форме без cookie входа.

- [Строка 26](C:/Ruby/movie_recommender/test/controllers/sessions_controller_test.rb:26) — `sign_in_as(User.take)`. Помощник заранее создаёт авторизацию. DELETE /session должен вернуть ко входу и очистить cookie.


<a id="file-077"></a>

## 77. Тесты восстановления пароля

[Открыть test/controllers/passwords_controller_test.rb](C:/Ruby/movie_recommender/test/controllers/passwords_controller_test.rb)

Проверяют постановку письма в очередь, токены и обновление digest.

~~~~ruby
require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_password_path
    assert_response :success
  end

  test "create" do
    post passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "reset instructions sent"
  end

  test "create for an unknown user redirects but sends no mail" do
    post passwords_path, params: { email_address: "missing-user@example.com" }
    assert_enqueued_emails 0
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "reset instructions sent"
  end

  test "edit" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "edit with invalid password reset token" do
    get edit_password_path("invalid token")
    assert_redirected_to new_password_path

    follow_redirect!
    assert_notice "reset link is invalid"
  end

  test "update" do
    assert_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token), params: { password: "new", password_confirmation: "new" }
      assert_redirected_to new_session_path
    end

    follow_redirect!
    assert_notice "Password has been reset"
  end

  test "update with non matching passwords" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "no", password_confirmation: "match" }
      assert_redirected_to edit_password_path(token)
    end

    follow_redirect!
    assert_notice "Passwords did not match"
  end

  private
    def assert_notice(text)
      assert_select "div", /#{text}/
    end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 4](C:/Ruby/movie_recommender/test/controllers/passwords_controller_test.rb:4) — `setup { @user = User.take }`. Использует пользователя из фикстур, которые сейчас необходимо согласовать с nickname.

- [Строка 13](C:/Ruby/movie_recommender/test/controllers/passwords_controller_test.rb:13) — `assert_enqueued_email_with`. Проверяет постановку конкретного mailer-вызова с аргументом пользователя. Не проверяет доставку в реальный почтовый ящик.

- [Строка 22](C:/Ruby/movie_recommender/test/controllers/passwords_controller_test.rb:22) — `assert_enqueued_emails 0`. Для неизвестного email письмо не должно создаваться, но внешний переход/текст должны оставаться такими же.

- [Строка 30](C:/Ruby/movie_recommender/test/controllers/passwords_controller_test.rb:30) — `@user.password_reset_token`. Генерирует валидный токен для формы; отдельный сценарий посылает заведомо неправильную строку.

- [Строка 43](C:/Ruby/movie_recommender/test/controllers/passwords_controller_test.rb:43) — `assert_changes`. Сравнивает password_digest до/после блока; reload читает актуальные данные из базы.

- [Строка 44](C:/Ruby/movie_recommender/test/controllers/passwords_controller_test.rb:44) — `password: "new"`. Тест использует пароль из 3 символов. Это согласуется с текущим on:create для минимальной длины и показывает пробел в единой политике паролей, а не доказательство минимума 8 на сбросе.

- [Строка 54](C:/Ruby/movie_recommender/test/controllers/passwords_controller_test.rb:54) — `assert_no_changes`. Несовпадающие пароль и подтверждение не должны менять digest; проверяется возврат к той же форме.

- [Строка 64](C:/Ruby/movie_recommender/test/controllers/passwords_controller_test.rb:64) — `def assert_notice`. Общий помощник ищет div, содержащий текст по регулярному выражению. Проверяется содержание ответа, а не класс цвета блока.


<a id="file-078"></a>

## 78. Предпросмотр письма

[Открыть test/mailers/previews/passwords_mailer_preview.rb](C:/Ruby/movie_recommender/test/mailers/previews/passwords_mailer_preview.rb)

Удобство разработки, не автоматический тест отправки.

~~~~ruby
# Preview all emails at http://localhost:3000/rails/mailers/passwords_mailer
class PasswordsMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/passwords_mailer/reset
  def reset
    PasswordsMailer.reset(User.take)
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/test/mailers/previews/passwords_mailer_preview.rb:2) — `class PasswordsMailerPreview`. Rails находит preview по соглашению каталогов.

- [Строка 5](C:/Ruby/movie_recommender/test/mailers/previews/passwords_mailer_preview.rb:5) — `PasswordsMailer.reset(User.take)`. Формирует письмо первому пользователю для просмотра. При пустой базе User.take вернёт nil и этот пример не сможет сформировать письмо.


<a id="file-079"></a>

## 79. Фильтрация чувствительных параметров в логах

[Открыть config/initializers/filter_parameter_logging.rb](C:/Ruby/movie_recommender/config/initializers/filter_parameter_logging.rb)

Настраивает скрытие значений по совпадающим именам параметров.

~~~~ruby
# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]
~~~~

**Разбор значимых строк и блоков**

- [Строка 6](C:/Ruby/movie_recommender/config/initializers/filter_parameter_logging.rb:6) — `Rails.application.config.filter_parameters +=`. Добавляет имена и частичные совпадения, которые Rails заменяет фильтрованным значением в соответствующем журналировании параметров.

- [Строка 7](C:/Ruby/movie_recommender/config/initializers/filter_parameter_logging.rb:7) — `:passw, :email, :secret, :token`. Покрывает пароль, email, токены и другие группы. Не следует произвольно логировать заголовки и секреты, полагаясь только на фильтр параметров: ручной logger может обойти ожидаемое скрытие.


<a id="file-080"></a>

## 80. Первый этап запуска Ruby-зависимостей

[Открыть config/boot.rb](C:/Ruby/movie_recommender/config/boot.rb)

Подготавливает Bundler и ускоритель старта.

~~~~ruby
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/config/boot.rb:1) — `ENV["BUNDLE_GEMFILE"] ||=`. Указывает Gemfile относительно текущего файла, если путь ещё не задан.

- [Строка 3](C:/Ruby/movie_recommender/config/boot.rb:3) — `require "bundler/setup"`. Настраивает загрузку версий библиотек из lock-файла.

- [Строка 4](C:/Ruby/movie_recommender/config/boot.rb:4) — `require "bootsnap/setup"`. Включает кэширование затратных операций загрузки; это не кэш результатов поиска фильмов.


<a id="file-081"></a>

## 81. Создание приложения Rails

[Открыть config/application.rb](C:/Ruby/movie_recommender/config/application.rb)

Общая конфигурация, на которую накладываются настройки окружений.

~~~~ruby
require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MovieRecommender
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/config/application.rb:1) — `require_relative "boot"`. Сначала подготавливаются зависимости.

- [Строка 3](C:/Ruby/movie_recommender/config/application.rb:3) — `require "rails/all"`. Подключаются компоненты Rails.

- [Строка 7](C:/Ruby/movie_recommender/config/application.rb:7) — `Bundler.require(*Rails.groups)`. Автоматически требует gem-библиотеки для соответствующих групп; исключения require:false обрабатываются отдельно.

- [Строка 9](C:/Ruby/movie_recommender/config/application.rb:9) — `module MovieRecommender`. Пространство имён приложения; Application наследуется от Rails::Application.

- [Строка 12](C:/Ruby/movie_recommender/config/application.rb:12) — `config.load_defaults 8.1`. Загружает стандартные настройки указанного поколения Rails, а не задаёт версию gem самостоятельно.

- [Строка 17](C:/Ruby/movie_recommender/config/application.rb:17) — `config.autoload_lib`. Включает автозагрузку Ruby-кода из lib, исключая assets и tasks. Закомментированные примеры time_zone и eager_load_paths не активны.


<a id="file-082"></a>

## 82. Инициализация окружения

[Открыть config/environment.rb](C:/Ruby/movie_recommender/config/environment.rb)

Завершает создание настроенного Rails-приложения.

~~~~ruby
# Load the Rails application.
require_relative "application"

# Initialize the Rails application.
Rails.application.initialize!
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/config/environment.rb:2) — `require_relative "application"`. Загружает определение приложения.

- [Строка 5](C:/Ruby/movie_recommender/config/environment.rb:5) — `Rails.application.initialize!`. Выполняет процесс инициализации и initializers. Это отличается от создания отдельного объекта пользователя.


<a id="file-083"></a>

## 83. Вход в команды Rails

[Открыть bin/rails](C:/Ruby/movie_recommender/bin/rails)

Команда ruby bin/rails принимает server, test, runner и другие аргументы.

~~~~ruby
#!/usr/bin/env ruby.exe
APP_PATH = File.expand_path("../config/application", __dir__)
require_relative "../config/boot"
require "rails/commands"
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/bin/rails:2) — `APP_PATH`. Абсолютный путь к config/application, вычисленный от каталога скрипта, а не случайного текущего каталога.

- [Строка 3](C:/Ruby/movie_recommender/bin/rails:3) — `require_relative`. Подготавливает boot.

- [Строка 4](C:/Ruby/movie_recommender/bin/rails:4) — `require "rails/commands"`. Передаёт обработку аргументов стандартному командному механизму Rails.


<a id="file-084"></a>

## 84. Последовательность локальных проверок

[Открыть config/ci.rb](C:/Ruby/movie_recommender/config/ci.rb)

Описывает сценарий для bin/ci.

~~~~ruby
# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Tests: Rails", "bin/rails test"
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  # Optional: Run system tests
  # step "Tests: System", "bin/rails test:system"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
~~~~

**Разбор значимых строк и блоков**

- [Строка 3](C:/Ruby/movie_recommender/config/ci.rb:3) — `CI.run do`. Блок деклараций шагов проверки.

- [Строка 4](C:/Ruby/movie_recommender/config/ci.rb:4) — `step "Setup"`. Подготовка проекта без запуска сервера.

- [Строка 6](C:/Ruby/movie_recommender/config/ci.rb:6) — `step "Style: Ruby"`. RuboCop проверяет стиль и некоторые ошибки Ruby. Это не проверка всех пользовательских сценариев.

- [Строка 8](C:/Ruby/movie_recommender/config/ci.rb:8) — `step "Security:`. Аудит gem-зависимостей, импортов JavaScript и статический анализ Rails выполняют разные виды проверки.

- [Строка 11](C:/Ruby/movie_recommender/config/ci.rb:11) — `step "Tests: Rails"`. Запускает тесты; при нынешних фикстурах и примерах без nickname нельзя ожидать успешный полный прогон.

- [Строка 12](C:/Ruby/movie_recommender/config/ci.rb:12) — `step "Tests: Seeds"`. Проверяет повторное заполнение тестовой базы seeds. Команда записана в Unix-стиле env, поэтому её переносимость на PowerShell не следует считать проверенной.

- [Строка 14](C:/Ruby/movie_recommender/config/ci.rb:14) — `# Optional:`. Системные тесты и signoff здесь закомментированы. Комментарии не выполняют публикацию статуса.


<a id="file-085"></a>

## 85. Проверки на GitHub

[Открыть .github/workflows/ci.yml](C:/Ruby/movie_recommender/.github/workflows/ci.yml)

Автоматические задания в Linux-окружении GitHub Actions.

~~~~yaml
name: CI

on:
  pull_request:
  push:
    branches: [ master ]

jobs:
  scan_ruby:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Scan for common Rails security vulnerabilities using static analysis
        run: bin/brakeman --no-pager

      - name: Scan for known security vulnerabilities in gems used
        run: bin/bundler-audit

  scan_js:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Scan for security vulnerabilities in JavaScript dependencies
        run: bin/importmap audit

  lint:
    runs-on: ubuntu-latest
    env:
      RUBOCOP_CACHE_ROOT: tmp/rubocop
    steps:
      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Prepare RuboCop cache
        uses: actions/cache@v4
        env:
          DEPENDENCIES_HASH: ${{ hashFiles('.ruby-version', '**/.rubocop.yml', '**/.rubocop_todo.yml', 'Gemfile.lock') }}
        with:
          path: ${{ env.RUBOCOP_CACHE_ROOT }}
          key: rubocop-${{ runner.os }}-${{ env.DEPENDENCIES_HASH }}-${{ github.ref_name == github.event.repository.default_branch && github.run_id || 'default' }}
          restore-keys: |
            rubocop-${{ runner.os }}-${{ env.DEPENDENCIES_HASH }}-

      - name: Lint code for consistent style
        run: bin/rubocop -f github

  test:
    runs-on: ubuntu-latest

    # services:
    #  redis:
    #    image: valkey/valkey:8
    #    ports:
    #      - 6379:6379
    #    options: --health-cmd "redis-cli ping" --health-interval 10s --health-timeout 5s --health-retries 5
    steps:
      - name: Install packages
        run: sudo apt-get update && sudo apt-get install --no-install-recommends -y libvips

      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Run tests
        env:
          RAILS_ENV: test
          # RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
          # REDIS_URL: redis://localhost:6379/0
        run: bin/rails db:test:prepare test

  system-test:
    runs-on: ubuntu-latest

    # services:
    #  redis:
    #    image: valkey/valkey:8
    #    ports:
    #      - 6379:6379
    #    options: --health-cmd "redis-cli ping" --health-interval 10s --health-timeout 5s --health-retries 5
    steps:
      - name: Install packages
        run: sudo apt-get update && sudo apt-get install --no-install-recommends -y libvips

      - name: Checkout code
        uses: actions/checkout@v6

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Run System Tests
        env:
          RAILS_ENV: test
          # RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
          # REDIS_URL: redis://localhost:6379/0
        run: bin/rails db:test:prepare test:system

      - name: Keep screenshots from failed system tests
        uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: screenshots
          path: ${{ github.workspace }}/tmp/screenshots
          if-no-files-found: ignore
~~~~

**Разбор значимых строк и блоков**

- [Строка 3](C:/Ruby/movie_recommender/.github/workflows/ci.yml:3) — `on:`. Запуск на pull_request и push только в ветку master согласно этому файлу. Если рабочая ветка называется main, прямой push в main не попадает под этот push-фильтр.

- [Строка 9](C:/Ruby/movie_recommender/.github/workflows/ci.yml:9) — `scan_ruby:`. Отдельное задание установки Ruby, Brakeman и аудита gem-библиотек.

- [Строка 27](C:/Ruby/movie_recommender/.github/workflows/ci.yml:27) — `scan_js:`. Проверяет зависимости importmap.

- [Строка 42](C:/Ruby/movie_recommender/.github/workflows/ci.yml:42) — `lint:`. RuboCop с кэшем. Ключ использует версии и содержимое конфигурации; восстановленный кэш ускоряет анализ, не подменяет исходники.

- [Строка 68](C:/Ruby/movie_recommender/.github/workflows/ci.yml:68) — `test:`. Подготавливает тестовую базу и запускает тесты в RAILS_ENV=test.

- [Строка 96](C:/Ruby/movie_recommender/.github/workflows/ci.yml:96) — `system-test:`. Отдельный запуск браузерных системных тестов. Закомментированные services не поднимают Redis/Valkey.

- [Строка 126](C:/Ruby/movie_recommender/.github/workflows/ci.yml:126) — `if: failure()`. При неудаче системных тестов загружаются доступные скриншоты. Это помогает диагностике; сам факт наличия workflow не означает, что последний запуск успешен.


<a id="file-086"></a>

## 86. Манифест устанавливаемого приложения

[Открыть app/views/pwa/manifest.json.erb](C:/Ruby/movie_recommender/app/views/pwa/manifest.json.erb)

Заготовка метаданных PWA.

~~~~erb
{
  "name": "MovieRecommender",
  "icons": [
    {
      "src": "/icon.png",
      "type": "image/png",
      "sizes": "512x512"
    },
    {
      "src": "/icon.png",
      "type": "image/png",
      "sizes": "512x512",
      "purpose": "maskable"
    }
  ],
  "start_url": "/",
  "display": "standalone",
  "scope": "/",
  "description": "MovieRecommender.",
  "theme_color": "#0b1120",
  "background_color": "#0b1120"
}
~~~~

**Разбор значимых строк и блоков**

- [Строка 2](C:/Ruby/movie_recommender/app/views/pwa/manifest.json.erb:2) — `"name"`. Имя приложения и набор иконок, включая maskable для подходящих систем.

- [Строка 16](C:/Ruby/movie_recommender/app/views/pwa/manifest.json.erb:16) — `"start_url"`. Адрес запуска, область scope и display:standalone для поддерживающей установки.

- [Строка 20](C:/Ruby/movie_recommender/app/views/pwa/manifest.json.erb:20) — `"theme_color"`. Цвета согласованы с тёмной темой. Маршрут manifest и его подключение в layout сейчас закомментированы: файл сам по себе не включает установку PWA.


<a id="file-087"></a>

## 87. Закомментированный пример push-обработчика

[Открыть app/views/pwa/service-worker.js](C:/Ruby/movie_recommender/app/views/pwa/service-worker.js)

Сохранённая заготовка генератора, а не работающие уведомления.

~~~~javascript
// Add a service worker for processing Web Push notifications:
//
// self.addEventListener("push", async (event) => {
//   const { title, options } = await event.data.json()
//   event.waitUntil(self.registration.showNotification(title, options))
// })
//
// self.addEventListener("notificationclick", function(event) {
//   event.notification.close()
//   event.waitUntil(
//     clients.matchAll({ type: "window" }).then((clientList) => {
//       for (let i = 0; i < clientList.length; i++) {
//         let client = clientList[i]
//         let clientPath = (new URL(client.url)).pathname
//
//         if (clientPath == event.notification.data.path && "focus" in client) {
//           return client.focus()
//         }
//       }
//
//       if (clients.openWindow) {
//         return clients.openWindow(event.notification.data.path)
//       }
//     })
//   )
// })
~~~~

**Разбор значимых строк и блоков**

- [Строка 3](C:/Ruby/movie_recommender/app/views/pwa/service-worker.js:3) — `// self.addEventListener("push"`. Все строки кода закомментированы. Пример получил бы данные push и вызвал showNotification, но сейчас этого не происходит.

- [Строка 8](C:/Ruby/movie_recommender/app/views/pwa/service-worker.js:8) — `// self.addEventListener("notificationclick"`. Пример при нажатии на уведомление искал бы открытое окно и фокусировал его либо открывал новое. Это не тот же механизм, что видимый колокольчик уведомлений внутри сайта.


<a id="file-088"></a>

## 88. Начальные данные

[Открыть db/seeds.rb](C:/Ruby/movie_recommender/db/seeds.rb)

Место для обязательных воспроизводимых записей.

~~~~ruby
# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
~~~~

**Разбор значимых строк и блоков**

- [Строка 1](C:/Ruby/movie_recommender/db/seeds.rb:1) — `# This file`. Сейчас файл содержит комментарии и пример, реальных операций записи нет. idempotent означает, что повторное выполнение не должно создавать ненужные дубликаты.

- [Строка 7](C:/Ruby/movie_recommender/db/seeds.rb:7) — `#   ["Action"`. Пример find_or_create_by! закомментирован; модели MovieGenre в текущем приложении нет.


<a id="file-089"></a>

## 89. Инструкция запуска и описание текущей готовности

[Открыть README.md](C:/Ruby/movie_recommender/README.md)

Документация проекта, а не исполняемый код.

~~~~markdown
# Movie Recommender

## UI and Tailwind CSS

The interface uses Tailwind CSS 4 via `tailwindcss-rails`. Theme colors and fonts live in
`app/assets/tailwind/application.css`. The app uses a dark theme by default, with
shared tokens for backgrounds, text, borders and accents. Native form controls
also use the dark color scheme. Views use Tailwind utilities; shared button,
input and label classes live in `ApplicationHelper`. Navigation and notifications
are shared view partials. Decorative SVG icons use `ui_icon` so stroke widths and
accessibility attributes stay consistent across screens.

Install dependencies and start the app (also builds the stylesheet):

```powershell
bundle install
ruby bin/dev
```

While editing views, run the Tailwind watcher in a second terminal:

```powershell
ruby bin/rails tailwindcss:watch
```

For a one-time build, run `ruby bin/rails tailwindcss:build`. Rails also builds
Tailwind before tests and production asset precompilation. Generated CSS in
`app/assets/builds` is ignored by Git. Tailwind is compiled locally; no browser CDN
or Node.js dependency is required.

## UI Kit screens

Authenticated UI routes include `/ratings`, `/recommendations`, `/rooms`,
`/rooms/new`, `/room` and `/rooms/:id`. The room's selection button opens
`/room/selection` or `/rooms/:id/selection`, with a return link to the same room.
The selection screen is a shell for the future shared survey. The room, invitation, recommendation and
personal rating interfaces are ready for backend integration. They do not create
records, send invitations, save ratings or calculate recommendations yet. Form
submission for actions without a backend stays on the page and reports that the action is not available. No
sample rooms, members, invitation links or recommendation results are generated.

## Movie search setup

Movie search uses the TMDB API from the Rails server. Create an API Read Access Token in your TMDB account settings, then set it in the environment before starting Rails:

```powershell
$env:TMDB_API_READ_ACCESS_TOKEN = "your-token"
bin/rails server
```

Open `/movies` while signed in to search the catalog. Keep the token out of source code and do not commit it.

Movie data and posters are provided by TMDB. This website uses TMDB and the TMDB APIs but is not endorsed, certified, or otherwise approved by TMDB.
~~~~

**Разбор значимых строк и блоков**

- [Строка 3](C:/Ruby/movie_recommender/README.md:3) — `## UI and Tailwind CSS`. Объясняет расположение темы и общих компонентов.

- [Строка 17](C:/Ruby/movie_recommender/README.md:17) — `ruby bin/dev`. Текущий запуск собирает стили и запускает сервер; watch описан отдельно.

- [Строка 31](C:/Ruby/movie_recommender/README.md:31) — `## UI Kit screens`. Прямо фиксирует, что комнаты, приглашения, оценки и расчёты пока не подключены к серверному сохранению.

- [Строка 42](C:/Ruby/movie_recommender/README.md:42) — `## Movie search setup`. Описывает установку TMDB API Read Access Token в окружение до запуска Rails. В примере только placeholder, не настоящий секрет.


## Что находится в остальных служебных файлах

Разбор выше охватывает прикладные изменения и связанный код, включая стандартную основу, от которой зависит их работа. В репозитории также есть инфраструктурные заготовки и автоматически создаваемые результаты:

- `Gemfile.lock` фиксирует точные версии, зависимости и платформы. Это результат Bundler, а не написанный алгоритм; меняется при разрешении зависимостей.
- `app/assets/builds/tailwind.css` — результат компиляции. Читать тысячи сгенерированных правил вместо темы и классов шаблона обычно не нужно: нужное правило определяется соответствующим классом.
- `db/cache_schema.rb`, `db/queue_schema.rb`, `db/cable_schema.rb` описывают таблицы инфраструктуры Solid. Их записи не являются фильмами, комнатами и оценками продукта.
- `config/environments/development.rb`, `test.rb`, `production.rb` выбирают поведение окружений: перезагрузку, ошибки, кэширование, очередь, обслуживание ресурсов и другие параметры. Локальная разработка не равна production. В production здесь настроены Solid Cache и Solid Queue; это ещё не свидетельство работающего развёртывания.
- `config/puma.rb` настраивает процессы/потоки сервера; `config/storage.yml` — файловое хранилище Active Storage, не SQLite и не TMDB.
- `config/deploy.yml`, Dockerfile и bin/kamal — заготовки развёртывания; не выполняются от открытия страницы.
- bin/setup, bin/rake, bin/importmap, bin/jobs, bin/rubocop и остальные bin-обёртки запускают инструменты. Именно доработанный bin/dev объяснён отдельно.
- `.rubocop.yml`, config/bundler-audit.yml и прочие настройки инструментов задают правила анализа, а не логику продукта.
- `.keep` нужны, чтобы Git сохранял пустые каталоги. Они не исполняются.
- Изображения, иконки и шрифтовые/графические данные — ресурсы оформления, а не серверные действия.
- Ключи и реальные секреты не включены в документ.

## Нюансы, которые важно понимать при объяснении проекта

1. **Не все маршруты имеют все действия.** resource :session и resources :passwords объявлены без only, поэтому генерируют больше стандартных маршрутов, чем реально написано методов. Для презентации стоит показывать реализованные сценарии.
2. **404 внешнего каталога и 404 нашей страницы — разные вещи.** Сервис переводит ответ TMDB в исключение; контроллер показывает сообщение, но сейчас не выставляет HTTP 404.
3. **Кэш инфраструктуры не означает кэш TMDB.** В MovieSearch нет Rails.cache.fetch и повторов запросов. Каждое обращение контроллера к search/popular/details вызывает сеть.
4. **Работающая шкала не равна сохранённой оценке.** После перезагрузки нет записи, из которой можно восстановить выбор.
5. **Никакой общей авторизационной cookie для компании не нужно.** У каждого своя Session; совместность позже зададут Room, Membership и конкретный запуск подбора в базе.
6. **URL с ID не гарантирует объект.** Сейчас /rooms/42 отображает оболочку без поиска записи. Будущая реализация должна загрузить комнату и проверить участие; простого знания ID для доступа недостаточно.
7. **Предложенные настройки формы ещё не участвуют в расчётах.** genre/duration/exclude_watched пока не преобразуются в фильтры TMDB или правила ранжирования.
8. **Пароль проверяется библиотекой, но политика задаётся нашим кодом.** Минимум 8 в User ограничен созданием аккаунта. Сброс пароля требует согласования с тем же правилом, если оно должно действовать всегда.
9. **Тесты отстали от nickname.** Фикстуры без NOT NULL поля и успешные create без nickname не соответствуют модели/схеме. Отрицательный тест может получать отказ по лишней причине. В рамках этого разбора тесты не исправлялись и полный прогон не выполнялся.
10. **Процессы нужно различать.** Сервер, сборка/наблюдение CSS и обработчик очереди — разные роли. Текущий bin/dev выполняет однократную сборку и сервер; Procfile.dev сам им не читается.
11. **Уведомления пока локальные.** Панель колокольчика показывает статический текст. Она не подключена к базе приглашений, Action Cable и Web Push.
12. **Данные модели и ограничения базы дополняют друг друга.** Валидации дают понятный отказ, уникальные индексы и внешние ключи обеспечивают целостность даже при параллельных записях. Ни CSS, ни JavaScript не заменяют их.

## В каком порядке объяснять на показе

Открой routes → MoviesController → MovieSearch → movies/index → _movie_card → movies/show → _rating_form → rating_controller → pending_action_controller. Это один понятный путь от запроса до поведения в браузере. Затем покажи RoomsController и общую recommendation_form: станет видно, как один partial работает с destination и без него. Заверши User, миграциями и тестами, чтобы объяснить постоянные данные и текущие границы готовности.
