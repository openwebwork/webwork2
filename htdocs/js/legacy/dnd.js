var changingSize = false;
var changingHorizontalSize = false;
var myStartWidth, libStartWidth;
var myStartHeight;
var mouseX, mouseY;
var changeInX = 0;
var changeInY = 0;
var dragging = false;
var horizontalSliderStartTop;
var scrollIntervals = new Array();
//dom element tools
function hasClassName(element, class_name) {
  return element?new RegExp("(?:^|\\s+)" + class_name + "(?:\\s+|$)").test(element.className):false;
}

function addClassName(element, class_name) {
  if (!hasClassName(element, class_name) && element) {
    var c = element.className;
    element.className = c ? [c, class_name].join(' ') : class_name;
  }
}

function removeClassName(element, class_name) {
  if (hasClassName(element, class_name)) {
    var c = element.className;
    element.className = c.replace(
        new RegExp("(?:^|\\s+)" + class_name + "(?:\\s+|$)", "g"), "");
  }
}

function getChildById(id, node){
  var children = node.childNodes;
  for(var i = 0; i < children.length; i++){
    if(children[i].id == id){
      return children[i];
    }
    else{
      var result = getChildById(id, children[i]);
      if(result){
        return result;
      }
    }
  }
  return false;
}

var fullscreen = false;
var savedScreenInfo = new Array(6);

function fullWindowMode(){
  if(fullscreen){
    document.getElementById("set_maker_two_box").style.position = savedScreenInfo[0];
    document.getElementById("set_maker_two_box").style.top = savedScreenInfo[1];
    document.getElementById("set_maker_two_box").style.left = savedScreenInfo[2];
    document.getElementById("set_maker_two_box").style.height = savedScreenInfo[3];
    document.getElementById("set_maker_two_box").style.width = savedScreenInfo[4];
    document.getElementById("set_maker_two_box").style.background = savedScreenInfo[5];
    document.getElementById("set_maker_two_box").style.zIndex = null;
  } else {
    savedScreenInfo[0] = document.getElementById("set_maker_two_box").style.position;
    document.getElementById("set_maker_two_box").style.position = "absolute";
    document.getElementById("set_maker_two_box").style.zIndex = 100;
    savedScreenInfo[1] = document.getElementById("set_maker_two_box").style.top;
    document.getElementById("set_maker_two_box").style.top = 0;
    savedScreenInfo[2] = document.getElementById("set_maker_two_box").style.left;
    document.getElementById("set_maker_two_box").style.left = 0;
    savedScreenInfo[3] = document.getElementById("set_maker_two_box").style.height;
    document.getElementById("set_maker_two_box").style.height = window.innerWidth;
    savedScreenInfo[4] = document.getElementById("set_maker_two_box").style.width;
    document.getElementById("set_maker_two_box").style.width = window.innerWidth;
    savedScreenInfo[5] = document.getElementById("set_maker_two_box").style.background;
    document.getElementById("set_maker_two_box").style.background = "white";
    //adjust for relatively position parrents
    if (Math.abs(findPos(document.getElementById("set_maker_two_box"))[1]) > 1){
      document.getElementById("set_maker_two_box").style.top = -findPos(document.getElementById("set_maker_two_box"))[1]; 
    }
    if (Math.abs(findPos(document.getElementById("set_maker_two_box"))[0]) > 1){
      document.getElementById("set_maker_two_box").style.left = -findPos(document.getElementById("set_maker_two_box"))[0]; 
    }
  }
  gridify(false);
  hasBeenGridded = false;
  gridify(false);
  fullscreen = !fullscreen;
}

