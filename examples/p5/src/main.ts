import p5 from "p5";
import { saveCanvasToBackendWithWorker } from "../../../src/ts/framerecorder";
const workerUrl = new URL("./worker", import.meta.url);
import "./style.css"

new p5((p: p5) => {
  let count = 1;
  let it = 0;
  let frame = 0;
  let sequence = new Date().toISOString();
  let isRecording = false;

  p.keyPressed = ({key}: {key: string}) => {
    switch(key) {
      case " ":
        isRecording = !isRecording;
        sequence = new Date().toISOString();
        frame = isRecording ? 0 : frame;
        break;
    }
  }

  p.setup = () => {
    p.createCanvas(600, 600);
  };

  p.draw = () => {
    if (isRecording) {
        saveCanvasToBackendWithWorker(
          "http://127.0.0.1:8000/api/imageseq",
          "canvas",
          sequence,
          frame,
          workerUrl);
        frame++;
    }

    if (p.frameCount % 30 === 0) {
      p.background(0);
      p.noStroke();

      p.fill(255, 0, 0);
      p.textSize(30);
      p.text(frame, 30, 60);

      p.fill(255);
      for(let j = 0; j < count; j++) {
        if ((j + it) % 2 === 0) {
          p.push();
          if (it % 2 === 0) {
            p.translate(0, j * p.height / count);
            p.rect(0, 0, p.width, p.height / count);
          } else {
            p.translate(j * p.width / count, 0);
            p.rect(0, 0, p.width / count, p.height);
          }
          p.pop();
        }
      }
      count *= 2;
      count = count > 256 ? 1 : count;
      it = (it + 1) % 2;
    }
  };
});
