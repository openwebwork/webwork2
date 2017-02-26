var isGridded = false;
var mysetsHeight, mysetsWidth;
var libraryHeight, libraryWidth;
var previewWidth = 440;
var previewHeight = 120;
var mysetsAcross = 1;
var libAcross = 4;
var padding = 20; //the amount of padding on the lists
var property = false; //our browsers transform property
//stored values while problem is previewed
var previewProblem;
var previewProblemScale;
var tempTop, tempLeft;
//state variables
var viewing = false;
var hasBeenGridded = false;
var timeoutID;
var relativeNode;
var magnification = 1;

function gridify(e){
  //set up
  var mysetsList = document.getElementById("mysets_problems");
  var mysetsProblems = mysetsList.childNodes;
  var libraryList = document.getElementById("setmaker_library_problems");
  var libProblems = libraryList.childNodes;
  mysetsHeight = mysetsList.clientHeight;
  mysetsWidth = mysetsList.clientWidth - padding;
  libraryHeight = libraryList.clientHeight;
  libraryWidth = libraryList.clientWidth - padding;
  property = getTransformProperty(document.getElementById("editor-form"));
  //no point if can't transform
  if(property){
    if(!isGridded){
      document.getElementById("gridifyButton").innerHTML = "Ungridify?";
      document.getElementById('mysets_problems').addEventListener('drop', styleAddedGridProblem, false);
      document.body.addEventListener('drop', styleRemovedGridProblem, false);
      
      for(var i = 0; i<mysetsProblems.length; i++){
        mysetsProblems[i].addEventListener('mouseover', onMouseOver, false);
        mysetsProblems[i].addEventListener('mousemove', onMouseMove, false);
        //libProblems[i].addEventListener('click', previewProblemEnd, false);
        mysetsProblems[i].addEventListener('mouseout', onMouseOut, false);
      }

      for(var i = 0; i < libProblems.length; i++){
        if(!libProblems[i].className.match("libProblem")){
          libProblems[i].addEventListener('mouseover', onMouseOver, false);
          libProblems[i].addEventListener('mousemove', onMouseMove, false);
          //libProblems[i].addEventListener('click', previewProblemEnd, false);
          libProblems[i].addEventListener('mouseout', onMouseOut, false);
        }
      }
      fixGrid();
      fixMysetsGrid();
      isGridded = true;
      document.getElementById('pastGridded').value = "true";
      hasBeenGridded = true;
    }else{
      previewProblemEnd(false);
      document.getElementById("gridifyButton").innerHTML = "Gridify!!";
      document.getElementById('mysets_problems').removeEventListener('drop', styleAddedGridProblem, false);
      document.body.removeEventListener('drop', styleRemovedGridProblem, false);
      //scale mysets
      for(var i = 0; i<mysetsProblems.length; i++){
        //set the height and width for the preview version
        mysetsProblems[i].style.height = "auto";
        mysetsProblems[i].style.width = "auto";
        mysetsProblems[i].style[property] = "none";
        mysetsProblems[i].removeEventListener('mouseover', onMouseOver, false);
        mysetsProblems[i].removeEventListener('mousemove', onMouseMove, false);
        //libProblems[i].removeEventListener('click', previewProblemEnd, false);
        mysetsProblems[i].removeEventListener('mouseout', onMouseOut, false);
        mysetsProblems[i].style.position = "static";
      }
      //scale library sets
      for(var i = 0; i < libProblems.length; i++){
        libProblems[i].style.height = "auto";
        libProblems[i].style.width = "auto";
        //ratio should allow for 4 accross in library sets
        libProblems[i].style[property] = "none";
        libProblems[i].removeEventListener('mouseover', onMouseOver, false);
        libProblems[i].removeEventListener('mousemove', onMouseMove, false);
        //libProblems[i].removeEventListener('click', previewProblemEnd, false);
        libProblems[i].removeEventListener('mouseout', onMouseOut, false);
        libProblems[i].style.position = "static";
      }
      isGridded = false;
      document.getElementById('pastGridded').value = "false";
    }
  }
}
//gui adjustments
function increasMysetsAcross(){
  mysetsAcross++;
  document.getElementById('mysetsAcross').innerHTML = mysetsAcross;
  if(isGridded){
    hasBeenGridded = false;
    fixGrid();
    fixMysetsGrid();
  }
}

