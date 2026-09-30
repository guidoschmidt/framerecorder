export enum ImageDataFormat {
  RAW = 0,
  DATA_URL = 1,
};

export type ImageData = {
    width: number,
    height: number,
    ext: string,
    img_format: ImageDataFormat,
    data: string,
}
