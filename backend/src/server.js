import { loadConfig } from './config/env.js';
import { createLogger } from './lib/logger.js';
import { createFirebaseDeps } from './lib/firebase.js';
import { createApp } from './app.js';

const config = loadConfig();
const logger = createLogger(config.logLevel);
const app = createApp({ ...createFirebaseDeps(config), config, logger });

const server = app.listen(config.port, () => logger.info({ port: config.port, env: config.nodeEnv }, 'api listening'));
server.requestTimeout = config.requestTimeoutMs + 5000;
server.headersTimeout = 20_000;

const shutdown = (sig) => {
  logger.info({ sig }, 'shutting down');
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10_000).unref();
};
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('unhandledRejection', (err) => logger.error({ err: { message: err?.message } }, 'unhandledRejection'));