function setup(){
  //console.log("app code name:" + navigator.appCodeName);
  //console.log("app name: " + navigator.appName);
  if(navigator.appCodeName != "Mozilla"){
    alert("Your browser may not be supported");
  }
  //set up all draggable items
  var dragItems = document.querySelectorAll('[draggable=true]');
  for (var i = 0; i < dragItems.length; i++) {
    dragItems[i].addEventListener('dragstart', function (event) {
      dragging = true;
      event.dataTransfer.effectAllowed = 'all';
      // store the ID of the element, and collect it on the drop later on
      event.dataTransfer.setData('Text', this.id);
      event.dataTransfer.setData('Move', event.shiftKey);
    },false);
  }
  
  var table = document.getElementById('mysets_problems');
  var targetProblems = table.childNodes;
  for(var i = 0; i < targetProblems.length; i++){
    targetProblems[i].addEventListener('drop', reorderDrop, false);
    targetProblems[i].addEventListener('dragenter', dragEnter, false);
    targetProblems[i].addEventListener('dragleave', reorderDragLeave, false);
    targetProblems[i].addEventListener('dragover', reorderDragOver, false);
  }
  
  //dynamically size the lists
  var libraryBox = document.querySelectorAll('div.setmaker_library');
  var mysetsBox = document.querySelectorAll('div.mysets');
  //fix sizes
  var totalWidth = document.getElementById('problem_container').clientWidth;
  myStartWidth = (100*(1/4))-0.8;
  libStartWidth = (100*(3/4))-0.8;
  for(var i = 0; i < libraryBox.length; i++)
    libraryBox[i].style.width = ""+libStartWidth+"%";
  for(var i = 0; i < mysetsBox.length; i++)
    mysetsBox[i].style.width = ""+myStartWidth+"%";
    
  var myset_sets = document.querySelectorAll('select#myset_sets option');
  for(var i = 0; i < myset_sets.length; i++){
    myset_sets[i].addEventListener('drop', singleAddDrop, false);
    myset_sets[i].addEventListener('dragenter', singleAddEnter, false);
    myset_sets[i].addEventListener('dragleave', singleAddLeave, false);
    myset_sets[i].addEventListener('dragover', singleAddOver, false);
    myset_sets[i].addEventListener('mouseover', singleMouseOver, false);
    myset_sets[i].addEventListener('mouseout', singleMouseOut, false);
  }
  
  myStartHeight = table.clientHeight;
  document.body.addEventListener('mousemove', sliderMove , false);
  document.getElementById("size_slider").addEventListener('mousedown', sliderDown , false);
  document.body.addEventListener('mouseup', sliderUp , false);
  var horizontalSlider = document.getElementById("horizontal_slider");
  horizontalSlider.style.width = totalWidth;
  horizontalSliderStartTop = findPos(table)[1] - findPos(horizontalSlider)[1] - 16;
  horizontalSlider.style.marginTop = horizontalSliderStartTop+"px";
  horizontalSlider.addEventListener('mousedown', horizontalSliderDown, false);
  
  //important drag and drop stuff
  table.addEventListener('drop', drop, false);
  table.addEventListener('dragenter', dragEnter, false);
  table.addEventListener('dragleave', dragLeave, false);
  table.addEventListener('dragover', dragOver, false);
  
  document.body.addEventListener('drop', removeDrop, false);
  document.body.addEventListener('dragenter', dragEnter, false);
  document.body.addEventListener('dragleave', dragLeave, false);
  document.body.addEventListener('dragover', dragOver, false);
  //set up problem counter
  document.getElementById('problem_counter').innerHTML = document.getElementById('mysets_problems').childNodes.length;
  
  var pastGridded = document.getElementById('pastGridded');
  //console.log(pastGridded.value);
  if(pastGridded.value == "true"){
    gridify(false);
  }
  document.getElementById("loading").style.display = "none";
}

