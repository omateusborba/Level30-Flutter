// Karma — Angular 18 (@angular-devkit/build-angular:karma).
// `npm test` roda headless; `npm run test:watch` abre o Chrome com o repórter HTML.

const path = require('path');

// macOS: se o Chrome não estiver no PATH, aponta para o app padrão.
if (!process.env.CHROME_BIN) {
  const mac = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
  if (require('fs').existsSync(mac)) process.env.CHROME_BIN = mac;
}

module.exports = function (config) {
  config.set({
    basePath: '',
    frameworks: ['jasmine', '@angular-devkit/build-angular'],
    plugins: [
      require('karma-jasmine'),
      require('karma-chrome-launcher'),
      require('karma-jasmine-html-reporter'),
      require('karma-coverage'),
      require('@angular-devkit/build-angular/plugins/karma'),
    ],
    client: { clearContext: false },
    coverageReporter: {
      dir: path.join(__dirname, './coverage/dashboard'),
      subdir: '.',
      reporters: [{ type: 'html' }, { type: 'text-summary' }],
    },
    reporters: ['progress'],
    browsers: ['ChromeHeadlessCI'],
    customLaunchers: {
      ChromeHeadlessCI: {
        base: 'ChromeHeadless',
        flags: ['--no-sandbox', '--disable-gpu'],
      },
    },
    restartOnFileChange: true,
  });
};
