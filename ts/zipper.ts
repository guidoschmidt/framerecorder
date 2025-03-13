export async function saveCanvasToBackend(
  zipperUrl: string,
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
  const data = {
    frame,
    width: canvas.width,
    height: canvas.height,
    data: dataUrl,
    foldername: `${sequence}`,
    filename: `${frame}`,
    ext: "png",
  };
  await fetch(zipperUrl, {
    method: "PUT",
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
    foldername: `${sequence}`,
    filename: `${frame}`,
    ext: "png",
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
