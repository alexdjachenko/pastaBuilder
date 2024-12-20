# За основу берем otlamp2 на базе ubuntu2004, apache2 и php72
FROM alexdjachenko/pastabuilder AS pastabuilder

# Copy project to builder
COPY . /opt/pastabuilder/var/

# Аргументы для сборщика
ARG PB_ARGS="-help"

# Последний этап настройки
# Мы должны это сделать после установки ядра
RUN echo 'start' \
    && cd /opt/pastabuilder/var \
    && /usr/bin/tclsh /opt/pastabuilder/bin/pastabuilder.tcl $PB_ARGS \
    && echo 'end'

# Пустой образ для результата
FROM scratch AS res-img

#COPY --from=moodledistr /tmp/build/moodle .
COPY --from=pastabuilder /opt/pastabuilder/var/result  .