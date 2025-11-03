export enum ImageDataFormat {
  RAW,
  DATA_URL,
};

export type ImageData = {
    frame: number,
    width: number,
    height: number,
    foldername: string,
    filename: string,
    ext: "png",
    data_format: ImageDataFormat,
    data: string,
}
