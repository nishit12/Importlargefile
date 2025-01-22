package com.xnode.fileupload;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
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
            // Remove "file://" prefix if exists
            String sanitizedPath = filePath.replace("file://", "");
            File file = new File(sanitizedPath);

            if (!file.exists()) {
                call.reject("File does not exist at path: " + sanitizedPath);
                return;
            }

            // Process file to get base64 and byte array
            byte[] fileData = implementation.readFileToByteArray(file);
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
            implementation.cleanupMemory(); // Free memory after processing

        } catch (Exception e) {
            call.reject("Error processing file: " + e.getMessage());
        }
    }
}
