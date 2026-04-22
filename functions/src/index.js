const {initializeDatabase, seedDatabaseDefaults} = require('./config/db');
const {port} = require('./config/env');
const app = require('./app');

async function bootstrap() {
  initializeDatabase();
  app.listen(port, () => {
    console.log(`RK Fuels API listening on port ${port}`);
  });
  seedDatabaseDefaults()
    .then(() => {
      console.log('Firestore defaults are ready.');
    })
    .catch((error) => {
      console.error('Firestore default seed failed:', error);
    });
}

bootstrap().catch((error) => {
  console.error('Failed to start API:', error);
  process.exit(1);
});
