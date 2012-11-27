
function delrow(num) { 
  $('#pgrow'+num).remove(); 
  /* Should also remove from the list of pg files for pagination */
  return(true)
}

function pathsub(num, fpath) {
  $('#filepath'+num).html(fpath);
  return(true);
}

function opl() {
  wwb = new webwork.Browse();
  /* wwb.go(); */
  alert("opl");
  return "Ho";
}
