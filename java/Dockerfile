FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt -y --no-install-recommends install openjdk-17-jre:amd64 openjdk-17-jdk:amd64 
RUN apt install -y --no-install-recommends pulseaudio 
COPY fonts/ fonts/
COPY graphics/ graphics/
COPY sound/ sound/
COPY java/Tetris.java .
RUN javac -encoding ISO-8859-1 Tetris.java
