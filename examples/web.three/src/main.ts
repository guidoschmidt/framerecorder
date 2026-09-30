import {
  BoxGeometry,
  Camera,
  Mesh,
  MeshNormalMaterial,
  OrthographicCamera,
  PerspectiveCamera,
  Scene,
  WebGLRenderer,
} from "three";
import { saveCanvasToBackendWithWorker } from "../../../src/ts/framerecorder";
const workerUrl = new URL("./worker", import.meta.url);
import "./style.css";

class MinimalRenderer {
  private readonly canvas: HTMLCanvasElement;
  private scene: Scene = new Scene();
  private camera: Camera = new PerspectiveCamera();
  private renderer: WebGLRenderer;
  private cube: Mesh | undefined = undefined;

  private sequenceName = "three";
  private isRecording: boolean = false;
  private frame: number = 0;

  constructor() {
    this.canvas = document.createElement("canvas");
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
    document.body.appendChild(this.canvas);

    this.renderer = this.setupRenderer();
    this.camera = this.setupCamera();
    this.scene = this.setupScene();

    this.setupListeners();

    this.renderer.setAnimationLoop(this.render.bind(this));
  }

  private setupListeners() {
    window.addEventListener("resize", () => this.resize());
    window.addEventListener("keyup", ({key}) => {
      switch(key) {
        case " ":
          this.isRecording = !this.isRecording;
          break;
        default:
          break;
      }
    });
  }

  private setupRenderer() {
    const renderer = new WebGLRenderer({
      antialias: true,
      canvas: this.canvas,
    });
    return renderer;
  }

  private setupScene() {
    const scene = new Scene();
    this.cube = new Mesh(new BoxGeometry(1, 1, 1), new MeshNormalMaterial());
    scene.add(this.cube);
    return scene;
  }

  private setupCamera() {
    const fov = 90;
    const aspect = this.canvas.width / this.canvas.height;
    const near = 0.1;
    const far = 100;
    const camera = new PerspectiveCamera(fov, aspect, near, far);
    camera.position.set(1, 1, 1);
    camera.lookAt(0, 0, 0);
    return camera;
  }

  render() {
    this.cube!.rotation.y += 0.01;
    this.renderer.render(this.scene, this.camera);

    if (this.isRecording) {
      saveCanvasToBackendWithWorker(
        "http://127.0.0.1:8000/api/imageseq",
        "canvas",
        this.sequenceName,
        this.frame,
        workerUrl);
        this.frame++;
    }
  }

  resize() {
    const { innerWidth: width, innerHeight: height } = window;
    const aspect = width / height;
    if (this.camera instanceof PerspectiveCamera) {
      this.camera.aspect = aspect;
      this.camera.updateProjectionMatrix();
    }
    if (this.camera instanceof OrthographicCamera) {
      this.camera.left = -1;
      this.camera.right = -1;
      this.camera.top = -aspect;
      this.camera.bottom = -aspect;
      this.camera.updateProjectionMatrix();
    }
    this.renderer.setSize(width, height);
    this.renderer.setPixelRatio(window.devicePixelRatio);
  }
}

new MinimalRenderer();
