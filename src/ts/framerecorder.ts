import type { ImageData } from "./ImageData";
import { ImageDataFormat } from "./ImageData";

export async function saveCanvasToBackend(
  url: string,
  selector: string,
  sequence: string,
  frame: number,
) {
  const canvas: HTMLCanvasElement | null = document.querySelector(
    selector || "canvas",
  );
  if (canvas === null) {
    throw new Error(`No canvas element with ${selector} found`);
  }
  const dataUrl = canvas!.toDataURL("image/png");
  const data: ImageData = {
    frame,
    width: canvas.width,
    height: canvas.height,
    data_format: ImageDataFormat.DATA_URL,
    data: dataUrl,
    foldername: `${sequence}`,
    filename: "test",
    ext: "png",
  };
  await fetch(url, {
    method: "POST",
    body: JSON.stringify(data),
  });
}

export function saveCanvasToBackendWithWorker(
  url: string,
  selector: string,
  sequence: string,
  frame: number,
  workerUrl: URL,
) {
  const canvas: HTMLCanvasElement | null = document.querySelector(
    selector || "canvas",
  );
  if (canvas === null) {
    throw new Error(`No canvas element with ${selector} found`);
  }
  const dataUrl = canvas!.toDataURL("image/png");
  const data = {
    frame,
    width: canvas.width,
    height: canvas.height,
    data: dataUrl,
    data_format: ImageDataFormat.DATA_URL,
    foldername: `${sequence}`,
    filename: "test",
    ext: "png",
    format: 1,
  };
  runInWebWorker(url, data, workerUrl);
}

function runInWebWorker(url: string, data: any, workerUrl: URL) {
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
