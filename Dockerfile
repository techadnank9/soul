# The API and the job runner, in one image.
#
# Deliberately host neutral. It runs on Fly, Railway, Render, App Runner, Cloud
# Run or a plain VM, because the thing that has to stop being true is that this
# service only exists on somebody's laptop.
#
# The image runs the HTTP server. The job queue is drained either by running
# the same image with `npm run worker -w @soul/api`, or by pointing a scheduler
# at POST /jobs/drain. See README, Running it somewhere real.

FROM node:22-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
COPY db/package.json db/package.json
COPY api/package.json api/package.json
RUN npm ci --omit=dev

FROM node:22-slim
WORKDIR /app
ENV NODE_ENV=production

# tsx runs the TypeScript directly, which is how the service runs in
# development too. One runtime, so a thing that works locally works here.
COPY --from=deps /app/node_modules node_modules
COPY package.json package-lock.json ./
COPY db db
COPY api api

# Not root. A container that never needs to write to its own filesystem should
# not be able to.
USER node

EXPOSE 8080
ENV PORT=8080

# No shell form, so signals reach the process and the platform can stop it
# cleanly rather than waiting to kill it.
CMD ["npm", "start", "-w", "@soul/api"]
