FROM node:18-alpine

WORKDIR /app

RUN npm install @y/websocket-server y-websocket

EXPOSE 1234

CMD ["npx", "y-websocket"]
