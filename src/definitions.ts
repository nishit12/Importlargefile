export interface FileuploadPluginPlugin {
  processFile(options: { filePath: string; type: string; name: string }): Promise<{ base64: string, size: number, type: string, fileName: string, byteArray: Uint8Array }>;
}