function decreaseMysetsAcross(){
  mysetsAcross--;
  document.getElementById('mysetsAcross').innerHTML = mysetsAcross;
  if(isGridded){
    hasBeenGridded = false;
    fixGrid();
    fixMysetsGrid();
  }
}

function increaseLibAcross(){
  libAcross++;
  document.getElementById('libAcross').innerHTML = libAcross;
  if(isGridded){
    hasBeenGridded = false;
    fixGrid();
    fixMysetsGrid();
  }
}

function decreaseLibAcross(){
  libAcross--;
  document.getElementById('libAcross').innerHTML = libAcross;
  if(isGridded){
    hasBeenGridded = false;
    fixGrid();
    fixMysetsGrid();
  }
}

function decreaseMagnification(){
  magnification -= 0.1;
  magnification = Math.round(magnification*10)/10;
  document.getElementById('magnification').innerHTML = magnification;
}
function increaseMagnification(){
  magnification += 0.1;
  magnification = Math.round(magnification*10)/10;
  document.getElementById('magnification').innerHTML = magnification;
}

function fixGrid(){
  var topDiff = 0;
  var tempHeight = 0;
  var libProblems = document.getElementById("setmaker_library_problems").childNodes;
  for(var i = 0; i < libProblems.length; i++){
    libProblems[i].style.height = "auto";
    libProblems[i].style.width = ""+previewWidth+"px";
    //ratio should allow for 4 accross in library sets
    var scale = (libraryWidth/libAcross)/previewWidth;
    var scaleY = previewHeight/libProblems[i].clientHeight;
    libProblems[i].style[property] = "scale("+scale+","+scaleY+")";
    libProblems[i].style.position = "absolute";
    //move things to create the grid
    if(!hasBeenGridded){
      topDiff = -(libProblems[i].clientHeight+2)*(1-scaleY)*(0.5);
      if(i == 0){
        tempHeight += 10;
        topDiff += tempHeight;
      } 
      else if(i%libAcross == 0){
        tempHeight += previewHeight + 10;
        topDiff += tempHeight;
      }
      else{
        topDiff += tempHeight;
      }
      libProblems[i].style.top = "" + ((topDiff)) + "px";
      //alert(topDiff);
    
      var leftDiff = -1*((((previewWidth-(libraryWidth/libAcross)))/2))+(i%libAcross)*(libraryWidth/libAcross);
      //pad the grid
      libProblems[i].style.left = "" + (leftDiff+10+(i%libAcross)*5) + "px";
    }
  }
}

function fixMysetsGrid(){
  var tempHeight = 0;
  var topDiff = 0;
  var mysetsProblems = document.getElementById("mysets_problems").childNodes;
  //scale mysets
  for(var i = 0; i<mysetsProblems.length; i++){
    mysetsProblems[i].style.height = "auto";
    mysetsProblems[i].style.width = ""+previewWidth+"px";
    //ratio should allow for 4 accross in library sets
    var scale = (mysetsWidth/mysetsAcross)/previewWidth;
    var scaleY = previewHeight/mysetsProblems[i].clientHeight;
    mysetsProblems[i].style[property] = "scale("+scale+","+scaleY+")";
    mysetsProblems[i].style.position = "absolute";
    //move things to create the grid
    if(!hasBeenGridded){
      topDiff = -(mysetsProblems[i].clientHeight+2)*(1-scaleY)*(0.5);
      if(i == 0){
        tempHeight += 10;
        topDiff += tempHeight;
      } 
      else if(i%mysetsAcross == 0){
        tempHeight += previewHeight + 10;
        topDiff += tempHeight;
      }
      else{
        topDiff += tempHeight;
      }
      mysetsProblems[i].style.top = "" + ((topDiff)) + "px";
      //alert(topDiff);
    
      var leftDiff = -1*((((previewWidth-(mysetsWidth/mysetsAcross)))/2))+(i%mysetsAcross)*(mysetsWidth/mysetsAcross);
      //pad the grid
      mysetsProblems[i].style.left = "" + (leftDiff+10+(i%mysetsAcross)*5) + "px";
    }
  }
}

