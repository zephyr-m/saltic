# Saltic — закрытое ядро

Метаданные контрольной точки. Исходники ядра остаются в `soul/seed`, эта папка их не копирует.

Дата: 2026-09-25.

Fixed point stage-2 и stage-3:

`c4a5152efd028328273385b55553e66c379e1f84d0ffa4aa2689ebe8d4513cba`

Файл `os/bootstrap/compiler.elf` в дереве — предыдущее поколение, хеш `01aef6950c7e046df2fb12bded8cdd898241cac7fd3f0ad7e7cf8c497e286729`. Он собирает stage-1. Совпавшие stage-2 и stage-3 собраны уже новым исходником.

Проверка:

```sh
just test
```

Каноническая сборка: исходник → прямой ELF. Восстановление компилятора — `os/bootstrap/compiler.elf` из Git.
