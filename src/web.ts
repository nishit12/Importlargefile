import { Capacitor, WebPlugin } from '@capacitor/core';

import type { FileuploadPluginPlugin } from './definitions';

export class FileuploadPluginWeb extends WebPlugin implements FileuploadPluginPlugin {
  async getContacts(filter: string): Promise<{ results: any[] }> {
    console.log('filter: ', filter);
    return {
      results: [{
        firstName: 'Dummy',
        lastName: 'Entry',
        telephone: '123456'
      }]
    };
  }

  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }

  async processFile(options: { filePath: string; type: string; name: string }): Promise<{ base64: string; size: number; type: string; fileName: string; byteArray: Uint8Array }> {
    console.log('Processing file at path:', options.filePath);
    try {
      const result = await Capacitor.Plugins.FileuploadPluginPlugin.processFile(options);
      console.log('Base64 result:', result);
      
      return {
        base64: result.base64,
        size: result.base64.length * (3 / 4), // Estimate file size
        type: options.type,
        fileName: options.name,
        byteArray: this.base64ToUint8Array(result.base64)
      };
    } catch (error) {
      console.error('Error in processFile:', error);
      throw error;
    }
  }

  private base64ToUint8Array(base64: string): Uint8Array {
    const binaryString = atob(base64);
    const length = binaryString.length;
    const byteArray = new Uint8Array(length);
    for (let i = 0; i < length; i++) {
      byteArray[i] = binaryString.charCodeAt(i);
    }
    return byteArray;
  }



}

