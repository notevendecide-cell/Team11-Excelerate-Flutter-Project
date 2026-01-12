// Vercel runs Node files as Serverless Functions.
// In that environment we must EXPORT the Express app (no app.listen / intervals).
// For local/dev (or traditional hosts), we start the HTTP server normally.

if (process.env.VERCEL) {
	const { createApp } = require('./src/app');
	module.exports = createApp();
} else {
	const { start } = require('./src/server');
	start();
}
 