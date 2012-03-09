/*
*	Mimic (XML-RPC Client for JavaScript) v2.0.1
*	Copyright (C) 2005-2009 Carlos Eduardo Goncalves (cadu.goncalves@gmail.com)
*
*	Mimic is dual licensed under the MIT (http://opensource.org/licenses/mit-license.php) 
* 	and GPLv3 (http://opensource.org/licenses/gpl-3.0.html) licenses.
*/


/** 
 * XmlRpc
 */
 function XmlRpc(){
 	
 };
 
/** <p>XML-RPC document prolog.</p> */
XmlRpc.PROLOG = "<?xml version=\"1.0\"?>\n";

/** <p>XML-RPC methodCall node template.</p> */
XmlRpc.REQUEST = "<methodCall>\n<methodName>${METHOD}</methodName>\n<params>\n${DATA}</params>\n</methodCall>";

/** <p>XML-RPC param node template.</p> */
XmlRpc.PARAM = "<param>\n<value>\n${DATA}</value>\n</param>\n";

/** <p>XML-RPC array node template.</p> */
XmlRpc.ARRAY = "<array>\n<data>\n${DATA}</data>\n</array>\n";

/** <p>XML-RPC struct node template.</p> */
XmlRpc.STRUCT = "<struct>\n${DATA}</struct>\n";

/** <p>XML-RPC member node template.</p> */
XmlRpc.MEMBER = "<member>\n${DATA}</member>\n";

/** <p>XML-RPC name node template.</p> */
XmlRpc.NAME = "<name>${DATA}</name>\n";

/** <p>XML-RPC value node template.</p> */
XmlRpc.VALUE = "<value>\n${DATA}</value>\n";

/** <p>XML-RPC scalar node template (int, i4, double, string, boolean, base64, dateTime.iso8601).</p> */
XmlRpc.SCALAR = "<${TYPE}>${DATA}</${TYPE}>\n"; 

/**
* <p>Get the tag name used to represent a JavaScript
* object in the XMLRPC protocol.</p>
* @param data
*		A JavaScript object.
* @return
*		<code>String</code> with XMLRPC object type.
*/
XmlRpc.getDataTag = function(data) {
  try {
    var tag = typeof data;
    switch(tag.toLowerCase()) { 	  	  
      case "number":
        tag = (Math.round(data) == data) ? "int" : "double";  
	    break;   
	  case "object": 
        if(data.constructor == Base64)
	      tag = "base64";
	    else	  	
        if(data.constructor == String)
	      tag = "string";
	    else
	    if(data.constructor == Boolean)
	      tag = "boolean";
	    else
	    if(data.constructor == Array)
	      tag = "array";
	    else	  
	    if(data.constructor == Date)
	      tag = "dateTime.iso8601";
	    else	  
        if(data.constructor == Number)
	      tag = (Math.round(data) == data) ? "int" : "double";  
	    else	  
	      tag = "struct"; 
	    break;
    }
    return tag;
  } 
  catch(e) {
    Engine.reportException(null, e); 
  }    
}; 

/**
* <p>Get JavaScript object type represented by 
* XMLRPC protocol tag.<p>
* @param tag
*		A XMLRPC tag name.
* @return
*		A JavaScript object.
*/
XmlRpc.getTagData = function(tag) {
  var data = null;
  switch(tag) {
    case "struct":
      data = new Object(); 
	  break;
    case "array":
      data = new Array(); 
	  break;
    case "datetime.iso8601":
      data = new Date(); 
	  break;
    case "boolean":
      data = new Boolean(); 
	  break;
    case "int":
    case "i4":
    case "double":
      data = new Number(); 
	  break;	  
    case "string":
      data = new String(); 
	  break;	  
    case "base64":
      data = new Base64(); 
	  break;	    				
  }
  return data;
}; 

/** 
 * XmlRpcRequest
 * @param url
 * 		Server url.
 * @param method
 * 		Server side method do call.
 */
