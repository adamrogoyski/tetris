FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt -y --no-install-recommends install sbcl cl-quicklisp libsdl2-2.0-0 libsdl2-mixer-2.0-0
RUN apt update && apt -y --no-install-recommends install gcc libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
RUN apt install -y --no-install-recommends pulseaudio git ca-certificates
RUN bash -c 'sbcl --load /usr/share/common-lisp/source/quicklisp/quicklisp.lisp <<< "(quicklisp-quickstart:install)"'
RUN ln -s ~/quicklisp quicklisp
RUN git clone https://github.com/rpav/cl-autowrap.git quicklisp/cl-autowrap
RUN git clone https://github.com/lispgames/cl-sdl2.git quicklisp/cl-sdl2
RUN git clone https://github.com/lispgames/cl-sdl2-mixer quicklisp/cl-sdl2-mixer
RUN git clone https://github.com/lispgames/cl-sdl2-image quicklisp/cl-sdl2-image
RUN git clone https://github.com/Failproofshark/cl-sdl2-ttf.git quicklisp/cl-sdl-ttf
RUN bash -c 'sbcl --load quicklisp/setup.lisp <<< "(ql:quickload \"sdl2\")"'
RUN bash -c 'sbcl --load quicklisp/setup.lisp <<< "(ql:quickload \"sdl2-mixer\")"'
RUN bash -c 'sbcl --load quicklisp/setup.lisp <<< "(ql:quickload \"sdl2-ttf\")"'
RUN bash -c 'sbcl --load quicklisp/setup.lisp <<< "(ql:quickload \"iterate\")"'
COPY fonts/ fonts/
COPY graphics/ graphics/
COPY sound/ sound/
COPY cl/tetris.lisp .
