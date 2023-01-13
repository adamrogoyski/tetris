# Typescript targeting NodeJS Tetris

Uses the [kmamal/node-sdl](https://github.com/kmamal/node-sdl) SDL library
and [node-aplay](https://www.npmjs.com/package/node-aplay) sound library.

Install Typescript for NodeJS and required modules:

```
$ npm install typescript
$ npm install @types/node --save-dev
$ npm install @kmamal/sdl
$ npm install canvas
$ npm install node-aplay
```

Build:

```
$ npx tsc tetrists
```

Run:

```
$ node tetris.js
```