function redoSetup(problemSet){
  //set up all draggable items
  //var dragItems = problemSet.childNodes;
  //this may add multiple listeners but they're all doing the same thing so it should be ok
  
  var dragItems = problemSet.childNodes;
  for (var i = 0; i < dragItems.length; i++) {
    dragItems[i].addEventListener('dragstart', function (event) {
      dragging = true;
      event.dataTransfer.effectAllowed = 'all';
      // store the ID of the element, and collect it on the drop later on
      event.dataTransfer.setData('Text', this.id);
      event.dataTransfer.setData('Move', event.shiftKey);
    },false);
  }
  if(problemSet.id == "mysets_problems"){
    for(var i = 0; i < dragItems.length; i++){
      dragItems[i].addEventListener('drop', reorderDrop, false);
      dragItems[i].addEventListener('dragenter', dragEnter, false);
      dragItems[i].addEventListener('dragleave', reorderDragLeave, false);
      dragItems[i].addEventListener('dragover', reorderDragOver, false);
    }
  }
  //set up problem counter
  document.getElementById('problem_counter').innerHTML = document.getElementById('mysets_problems').childNodes.length;

}

/****** view problems functions ******/

function selectAll(){
  //console.log("test");
  var libraryCheckboxes = document.querySelectorAll(".add_problem_checkbox");
  for(var i = 0; i < libraryCheckboxes.length; i++){
    libraryCheckboxes[i].checked = true;
  }
}

function selectNone(){
  var libraryCheckboxes = document.querySelectorAll(".add_problem_checkbox");
  for(var i = 0; i < libraryCheckboxes.length; i++){
    libraryCheckboxes[i].checked = false;
  }
}

/****** end view problems functions ******/

/****** Event listeners ******/

/****** automatic scrolling functions ******/
function scrollMouseMove(event){
  //var mouseX = event.pageX;
  var mousePos = getMouseXY(event);
  if (mousePos[1] > (document.getElementById('mysets_problems' ).offsetTop+document.getElementById('mysets_problems').clientHeight) - 20){
    scrollIntervals.push(setInterval('scrollMysetsDown()', 50));
    //document.getElementById('mysets_problems').scrollTop = 300;
  } else if (mousePos[1] < document.getElementById('mysets_problems' ).offsetTop + 20){
    scrollIntervals.push(setInterval('scrollMysetsUp()', 50));
  } else {
    for(var i = 0; i < scrollIntervals.length; i++){
      clearInterval(scrollIntervals[i]); 
    }
  }
}

function scrollMysetsDown(){
  //console.log("scrolling to: "+document.getElementById('mysets_problems').scrollTop);
  document.getElementById('mysets_problems').scrollTop+=5; 
}

function scrollMysetsUp(){
  //console.log("scrolling to: "+document.getElementById('mysets_problems').scrollTop);
  document.getElementById('mysets_problems').scrollTop-=5; 
}

/****** resize list functions ******/
//change the precent width of the lists by how much the mouse has moved
function sliderMove(event){
  event.preventDefault();
  if(changingSize){
    changeInX += event.pageX-mouseX;
    var totalWidth = document.getElementById('problem_container').clientWidth;
    if((libStartWidth-((changeInX/totalWidth)*100))>2 && (myStartWidth+((changeInX/totalWidth)*100)) > 2 ){
      mouseX = event.pageX;
      var libraryBox = document.getElementById('setmaker_library_box');
      var mysetsBox = document.getElementById('mysets_problems_box');
      libraryBox.style.width = ""+(libStartWidth-((changeInX/totalWidth)*100))+ "%";
      mysetsBox.style.width = ""+(myStartWidth+((changeInX/totalWidth)*100))+ "%";
    }
  } else if(changingHorizontalSize && 163+(changeInY+(event.pageY-mouseY)) > 0){
    changeInY += event.pageY-mouseY;
    var controlPanels = document.querySelectorAll("div.setSelector");
    for(var i = 0; i < controlPanels.length; i++){
      controlPanels[i].style.height = (163 + changeInY) + "px";
      document.getElementById("mysets_problems").style.height = (myStartHeight - changeInY)+"px";
      document.getElementById("setmaker_library_problems").style.height = (myStartHeight - changeInY)+"px";
    }
    document.getElementById('horizontal_slider').style.marginTop = (horizontalSliderStartTop + changeInY)+"px";
    document.getElementById('size_slider').style.marginTop = (horizontalSliderStartTop +changeInY)+"px";
    document.getElementById('size_slider').style.height = (myStartHeight - changeInY)+"px";
    mouseY = event.pageY;
  }
}