function XmlRpcRequest(url, method) {
  this.serviceUrl = url;
  this.methodName = method;
  this.params = [];
};

/**
 * <p> Add a new request parameter.</p>
 * @param data
 * 		New parameter value.
 */
XmlRpcRequest.prototype.addParam = function(data) {
  var type = typeof data;
  switch(type.toLowerCase()) {
    case "function":
	  return;
	case "object":
	  if(!data.constructor.name) return;
  }
  this.params.push(data);	
};

/**
 * <p>Clear all request parameters.</p>
 * @param data
 * 		New parameter value.
 */
XmlRpcRequest.prototype.clearParams = function() {
  this.params.splice(0, this.params.length);
};

/**
 * <p>Execute a synchronous XML-RPC request.</p>
 * @return
 *		XmlRpcResponse object.
 */
XmlRpcRequest.prototype.send = function() {
  var xml_params = "";
  for(var i = 0; i < this.params.length; i++)
    xml_params += XmlRpc.PARAM.replace("${DATA}", this.marshal(this.params[i]));	
  var xml_call = XmlRpc.REQUEST.replace("${METHOD}", this.methodName);	
  xml_call = XmlRpc.PROLOG + xml_call.replace("${DATA}", xml_params); 
  var xhr = Builder.buildXHR();
  xhr.open("POST", this.serviceUrl, false);   
  xhr.send(Builder.buildDOM(xml_call));
  return new XmlRpcResponse(xhr.responseXML);  	   	     
};

/**
 * <p>Marshal request parameters.</p>
 * @param data
 * 		A request parameter.
 * @return
 *		String with XML-RPC element notation.
 */
XmlRpcRequest.prototype.marshal = function(data) {
  var type = XmlRpc.getDataTag(data);
  var scalar_type = XmlRpc.SCALAR.replace(/\$\{TYPE\}/g, type);
  var xml = "";
  switch(type) {
    case "struct":
      var member = "";	  
      for(var i in data) {
        var value = "";
        value += XmlRpc.NAME.replace("${DATA}", i);
        value += XmlRpc.VALUE.replace("${DATA}", this.marshal(data[i]));
        member += XmlRpc.MEMBER.replace("${DATA}", value);		 
	  }
	  xml = XmlRpc.STRUCT.replace("${DATA}", member); 
	  break;	  
	case "array":
	  var value = "";
	  for(var i = 0; i < data.length; i++) {
        value += XmlRpc.VALUE.replace("${DATA}", this.marshal(data[i])); 
	  }
      xml = XmlRpc.ARRAY.replace("${DATA}", value); 
      break;
	case "dateTime.iso8601":     
	  xml = scalar_type.replace("${DATA}", data.toIso8601()); 
	  break;	
	case "boolean": 
	  xml = scalar_type.replace("${DATA}", (data == true) ? 1 : 0); 
	  break;
	case "base64":
	  xml = scalar_type.replace("${DATA}", data.encode()); 
	  break;	
    default : 
	  xml = scalar_type.replace("${DATA}", data); 
	  break;
  }
  return xml;
};

/** 
 * XmlRpcResponse
 * @param xml
 * 		Response XML document.
 */
function XmlRpcResponse(xml) {	
  this.xmlData = xml;
};

/** 
 * <p>Indicate if response is a fault.</p>
 * @return
 * 		Boolean flag indicating fault status.
 */
XmlRpcResponse.prototype.isFault = function() {
  return this.faultValue;
};

/** 
 * <p>Parse XML response to JavaScript.</p>
 * @return
 * 		JavaScript object parsed from XML-RPC document.
 */
XmlRpcResponse.prototype.parseXML = function() {    	
  this.faultValue = undefined;
  this.currentIsName = false;
  this.propertyName = "";
  this.params = [];  	
  for(var i = 0; i < this.xmlData.childNodes.length; i++)
      this.unmarshal(this.xmlData.childNodes[i], 0);
  return this.params[0];
};

