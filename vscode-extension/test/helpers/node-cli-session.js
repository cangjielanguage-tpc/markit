'use strict';

const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { createRequire } = require('node:module');
const childProcess = require('node:child_process');

// Load the unchanged production session with a fixture-only process launcher.
// Windows cannot execute a JavaScript shebang file directly. Starting it with
// this test runner's Node preserves real pipes, exit codes, ACKs and signals.
// All other commands still use real spawn, including the missing-command test.
function loadNodeCliSession(scriptName) {
  const filename = path.resolve(__dirname, '../../src/session.js');
  const productionRequire = createRequire(filename);
  const fixtureRequire = name => name === 'node:child_process'
    ? { ...childProcess, spawn: (executable, args, options) => path.basename(executable) === scriptName
      ? childProcess.spawn(process.execPath, [executable, ...args], options)
      : childProcess.spawn(executable, args, options) }
    : productionRequire(name);
  const loaded = { exports: {} };
  // compileFunction uses this realm, so cross-realm object prototypes do not
  // change the existing strict deep-equality assertions.
  vm.compileFunction(fs.readFileSync(filename, 'utf8'),
    ['require', 'module', 'exports', '__filename', '__dirname'], { filename })(
    fixtureRequire, loaded, loaded.exports, filename, path.dirname(filename));
  return loaded.exports.PreviewSession;
}

module.exports = { loadNodeCliSession };