function horizontalSliderDown(event){
  event.preventDefault();
  changingHorizontalSize = true;
  mouseY = event.pageY;
}

//mouse down over slider bar between the lists
function sliderDown(event){
  event.preventDefault();
  changingSize = true;
  mouseX = event.pageX;
  mouseY = event.pageY;
}

function sliderUp(event){
  if(changingSize && isGridded){
    gridify(false)
    hasBeenGridded = false;
    gridify(false);
    hasBeenGridded = false;
    fixGrid();
    fixMysetsGrid();
  }
  changingSize = false;
  changingHorizontalSize = false;
}

/****** reorder functions ******/
//reorder problems
function reorderDrop(event){
  for(var i = 0; i < scrollIntervals.length; i++){
    clearInterval(scrollIntervals[i]); 
  }
  dragging = false;
  if (event.preventDefault) event.preventDefault();
  if (event.stopPropagation) event.stopPropagation();
  var movedProblem = document.getElementById(event.dataTransfer.getData('Text'));
  //console.log(event.dataTransfer.getData('Text'));
  previewProblemEnd(event);
  //get problem dropped on
  var targetProblem = event.target;
  while(targetProblem && !hasClassName(targetProblem, "problem")){
    targetProblem = targetProblem.parentNode;
  }
  //dont let it drop on itself;
  if(targetProblem.id == movedProblem.id){
    if (event.stopPropagation) event.stopPropagation();
    return false;
  }
  if((hasClassName(movedProblem, 'myProblem') && !hasClassName(movedProblem, "removedProblem")) || hasClassName(movedProblem, "libProblem")){  
    //console.log("were just doing a reorder");
    movedProblem.parentNode.removeChild(movedProblem);
    targetProblem.parentNode.insertBefore(movedProblem, targetProblem);
  } else {
    //cancel remove problem
    if(hasClassName(movedProblem, 'removedProblem')){
      //console.log("we're adding a problem back and reordering it");
      //have to disable a remove checkbox here as well
      var deleteProbBox = document.getElementById("deleted" + movedProblem.id);
      deleteProbBox.checked = false;
      deleteProbBox.parentNode.style.display = "inline";
      removeClassName(movedProblem,"removedProblem");
      //uncomment for reorder
      movedProblem.addEventListener('drop', reorderDrop, false);
      movedProblem.addEventListener('dragenter', dragEnter, false);
      movedProblem.addEventListener('dragleave', reorderDragLeave, false);
      movedProblem.addEventListener('dragover', reorderDragOver, false);
      
      movedProblem.parentNode.removeChild(movedProblem);
      targetProblem.parentNode.insertBefore(movedProblem, targetProblem);
    }
    //add library problem to target set
    else{
      //console.log("we're adding a new problem");
      addClassName(movedProblem,"libProblem");
      //where the work needs to be done
      var toBeMoved = event.dataTransfer.getData('Move') == "true";
      var moveProbBox = document.getElementById("moved" + movedProblem.id);
      if(moveProbBox){
        moveProbBox.checked = toBeMoved;
        moveProbBox.parentNode.style.display = "none";
      }
      //console.log("trial"+movedProblem.id);
      var addProbBox = document.getElementById("trial" + movedProblem.id);
      //only add problem if not moving
      addProbBox.checked = !toBeMoved || !moveProbBox;
      //addProbBox.parentNode.style.display = "none";
    
      var hideProbBox = document.getElementById("hideme" + movedProblem.id);
      //hideProbBox.parentNode.style.display = "none";
      //do the work to copy problem over to target set
      //remove if else to turn off copy
      if(addProbBox.checked){
        var cloneEl = movedProblem.cloneNode(true);
        cloneEl.id = movedProblem.id + "clone";
        cloneEl.removeChild(getChildById("trial" + movedProblem.id, cloneEl).parentNode.parentNode);
        cloneEl.removeChild(getChildById("hideme" + movedProblem.id, cloneEl).parentNode.parentNode);
        cloneEl.removeChild(getChildById("filetrial" + movedProblem.id, cloneEl));
        if(moveProbBox)
          cloneEl.removeChild(getChildById("moved" + movedProblem.id, cloneEl).parentNode.parentNode);
        targetProblem.parentNode.insertBefore(cloneEl, targetProblem);
        movedProblem.draggable = false;
        cloneEl.addEventListener('dragstart', function (event) {
          event.dataTransfer.effectAllowed = 'all';
          // store the ID of the element, and collect it on the drop later on
          event.dataTransfer.setData('Text', this.id);
          },false);
        //uncomment for reorder
        cloneEl.addEventListener('drop', reorderDrop, false);
        cloneEl.addEventListener('dragenter', dragEnter, false);
        cloneEl.addEventListener('dragleave', reorderDragLeave, false);
        cloneEl.addEventListener('dragover', reorderDragOver, false);
        
        if(isGridded){
          cloneEl.addEventListener('mouseover', onMouseOver, false);
          cloneEl.addEventListener('mousemove', onMouseMove, false);
          //libProblems[i].addEventListener('click', previewProblemEnd, false);
          cloneEl.addEventListener('mouseout', onMouseOut, false);
        }
      }
      else{ //move
        //console.log("we're moving a problem?");
        //uncomment for reorder
        movedProblem.addEventListener('drop', reorderDrop, false);
        movedProblem.addEventListener('dragenter', dragEnter, false);
        movedProblem.addEventListener('dragleave', reorderDragLeave, false);
        movedProblem.addEventListener('dragover', reorderDragOver, false);
        
        movedProblem.parentNode.removeChild(movedProblem);
        targetProblem.parentNode.insertBefore(movedProblem, targetProblem);
      }
    }
    document.getElementById('problem_counter').innerHTML = document.getElementById('mysets_problems').childNodes.length;
  }
  
  document.getElementById('isReordered').value = 1;
  //propegation issue so call fix grids here..should really do this better
  if(isGridded){
    targetProblem.style.borderLeft = "none";
    movedProblem.style.borderLeft = "none";
  }
  else {
    targetProblem.style.borderTop = "none";
    movedProblem.style.borderTop = "none";
  }
  //rename and reorder all problems in the target set
  var reorderedProblems = document.getElementById('mysets_problems').childNodes;
  for(var i = 0; i < reorderedProblems.length; i++){
    //starts counting at one
    var currentCount = i+1;
    if(document.getElementById('reorder'+currentCount)){
      document.getElementById('reorder'+currentCount).parentNode.removeChild(document.getElementById('reorder'+currentCount));
    }
    var reorderedInput = document.createElement('input');
    reorderedInput.type = "hidden";
    reorderedInput.id = "reorder"+currentCount;
    reorderedInput.name = "reorder"+currentCount;
    var fileNameToGet = reorderedProblems[i].id.match("clone")?reorderedProblems[i].id.replace("clone", ""):reorderedProblems[i].id;
    reorderedInput.value = document.getElementById("filetrial"+fileNameToGet).value;
    reorderedInput.override = 1;
    reorderedProblems[i].appendChild(reorderedInput);
  }
  
  if(isGridded){
    hasBeenGridded = false;
    fixGrid();
    fixMysetsGrid();
  }
  return true;
}

