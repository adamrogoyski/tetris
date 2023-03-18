FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update
RUN apt -y --no-install-recommends install gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
RUN apt install -y --no-install-recommends rustc cargo
RUN apt install -y --no-install-recommends pulseaudio ca-certificates gnupg
COPY fonts/ fonts/
COPY graphics/ graphics/
COPY sound/ sound/
COPY rust/Cargo.lock .
COPY rust/Cargo.toml .
COPY rust/src/main.rs src/main.rs
RUN cargo build
