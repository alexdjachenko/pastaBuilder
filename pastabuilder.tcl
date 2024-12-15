#!/usr/bin/tclsh

#############################################################
# Предустановки
#############################################################

# Тип Источник сценария сборки: file/env
set strBScriptType "file"

# Путь к  файлу с описанием билда
set strBScriptPath "pastabuilder.yml"

# Формат источника сценария сборки yaml/json
set strBScriptFormat "yaml"

# Имя собираемого дистрибутива (без расширения)
set strBCode "1.0.O"

# Путь к временной папке для сборки (здесь и временные папки и кеши)
# Формат пути 
# Полезная нагрузка, собранная во-время шага cache/{{strBCode}}/{{strBStageCode}}/payload
set strBCachePath "cache"

# Путь к папке с собранными дистрибутивами 
# Формат пути (может формировать сразу несколько суффиксов, подпапок или файлов с расширениями)
#  result/{{strBCode}}[расширение]
set strBResultPath "result"

# Путь к папке с проектом, из которой импортируются файлы
set strBProjectPath "./"

# Имя файла со списком исключений, при импорте в проект, между проектами и экспорте релиза
# Должен находится в корне копируемой папки
set strExcludeFile ".pbignore"


#############################################################
# Инициализация
#############################################################


# Подключаем пакет yaml из tcllib
package require yaml

# Инициализация ООП
# Все это не нужно, и так работает:
#package require TclOO
# Чтобы не добавлять ::oo:: перед каждым оператором class и method
# namespace import oo::*

# Считываем содержимое файла в строку
set strBScript [read [open $strBScriptPath]]

# Конвертируем содержимое файла в массив
set dictBScript [::yaml::yaml2dict $strBScript]

# Отображаем для контроля (на этапе отладки)
#puts $dictBScript



#############################################################
# Библиотеки
#############################################################

