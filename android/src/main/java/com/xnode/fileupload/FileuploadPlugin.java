package com.xnode.fileupload;

import android.util.Log;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;

public class FileuploadPlugin {

    public String echo(String value) {
        Log.i("Echo", value);
        return value;
    }

    // Read file into a byte array
    public byte[] readFileToByteArray(File file) throws IOException {
        FileInputStream fis = new FileInputStream(file);
        byte[] data = new byte[(int) file.length()];
        int bytesRead = fis.read(data);
        fis.close();

        Log.i("FileUpload", "File read successfully, bytes: " + bytesRead);
        return data;
    }

    // Function to clean up memory
    public void cleanupMemory() {
        System.gc(); // Request garbage collection
        Log.i("FileUpload", "Memory cleanup triggered");
    }
}
