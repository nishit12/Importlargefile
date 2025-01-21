import { registerPlugin } from '@capacitor/core';

import type { FileuploadPluginPlugin } from './definitions';

const FileuploadPlugin = registerPlugin<FileuploadPluginPlugin>('FileuploadPlugin', {
  web: () => import('./web').then((m) => new m.FileuploadPluginWeb()),
});

export * from './definitions';
export { FileuploadPlugin };
