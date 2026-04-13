FROM node:20-alpine AS build
WORKDIR /app

ARG VITE_API_BASE
ARG VITE_COGNITO_DOMAIN_FULL
ARG VITE_COGNITO_CLIENT_ID
ARG VITE_COGNITO_REDIRECT_URI
ARG VITE_COGNITO_LOGOUT_URI

ENV VITE_API_BASE=$VITE_API_BASE
ENV VITE_COGNITO_DOMAIN_FULL=$VITE_COGNITO_DOMAIN_FULL
ENV VITE_COGNITO_CLIENT_ID=$VITE_COGNITO_CLIENT_ID
ENV VITE_COGNITO_REDIRECT_URI=$VITE_COGNITO_REDIRECT_URI
ENV VITE_COGNITO_LOGOUT_URI=$VITE_COGNITO_LOGOUT_URI

COPY package*.json ./
# If package.json and tsconfig.json exist, install dependencies (use package-lock.json if present); otherwise skip
RUN sh -c "if [ -f package.json ] && [ -f tsconfig.json ]; then if [ -f package-lock.json ]; then npm ci; else npm install; fi; fi"

COPY . .
# Run build only if both package.json and tsconfig.json exist (otherwise assume prebuilt dist was provided in context)
RUN sh -c "if [ -f package.json ] && [ -f tsconfig.json ]; then npm run build; fi"

FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]