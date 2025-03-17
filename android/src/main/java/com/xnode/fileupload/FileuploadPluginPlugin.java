package com.xnode.fileupload;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.ByteArrayOutputStream;

import android.net.Uri;
import android.util.Base64;
import android.util.Log;

@CapacitorPlugin(name = "FileuploadPlugin")
public class FileuploadPluginPlugin extends Plugin {

    private FileuploadPlugin implementation = new FileuploadPlugin();

    @PluginMethod
    public void echo(PluginCall call) {
        String value = call.getString("value");

        JSObject ret = new JSObject();
        ret.put("value", implementation.echo(value));
        call.resolve(ret);
    }

    @PluginMethod
    public void processFile(PluginCall call) {
        String filePath = call.getString("filePath");
        String fileType = call.getString("type");
        String fileName = call.getString("name");

        if (filePath == null || fileType == null || fileName == null) {
            call.reject("File path, type, and name are required");
            return;
        }

        try {
            byte[] fileData;

            if (filePath.startsWith("content://")) {
                Log.d("FileuploadPlugin", "Detected content:// URI, processing...");
                fileData = readFileFromContentUri(filePath);
            } else {
                // Remove "file://" prefix if exists
                String sanitizedPath = filePath.replace("file://", "");
                File file = new File(sanitizedPath);

                if (!file.exists()) {
                    call.reject("File does not exist at path: " + sanitizedPath);
                    return;
                }

                fileData = implementation.readFileToByteArray(file);
            }

            if (fileData == null) {
                call.reject("Failed to read file");
                return;
            }

            String base64Encoded = Base64.encodeToString(fileData, Base64.DEFAULT);
            int fileSize = fileData.length;

            JSObject result = new JSObject();
            result.put("base64", base64Encoded);
            result.put("size", fileSize);
            result.put("type", fileType);
            result.put("fileName", fileName);
            result.put("byteArray", fileData);

            call.resolve(result);
            implementation.cleanupMemory();

        } catch (Exception e) {
            call.reject("Error processing file: " + e.getMessage());
        }
    }

    private byte[] readFileFromContentUri(String contentUri) throws IOException {
        InputStream inputStream = null;
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        try {
            Uri uri = Uri.parse(contentUri);
            inputStream = getActivity().getContentResolver().openInputStream(uri);

            if (inputStream == null) {
                throw new IOException("Failed to open input stream for URI: " + contentUri);
            }

            byte[] data = new byte[1024];
            int bytesRead;
            
            while ((bytesRead = inputStream.read(data, 0, data.length)) != -1) {
                buffer.write(data, 0, bytesRead);
            }

            return buffer.toByteArray();
        } finally {
            if (inputStream != null) {
                inputStream.close();
            }
        }
    }
}
