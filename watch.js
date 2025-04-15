#!/usr/bin/env node

const chokidar = require("chokidar");
const { spawn } = require("child_process");
const path = require("path");
// const os = require("os");

let refresh = 0;
console.log("\x1B[2J\x1B[0f");

// --- Configuration ---
let args = process.argv.slice(2);

// Handle --quiet flag (can appear anywhere after mandatory args)
const quietIndex = args.findIndex((arg) => arg === "--quiet");
const quietMode = quietIndex !== -1;
if (quietMode) {
    args.splice(quietIndex, 1); // Remove --quiet from args array for easier processing
}

// Check for mandatory arguments
if (args.length < 2) {
    // Updated Usage Message
    console.error("Usage: node watcher.js <script-to-run.lua> <directory-to-watch> [host] [port] [--quiet]");
    console.error("\nExample (default host/port): node watcher.js index.lua ./src");
    console.error("Example (custom host/port): node watcher.js index.lua ./src 0.0.0.0 8080");
    process.exit(1);
}

// --- Assign Arguments ---
const scriptToRun = path.resolve(args[0]); // Mandatory: e.g., index.lua
const directoryToWatch = path.resolve(args[1]); // Mandatory: e.g., ./src

// Optional host and port with defaults
const host = args[2] || "127.0.0.1"; // Default host if args[2] is not provided
const port = args[3] || "3000"; // Default port if args[3] is not provided

// --- State Variables ---
let childProcess = null;
let restartTimeout = null;
const DEBOUNCE_DELAY = 100; // milliseconds

// --- Helper Functions ---

function log(message) {
    if (!quietMode) {
        const timestamp = new Date().toLocaleTimeString();
        console.log(`[Watcher ${timestamp}] ${message}`);
    }
}

function getCurrentTime() {
    const now = new Date();
    const hrs = String(now.getHours()).padStart(2, "0");
    const mins = String(now.getMinutes()).padStart(2, "0");
    const secs = String(now.getSeconds()).padStart(2, "0");
    return `${hrs}:${mins}:${secs}`;
}

const startAt = getCurrentTime();
function startServer() {
    const scriptDir = path.dirname(scriptToRun);
    const scriptFilename = path.basename(scriptToRun);

    console.log(`[${startAt} - ${getCurrentTime()}](x${refresh})`);

    // Log the arguments being passed
    log(`Starting \`${scriptFilename}\` with args: ${host}, ${port} in directory: ${scriptDir}`);

    childProcess = spawn("lua", [scriptToRun, host, port], {
        // Pass script, host, port
        stdio: "inherit", // Connect stdio ('pipe' if you need to process output here)
        cwd: scriptDir, // Set the working directory
    });

    childProcess.on("spawn", () => {
        log(`Process \`${scriptFilename}\` started (PID: ${childProcess.pid})`);
    });

    childProcess.on("error", (err) => {
        console.error(`[Watcher] Error starting \`${scriptFilename}\` with 'lua':`, err.message);
        if (err.code === "ENOENT") {
            console.error("[Watcher] Hint: Is 'lua' installed and available in your system's PATH?");
        }
        childProcess = null;
    });

    childProcess.on("close", (code, signal) => {
        if (childProcess && !childProcess.killed) {
            log(`Process \`${scriptFilename}\` exited with code ${code}, signal ${signal}`);
        }
        childProcess = null;
    });
}

function stopServer() {
    if (!childProcess) {
        return;
    }
    const scriptFilename = path.basename(scriptToRun); // Get filename for logging
    log(`Stopping process \`${scriptFilename}\` (PID: ${childProcess.pid})...`);
    childProcess.killed = true;
    const success = childProcess.kill("SIGTERM");
    if (!success) {
        log(`Failed to send SIGTERM to process ${childProcess.pid}. It might already be stopped.`);
    }
    childProcess = null;
}

function restartServer() {
    refresh++;
    log("Attempting to restart target script...");
    stopServer();
    console.log("\x1B[2J\x1B[0f");
    setTimeout(startServer, 50); // Small delay
}

function handleFileChange(event, filePath) {
    log(`Detected ${event}: ${path.relative(process.cwd(), filePath)}`);
    if (restartTimeout) {
        clearTimeout(restartTimeout);
    }
    restartTimeout = setTimeout(() => {
        restartServer();
        restartTimeout = null;
    }, DEBOUNCE_DELAY);
}

// --- Initialization ---

log(`Watching directory: ${directoryToWatch}`);
log(`Will run script: ${scriptToRun} using 'lua'`);
log(`Default/Passed arg1: ${host}`);
log(`Default/Passed arg2: ${port}`);
if (quietMode) log("Quiet mode enabled.");

const watcher = chokidar.watch(directoryToWatch, {
    ignored: /(^|[\/\\])\../,
    persistent: true,
    ignoreInitial: true,
});

watcher
    .on("add", (filePath) => handleFileChange("add", filePath))
    .on("change", (filePath) => handleFileChange("change", filePath))
    .on("unlink", (filePath) => handleFileChange("unlink", filePath))
    .on("error", (error) => console.error(`[Watcher] Error: ${error}`))
    .on("ready", () => {
        log("Initial scan complete. Ready for changes.");
        startServer(); // Start initially
    });

// --- Graceful Shutdown ---
function cleanup() {
    log("Watcher shutting down...");
    watcher.close();
    if (childProcess) {
        log("Stopping child process before exiting...");
        stopServer();
    }
    setTimeout(() => process.exit(0), 100);
}

process.on("SIGINT", cleanup);
process.on("SIGTERM", cleanup);
process.on("exit", () => {
    if (childProcess) {
        log("Watcher exited unexpectedly, ensuring child process is stopped.");
        stopServer();
    }
});
