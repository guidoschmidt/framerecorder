[![CI](https://github.com/guidoschmidt/framerecorder/actions/workflows/build.yaml/badge.svg)](https://github.com/guidoschmidt/zipper/actions/workflows/build.yaml)

# framerecorder
> zig REST api server to store image data requests, 
> e.g. for saving web canvas data

### Rationale
Working with [Web canvas
API](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API) it's often
tedious to export animations as movies right from the browser. Usually one ends
up using a screen recording software (OBS, Quicktime, ...) or the browsers
download feature (resulting in thousand of download prompts opening up).

This is a quick and dirty image request handler for storing images & image
sequences right from canvas API animations.

### Build & Run

```bash
git clone git@github.com:guidoschmidt/framerecorder.git
cd framerecorder
git submodule update --recursive --init
zig build
zig build run
```

### Sending image data from the browser

Add the following Javascript/Typescript code and call it from your animation loop:

```typescript
function saveCanvasToBackend(selector: string, sequence: string, frame: number) {
  const canvas: HTMLCanvasElement | null = document.querySelector(
    selector || "canvas"
  );
  if (canvas === null) {
    throw new Error(`No canvas element with ${selector} found`);
  }
  const dataUrl = canvas!
    .toDataURL("image/png")
    ?.replace("image/png", "image/octet-stream");
  const data = {
    imageData: dataUrl,
    foldername: `${sequence}`,
    filename: `${frame}`,
    ext: "png",
  };
  fetch("http://localhost:3000", {
    method: "POST",
    body: JSON.stringify(data),
  });
}
```

Implement any user interaction (button press, key press, etc) to set
`isRecording` to `true` and call `saveCanvasToBackend` in the animation loop function:

```Typescript
let frame = 0;
let isRecording = false;

function draw() {
  if (isRecording) {
    saveCanvasToBackend("canvas", "Sequence-1", frame);
    frame++;
  }
}
```

### TODO
- Error handling
- p5.js example
- three.js example

### References
- [ofxFFmpegRecorder](https://github.com/NickHardeman/ofxFFmpegRecorder/blob/master/src/ofxFFmpegRecorder.cpp)
