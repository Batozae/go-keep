/**
 * Middleware penanganan error global.
 * Menjamin semua error yang tidak tertangani dikembalikan dalam format konsisten:
 * { "message": "..." }
 */
const errorHandler = (err, req, res, next) => {
  console.error('[Unhandled Error]:', err);

  // Tangani syntax error JSON dari body-parser
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    return res.status(400).json({
      message: 'Format JSON body tidak valid.'
    });
  }

  const statusCode = err.statusCode || err.status || 500;
  const message = err.message || 'Terjadi kesalahan pada server.';

  res.status(statusCode).json({
    message: message
  });
};

module.exports = errorHandler;