function reorderDragOver(event) {
  scrollMouseMove(event);
    if (event.preventDefault) event.preventDefault(); // allows us to drop
    event.dataTransfer.effectAllowed = 'all';
    //var table = e.target;
  //table.style.background = "green";
  //doesn't work in webkit
  //var movedProblem = document.getElementById(event.dataTransfer.getData('Text'));
  //get problem dropped on
  var targetProblem = event.target;
  while(targetProblem && !hasClassName(targetProblem, "problem")){
    targetProblem = targetProblem.parentNode;
  }
  //don't allow move and reorder at the same time
  //if(((movedProblem.hasClassName("myProblem") && !movedProblem.hasClassName("removedProblem")) || movedProblem.hasClassName("libProblem"))&&((targetProblem.hasClassName("myProblem") && !targetProblem.hasClassName("removedProblem")) || targetProblem.hasClassName("libProblem"))){
    //show where it will be dropped
    if(isGridded){
      targetProblem.style.borderLeft = "3px solid blue";
    }
    else {
      targetProblem.style.borderTop = "3px solid blue";
    }
  //}
}


function reorderDragLeave(event) {
  for(var i = 0; i < scrollIntervals.length; i++){
    clearInterval(scrollIntervals[i]); 
  }
  if (event.preventDefault) event.preventDefault(); // allows us to drop
  //var table = e.target;
  //table.style.background = "red";
  //var movedProblem = document.getElementById(event.dataTransfer.getData('Text'));
  //get problem dropped on
  var targetProblem = event.target;
  while(targetProblem && !hasClassName(targetProblem, "problem")){
    targetProblem = targetProblem.parentNode;
  }
  //don't allow move and reorder at the same time
  //if(((movedProblem.hasClassName("myProblem") && !movedProblem.hasClassName("removedProblem")) || movedProblem.hasClassName("libProblem"))&&((targetProblem.hasClassName("myProblem") && !targetProblem.hasClassName("removedProblem")) || targetProblem.hasClassName("libProblem"))){
    //show where it will be dropped
    if(isGridded){
      targetProblem.style.borderLeft = "none";
    }
    else {
      targetProblem.style.borderTop = "none";
    }
  //}

}

