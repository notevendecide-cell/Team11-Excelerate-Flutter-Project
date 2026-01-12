const { HttpError } = require('../utils/httpErrors');

function errorHandler(err, req, res, next) {
  const status = err instanceof HttpError ? err.status : 500;
  const message = status === 500 ? 'Internal Server Error' : err.message;

  const requestId = req.headers['x-vercel-id'] || req.headers['x-request-id'] || undefined;

  // Log server-side for debugging. Don't leak details to clients.
  try {
    if (status === 500) {
      // eslint-disable-next-line no-console
      console.error('Unhandled error', {
        requestId,
        method: req.method,
        path: req.path,
      });
      // eslint-disable-next-line no-console
      console.error(err?.stack || err);
    } else if (process.env.NODE_ENV !== 'production') {
      // eslint-disable-next-line no-console
      console.error('Request error', { requestId, status, message });
    }
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error('Failed to log error:', e);
  }

  res.status(status).json({
    error: {
      message,
      requestId,
      details: err instanceof HttpError ? err.details : undefined,
    },
  });
}

module.exports = { errorHandler };
