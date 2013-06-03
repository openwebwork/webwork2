window.focus();  //  bring the current window to the front
                 //  (needed by Firefox when the target window
                 //  is not frontmost)

if (!window.ww) {window.ww = {}}
try {ww.openerName = window.opener.name} catch (err) {ww.openerName = ""}

ww.ReTarget = function () {
  var tags = document.getElementsByTagName('a');
  for (var i = 0; i < tags.length; i++) {
    if (!tags[i].target && !tags[i].href.match(/pgProblemEditor/)) {tags[i].target = "WW_View"} 
  }
  tags = document.getElementsByTagName('form');
  for (var i = 0; i < tags.length; i++) {
    if (!tags[i].target && tags[i].id != 'editor') {tags[i].target = "WW_View"}
  }
}

if (window.name == 'WW_Editor' ||
   (document.title && document.title.match(/ Editor$/))) {
  window.name = "WW_Editor";
} else if (!window.opener || ww.openerName != 'WW_View') {
  window.name = "WW_View";
}

if (window.name != "WW_View") {ww.ReTarget()}