/****** individual add functions ******/
function singleMouseOver(event) {
  //this is the kind of crazy work around that shouldn't be nessisary:
  event.target.style.background = "rgba(176, 216, 230, 1)";
  event.target.parentNode.style.background = "white";
}

function singleMouseOut(event) {
  event.target.style.background = "none";
  event.target.parentNode.style.background = "none";
}

function singleAddOver(event) {
    if (event.preventDefault) event.preventDefault(); // allows us to drop
    event.dataTransfer.effectAllowed = 'all';
    event.target.style.background = "rgba(176, 216, 230, 1)";
    event.target.parentNode.style.background = "white";
    
}

  // to get IE to work
function singleAddEnter(event) {
  if (event.preventDefault) event.preventDefault(); // allows us to drop
  event.dataTransfer.effectAllowed = 'all';
  event.target.style.background = "rgba(176, 216, 230, 1)";
  event.target.parentNode.style.background = "white";
  //var table = e.target;
  //table.style.background = "white";

}

function singleAddLeave(event) {
  //if (event.preventDefault) event.preventDefault(); // allows us to drop
  event.target.style.background = "none";
  event.target.parentNode.style.background = "none";
}

function singleAddDrop(event) {
  for(var i = 0; i < scrollIntervals.length; i++){
    clearInterval(scrollIntervals[i]); 
  }
  dragging = false;
  previewProblemEnd(event);
  if (event.preventDefault) event.preventDefault();
  if (event.stopPropagation) event.stopPropagation();
  var el = document.getElementById(event.dataTransfer.getData('Text'));
  var currentURL = window.location.href//window.location.protocol + "//" + window.location.host + window.location.pathname;
  //var wantedElements = ["myset_sets", "local_sets", "reorder", "user", "filetrial", "isReordered", "mysetfiletrial", "trial", "deleted", "moved", "effectiveUser", "key", "new_set_name", "library_sets"];
  var form = document.createElement('form');
  var currentFormElements = document.getElementById('mainform').elements;
  
  form.appendChild(currentFormElements['user'].cloneNode(true));
  form.appendChild(currentFormElements['effectiveUser'].cloneNode(true));
  form.appendChild(currentFormElements['key'].cloneNode(true));
  
  var myset_sets = document.createElement('input');
  myset_sets.name = "myset_sets";
  myset_sets.value = event.target.value;
  form.appendChild(myset_sets);
  
  form.appendChild(currentFormElements['local_sets'].cloneNode(true));
  
  //console.log(parseInt(el.id));
  for(var i = 1; i < parseInt(el.id); i++){
    var addedProblem = document.createElement('input');
    addedProblem.name = "filetrial" + i;
    addedProblem.value = document.getElementById("filetrial" + i).value;
    form.appendChild(addedProblem);
  }

  var addedProblem = document.createElement('input');
  addedProblem.name = "filetrial" + el.id.replace('myset', '');
  addedProblem.value = document.getElementById("filetrial" + el.id).value;
  form.appendChild(addedProblem);
    
  var addedProblemAddBox = document.createElement('input');
  addedProblemAddBox.name = "trial" + el.id.replace('myset', '');
  addedProblemAddBox.value = 1;
  form.appendChild(addedProblemAddBox);
  
  singleAddSubmit(form, currentURL, 'save_changes_spinner');
  event.target.style.background = "none";
  event.target.parentNode.style.background = "none";
}