/** 
 * <p>Unmarshal response parameters.</p>
 * @param node
 * 		Current document node under processing.
 * @param parent
 * 		Current node' parent node.
 */
XmlRpcResponse.prototype.unmarshal = function(node, parent) { 
  if(node.nodeType == 1) {
	var obj = null;
	var tag = node.tagName.toLowerCase();
    switch(tag) {  
      case "fault":
	    this.faultValue = true; 
		break;	  		
      case "name":
	    this.currentIsName = true;
		break;
	  default: 
	    obj = XmlRpc.getTagData(tag);
		break;
    }
	if(obj != null) {
      this.params.push(obj);	  
      if(tag == "struct" || tag == "array") {
		if(this.params.length > 1) {  
          switch(XmlRpc.getDataTag(this.params[parent])) {		  
            case "struct": 	
              this.params[parent][this.propertyName] = this.params[this.params.length - 1]; 
			  break;
            case "array": 	 
              this.params[parent].push(this.params[this.params.length - 1]); 
			  break;	 
          }		
		}
        var parent = this.params.length - 1;		  	   
	  }
	}
    for(var i = 0; i < node.childNodes.length; i++) {	
       this.unmarshal(node.childNodes[i], parent);
    } 
  }
  if( (node.nodeType == 3) && (/[^\t\n\r ]/.test(node.nodeValue)) ) {
    if(this.currentIsName == true) {
	  this.propertyName = node.nodeValue;
      this.currentIsName = false;
	}
	else {
      switch(XmlRpc.getDataTag(this.params[this.params.length - 1])) {	   
	    case "dateTime.iso8601":
	      this.params[this.params.length - 1] = Date.fromIso8601(node.nodeValue); 
		  break;
 	    case "boolean":
		  this.params[this.params.length - 1] = (node.nodeValue == "1") ? true : false; 
		  break;
 	    case "int":
 	    case "double":		
		  this.params[this.params.length - 1] = new Number(node.nodeValue); 
		  break;
 	    case "string":
		  this.params[this.params.length - 1] = new String(node.nodeValue); 
		  break;
 	    case "base64":
		  this.params[this.params.length - 1] = new Base64(node.nodeValue); 
		  break;
      }
	  if(this.params.length > 1) {  	  
        switch(XmlRpc.getDataTag(this.params[parent])) {		  
          case "struct": 	
            this.params[parent][this.propertyName] = this.params[this.params.length - 1]; 
			break;
          case "array": 	 
            this.params[parent].push(this.params[this.params.length - 1]); 
			break;	 
        }
	  }
	}
  }
};

/**
 * Builder
 */
function Builder(){
	
};

/**
 * <p>Build a valid XMLHttpRequest object</p>
 * @return 
 * 		XMLHttpRequest object.
 */
Builder.buildXHR = function() {
   return (typeof XMLHttpRequest != "undefined") ? new XMLHttpRequest() : new ActiveXObject("Microsoft.XMLHTTP"); 
};

/**
 * <p>Build a valid XML document from string markup.</p>
 * @param xml
 * 		Document markup.
 * @return
 * 		XMLDocument object. 
 */
Builder.buildDOM = function(xml) {	
  if(typeof DOMParser != "undefined") { 
  	var w3c_parser = new DOMParser();	
  	return w3c_parser.parseFromString(xml, "text/xml");
  }
  else {
  	var names = ["Microsoft.XMLDOM", "MSXML2.DOMDocument", "MSXML.DOMDocument"];
    for(var i = 0; i < names.length; i++) {
      try{
        var atx_parser = new ActiveXObject(names[i]);
        atx_parser.loadXML(xml);
        return atx_parser;
       } 
	   catch (e) {/* ignore */ }
    }
  }
  return null;
};

