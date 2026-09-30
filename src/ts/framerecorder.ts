import type { ImageData } from "./ImageData";
import { ImageDataFormat } from "./ImageData";

export async function saveCanvas(
  host: string,
  port: number,
  sequence: string,
  frame: number,
  canvas: HTMLCanvasElement,
  workerUrl?: URL) {
  const url = `${host}:${port}/api/imageseq/${sequence}/${frame}`;
  if (workerUrl) {
    return saveCanvasToBackendWithWorker(url, canvas, workerUrl);
  }
  else return saveCanvasToBackend(url, canvas);
}

function saveCanvasToBackend(
  url: string,
  canvas: HTMLCanvasElement,
) {
  if (canvas === null) {
    throw new Error(`Canvas element is null`);
  }
  const dataUrl = canvas!.toDataURL("image/png");

  // @TODO
  // Use `getImageData` via context
  // const ctx = canvas.getContext("2d");
  // ctx.getImageData();

  const data: ImageData = {
    width: canvas.width,
    height: canvas.height,
    img_format: ImageDataFormat.DATA_URL,
    data: dataUrl,
    ext: "png",
  };
  return fetch(url, {
    method: "PUT",
    body: JSON.stringify(data),
  });
}

function saveCanvasToBackendWithWorker(
  url: string,
  canvas: HTMLCanvasElement,
  workerUrl: URL,
) {
  if (canvas === null) {
    throw new Error(`No canvas element is null`);
  }
  const dataUrl = canvas!.toDataURL("image/png");
  const data: ImageData = {
    width: canvas.width,
    height: canvas.height,
    data: dataUrl,
    format: ImageDataFormat.DATA_URL,
  };
  const worker = new Worker(workerUrl, {
    type: "module",
  });
  worker.postMessage([url, data]);
  worker.onmessage = () => {
    worker.terminate();
    // Free up memory
    URL.revokeObjectURL(url);
  };
}

/**
 * Helper function to import and use in a worker implementation, e.g.
 * ```ts
 * import { passToWorker } from "framerecorder"
 * 
 * ```
 */
export async function passToWorker(
  e: { data: [URL, string] },
  postMessage: Function,
) {
  const [url, data] = e.data;
  await fetch(url, {
    method: "PUT",
    body: JSON.stringify(data),
  });
  postMessage(true);
}
