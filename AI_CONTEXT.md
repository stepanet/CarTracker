# Контекст для ИИ-ассистента


## Проект
iOS-приложение CarTracker для учёта работ по автомобилю.
SwiftUI + Swift Charts, хранение в UserDefaults.
Минимальная версия iOS: 16.0
## Архитектура
- **MVVM** (Models / ViewModels / Views)
- **Сторы** (`CarWorkStore`, `ReminderStore`, `VehicleStore`) — `ObservableObject`
- **Репозитории** (`WorksRepository`, `RemindersRepository`, `VehiclesRepository`) — доступ к Supabase
- **Realtime** (`RealtimeManager`) — подписки через WebSocket
- **Аутентификация** (`AuthManager`) — сессия в Keychain
- **Клиент Supabase** (`SupabaseService`) — singleton
- **`VehicleStore.shared`** — singleton, доступен из других сторов

## Модель данных
- **CarWork**: id, vehicleId, title, category, date, mileage, cost, note, isDone, subWorks
- **SubItem**: id, type (work/part), title, quantity, unitPrice, note
- **Reminder**: id, vehicleId, title, icon, intervalKm, intervalMonths, lastDate, lastMileage, isEnabled
- **Vehicle**: id, name, type, plate, year, icon, initialMileage, isDefault
- **WorkCategory**: maintenance, repair, tires, fuel, insurance, other
- **VehicleType**: car, motorcycle, scooter, other

## Соглашения по коду
- Комментарии на русском
- Названия на английском
- Форматирование валюты: "₽", без копеек
- Категории имеют icon и цвет (см. StatsView.colorFor)
- Не использовать сторонние зависимости без обсуждения
- Бэкапы используют JSON с `.iso8601` датами и `version` для будущих миграций
- CSV-экспорт: разделитель `;`, BOM в начале файла (для Excel)
- Фоновые задачи регистрируются в `CarTrackerApp.init()`, планируются при уходе в фон
- Идентификатор задачи: `com.cartracker.app.refresh` (должен совпадать с Info.plist)
- Сторы работают с Supabase через репозитории (`WorksRepository`, `RemindersRepository`)
- Realtime-подписки через `RealtimeManager` (единый singleton)
- Оптимистичные обновления: сначала UI, потом сервер, при ошибке — откат
- Миграция UserDefaults → Supabase при первом входе
- При работе с `User` (Supabase Auth) — `import Auth` в файле
- Кастомный `init(from:)` в моделях для совместимости с бэкапами
- `replica identity full` в Supabase для Realtime DELETE
- Метод удаления в сторах — `remove(_:)`, а не `delete(_:)`
- `.sheet` не наследует `@EnvironmentObject` — передавать явно
- `VehicleStore.shared` — singleton, доступен из других сторов
- `activeVehicleId` фильтрует работы и напоминания

## Что НЕ делать
- Не переходить на UIKit
- Не ломать существующий API CarWorkStore
- При добавлении фич — обновлять README и CHANGELOG
- Не кладите `service_role` key в клиент (только `anon`)
- Не используйте `subscribe()` — только `subscribeWithError()`
- Не забывайте `import Auth` при работе с полями `User`


## Текущая задача


## История версий
- v3.0 (2026-10-01) — Гараж: несколько транспортных средств
- v2.0 (2026-09-24) — облачная синхронизация через Supabase
- v1.3 (2026-09-23) — подработки и статистика 2.0
- v1.2 (2026-09-22) — фоновая проверка напоминаний
- v1.1 (2026-09-22) — экспорт/импорт JSON и CSV
- v1.0 (2026-09-21) — релиз: работы, статистика, напоминания