function onMouseOver(event){
  if(!viewing && !dragging){
    clearTimeout(timeoutID);
    //console.log("?");
    previewProblem = getProblem(event.target);
    if (previewProblem){
      timeoutID = setTimeout("previewProblemStart()", 250);
    }
  }
}

function onMouseMove(event){
  if(!viewing && !dragging){
    clearTimeout(timeoutID);
    timeoutID = setTimeout("previewProblemStart()", 250);
  }
}

function onMouseOut(event){
  clearTimeout(timeoutID);
  //previewProblemEnd(false);
}


function previewProblemStart(){
  //save stuff for mouse leave
  tempTop = previewProblem.style.top;
  tempLeft = previewProblem.style.left;
  previewProblemScale = previewProblem.style[property];
  //adjust for magnification
  var leftDiff = -(((1-magnification)*previewProblem.clientWidth)/2);
  var topDiff = -(((1-magnification)*previewProblem.clientHeight)/2);
  
  var container = previewProblem.parentNode;
  /*var newPos = [Math.max(10, (previewProblem.offsetTop-topDiff)-previewProblem.parentNode.scrollTop), Math.max(10, (previewProblem.offsetLeft-leftDiff)-previewProblem.parentNode.scrollLeft)];
  previewProblem.style.top = newPos[0];
  previewProblem.style.left = newPos[1];*/
  previewProblem.style.zIndex = "1000";
  //previewProblem.className += " shadowed";
  //previewProblem.style.position = "fixed";
  /*if(previewProblem.offsetTop+previewProblem.clientHeight*magnification > previewProblem.parentNode.clientHeight){
    previewProblem.style.top = previewProblem.parentNode.clientHeight-previewProblem.clientHeight*magnification-10;
  }
  if((previewProblem.offsetLeft-leftDiff)+(previewProblem.clientWidth*magnification) > previewProblem.parentNode.clientWidth && previewProblem.clientWidth*magnification < previewProblem.parentNode.clientWidth){
    previewProblem.style.left = previewProblem.parentNode.clientWidth-10-previewProblem.clientWidth*magnification;
  }*/
  previewProblem.style[property] = "scale("+magnification+")";
  
  //get it's position relative to the problem container
  var relativePosition = findPos(previewProblem, "problemList");
  relativePosition[0] += leftDiff;
  relativePosition[1] += topDiff;
  relativePosition[1] -= previewProblem.parentNode.scrollTop;
  relativePosition[0] -= previewProblem.parentNode.scrollLeft;
  //set a relative node so it can be put back in the correct place
  relativeNode = previewProblem.nextSibling != null ? previewProblem.nextSibling : previewProblem.parentNode;
  //move the problem out of the box to deal with overflow
  previewProblem.parentNode.removeChild(previewProblem);
  document.getElementById('problem_container').appendChild(previewProblem);
  //set new position
  previewProblem.style.left = relativePosition[0];
  previewProblem.style.top = relativePosition[1];
  //set up a cover so that mouse out will work
  var divCover;
  if(!document.getElementById("div_cover")){
    divCover = document.createElement('div');
    divCover.id = "div_cover";
    divCover.className += "shadowed"
    document.getElementById('problem_container').appendChild(divCover);
    divCover.style.position = "absolute";
    divCover.style.zIndex = "2000";
  } else {
    divCover = document.getElementById("div_cover");
  }
  divCover.addEventListener('dragstart', dummyDrag,false);
  divCover.addEventListener('mouseout', previewProblemEnd, false);
  divCover.style.display = "block";
  divCover.style.height = previewProblem.clientHeight*magnification;
  divCover.style.width = previewProblem.clientWidth*magnification;
  divCover.style.top = previewProblem.offsetTop-topDiff;
  divCover.style.left = previewProblem.offsetLeft-leftDiff;
  //divCover.style[property] = "scale("+magnification+")";
  divCover.draggable = previewProblem.draggable;
  viewing = !viewing;
}

