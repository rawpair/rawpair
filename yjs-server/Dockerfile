FROM node:22-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY server.mjs ./
RUN mkdir -p /var/lib/rawpair-collaboration && chown node:node /var/lib/rawpair-collaboration
USER node
ENV RAWPAIR_COLLABORATION_BIND=0.0.0.0
EXPOSE 1234
CMD ["node", "server.mjs"]
