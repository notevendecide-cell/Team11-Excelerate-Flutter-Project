const { HttpError } = require('../utils/httpErrors');

function errorHandler(err, req, res, next) {
  const status = err instanceof HttpError ? err.status : 500;
  const message = status === 500 ? 'Internal Server Error' : err.message;

  if (process.env.NODE_ENV !== 'production') {
    try {
      // eslint-disable-next-line no-console
      console.error(err?.stack || err);
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error('Failed to log error:', e);
    }
  }

  res.status(status).json({
    error: {
      message,
      details: err instanceof HttpError ? err.details : undefined,
    },
  });
}

module.exports = { errorHandler };
