let count = 0;
export const installGuest = () => {
  count = 0;
  let next = 1n;
  const memory = new Map();
  const store = value => { const offset = next++; memory.set(offset, value); return offset; };
  globalThis.Memory = {
    fromString: value => ({ offset: store(value) }),
    find: offset => ({ readString: () => memory.get(offset) }),
  };
  globalThis.Host = {
    getFunctions: () => new Proxy({}, { get: (_, name) => () => {
      count++;
      return store(name === "stdout" ? "guest output" : name === "get_secret" ? "[]" :
        ["set_secret", "add_secretmanager"].includes(name) ? "secret-id" : JSON.stringify({ id: name + "-id" }));
    } }),
  };
};
export const removeGuest = () => { delete globalThis.Host; delete globalThis.Memory; };
export const callCount = () => count;
