import { passToWorker } from "../../../src/ts/worker";

onmessage = async function (e) {
  await passToWorker(e, this.postMessage);
};
