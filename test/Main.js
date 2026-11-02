let recorded = [];
const pipeline = (stage) => {
  const next = (call) => {
    recorded.push(call);
    return pipeline(stage + 1);
  };
  return {
    withWorkdir: (path) => next(`workdir:${path}`),
    withEnvVariable: (name, value) => next(`env:${name}=${value}`),
    withExec: (args) => next(`exec:${args.join(",")}`),
    waitOn: (port, timeout) => next(`wait:${port}:${timeout}`),
    withCache: (cache) => next(`cache:${cache.name}`),
    withSecretVariable: (name, secret) => next(`secret:${name}=${secret.name}`),
    withService: (service) => next(`service:${service.name}`),
    nix: (args) => next(`nix:${args.impure}`),
    asService: (name) => next(`asService:${name}`),
    stdout: () => Promise.resolve(`stage ${stage}`),
  };
};
export const fixture = () => {
  recorded = [];
  return pipeline(0);
};
export const calls = () => [...recorded];
export const cache = { name: "cache" };
export const secret = { name: "secret" };
export const service = { name: "service" };
export const git = {
  branch(name) {
    recorded.push(`branch:${name}`);
    return { tree() { recorded.push(`tree:${name}`); return {}; } };
  },
};