function dummyDrag(event){
  dragging = true;
  event.dataTransfer.effectAllowed = 'all';
  event.dataTransfer.setDragImage(previewProblem, previewProblem.clientWidth*(1/4), previewProblem.clientHeight*(1/4));
  //console.log("drag start for: "+previewProblem.id);
  // store the ID of the element, and collect it on the drop later on
  event.dataTransfer.setData('Text', previewProblem.id);
  event.dataTransfer.setData('Move', event.shiftKey);
  //previewProblemEnd(event);
}

function previewProblemEnd(event){
  if (event.preventDefault) event.preventDefault();
  if (event.stopPropagation) event.stopPropagation();
  clearTimeout(timeoutID);
  if(viewing){
    //document.getElementById('problem_container').removeChild(document.getElementById("div_cover"));
    document.getElementById("div_cover").style.display = "none";
    //document.getElementById("div_cover").style.zIndex = "-1000";
    document.getElementById("div_cover").removeEventListener('dragstart', dummyDrag,false);
    document.getElementById("div_cover").removeEventListener('mouseout', previewProblemEnd, false);
    document.getElementById('problem_container').removeChild(previewProblem);
    if(hasClassName(relativeNode, 'problemList')){
      relativeNode.appendChild(previewProblem);
    }else{
      relativeNode.parentNode.insertBefore(previewProblem, relativeNode); 
    }
    if(previewProblem.parentNode.id == "setmaker_library_problems"){
      var scale = (libraryWidth/libAcross)/previewWidth;
    }else{
      var scale = (mysetsWidth/mysetsAcross)/previewWidth;
    }
    previewProblem.style.position = "absolute";
    previewProblem.style.top = tempTop;
    previewProblem.style.left = tempLeft;
    previewProblem.style.zIndex = "0";
    previewProblem.style[property] = previewProblemScale;
    removeClassName(previewProblem, "shadowed");
    viewing = !viewing;
    //previewProblem = null;
  }
}

//utilities
function styleAddedGridProblem(e){
  previewProblemEnd(e);
  for(var i = 0; i < scrollIntervals.length; i++){
    clearInterval(scrollIntervals[i]); 
  }
  dragging = false;
  hasBeenGridded = false;
  fixGrid();
  fixMysetsGrid();
}

function styleRemovedGridProblem(e){
  previewProblemEnd(e);
  for(var i = 0; i < scrollIntervals.length; i++){
    clearInterval(scrollIntervals[i]); 
  }
  dragging = false;
  hasBeenGridded = false;
  fixGrid();
  fixMysetsGrid();
}

function getProblem(node){
  if(hasClassName(node, "problem")){
    return node;
  }
  else{
    return getProblem(node.parentNode);
  }
}

function getMouseXY(e) {
  var IE = document.all?true:false;
  var tempX, tempY;
  if (IE) { // grab the x-y pos.s if browser is IE
    tempX = event.clientX + document.body.scrollLeft;
    tempY = event.clientY + document.body.scrollTop;
  }
  else {  // grab the x-y pos.s if browser is NS
    tempX = e.pageX;
    tempY = e.pageY;
  }  
  if (tempX < 0){tempX = 0;}
  if (tempY < 0){tempY = 0;}  

  return [tempX, tempY];
}
    
function findPos(obj, until) {
  var curleft = curtop = 0;
  if (obj.offsetParent) {
     while (obj) {
      curleft += obj.offsetLeft;
      curtop += obj.offsetTop;
      if(hasClassName(obj,until))
        break;
      obj = obj.offsetParent
    }
  }
  return [curleft,curtop];
}

function findPos(obj) {
  var curleft = curtop = 0;
  if (obj.offsetParent) {
     while (obj) {
      curleft += obj.offsetLeft;
      curtop += obj.offsetTop;
      obj = obj.offsetParent
    }
  }
  return [curleft,curtop];
}

//from http://www.zachstronaut.com/posts/2009/02/17/animate-css-transforms-firefox-webkit.html
function getTransformProperty(element) {
    var properties = ['transform', 'WebkitTransform', 'MozTransform'];
    var p;
    while (p = properties.shift()) {
        if (typeof element.style[p] != 'undefined') {
            return p;
        }
    }
    return false;
}
