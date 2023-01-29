FROM debian:bookworm
WORKDIR /usr/src/tetris
RUN apt update && apt -y --no-install-recommends install gcc make libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
RUN apt install -y --no-install-recommends pulseaudio alsa-utils wget ca-certificates gnupg
RUN wget -O- https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
RUN echo deb https://deb.nodesource.com/node_16.x bookworm main >> /etc/apt/sources.list
RUN apt install -y nodejs npm
RUN npm install typescript
RUN npm install @types/node --save-dev
RUN npm install @kmamal/sdl
RUN npm install canvas
RUN npm install node-aplay
COPY fonts/ fonts/
COPY graphics/ graphics/
COPY sound/ sound/
COPY typescript/package.json .
COPY typescript/tetris.ts .
RUN npx tsc tetris.ts