# Класс для работы с путями и папками
::oo::class create keeperPaths {
  # Базовые пути, относительно которых формируются все остальные
  variable strBCachePath
  variable strBResultPath
  variable strBProjectPath
  # Код сборки (версия)
  variable strBCode
  # Код этапа сборки
  variable strCodeStage
  # Номер шага сборки
  variable intStepNum
  # Автосоздаение папок
  variable flagAutoCreate
  # Файл с исключениями для копирования в проект и между проектами
  variable strExcludeFile
  
  # Конструктор
  constructor {strBCachePath1 strBResultPath1 strBProjectPath1 strBCode1 strExcludeFile1} {
    # Значения из конструктора
    variable strBCachePath $strBCachePath1
    variable strBResultPath $strBResultPath1
    variable strBProjectPath $strBProjectPath1
    variable strBCode $strBCode1
    variable strExcludeFile $strExcludeFile1
    
    # Дефолтные значения
    variable flagAutoCreate 1
  }
  
  method setCodeStage {strCodeStage1} {
    #set strCodeStage $strCodeStage
    variable strCodeStage $strCodeStage1
  }
  
  method setStepNum {intStepNum1} {
    #set strCodeStage $strCodeStage
    variable intStepNum $intStepNum1
  }

  # Возвращает путь к базовой папке с результатами сборки
  method getBResultDirBasePath {} {
    set strPath [file normalize "$strBResultPath/"]
    my createDir $strPath 
    return $strPath
  }  
  # Возвращает путь к папке для результата сборки
  method getBResultDirPath {} {
    set strPath [file normalize "$strBResultPath/$strBCode/"]
    my createDir $strPath 
    return $strPath
  }

  # Возвращает путь и имя файла для результата сборки
  # Файл должен иметь расширение и может иметь суффикс (записывается после кода версии)
  method getBResultFilePath {extension {suffix ""}} {
    set strPath [file normalize "$strBResultPath/$strBCode$suffix.$extension"]
    return $strPath
  }

  # Путь к базовой папке с кешами
  method getCachePath {} {
    set strPath [file normalize "$strBCachePath/"]
    my createDir $strPath 
    return $strPath
  }
  
  # Путь к папке с результатом сборки этапа
  method getPayloadPath {{strSubPath ""} {strCodeStage2 ""} } {
    if { $strCodeStage2 == "" } {
      set strCodeStage2 $strCodeStage
    }
    
    set strPath [file normalize "$strBCachePath/$strBCode/$strCodeStage2/payload/$strSubPath"]
    my createDir $strPath 
    return $strPath
  }

  # Путь к временной папке для шага
  # Можно передать дополнительный суб-путь, 
  method getTempPath {{strSubPath ""}} {
    set strPath [file normalize "$strBCachePath/$strBCode/$strCodeStage/temp/$intStepNum/$strSubPath"]
    my createDir $strPath 
    return $strPath
  }
  
  # Путь к папке проекта
  method getProjectPath {{strSubPath ""}} {
    set strPath [file normalize "$strBProjectPath/$strSubPath"]
    # Проверка существования пути
    if {![file exists $strPath]} {
      throw wrong_class_name "Error: $strPath isn't exists!"
    }
    return $strPath
  }
  
  method createDir {strPath} {
    # Нормализуем путь
    set strPath [file normalize $strPath]
    
    # Проверяем, что целевой путь не является существующим файлом
    if {[file isfile $strPath]} {
      throw wrong_class_name "Error: $strPath is a file!"
    }
    
    # Проверяем флаг автосоздания
    if { ! $flagAutoCreate } {
      # Автосоздание выключено
      # Проверяем существование целевой папки
      if {![file isdirectory $strPath]} {
        throw wrong_class_name "Error: $strPath isn't exist and auto creation is off!"
      }
      return
    }

    # Проверяем наличие папки и создаем
    if {![file isdirectory $strPath]} {
      # puts "Создаем папку"
      return [file mkdir $strPath]
    }
    return
  }
  # Копирование файлов из источника в получатель
  # С проверкой существования и типа источника и получателя
  # Получатель всегда должен находиться внутри папки cache или result
  # flagDelete (по умолчанию - да) определяет, должны ли удаляться файлы в получателе, которые отсутствуют в источнике
  method copyFiles {strSrcPath strDestPath {flagDelete 1} {listExclude {}}} {
    # Нормализуем источник и получатель
    set strSrcPath [file normalize $strSrcPath]
    set strDestPath [file normalize $strDestPath]
    
    # Строка для дополнительных параметров к комманде
    set strExtOpts ""
    
    # Проверяем, что источник и получатель не выходят за пределы допустимых папок
    # Вариант 1
    #if {[string first $substring $strSrcPath] == -1} {
    #  throw wrong_class_name "Error: $strSrcPath isn't in $substring!"
    #}
    # Вариант 2, через glob-условие
    if {![string match [my getBResultDirPath]* $strDestPath] && ![string match [my getPayloadPath]* $strDestPath]} {
      puts "Error: $strDestPath isn't in [my getBResultDirPath] or in [my getPayloadPath]!"
      throw wrong_class_name "Error: $strDestPath isn't in [my getBResultDirPath] or in [my getPayloadPath]!"
    }
    
    # Обрабатываем флаг очистки получателя от лишних файлов, которых нет в источнике
    if { $flagDelete } {
      append strExtOpts " --delete "
    }
    
    # Обработка списка исключений для копирования
    # если список не пуст 
    #generateRsyncExcludeCommand {exclusionList}
    if {[llength $listExclude]} {
      # Добавляем к строке с дополнительными опциями список исключений
      append strExtOpts [my generateRsyncExcludeCommand $listExclude]
    }

    
    # Если источник - папка
    if {[file isdirectory $strSrcPath]} {
      # puts "Источник $strSrcPath являкется папкой"
      
      # Добавление опции с файлом исключений
      # Переменная из атрибутов класса
      if {[llength $strExcludeFile] && [file exists "$strSrcPath/$strExcludeFile"]} {
        # Добавляем к строке с дополнительными опциями список исключений
        append strExtOpts " --exclude-from='$strExcludeFile' "
        # Сам файл тоже добавляем в исключения
        append strExtOpts " --exclude='$strExcludeFile' "
      }
      
      # Проверяем на существование и создаем папку-получатель
      # с учетом флага автосоздания
      my createDir $strDestPath
      # Дополняем путь к источнику, чтобы копировалось только содержимое папки
      set strSrcPath "$strSrcPath/."
    
    # Если источник - файл
    } elseif {[file isfile $strSrcPath]} {
      # puts "Источник $strSrcPath является файлом"
      # Проверяем на существование и создаем родительску папку для получателя
      # с учетом флага автосоздания
      my createDir [file dirname $strDestPath]
    # Источник - ни файл и ни папка,
    # то есть его вообще нет
    } else {
      throw wrong_class_name "Error: $strSrcPath isn't exists!"
    }
    
    
    # Копирование
    puts "Копирование $strSrcPath в $strDestPath"
    # Синхронизируем с удалением лишних файлов
    set strCopyCommand "/usr/bin/rsync -a $strExtOpts $strSrcPath $strDestPath"
    
    puts $strCopyCommand
    # Исполнение команды и вывод результата
    if {[catch {exec /bin/sh -c "$strCopyCommand" } msg]} {
      puts "Результат выполнения: $msg."
    }
  }
  
  # Служебный мето для генерации фрагмента rsync по списку для исключения файлов по шаблонов
  method generateRsyncExcludeCommand {exclusionList} {
    # Проверяем, что передан список исключений
    if {[llength $exclusionList] == 0} {
        return ""
    }

    # Создаем фрагмент команды для rsync
    set excludeCommand ""
    foreach pattern $exclusionList {
        # Экранируем специальные символы для безопасности
        set safePattern [string map {'"' '\"' '\' '\\'} $pattern]
        append excludeCommand "--exclude=\"$safePattern\" "
    }

    # Возвращаем готовый фрагмент команды
    return $excludeCommand
  }
  
}



# Класс для этапа сборки
::oo::class create builderStage {
    # Словарь с параметрами этапа
    variable dictStage
    # Код этапа
    variable strCode
    # Шаги (сценарий) этапа
    variable dictSteps
    # Описание этапа
    variable strAbout
    # Системные пути
    variable objKeeperPaths
    
    
    # В качестве аргумента получаем весь словарь очередного stage
    # Включая ключ stage, содержащий код шага
    constructor {dictStage1 objKeeperPaths1} {
      #Параметры этапа
      #set dictStage $dictStage
      variable dictStage $dictStage1
      #Хранитель путей этапа
      #set keeperPaths $keeperPaths
      variable objKeeperPaths $objKeeperPaths1
      #puts [$keeperPaths getBResultPath]
      # Код этапа
      set strCode [dict get $dictStage stage]
      # Шаги этапа
      set dictSteps [dict get $dictStage steps]
      # Описание опционально
      if {[dict exists $dictStage about]} {
        set strAbout [dict get $dictStage about]
      }
    }

    # Исполнение сценария сборки для этапа
    method process {} {
      
      # Код должен присутствовать обязательно, чтобы не ленились
      puts "Этап: $strCode"
      
      # Описание этапа опционально
      if {[info exists strAbout]} {
        puts "Описание этапа: $strAbout"
      }
      
      # Нумеруем шаги внутри этапа с первого
      set intStepNum 0
      
      # Тестирую объек хранителя путей
      #puts [$objKeeperPaths getBResultDirPath]
      
      foreach {step} $dictSteps {
        # Инкремируем номер шага 
        incr intStepNum 1
        # Имя должно присутствовать обязательно, чтобы не ленились
        puts "  Шаг №$intStepNum: [dict get $step step]"
        puts "  Класс: [dict get $step class]"
        # Описание опуционально
        if {[dict exists $step about]} {
          puts "  Описание шага: [dict get $step about]"
        }
        #set step [mysubclass new]
        #set step [create_steps_handler empty]
        # Клонируем и доинициализируем хранитель путей
        # и записываем в переменную
        set objKeeperStepPaths [::oo::copy $objKeeperPaths]
        $objKeeperStepPaths setStepNum $intStepNum
        # Создаем объект шага
        # Передаем конструктору имя класса шага и описание шага
        set objStep [
          create_steps_handler [dict get $step class] $step $objKeeperStepPaths
        ]
        # Запускаем объект шага
        set stepResult [$objStep process]
      } 
    }
    
}


# Родительский класс для всех типов шагов сборки
::oo::class create builderStep {
    variable dictStep
    variable objKeeperPaths
    
    # В качестве аргумента получаем весь словарь очередного stage
    # Включая ключ stage, содержащий код шага
    constructor {dictStep1 objKeeperStepPaths} {
      variable dictStep $dictStep1
      variable objKeeperPaths $objKeeperStepPaths

    }
    
    method test {} {
        #puts "This is the state of the object: ... (print variables)"
        puts "Hellow world"
        puts $objKeeperPaths
    }
    
    # Прототип исполнения сценария сборки для шага
    method process {} {
        my variable dictStep
        puts "Processing [dict get $dictStep class] step"
    }
    
}

# Пустой класс для отладки
::oo::class create builderStep_empty {
    superclass builderStep
    method process {} {
        #puts "This is the state of the object: ... (print variables)"
        my variable dictStep
        puts "    Processing [dict get $dictStep class] step"
        #puts [dict get $this.step class] 
         
    }
    
}

# Второй пустой класс для отладки
::oo::class create builderStep_helloworld {
    superclass builderStep
    method process {} {
        my variable dictStep
        puts "    Processing [dict get $dictStep class] step"
        
        my variable objKeeperPaths
        # Путь к папке этапа
        puts "    Путь к папке этапа: [$objKeeperPaths getPayloadPath]"
        # Путь к временной папке шага
        puts "    Путь к временной папке шага: [$objKeeperPaths getTempPath]"
    }
    
}

# Класс для скачивания файлов
::oo::class create builderStep_download {
    superclass builderStep
    method process {} {
        # Инициализация переменных
        # Словарь с параметрами шага из родительского класса
        my variable dictStep
        
        puts "    Processing [dict get $dictStep class] step"
        
        # Получаем объект хранителя путей из родительского класса
        my variable objKeeperPaths
        
        # Получаем из настроек подпапки откуда и куда копировать данные
        set strSubFolgerSrcPath ""
        set strSubFolgerDestPath ""
        if {[dict exists $dictStep subfoldersrc]} { 
          set strSubFolgerSrcPath [dict get $dictStep subfoldersrc]
        }
        if {[dict exists $dictStep subfolderdest]} {
          set strSubFolgerDestPath [dict get $dictStep subfolderdest]
        }
        
        # Получаем из настроек флаг очистки получателя от лишних файлов
        # по-умолчанию влючен
        set flagDelete 1
        if { [dict exists $dictStep cleanunexisted] } {
          set flagDelete [dict get $dictStep cleanunexisted]
        }
        
        # Путь к источнику по-умолчанию
        # (переопределим для копирования одиночного файла)
        set strSrcPath "[$objKeeperPaths getTempPath unarch/$strSubFolgerSrcPath]"
        
        # Переопределяем путь к получателю
        # Сперва формируем путь к /payload, а остальное уже от типа архивации
        # т.к. при копировании файла не нужно создавать папку в получателе
        set strDestPath "[$objKeeperPaths getPayloadPath]"

        # Путь к папке этапа
        #puts "Путь к папке этапа: [$objKeeperPaths getPayloadPath]"
        # Путь к временной папке шага
        #puts "Путь к временной папке шага: [$objKeeperPaths getTempPath]"
        
        # Подключаем пакет для работы с http
        #package require http 2
        #package require tls 1.7
        
        # Получаем url из настроек
        set url [dict get $dictStep url]
        
        puts "    Загрузка: $url"
        
        # Вариант скачивания полностью инструментами TCL
        # Файл для результата
        #set file [open [$objKeeperPaths getTempPath]/download wb]
        # Подключаем tls для работы https
        #http::register https 443 [list ::tls::socket -autoservername true]
        # Выполняем скачивание
        #set token [http::geturl $url -channel $file -binary 1]
        #close $file
        #if {[http::status $token] eq "ok" && [http::ncode $token] == 200} {
        #  puts "  Downloaded successfully"
        #}
        #http::cleanup $token
        #puts "    curl -L $url --output $file"
        #catch {puts [exec /bin/sh -c "curl -C - –location $url --output [$objKeeperPaths getTempPath]/download]" }
        
        # Скачиваем curl-ом
        set strDowncloadCommand "curl -C - --location $url --output [$objKeeperPaths getTempPath]/download"
        puts "    $strDowncloadCommand"
        if {[catch {exec /bin/sh -c $strDowncloadCommand} msg]} {
          puts "Результат выполнения: $msg."
        }
        
        puts "    Скачено в [$objKeeperPaths getTempPath]/download"
        
        
        # Архивирование
        # Значение типа архивирования по умолчанию - none
        if {![dict exists $dictStep archive]} {
          dict set dictStep archive "none"
        }
        
        # Выполняем разархивирование
        switch [dict get $dictStep archive] {
          "none" {
            puts "    Распаковка не требуется. Используем исходный файл."
            set strSrcPath "[$objKeeperPaths getTempPath]/download"
            # Формируем путь к файлу-получателю 
            set strDestPath "[$objKeeperPaths getPayloadPath]/$strSubFolgerDestPath"
          }
          "zip" {
            puts "    Распаковка zip"
            # Пробую сделать это в блочном варианте
            # Позже стоит переделать на потоки https://core.tcl-lang.org/tips/doc/trunk/tip/234.md
            #zlib deflate
            # Пробую непосредственно через консоль
            set strUnpachCommand "unzip -u -o [$objKeeperPaths getTempPath]/download -d [$objKeeperPaths getTempPath unarch]"
            puts "    $strUnpachCommand"
            # Исполнение команды и вывод результата
            if {[catch {exec /bin/sh -c "$strUnpachCommand" } msg]} {
              puts "Результат выполнения: $msg."
            }
            
            puts "    Сохранено [$objKeeperPaths getTempPath]/unarch"
            # Формируем путь к папке-получателю и сразу создаем ее
            set strDestPath "[$objKeeperPaths getPayloadPath $strSubFolgerDestPath]"
          }

          "tar.gz" {
            puts "    Распаковка tar.gz"
            # Пробую сделать это в блочном варианте
            # Позже стоит переделать на потоки https://core.tcl-lang.org/tips/doc/trunk/tip/234.md
            #zlib deflate
            # Пробую непосредственно через консоль
            set strUnpachCommand "tar -xvzf [$objKeeperPaths getTempPath]/download -C [$objKeeperPaths getTempPath unarch]"
            puts "    $strUnpachCommand"
            # Исполнение команды и вывод результата
            if {[catch {exec /bin/sh -c "$strUnpachCommand" } msg]} {
              puts "Результат выполнения: $msg."
            }
            # Формируем путь к папке-получателю и сразу создаем ее
            set strDestPath "[$objKeeperPaths getPayloadPath $strSubFolgerDestPath]"
          }
          default {
            throw wrong_class_name "Error: [dict get $dictStep archive] isn't valid type of archivator!"
          }
        }

        # Копирование  в payload этапа
        # puts "    Копирование результата из $strSrcPath в $strDestPath"
        $objKeeperPaths copyFiles $strSrcPath $strDestPath  $flagDelete
    }
    
}


# Класс для копирования данных из другого этапа
::oo::class create builderStep_copyfromstage {
    superclass builderStep
    method process {} {
        # Инициализация переменных
        # Словарь с параметрами шага из родительского класса
        my variable dictStep
        
        puts "    Processing [dict get $dictStep class] step"
        
        # Получаем объект хранителя путей из родительского класса
        my variable objKeeperPaths
        
        # Этап-источник
        if {[dict exists $dictStep stagesrc]} {
          
          set strCodeStageSrc [dict get $dictStep stagesrc]
        } else {
          # Ошибка, не задан этап-источник
          throw wrong_class_name "Error: stagesrc isn't defined!"
        }
        
        
        # Получаем из настроек подпапки откуда и куда копировать данные
        set strSubFolgerSrcPath ""
        set strSubFolgerDestPath ""
        if {[dict exists $dictStep subfoldersrc]} { 
          set strSubFolgerSrcPath [dict get $dictStep subfoldersrc]
        }
        if {[dict exists $dictStep subfolderdest]} {
          set strSubFolgerDestPath [dict get $dictStep subfolderdest]
        }
        
        # Получаем из настроек флаг очистки получателя от лишних файлов
        # по-умолчанию влючен
        set flagDelete 1
        if { [dict exists $dictStep cleanunexisted] } {
          set flagDelete [dict get $dictStep cleanunexisted]
        }
        
        # Получаем из настроекс список шаблонов исключений файлов
        set listExclude {}
        if { [dict exists $dictStep exclude] } {
          set listExclude [dict get $dictStep exclude]
        }
        
        # Путь к источнику
        # (переопределим для копирования одиночного файла)
        set strSrcPath "[$objKeeperPaths getPayloadPath $strSubFolgerSrcPath $strCodeStageSrc]"
        
        # Базовый путь к получателю
        set strDestPath "[$objKeeperPaths getPayloadPath]"

        # Копирование  в payload этапа
        puts "    Копирование результата из $strSrcPath в $strDestPath"
        $objKeeperPaths copyFiles $strSrcPath $strDestPath $flagDelete $listExclude
    }
}

# Класс для копирования данных из текущего этапа в релиз
# Дополнительные опции позволяют заархивировать файлы
::oo::class create builderStep_release {
    superclass builderStep
    method process {} {
        # Инициализация переменных
        # Словарь с параметрами шага из родительского класса
        my variable dictStep
        
        puts "    Processing [dict get $dictStep class] step"
        
        # Получаем объект хранителя путей из родительского класса
        my variable objKeeperPaths
                
        # Архивирование
        # Значение типа архивирования по умолчанию - none
        if {![dict exists $dictStep archive]} {
          dict set dictStep archive "none"
        }
        
        # Суффикс для файла с архивом
        set strSuffix ""
        if {[dict exists $dictStep suffix]} {
          set strSuffix [dict get $dictStep suffix]
        }
        
        
        
        # Путь к источнику
        # (переопределим для копирования одиночного файла)
        set strSrcPath "[$objKeeperPaths getPayloadPath]"
        
        # Выполняем разархивирование
        switch [dict get $dictStep archive] {
          "none" {
            # Базовый путь к папке-получателю и автосоздание папки для результата
            set strDestPath "[$objKeeperPaths getBResultDirPath]"
            puts "    Упаковка не требуется. Копируем $strSrcPath в $strDestPath."
            $objKeeperPaths copyFiles $strSrcPath $strDestPath
          }
          "zip" {
            puts "    Упаковка релиза в zip"
            set strDestPath "[$objKeeperPaths getBResultFilePath "zip" $strSuffix]"
            #set strPackCommand "cd $strSrcPath && zip -r  $strDestPath  $strSrcPath/*"
            # --filesync - удалить из архива файлы, которые больше не присутвуют в шаге
            set strPackCommand "(cd $strSrcPath && zip --filesync -r  $strDestPath  .)"
            puts "    $strPackCommand"
            # Исполнение команды и вывод результата
            if {[catch {exec /bin/sh -c "$strPackCommand" } msg]} {
              puts "Результат выполнения: $msg."
            }
          }

          "tar.gz" {
            puts "    Распаковка tar.gz"
            set strDestPath "[$objKeeperPaths getBResultFilePath "tar.gz" $strSuffix]"
            set strPackCommand "(tar -czf  $strDestPath -C $strSrcPath .)"
            puts "    $strPackCommand"
            # Исполнение команды и вывод результата
            if {[catch {exec /bin/sh -c "$strPackCommand" } msg]} {
              puts "Результат выполнения: $msg."
            } 
          }
          default {
            throw wrong_class_name "Error: [dict get $dictStep archive] isn't valid type of archivator!"
          }
        }
    }
}

# Класс для импорта файлов из проекта
::oo::class create builderStep_import {
    superclass builderStep
    method process {} {
        # Инициализация переменных
        # Словарь с параметрами шага из родительского класса
        my variable dictStep
        
        puts "    Processing [dict get $dictStep class] step"
        
        # Получаем объект хранителя путей из родительского класса
        my variable objKeeperPaths
        
        # Получаем из настроек подпапки откуда и куда копировать данные
        set strSubFolgerSrcPath ""
        set strSubFolgerDestPath ""
        if {[dict exists $dictStep subfoldersrc]} { 
          set strSubFolgerSrcPath [dict get $dictStep subfoldersrc]
        }
        if {[dict exists $dictStep subfolderdest]} {
          set strSubFolgerDestPath [dict get $dictStep subfolderdest]
        }
        
        # Получаем из настроек флаг очистки получателя от лишних файлов
        # по-умолчанию влючен
        set flagDelete 1
        if { [dict exists $dictStep cleanunexisted] } {
          set flagDelete [dict get $dictStep cleanunexisted]
        }
        
        # Получаем из настроекс список шаблонов исключений файлов
        set listExclude {}
        if { [dict exists $dictStep exclude] } {
          set listExclude [dict get $dictStep exclude]
        }
        
        # Путь к источнику
        # (переопределим для копирования одиночного файла)
        set strSrcPath "[$objKeeperPaths getProjectPath $strSubFolgerSrcPath]"
        
        # Базовый путь к получателю
        set strDestPath "[$objKeeperPaths getPayloadPath]"
        
        # Исключаем папку кеша и результатов сборки, чтобы они никогда не попадали в проект
        # Чтобы избежать рекурсии
        if {[string equal -length [string length $strSrcPath] $strSrcPath [$objKeeperPaths getCachePath]]} {
          # Do the replacement
          # Кеш действительно находится внутри проекта - добавляем исключение
          # Нужен относительный путь, поэтому выкусываем включая начальный слеш в имени папки
          lappend listExclude "[string replace [$objKeeperPaths getCachePath] 0 [string length $strSrcPath]]/"
        }
        if {[string equal -length [string length $strSrcPath] $strSrcPath [$objKeeperPaths getBResultDirBasePath]]} {
          # Do the replacement
          # Папка результатов действительно находится внутри проекта - добавляем исключение
          # Нужен относительный путь, поэтому выкусываем включая начальный слеш в имени папки
          lappend listExclude "[string replace [$objKeeperPaths getBResultDirBasePath] 0 [string length $strSrcPath]]/"
        }

        #lappend listExclude "[$objKeeperPaths getBResultDirBasePath]/*"
        # [string replace $string 0 [string length $prefix]-1]
        #lappend listExclude [string replace [$objKeeperPaths getBResultDirBasePath] 0 [string length $strSrcPath]-1]
        #lappend listExclude [$objKeeperPaths getCachePath]
        #lappend listExclude [string replace [$objKeeperPaths getCachePath] 0 [string length $strSrcPath]-1]

        # Копирование  в payload этапа
        puts "    Копирование результата из $strSrcPath в $strDestPath"
        $objKeeperPaths copyFiles $strSrcPath $strDestPath $flagDelete $listExclude
    }
}


# Фабрика для создания объектов шагов по имени
proc create_steps_handler {strStepName step objKeeperStepPaths} {
   # Очищаем строку и приводим к нижнему регистру
   set strStepName [string tolower [string trim $strStepName]]
   # Проверяем строку на отсутвие лишних символом
   if { !([string is wordchar -strict $strStepName]) } {
    throw wrong_class_name "Error: $strStepName is unvalidate!"
   }
   
   return ["builderStep_$strStepName" new $step $objKeeperStepPaths]
}

#############################################################
# Исполнение
#############################################################
# Обходим конфигурацию и выполняем сборку

# Иницииализируем общий хранитель путей
set objKeeperPaths [keeperPaths new $strBCachePath $strBResultPath $strBProjectPath $strBCode $strExcludeFile]


# Обходим этапы сборки
foreach {stage} $dictBScript {
  # Клонируем и доинициализируем хранитель путей
  # и записываем в переменную
  set objKeeperStagePaths [::oo::copy $objKeeperPaths]
  $objKeeperStagePaths setCodeStage [dict get $stage stage]
  
  
  # Создаем и инициализируем объект этапа
  set objStage [builderStage new $stage $objKeeperStagePaths]
  # Запускаем обработку этапа сборки
  $objStage process
  
}
