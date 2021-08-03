document.addEventListener("DOMContentLoaded", function(event) {
    function dispatchAttachment(attachNumber, fileData) {
        console.log("attach" + attachNumber + " :: onload");
        
        var bytes = new Uint8Array(fileData);
        
        console.log("attach" + attachNumber + " :: bytes = " + bytes);
        
        safari.extension.dispatchMessage("attach" + attachNumber, {"data" : Array.from(bytes)});
        
        console.log("attach" + attachNumber + " :: sent");
    }
    
    function prepopulateMessage(elements) {
        var message = new Object();
        for (let key in elements) {
            if (key != null) {
                message[key] = elements[key].value;
            }
        }
        return message
    }
    
    console.log('ready');
    safari.extension.dispatchMessage("document loaded");
    
    if (document.URL.includes("note.cgi")) {
        var noteForms = document.forms;
        if (noteForms != null) {
            console.log("At lease one noteForm exists: " + noteForms);
            
            for (var index = 0; index < noteForms.length; index++) {
                console.log('noteForm = ' + noteForms[index]);
                noteForms[index].addEventListener('submit', function (noteEvent) {
                    const elements = this.elements;
                    console.log(elements);
                    var message = prepopulateMessage(elements)
                    safari.extension.dispatchMessage("noteForm", message);
                });
            }
        }
    }
    
    var commentForm = document.forms['addcomment'];
    if (commentForm != null) {
        console.log('A commentForm exists');
        
        let boardTitle = document.getElementsByTagName('h1')[0].innerText;
        let articleTitle = document.getElementsByClassName('article')[0].innerText;
        
        commentForm.addEventListener('submit', function(commentEvent) {
            console.log('submit');
            safari.extension.dispatchMessage("A comment submitted");
            
            const elements = this.elements;
            console.log(elements);
            
            var message = prepopulateMessage(elements)
            message.boardTitle = boardTitle.toString();
            message.articleTitle = articleTitle.toString();
            
            safari.extension.dispatchMessage("commentForm", message);
            
            
            const { action, aid, bid, p, img, lastcno, body, submit } = this.elements;
        });
    }

    var writeForm = document.forms['writeform'];
    if (writeForm != null) {
        console.log('A writeForm exists');
        
        let boardTitle = document.getElementsByTagName('h1')[0].innerText;
        
        let attachments = ["attach1", "attach2", "attach3", "attach4", "attach5", "attach6", "attach7", "attach8", "attach9", "attach10"]
        
        var reader1 = new FileReader();
        reader1.onload = function (e) {
            dispatchAttachment(1, reader1.result)
        };
        
        var reader2 = new FileReader();
        reader2.onload = function (e) {
            dispatchAttachment(2, reader2.result)
        };
        
        var reader3 = new FileReader();
        reader3.onload = function (e) {
            dispatchAttachment(3, reader3.result)
        };
        
        var reader4 = new FileReader();
        reader4.onload = function (e) {
            dispatchAttachment(4, reader4.result)
        };
        
        var reader5 = new FileReader();
        reader5.onload = function (e) {
            dispatchAttachment(5, reader5.result)
        };
        
        var reader6 = new FileReader();
        reader6.onload = function (e) {
            dispatchAttachment(6, reader6.result)
        };
        
        var reader7 = new FileReader();
        reader7.onload = function (e) {
            dispatchAttachment(7, reader7.result)
        };
        
        var reader8 = new FileReader();
        reader8.onload = function (e) {
            dispatchAttachment(8, reader8.result)
        };
        
        var reader9 = new FileReader();
        reader9.onload = function (e) {
            dispatchAttachment(9, reader9.result)
        };
        
        var reader10 = new FileReader();
        reader10.onload = function (e) {
            dispatchAttachment(10, reader10.result)
        };
        
        writeForm.addEventListener('submit', function(writeEvent) {
            console.log('submit');
            
            const elements = this.elements;
            
            var message = new Object();
            for (let key in elements) {
                if (key != null) {
                    message[key] = elements[key].value;
                }
                
                if (key == "attach1") {
                    console.log(key)
                    var file = elements[key].files[0];
                    safari.extension.dispatchMessage(key,
                                                     {"name": file.name, "type": file.type, "size": file.size});
                    reader1.readAsArrayBuffer(file);
                }
                
                if (key == "attach2") {
                    console.log(key)
                    var file = elements[key].files[0];
                    safari.extension.dispatchMessage(key,
                                                     {"name": file.name, "type": file.type, "size": file.size});
                    reader2.readAsArrayBuffer(file);
                }
                
                if (key == "attach3") {
                    console.log(key)
                    var file = elements[key].files[0];
                    safari.extension.dispatchMessage(key,
                                                     {"name": file.name, "type": file.type, "size": file.size});
                    reader3.readAsArrayBuffer(file);
                }
                
                if (key == "attach4") {
                    console.log(key)
                    var file = elements[key].files[0];
                    safari.extension.dispatchMessage(key,
                                                     {"name": file.name, "type": file.type, "size": file.size});
                    reader4.readAsArrayBuffer(file);
                }
                
                if (key == "attach5") {
                    console.log(key)
                    var file = elements[key].files[0];
                    safari.extension.dispatchMessage(key,
                                                     {"name": file.name, "type": file.type, "size": file.size});
                    reader5.readAsArrayBuffer(file);
                }
                
                if (key == "attach6") {
                    console.log(key)
                    var file = elements[key].files[0];
                    safari.extension.dispatchMessage(key,
                                                     {"name": file.name, "type": file.type, "size": file.size});
                    reader6.readAsArrayBuffer(file);
                }
                
                if (key == "attach7") {
                    console.log(key)
                    var file = elements[key].files[0];
                    safari.extension.dispatchMessage(key,
                                                     {"name": file.name, "type": file.type, "size": file.size});
                    reader7.readAsArrayBuffer(file);
                }
                
                if (key == "attach8") {
                    console.log(key)
                    var file = elements[key].files[0];
                    safari.extension.dispatchMessage(key,
                                                     {"name": file.name, "type": file.type, "size": file.size});
                    reader8.readAsArrayBuffer(file);
                }
                
                if (key == "attach9") {
                    console.log(key)
                    var file = elements[key].files[0];
                    safari.extension.dispatchMessage(key,
                                                     {"name": file.name, "type": file.type, "size": file.size});
                    reader9.readAsArrayBuffer(file);
                }
                
                if (key == "attach10") {
                    console.log(key)
                    var file = elements[key].files[0];
                    safari.extension.dispatchMessage(key,
                                                     {"name": file.name, "type": file.type, "size": file.size});
                    reader10.readAsArrayBuffer(file);
                }
            }
            
            console.log("attach-count = " + message["attach-count"])
            
            message.boardTitle = boardTitle.toString();
            safari.extension.dispatchMessage("writeForm", message);
            
        });
    }
});
