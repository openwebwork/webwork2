(function () {
    var textareas = document.getElementsByClassName("codeshard");
    var editors = [];
    for (i=0; i<textareas.length; i++) {
        var ta_cols = textareas[i].cols;
        editors[i] = CodeMirror.fromTextArea(textareas[i],{matchBrackets: true});
        editors[i].getWrapperElement().style.width = 9*ta_cols + 20 + "px";
    }

})();