/****** normal drag functions ******/
function dragOver(event) {
    scrollMouseMove(event);
    if (event.preventDefault) event.preventDefault(); // allows us to drop
    event.dataTransfer.effectAllowed = 'all';
}

  // to get IE to work
function dragEnter(event) {
  if (event.preventDefault) event.preventDefault(); // allows us to drop
  event.dataTransfer.effectAllowed = 'all';
  //var table = e.target;
  //table.style.background = "white";

}

function dragLeave(event) {
     for(var i = 0; i < scrollIntervals.length; i++){
        clearInterval(scrollIntervals[i]); 
      }
  //if (event.preventDefault) event.preventDefault(); // allows us to drop
}

function drop(event) {
    for(var i = 0; i < scrollIntervals.length; i++){
        clearInterval(scrollIntervals[i]); 
      }
    dragging = false;
  //has to be done in both places just in case
  previewProblemEnd(event);
  if (event.preventDefault) event.preventDefault();
  if (event.stopPropagation) event.stopPropagation();
  var table = document.getElementById('mysets_problems');
  var el = document.getElementById(event.dataTransfer.getData('Text'));
  //If I drop on the empty table place at end
  if((hasClassName(el,"myProblem") && !hasClassName(el,"removedProblem")) || hasClassName(el,"libProblem")){
    table.removeChild(el);
    table.appendChild(el);
  }
  else {
    //cancel remove problem
    if(hasClassName(el,'removedProblem')){
      //have to disable a remove checkbox here as well
      var deleteProbBox = document.getElementById("deleted" + el.id);
      deleteProbBox.checked = false;
      deleteProbBox.parentNode.style.display = "inline";
      removeClassName(el, "removedProblem");
      //uncomment for reorder
      el.addEventListener('drop', reorderDrop, false);
      el.addEventListener('dragenter', dragEnter, false);
      el.addEventListener('dragleave', reorderDragLeave, false);
      el.addEventListener('dragover', reorderDragOver, false);
      
      el.parentNode.removeChild(el);
      table.appendChild(el);
    }
    //add library problem to target set
    else{
      addClassName(el,"libProblem");
      //where the work needs to be done
      var toBeMoved = event.dataTransfer.getData('Move') == "true";
      var moveProbBox = document.getElementById("moved" + el.id);
      if(moveProbBox){
        moveProbBox.checked = toBeMoved;
        moveProbBox.parentNode.style.display = "none";
      }
      var addProbBox = document.getElementById("trial" + el.id);
      //only add problem if not moving
      addProbBox.checked = !toBeMoved || !moveProbBox;
      //addProbBox.parentNode.style.display = "none";
    
      var hideProbBox = document.getElementById("hideme" + el.id);
      //hideProbBox.parentNode.style.display = "none";
      //do the work to copy problem over to target set
      //remove if else to turn off copy
      if(addProbBox.checked){
        var cloneEl = el.cloneNode(true);
        cloneEl.id = el.id + "clone";
        cloneEl.removeChild(getChildById("trial" + el.id, cloneEl).parentNode.parentNode);
        cloneEl.removeChild(getChildById("hideme" + el.id, cloneEl).parentNode.parentNode);
        cloneEl.removeChild(getChildById("filetrial" + el.id, cloneEl));
        if(moveProbBox)
          cloneEl.removeChild(getChildById("moved" + el.id, cloneEl).parentNode.parentNode);
        table.appendChild(cloneEl);
        el.draggable = false;
        cloneEl.addEventListener('dragstart', function (event) {
          event.dataTransfer.effectAllowed = 'all';
          // store the ID of the element, and collect it on the drop later on
          event.dataTransfer.setData('Text', this.id);
          },false);
        //uncomment for reorder
        el.addEventListener('drop', reorderDrop, false);
        el.addEventListener('dragenter', dragEnter, false);
        el.addEventListener('dragleave', reorderDragLeave, false);
        el.addEventListener('dragover', reorderDragOver, false);
      }
      else{ //move
        //uncomment for reorder
        el.addEventListener('drop', reorderDrop, false);
        el.addEventListener('dragenter', dragEnter, false);
        el.addEventListener('dragleave', reorderDragLeave, false);
        el.addEventListener('dragover', reorderDragOver, false);
        
        el.parentNode.removeChild(el);
        table.appendChild(el);
      }
    }
    document.getElementById('problem_counter').innerHTML = document.getElementById('mysets_problems').childNodes.length;
  }
  return false;
}

