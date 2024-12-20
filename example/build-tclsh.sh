#!/bin/bash

# Получаем полный путь к директории, где находится скрипт
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Меняем текущую директорию на директорию скрипта
cd "$SCRIPT_DIR" || exit

# Теперь текущая папка — это папка скрипта
echo "Текущая директория: $(pwd)"

#/usr/bin/tclsh ../pastabuilder.tcl "$@"
/usr/bin/tclsh ../pastabuilder.tcl -code 0.0.1b