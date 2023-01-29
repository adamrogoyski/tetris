FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt -y --no-install-recommends install gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
RUN apt install -y --no-install-recommends pulseaudio git curl ca-certificates
RUN apt install -y --no-install-recommends guile-3.0 guile-3.0-dev autoconf automake texinfo libturbojpeg0-dev libopenal-dev
RUN git clone https://git.dthompson.us/guile-sdl2.git && cd guile-sdl2 && autoreconf --install && ./configure && make && make install
RUN curl -oguile-opengl-0.1.0.tar.gz https://ftp.gnu.org/gnu/guile-opengl/guile-opengl-0.1.0.tar.gz && tar -zxvf guile-opengl-0.1.0.tar.gz && cd guile-opengl-0.1.0 && sed -i 's/2.2 2.0/3.0 2.2 2.0/' configure && sed -i 's/2.2 2.0/3.0 2.2 2.0/' configure.ac && autoreconf && ./configure && make && make install
RUN git clone https://git.dthompson.us/chickadee.git
RUN rm /usr/bin/guile && /bin/echo -e '#!/bin/sh\nGUILE_LOAD_COMPILED_PATH=/usr/local/lib/guile/3.0/site-ccache:/usr/local/lib/guile/3.0/ccache /etc/alternatives/guile "$@"' > /usr/bin/guile && chmod 755 /usr/bin/guile
RUN cd chickadee && autoreconf --install && ./configure
RUN bash -c "cd chickadee; for f in chickadee/graphics/*.scm; do t=\"\$(mktemp)\"; cat <(echo '(add-to-load-path \"/usr/local/share/guile/site/3.0\")') \"\${f}\" > \"\${t}\"; mv \"\${t}\" \"\${f}\"; done && make && make install"
COPY fonts/ fonts/
COPY graphics/ graphics/
COPY sound/ sound/
COPY scheme/guile-chickadee/tetris.scm .
