import { passToWorker } from "../../ts/worker";

onmessage = async function (e) {
  await passToWorker(e, this.postMessage);
};
