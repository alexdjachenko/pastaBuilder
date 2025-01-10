# За основу берем свежий образ Ubuntu 20.04
# Хеш свежей сборки 20.04 можно посмотреть вот здесь: https://hub.docker.com/_/ubuntu/tags?page=1&name=20.04
# FROM otcloud.hub.3072.ru/ubuntu:20.04@sha256:874aca52f79ae5f8258faff03e10ce99ae836f6e7d2df6ecd3da5c1cad3a912b
#FROM otcloud.hub.3072.ru/ubuntu:20.04@sha256:cc9cc8169c9517ae035cf293b15f06922cb8c6c864d625a72b7b18667f264b70
#  2024-07-24
# FROM otcloud.hub.3072.ru/ubuntu:20.04@sha256:d86db849e59626d94f768c679aba441163c996caf7a3426f44924d0239ffe03f
FROM ubuntu:20.04@sha256:85c08a37b74bc18a7b3f8cf89aabdfac51c525cdbc193a753f7907965e310ec2

LABEL maintainer="Alex Dyachenko" 

# Параметры запуска образа
# Вокруг = не должно быть пробелов!!!
# Там, где переменные связаны с другими образамии имена переменных приведены в соответствие с их аналогами
# например, для образов mysql и postgresql.
# Переменные добавлены одной колонкой, чтобы уменьшить количество слоев
# Дефолтные секреты не передавайте их через меременные окружения!
# Используйте Docker secrets

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm \
    TZ='UTC' \
    LANG='en_US.utf8'


# Ставим базовые пакеты, необходимые для сборки
# Отделено в отдельный этап, чтобы лучше кешировалась сборка
RUN echo Build stage 1 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
                ca-certificates  \
                apt-transport-https \
                locales \
                lsb-release \ 
                git \
                zip \
                unzip \
                curl \
                wget \
                rsync \
                patch \
# Ставим штатный tcl
                tcl \
# Стандартная библиотека для tcl
                tcllib \
# Библиотека для https
                tcl-tls \
# Библиотеки, без которых не работает freewrap
                libxft2 \
# Для скачивания drupal и библиотек на php
#                composer \
# Поскольку composer-1 устарел, ставим php-cli и компосер с сайта разработчиков
                 php-cli \
                 php-curl \
# Добавляем финальную строку без завершающего \, чтобы не забывать в остальных строках ее добавлять
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
# Installing freewrap
    && mkdir -p --mode=o+x /opt/freewrap \
    && cd /opt/freewrap \
    && wget https://sourceforge.net/projects/freewrap/files/freewrap/freeWrap%206.75/freewrap675.tar.gz/download --output-document=/opt/freewrap/freewrap675.tar.gz \
    && tar -xvzf freewrap675.tar.gz \
    && mkdir -p --mode=o+x /opt/pastabuilder/bin \
    && mkdir -p --mode=o+x /opt/pastabuilder/var/cache \
    && mkdir -p --mode=o+x /opt/pastabuilder/var/result \
# Для скачивания drupal и библиотек на php ставим свежий компосер
    && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php -r "if (hash_file('sha384', 'composer-setup.php') === 'dac665fdc30fdd8ec78b38b9800061b4150413ff2e3b6f88543c636f7cd84f6db9189d43a81e5503cda447da73c7e5b6') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
    && php composer-setup.php \
    && php -r "unlink('composer-setup.php');" \
    && mv composer.phar /usr/local/bin/composer \
    && alias composer='/usr/local/bin/composer' \
    && echo 'end'

# Второй этап установки пока не нужен
#RUN echo Build stage 2 \
# Preparing folder for pastabuilder
#    && echo 'end'

ENV COMPOSER_ALLOW_SUPERUSER=1

COPY pastabuilder.tcl /opt/pastabuilder/bin/pastabuilder.tcl

# Команда для бесконечного запуска
CMD ["/usr/bin/tail","-F","/dev/stdout"]    

 


    

 