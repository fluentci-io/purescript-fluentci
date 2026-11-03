import assert from "node:assert/strict";
import { test } from "node:test";
import * as P from "../src/FluentCI/Plugin.js";
import { invoke, signatureJson } from "../src/FluentCI/Plugin/Internal/Imports.js";
import { readFileSync } from "node:fs";

const signatures = JSON.parse(signatureJson);
const makeError = kind => operation => message => ({ kind, operation, message });
const left = error => ({ error });
const right = value => ({ value });
const run = plan => P.runImpl(invoke)(makeError)(left)(right)(false)(plan)();
const perform = (name, args) => P.effectImpl(invoke)(makeError)(left)(right)(name)(args)();
function guest(overrides = {}) {
  const calls = [];
  const memory = new Map();
  let next = 1n;
  const allocate = value => { const id = next++; memory.set(id, value); return id; };
  globalThis.Memory = {
    fromString: value => ({ offset: allocate(value) }),
    find: id => ({ readString: () => { assert(memory.has(id)); return memory.get(id); } }),
  };
  const functions = Object.fromEntries(Object.entries(signatures).map(([name, signature]) => [name, (...args) => {
    assert.equal(args.length, signature.input ? 1 : 0, `${name}: input arity`);
    if (signature.input) assert.equal(typeof args[0], "bigint", "pass memory offsets, not memory objects");
    const input = signature.input ? memory.get(args[0]) : undefined;
    if (signature.json) JSON.parse(input);
    calls.push({ name, input });
    if (name in overrides) {
      const response = overrides[name](input);
      return signature.output ? allocate(response) : undefined;
    }
    if (!signature.output) return undefined;
    const response = name === "stdout" ? "héllo 世界\n"
      : ["set_secret", "add_secretmanager"].includes(name) ? `${name}-id`
      : name === "get_secret" ? JSON.stringify([{ id: "remote-secret", name: "PASSWORD", mount: "db" }])
      : name === "has_env" ? "true"
      : name === "sha256" ? "hash"
      : name === "call" ? "nested result"
      : JSON.stringify({ id: `${name}-id` });
    return allocate(response);
  }]));
  globalThis.Host = { getFunctions: () => functions, inputString: () => "input 世界", outputString: value => calls.push({ name: "output", input: value }) };
  return { calls, functions };
}

test("all generated signatures match the canonical schema, including void results", () => {
  const schema = JSON.parse(readFileSync(new URL("../schema/host.json", import.meta.url)));
  assert.equal(Object.keys(signatures).length, 52);
  for (const [name, fn] of Object.entries(schema.imports))
    assert.deepEqual(signatures[name], { input: "input" in fn, output: "output" in fn, json: fn.input?.contentType === "application/json" });
});

test("builders are immutable and execution is delayed to the terminal Effect thunk", () => {
  const { calls } = guest();
  const original = P.pipeline("build");
  const args = ["printf", "%s", "space 'quotes'; $(touch injected) 世界"];
  const configured = P.exec(args)(original);
  args.push("mutated");
  assert.equal(original.steps.length, 0);
  assert(Object.isFrozen(configured.steps[0].args));
  const effect = P.runImpl(invoke)(makeError)(left)(right)(false)(configured);
  assert.equal(calls.length, 0);
  assert.deepEqual(effect(), { value: "héllo 世界\n" });
  const words = JSON.parse(calls.find(call => call.name === "with_exec").input);
  assert.equal(words.length, 3);
  assert.equal(words[2], "'space '\\''quotes'\\''; $(touch injected) 世界'");
});

test("the complete service tree validates before any host call", () => {
  const { calls } = guest();
  const broken = P.asService("db")(P.exec(["sleep", "bad\0argument"])(P.pipeline("db")));
  const plan = P.withService(broken)(P.pipeline("client"));
  assert.equal(run(plan).error.kind, "invalid-input");
  assert.deepEqual(calls, []);
  assert.equal(run(P.exec([])(P.pipeline("invalid"))).error.kind, "invalid-input");
  assert.equal(run(P.waitOn(0)(1)(P.pipeline("invalid"))).error.kind, "invalid-input");
});

test("cache handles resolve before services and pipeline steps, without resetting built graphs", () => {
  const { calls } = guest();
  const db = P.asService("db")(P.exec(["database"])(P.pipeline("db")));
  let plan = P.withService(db)(P.withService(db)(P.pipeline("client")));
  plan = P.withCache("target")(P.cache("cargo"))(plan);
  plan = P.exec(["build"])(plan);
  run(plan);
  const index = name => calls.findIndex(call => call.name === name);
  assert(index("cache") < index("as_service"));
  assert(index("cache") < index("pipeline"));
  assert(index("as_service") < index("with_service"));
  assert.equal(calls.filter(call => call.name === "as_service").length, 1);
  assert.equal(calls.filter(call => call.name === "with_service").length, 1);
  assert.deepEqual(JSON.parse(calls.find(call => call.name === "with_cache").input), { id: "cache-id", key: "cargo", path: "target" });
});

