FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts
# copy only what the app needs instead of the whole folder
COPY server.js ./
COPY data ./data
USER node
EXPOSE 5000
CMD ["node", "server.js"]