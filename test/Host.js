import { existsSync, readFileSync } from "node:fs";
export const configuration = () => ({
  baseUrl: process.env.FLUENTCI_TEST_SERVER ?? "",
  token: process.env.FLUENTCI_RUN_TOKEN ?? "",
  cwd: process.env.FLUENTCI_TEST_CWD ?? "",
  binary: process.env.FLUENTCI_TEST_ENGINE ?? "",
  packageManager: process.env.FLUENTCI_TEST_PACKAGE_MANAGER ?? "",
  packageExecutable: process.env.FLUENTCI_TEST_PACKAGE_EXECUTABLE ?? "",
});
export const inspectPlan = text => {
  const plan = JSON.parse(text);
  return !Object.hasOwn(plan, "workspace") && plan.version === 1 && plan.inherit_env === false && plan.jobs === 2 &&
    plan.tasks[0].args[0] === "literal; $VALUE" && plan.tasks[0].args[1] === "two words" &&
    Object.hasOwn(plan.tasks[0].env, "__proto__") && plan.tasks[0].env.__proto__ === "preserved" &&
    JSON.stringify(plan.tasks[3].needs) === '["left","right"]';
};

const childFile = () => `${process.env.FLUENTCI_TEST_CWD}/local-child.pid`;
export const localChildStarted = () => existsSync(childFile());
export const localChildAlive = () => {
  try { process.kill(Number(readFileSync(childFile(), "utf8").trim()), 0); return true; }
  catch (error) { if (error.code === "ESRCH") return false; throw error; }
};

export const inspectPackages = text => {
  const task = JSON.parse(text).tasks[0];
  return task.package_install.provider.manager === "macports" && task.package_install.provider.backend === "rust" && task.package_install.provider.executable === "/tools/port" && task.package_install.packages[0] === "jq";
};

export const inspectWorkspace = runDirectory => () =>
  readFileSync(`${runDirectory}/workspace/workspace-artifact`, "utf8") === "isolated" &&
  !existsSync(`${process.env.FLUENTCI_TEST_CWD}/workspace-artifact`);