function removeDrop(e) {
  if (e.preventDefault) e.preventDefault();
  //kind of a hack fix later
  if(e.target.id == "div_cover"){
    if (e.stopPropagation) e.stopPropagation();
    return false;
  }
  //has to be done in both places just in case
  previewProblemEnd(e);
  if (e.stopPropagation) e.stopPropagation(); // stops the browser from redirecting
  var el = document.getElementById(e.dataTransfer.getData('Text'));
  //cancel remove
  if(hasClassName(el,'myProblem')){
    //have to enable a remove checkbox here as well
    var deleteProbBox = document.getElementById("deleted" + el.id);
    deleteProbBox.checked = true;
    deleteProbBox.parentNode.style.display = "none";
    addClassName(el,"removedProblem");
    el.parentNode.removeChild(el);
    //uncomment for reorder
    el.removeEventListener('drop', reorderDrop, false);
    el.removeEventListener('dragenter', dragEnter, false);
    el.removeEventListener('dragleave', reorderDragLeave, false);
    el.removeEventListener('dragover', reorderDragOver, false);
    document.getElementById('setmaker_library_problems').appendChild(el);
  }
  //cancel add
  else if(hasClassName(el,'libProblem')){
    //comment for only one moved problem
    var realEl = document.getElementById(el.id.replace("clone", ""));
    realEl.draggable = true;
    //remove libProblem tag
    removeClassName(realEl,'libProblem');
    //only one moved problem
    //el.removeClassName('libProblem');
    var addProbBox = document.getElementById("trial" + realEl.id);
    addProbBox.checked = false;
    addProbBox.parentNode.style.display = "inline";
    var moveProbBox = document.getElementById("moved" + realEl.id);
    if(moveProbBox){
      moveProbBox.checked = false;
      moveProbBox.parentNode.style.display = "inline";
    }
    var hideProbBox = document.getElementById("hideme" + realEl.id);
    hideProbBox.parentNode.style.display = "inline";
    el.parentNode.removeChild(el);
    
    //uncomment for reorder
    el.removeEventListener('drop', reorderDrop, false);
    el.removeEventListener('dragenter', dragEnter, false);
    el.removeEventListener('dragleave', reorderDragLeave, false);
    el.removeEventListener('dragover', reorderDragOver, false);
    
    //only one moved problem:
    //document.getElementById('setmaker_library_problems').appendChild(el);
  }
  document.getElementById('problem_counter').innerHTML = document.getElementById('mysets_problems').childNodes.length;
  return false;
}

/****** end event listeners ******/

/****** help function ******/
function toggleHelp(sender){
  if(sender.value == "false"){
    document.getElementById('help').style.display = "block";
    sender.value = "true";
  }
  else{
    document.getElementById('help').style.display = "none";
    sender.value = "false";
  }
}
