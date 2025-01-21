import { FileuploadPlugin } from 'fileupload-plugin';

window.testEcho = () => {
    const inputValue = document.getElementById("echoInput").value;
    FileuploadPlugin.echo({ value: inputValue })
}
