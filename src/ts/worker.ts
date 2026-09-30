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
