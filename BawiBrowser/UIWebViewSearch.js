// https://stackoverflow.com/questions/38317747/find-text-in-webview-page-using-swift
// https://github.com/sstahurski/SearchWKWebView

var uiWebview_SearchResultTotalCount = 0;
var uiWebview_SearchResultCounter = 0;

/*!
 @method     uiWebview_HighlightAllOccurencesOfStringForElement
 @abstract   // helper function, recursively searches in elements and their child nodes
 @discussion // helper function, recursively searches in elements and their child nodes

 element    - HTML elements
 keyword    - string to search
 */

function uiWebview_HighlightAllOccurencesOfStringForElement(element,keyword) {
    if (element) {
        if (element.nodeType == 3) {        // Text node

            var count = 0;
            var elementTmp = element;
            while (true) {
                var value = elementTmp.nodeValue;  // Search for keyword in text node
                var idx = value.toLowerCase().indexOf(keyword);

                if (idx < 0) break;

                count++;
                elementTmp = document.createTextNode(value.substr(idx+keyword.length));
            }

            uiWebview_SearchResultTotalCount += count;

            //var index = uiWebview_SearchResultCounter;
            while (true) {
                var value = element.nodeValue;  // Search for keyword in text node
                var idx = value.toLowerCase().indexOf(keyword);

                if (idx < 0) break;             // not found, abort

                //we create a SPAN element for every parts of matched keywords
                var span = document.createElement("span");
                var text = document.createTextNode(value.substr(idx,keyword.length));
                span.appendChild(text);

                span.setAttribute("class","uiWebviewHighlight");
                span.style.backgroundColor="yellow";
                span.style.color="black";

                uiWebview_SearchResultCounter++;
                span.setAttribute("id", "SEARCH WORD"+(uiWebview_SearchResultCounter));
                //span.setAttribute("id", "SEARCH WORD"+uiWebview_SearchResultTotalCount);

                //element.parentNode.setAttribute("id", "SEARCH WORD"+uiWebview_SearchResultTotalCount);

                //uiWebview_SearchResultTotalCount++;    // update the counter

                text = document.createTextNode(value.substr(idx+keyword.length));
                element.deleteData(idx, value.length - idx);

                var next = element.nextSibling;
                //alert(element.parentNode);
                element.parentNode.insertBefore(span, next);
                element.parentNode.insertBefore(text, next);
                element = text;
            }


        } else if (element.nodeType == 1) { // Element node
            if (element.style.display != "none" && element.nodeName.toLowerCase() != 'select') {
                for (var i=element.childNodes.length-1; i>=0; i--) {
                    uiWebview_HighlightAllOccurencesOfStringForElement(element.childNodes[i],keyword);
                }
            }
        }
    }
}

// the main entry point to start the search
function uiWebview_HighlightAllOccurencesOfString(keyword) {
    uiWebview_RemoveAllHighlights();
    uiWebview_HighlightAllOccurencesOfStringForElement(document.body, keyword.toLowerCase());
}

// helper function, recursively removes the highlights in elements and their childs
function uiWebview_RemoveAllHighlightsForElement(element) {
    if (element) {
        if (element.nodeType == 1) {
            if (element.getAttribute("class") == "uiWebviewHighlight") {
                var text = element.removeChild(element.firstChild);
                element.parentNode.insertBefore(text,element);
                element.parentNode.removeChild(element);
                return true;
            } else {
                var normalize = false;
                for (var i=element.childNodes.length-1; i>=0; i--) {
                    if (uiWebview_RemoveAllHighlightsForElement(element.childNodes[i])) {
                        normalize = true;
                    }
                }
                if (normalize) {
                    element.normalize();
                }
            }
        }
    }
    return false;
}

// the main entry point to remove the highlights
function uiWebview_RemoveAllHighlights() {
    uiWebview_SearchResultTotalCount = 0;
    uiWebview_SearchResultCounter = 0;
    uiWebview_RemoveAllHighlightsForElement(document.body);
}

function uiWebview_ScrollTo(idx) {
    var scrollTo = document.getElementById("SEARCH WORD" + idx);
    if (scrollTo) scrollTo.scrollIntoView(true);
}
