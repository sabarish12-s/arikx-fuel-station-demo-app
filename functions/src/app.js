const express = require('express');
const cors = require('cors');
const morgan = require('morgan');

const authRoutes = require('./routes/auth');
const adminRoutes = require('./routes/admin');
const creditsRoutes = require('./routes/credits');
const inventoryRoutes = require('./routes/inventory');
const managementRoutes = require('./routes/management');
const salesRoutes = require('./routes/sales');
const usersRoutes = require('./routes/users');

const app = express();

app.use(cors());
app.use(express.json({limit: '1mb'}));
app.use(morgan('dev'));

app.get('/health', (_req, res) => {
  res.status(200).json({status: 'ok'});
});

app.use('/auth', authRoutes);
app.use('/admin', adminRoutes);
app.use('/credits', creditsRoutes);
app.use('/inventory', inventoryRoutes);
app.use('/management', managementRoutes);
app.use('/sales', salesRoutes);
app.use('/users', usersRoutes);

app.use((err, req, res, _next) => {
  const message = err instanceof Error ? err.message : 'Internal server error';
  console.error('Unhandled API error:', {
    method: req.method,
    path: req.originalUrl || req.url,
    message,
    stack: err instanceof Error ? err.stack : String(err),
  });
  res.status(500).json({message});
});

module.exports = app;
