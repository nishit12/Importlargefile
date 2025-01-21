# fileupload-plugin

A Capacitor plugin for importing and processing files from Android and iOS devices.

## Features
- Import files from Android and iOS devices.
- Convert files to base64 format.
- Retrieve file metadata such as size, type, and name.
- Asynchronous processing for better performance.

## Installation

Install the plugin using npm:

```bash
npm install fileupload-plugin
npx cap sync
```

## API

<docgen-index>

* [`processFile(...)`](#processfile)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>

### processFile(...)

```typescript
processFile(options: { filePath: string; type: string; name: string; }) => Promise<{ base64: string; size: number; type: string; fileName: string; byteArray: Uint8Array; }>
```

#### Parameters

| Param         | Type                                                           | Description                      |
| ------------- | -------------------------------------------------------------- | -------------------------------- |
| **`options`** | <code>{ filePath: string; type: string; name: string; }</code> | File processing options.         |

#### Returns

A promise resolving to:

```typescript
{
  base64: string;
  size: number;
  type: string;
  fileName: string;
  byteArray: Uint8Array;
}
```

--------------------

## Usage

Import and use the plugin in your code:

```typescript
import { Plugins } from '@capacitor/core';
const { FileuploadPlugin } = Plugins;

async function uploadFile() {
  const result = await FileuploadPlugin.processFile({
    filePath: 'path/to/file',
    type: 'image/png',
    name: 'example.png'
  });
  console.log('Base64:', result.base64);
  console.log('File Size:', result.size);
}
```

## License

MIT License

