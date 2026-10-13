# Windows Customization Stack (Komorebi + YASB + whkd + OneCommander + Terminal + Fastfetch + VS Code)

Связка для организации рабочих столов, динамического тайлинга, красивого терминала (Windows Terminal + PowerShell 7 + Oh My Posh wholespace + Fastfetch), редактора VS Code (Lunar Pink + Bunker) и быстрого управления на Windows 11.

---

## Профили (Workspaces)

Все приложения автоматически распределяются по своим рабочим столам:

| Номер | Имя | Назначение | Автоматически привязанные приложения |
|---|---|---|---|
| **`Alt + 1`** | **`DEV`** | Разработка & IDE | VS Code (`Code.exe`), Cursor, JetBrains (IntelliJ, PyCharm, WebStorm) |
| **`Alt + 2`** | **`WEB`** | Браузер | Chrome (`chrome.exe`), Edge, Brave, Firefox, Zen |
| **`Alt + 3`** | **`FILES`** | Файловый менеджер | **OneCommander** (`OneCommander.exe`), Explorer |
| **`Alt + 4`** | **`TERM`** | Терминалы & Shell | Windows Terminal (`WindowsTerminal.exe`), wt, pwsh, cmd, Alacritty |
| **`Alt + 5`** | **`CHAT`** | Мессенджеры | Telegram, Discord, Slack, WhatsApp, Unigram |
| **`Alt + 6`** | **`MEDIA`** | Мультимедиа & Заметки | **YouTube Music**, Spotify, VLC, Obsidian, Notion |
| **`Alt + 7`** | **`MISC`** | Свободный стол | Любые временные окна |

---

## Горячие клавиши (whkd)

### Навигация и столы
| Комбинация | Действие |
|---|---|
| **`Alt + 1 .. 7`** | Мгновенно переключиться на стол 1 .. 7 |
| **`Alt + Shift + 1 .. 7`** или **`Alt + Ctrl + 1 .. 7`** | Перенести активное окно на стол 1 .. 7 |
| **`Alt + Стрелки`** / **`Alt + H/J/K/L`** | Фокус окна (влево/вниз/вверх/вправо) |
| **`Alt + Shift + Стрелки`** / **`H/J/K/L`** | Переместить окно внутри сетки |
| **`Alt + Shift + Enter`** | Сделать окно главным (Promote) |
| **`Alt + Shift + [` / `]`** | Циклический фокус окон |

### Управление окнами
| Комбинация | Действие |
|---|---|
| **`Alt + M`** | **Захватить окно в Komorebi** (если открыто вне тайлинга) |
| **`Alt + F`** | **Toggle Float** (отвязать окно от сетки / плавающий режим) |
| **`Alt + Shift + F`** | **Monocle** (развернуть окно на весь экран без выхода из тайлинга) |
| **`Alt + Shift + Q`** | Закрыть окно |
| **`Alt + Shift + M`** | Свернуть окно |
| **`Alt + Q`** | **Retile** (принудительно пересчитать сетку окон) |
| **`Alt + P`** | **Pause** (приостановить тайлинг) |
| **`Alt + X`** / **`Alt + Y`** | Отразить раскладку (по горизонтали / по вертикали) |

### Ресайз окон
| Комбинация | Действие |
|---|---|
| **`Alt + Plus`** / **`Minus`** | Увеличить / уменьшить ширину по горизонтали |
| **`Alt + Shift + Plus`** / **`Minus`** | Увеличить / уменьшить высоту по вертикали |

### Быстрый запуск и служебные
| Комбинация | Действие |
|---|---|
| **`Alt + E`** | Запустить **OneCommander** |
| **`Alt + Return`** / **`Alt + T`** | Запустить **Windows Terminal (pwsh + Oh My Posh)** |
| **`Alt + B`** | Показать / скрыть панель задач Windows |
| **`Alt + Shift + O`** | Перезагрузить конфиг Komorebi и применить правила столов |
| **`Alt + Shift + E`** | Принудительно раскидать все открытые окна по профилям |
| **`Alt + O`** | Перезапустить демон хоткеев whkd |

---

## Редактор VS Code (Lunar Pink + Bunker Icons)

- Цветовая тема: **Lunar Pink** (`nicolasdschmidt.lunar-pink`)
- Набор иконок: **dobri-theme-icons** (`sldobri.bunker`)
- Конфигурация: `vscode/settings.json` и `vscode/extensions.txt`

При выполнении `.\scripts\sync.ps1` настройки автоматически сливаются в `%APPDATA%\Code\User\settings.json`, а расширения при необходимости доустанавливаются через CLI `code`.

---

## Синхронизация конфигов из репозитория

Чтобы применить правки из репозитория в систему:

```powershell
# Быстрая замена конфигов без прерывания
.\scripts\sync.ps1

# Полный чистый перезапуск демонов
.\scripts\sync.ps1 -Restart
```
