# Контекст для ИИ-ассистента

## Проект
iOS-приложение CarTracker для учёта работ по автомобилю.
SwiftUI + Swift Charts, хранение в UserDefaults.
Минимальная версия iOS: 16.0

## Архитектура
- MVVM (Models / ViewModels / Views)
- CarWorkStore — ObservableObject, хранит массив CarWork
- Персистентность: JSON → UserDefaults (ключ "car_works_v1")

## Модель данных
CarWork: id, title, category, date, mileage, cost, note, isDone
WorkCategory: maintenance, repair, tires, fuel, insurance, other

## Соглашения по коду
- Комментарии на русском
- Названия на английском
- Форматирование валюты: "₽", без копеек
- Категории имеют icon и цвет (см. StatsView.colorFor)
- Не использовать сторонние зависимости без обсуждения

## Что НЕ делать
- Не переходить на UIKit
- Не ломать существующий API CarWorkStore
- При добавлении фич — обновлять README и CHANGELOG


## Текущая задача
(пусто — фича «Напоминания» завершена)

## История версий
- v1.0 (2026-09-21) — релиз: работы, статистика, напоминания
