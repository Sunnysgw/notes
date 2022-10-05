FROM node:10
WORKDIR /opt/sgw
COPY package*.json ./
RUN npm install
COPY . .
CMD ["npm", "start"]