test("Nix settings, wait probes and environment pairs preserve their canonical payloads", () => {
  const { calls } = guest();
  let plan = P.providerImpl("nix")(true)(P.pipeline("build"));
  plan = P.withEnv("__proto__")("literal")(plan);
  plan = P.waitOn(8080)(10)(plan);
  run(plan);
  assert.deepEqual(JSON.parse(calls.find(call => call.name === "nix").input), { impure: true });
  assert.deepEqual(JSON.parse(calls.find(call => call.name === "set_envs").input), [["__proto__", "literal"]]);
  assert.deepEqual(JSON.parse(calls.find(call => call.name === "wait_on").input), [8080, 10]);
});

test("local and remote secrets lower by opaque IDs, never as command arguments", () => {
  const { calls } = guest();
  const source = P.secret("TOKEN")("sensitive value");
  run(P.withSecret("TOKEN")(source)(P.exec(["check"])(P.pipeline("build"))));
  assert.deepEqual(JSON.parse(calls.find(call => call.name === "set_secret").input), ["TOKEN", "sensitive value"]);
  assert.deepEqual(JSON.parse(calls.find(call => call.name === "with_secret_variable").input), ["TOKEN", "set_secret-id"]);
  assert(!calls.find(call => call.name === "with_exec").input.includes("sensitive value"));
  const manager = perform("secretmanager", ["aws", "eu-west-1"]);
  assert.deepEqual(manager, { value: "add_secretmanager-id" });
  assert.deepEqual(JSON.parse(calls.find(call => call.name === "add_secretmanager").input), { Aws: { aws_region: "eu-west-1" } });
  const fetched = P.getSecretsImpl(invoke)(makeError)(left)(right)(manager.value)("db")();
  assert.equal(fetched.value[0].id, "remote-secret");
  calls.length = 0;
  run(P.withSecret("PASSWORD")(fetched.value[0])(P.pipeline("client")));
  assert(!calls.some(call => call.name === "set_secret"));
  assert.deepEqual(JSON.parse(calls.find(call => call.name === "with_secret_variable").input), ["PASSWORD", "remote-secret"]);
});

test("file hashing and nested modules pass paths and literal input through exposed PDK calls", () => {
  const { calls } = guest();
  assert.deepEqual(perform("sha256", ["path with spaces"]), { value: "hash" });
  assert.equal(calls.find(call => call.name === "sha256").input, "path with spaces");
  assert.deepEqual(perform("call", ["plugin.wasm", "greet", "héllo 'quotes'"]), { value: "nested result" });
  assert.deepEqual(JSON.parse(calls.find(call => call.name === "call").input), { url: "plugin.wasm", function: "greet", args: "héllo 'quotes'" });
  calls.length = 0;
  run(P.copyFile("destination path")(P.file("source path"))(P.pipeline("copy")));
  assert.deepEqual(JSON.parse(calls.find(call => call.name === "with_exec").input), ["'/bin/cp'", "'--'", "'source path'", "'destination path'"]);
});

test("missing imports, malformed engine responses and execution failures are distinct errors", () => {
  let state = guest();
  delete state.functions.with_exec;
  assert.equal(run(P.exec(["echo"])(P.pipeline("build"))).error.kind, "missing-host");
  guest({ pipeline: () => "not JSON" });
  assert.equal(run(P.pipeline("build")).error.kind, "invalid-response");
  guest({ stdout: () => { throw Error("command failed (exit status 7)"); } });
  const error = run(P.pipeline("build")).error;
  assert.deepEqual(error, { kind: "host-failure", operation: "stdout", message: "command failed (exit status 7)" });
  guest({ has_env: () => '"true"' });
  assert.equal(perform("has_env", ["NAME"]).error.kind, "invalid-response");
  delete globalThis.Host;
  assert.equal(run(P.pipeline("build")).error.kind, "missing-host");
});

test("guest input and output stay explicit effects", () => {
  const { calls } = guest();
  assert.deepEqual(perform("input", []), { value: "input 世界" });
  assert.deepEqual(perform("output", ["héllo 世界"]), { value: "" });
  assert.deepEqual(calls, [{ name: "output", input: "héllo 世界" }]);
});
