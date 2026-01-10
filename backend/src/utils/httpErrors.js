class HttpError extends Error {
  constructor(status, message, details) {
    super(message);
    this.status = status;
    this.details = details;
  }
}

function notFound() {
  return new HttpError(404, 'Not Found');
}

module.exports = { HttpError, notFound };
