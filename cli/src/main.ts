#!/usr/bin/env node
import { run } from "./runner.js";

process.exitCode = await run(process.argv.slice(2));