/** 
 * Date
 */
 
 /**
* <p>Convert a GMT date to ISO8601.</p>
* @return
*		<code>String</code> with an ISO8601 date.
*/
Date.prototype.toIso8601 = function() {
  year = this.getYear();
  if (year < 1900) year += 1900;   
  month = this.getMonth() + 1;
  if (month < 10) month = "0" + month;     
  day = this.getDate();
  if (day < 10) day = "0" + day;     
  time = this.toTimeString().substr(0,8);
  return year + month + day + "T" + time;
};

/**
* <p>Convert ISO8601 date to GMT.</p>
* @param value
*		ISO8601 date.
* @return
*		GMT date.
*/
Date.fromIso8601 = function(value) {
  year = value.substr(0,4); 
  month = value.substr(4,2);
  day = value.substr(6,2); 
  hour = value.substr(9,2); 
  minute = value.substr(12,2); 
  sec = value.substr(15,2);  
  return new Date(year, month - 1, day, hour, minute, sec, 0);
};

/** 
 * Base64
 */
function Base64(value) {	
  Base64.prototype.bytes = value;
};

/** <p>Base64 characters map.</p> */
Base64.CHAR_MAP = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

/**
* <p>Encode the object bytes using base64 algorithm.</p>
* @return
*		Encoded string.
*/
Base64.prototype.encode = function() {
  if(typeof btoa == "function")
    this.bytes = btoa(this.bytes);
  else {
    var _byte = new Array(), _char = new Array(), _result = new Array();
    var j = 0;
	for (var i = 0; i < this.bytes.length; i += 3) {
      _byte[0] = this.bytes.charCodeAt(i);
	  _byte[1] = this.bytes.charCodeAt(i + 1);
	  _byte[2] = this.bytes.charCodeAt(i + 2);
	  _char[0] = _byte[0] >> 2;
	  _char[1] = ((_byte[0] & 3) << 4) | (_byte[1] >> 4);
	  _char[2] = ((_byte[1] & 15) << 2) | (_byte[2] >> 6);
      _char[3] = _byte[2] & 63;		
	  if(isNaN(_byte[1]))
	    _char[2] = _char[3] = 64;
	  else 
	  if(isNaN(_byte[2]))
	    _char[3] = 64;
	  _result[j++] = Base64.CHAR_MAP.charAt(_char[0]) + Base64.CHAR_MAP.charAt(_char[1]) 
				   + Base64.CHAR_MAP.charAt(_char[2]) + Base64.CHAR_MAP.charAt(_char[3]);
	}	 
    this.bytes = _result.join("");
  }
  return this.bytes;
};

/**
* <p>Decode the object bytes using base64 algorithm.</p>
* @return
*		Decoded string.
*/
Base64.prototype.decode = function() {
  if(typeof atob == "function")	
    this.bytes = atob(this.bytes);
  else {
	var _byte = new Array(), _char = new Array(), _result = new Array();
	var j = 0;
	while ((this.bytes.length % 4) != 0)
	  this.bytes += "=";
    for (var i = 0; i < this.bytes.length; i += 4) {
	  _char[0] = Base64.CHAR_MAP.indexOf(this.bytes.charAt(i));
	  _char[1] = Base64.CHAR_MAP.indexOf(this.bytes.charAt(i + 1));
	  _char[2] = Base64.CHAR_MAP.indexOf(this.bytes.charAt(i + 2));
	  _char[3] = Base64.CHAR_MAP.indexOf(this.bytes.charAt(i + 3));
	  _byte[0] = (_char[0] << 2) | (_char[1] >> 4);
	  _byte[1] = ((_char[1] & 15) << 4) | (_char[2] >> 2);
	  _byte[2] = ((_char[2] & 3) << 6) | _char[3];
	  _result[j++] = String.fromCharCode(_byte[0]);
	  if(_char[2] != 64) 
	    _result[j++] = String.fromCharCode(_byte[1]);
	  if(_char[3] != 64) 
	    _result[j++] = String.fromCharCode(_byte[2]);	
	}
	this.bytes = _result.join("");
  }
  return this.bytes;
};