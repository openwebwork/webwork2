var $hxClasses = $hxClasses || {},$estr = function() { return js.Boot.__string_rec(this,''); };
function $extend(from, fields) {
	function inherit() {}; inherit.prototype = from; var proto = new inherit();
	for (var name in fields) proto[name] = fields[name];
	return proto;
}
var EReg = $hxClasses["EReg"] = function(r,opt) {
	opt = opt.split("u").join("");
	this.r = new RegExp(r,opt);
};
EReg.__name__ = ["EReg"];
EReg.prototype = {
	customReplace: function(s,f) {
		var buf = new StringBuf();
		while(true) {
			if(!this.match(s)) break;
			buf.b += Std.string(this.matchedLeft());
			buf.b += Std.string(f(this));
			s = this.matchedRight();
		}
		buf.b += Std.string(s);
		return buf.b;
	}
	,replace: function(s,by) {
		return s.replace(this.r,by);
	}
	,split: function(s) {
		var d = "#__delim__#";
		return s.replace(this.r,d).split(d);
	}
	,matchedPos: function() {
		if(this.r.m == null) throw "No string matched";
		return { pos : this.r.m.index, len : this.r.m[0].length};
	}
	,matchedRight: function() {
		if(this.r.m == null) throw "No string matched";
		var sz = this.r.m.index + this.r.m[0].length;
		return this.r.s.substr(sz,this.r.s.length - sz);
	}
	,matchedLeft: function() {
		if(this.r.m == null) throw "No string matched";
		return this.r.s.substr(0,this.r.m.index);
	}
	,matched: function(n) {
		return this.r.m != null && n >= 0 && n < this.r.m.length?this.r.m[n]:(function($this) {
			var $r;
			throw "EReg::matched";
			return $r;
		}(this));
	}
	,match: function(s) {
		if(this.r.global) this.r.lastIndex = 0;
		this.r.m = this.r.exec(s);
		this.r.s = s;
		return this.r.m != null;
	}
	,r: null
	,__class__: EReg
}
var Hash = $hxClasses["Hash"] = function() {
	this.h = { };
};
Hash.__name__ = ["Hash"];
Hash.prototype = {
	toString: function() {
		var s = new StringBuf();
		s.b += Std.string("{");
		var it = this.keys();
		while( it.hasNext() ) {
			var i = it.next();
			s.b += Std.string(i);
			s.b += Std.string(" => ");
			s.b += Std.string(Std.string(this.get(i)));
			if(it.hasNext()) s.b += Std.string(", ");
		}
		s.b += Std.string("}");
		return s.b;
	}
	,iterator: function() {
		return { ref : this.h, it : this.keys(), hasNext : function() {
			return this.it.hasNext();
		}, next : function() {
			var i = this.it.next();
			return this.ref["$" + i];
		}};
	}
	,keys: function() {
		var a = [];
		for( var key in this.h ) {
		if(this.h.hasOwnProperty(key)) a.push(key.substr(1));
		}
		return HxOverrides.iter(a);
	}
	,remove: function(key) {
		key = "$" + key;
		if(!this.h.hasOwnProperty(key)) return false;
		delete(this.h[key]);
		return true;
	}
	,exists: function(key) {
		return this.h.hasOwnProperty("$" + key);
	}
	,get: function(key) {
		return this.h["$" + key];
	}
	,set: function(key,value) {
		this.h["$" + key] = value;
	}
	,h: null
	,__class__: Hash
}
var HxOverrides = $hxClasses["HxOverrides"] = function() { }
HxOverrides.__name__ = ["HxOverrides"];
HxOverrides.dateStr = function(date) {
	var m = date.getMonth() + 1;
	var d = date.getDate();
	var h = date.getHours();
	var mi = date.getMinutes();
	var s = date.getSeconds();
	return date.getFullYear() + "-" + (m < 10?"0" + m:"" + m) + "-" + (d < 10?"0" + d:"" + d) + " " + (h < 10?"0" + h:"" + h) + ":" + (mi < 10?"0" + mi:"" + mi) + ":" + (s < 10?"0" + s:"" + s);
}
HxOverrides.strDate = function(s) {
	switch(s.length) {
	case 8:
		var k = s.split(":");
		var d = new Date();
		d.setTime(0);
		d.setUTCHours(k[0]);
		d.setUTCMinutes(k[1]);
		d.setUTCSeconds(k[2]);
		return d;
	case 10:
		var k = s.split("-");
		return new Date(k[0],k[1] - 1,k[2],0,0,0);
	case 19:
		var k = s.split(" ");
		var y = k[0].split("-");
		var t = k[1].split(":");
		return new Date(y[0],y[1] - 1,y[2],t[0],t[1],t[2]);
	default:
		throw "Invalid date format : " + s;
	}
}
HxOverrides.cca = function(s,index) {
	var x = s.charCodeAt(index);
	if(x != x) return undefined;
	return x;
}
HxOverrides.substr = function(s,pos,len) {
	if(pos != null && pos != 0 && len != null && len < 0) return "";
	if(len == null) len = s.length;
	if(pos < 0) {
		pos = s.length + pos;
		if(pos < 0) pos = 0;
	} else if(len < 0) len = s.length + len - pos;
	return s.substr(pos,len);
}
HxOverrides.remove = function(a,obj) {
	var i = 0;
	var l = a.length;
	while(i < l) {
		if(a[i] == obj) {
			a.splice(i,1);
			return true;
		}
		i++;
	}
	return false;
}
HxOverrides.iter = function(a) {
	return { cur : 0, arr : a, hasNext : function() {
		return this.cur < this.arr.length;
	}, next : function() {
		return this.arr[this.cur++];
	}};
}
var IntHash = $hxClasses["IntHash"] = function() {
	this.h = { };
};
IntHash.__name__ = ["IntHash"];
IntHash.prototype = {
	toString: function() {
		var s = new StringBuf();
		s.b += Std.string("{");
		var it = this.keys();
		while( it.hasNext() ) {
			var i = it.next();
			s.b += Std.string(i);
			s.b += Std.string(" => ");
			s.b += Std.string(Std.string(this.get(i)));
			if(it.hasNext()) s.b += Std.string(", ");
		}
		s.b += Std.string("}");
		return s.b;
	}
	,iterator: function() {
		return { ref : this.h, it : this.keys(), hasNext : function() {
			return this.it.hasNext();
		}, next : function() {
			var i = this.it.next();
			return this.ref[i];
		}};
	}
	,keys: function() {
		var a = [];
		for( var key in this.h ) {
		if(this.h.hasOwnProperty(key)) a.push(key | 0);
		}
		return HxOverrides.iter(a);
	}
	,remove: function(key) {
		if(!this.h.hasOwnProperty(key)) return false;
		delete(this.h[key]);
		return true;
	}
	,exists: function(key) {
		return this.h.hasOwnProperty(key);
	}
	,get: function(key) {
		return this.h[key];
	}
	,set: function(key,value) {
		this.h[key] = value;
	}
	,h: null
	,__class__: IntHash
}
var IntIter = $hxClasses["IntIter"] = function(min,max) {
	this.min = min;
	this.max = max;
};
IntIter.__name__ = ["IntIter"];
IntIter.prototype = {
	next: function() {
		return this.min++;
	}
	,hasNext: function() {
		return this.min < this.max;
	}
	,max: null
	,min: null
	,__class__: IntIter
}
var List = $hxClasses["List"] = function() {
	this.length = 0;
};
List.__name__ = ["List"];
List.prototype = {
	map: function(f) {
		var b = new List();
		var l = this.h;
		while(l != null) {
			var v = l[0];
			l = l[1];
			b.add(f(v));
		}
		return b;
	}
	,filter: function(f) {
		var l2 = new List();
		var l = this.h;
		while(l != null) {
			var v = l[0];
			l = l[1];
			if(f(v)) l2.add(v);
		}
		return l2;
	}
	,join: function(sep) {
		var s = new StringBuf();
		var first = true;
		var l = this.h;
		while(l != null) {
			if(first) first = false; else s.b += Std.string(sep);
			s.b += Std.string(l[0]);
			l = l[1];
		}
		return s.b;
	}
	,toString: function() {
		var s = new StringBuf();
		var first = true;
		var l = this.h;
		s.b += Std.string("{");
		while(l != null) {
			if(first) first = false; else s.b += Std.string(", ");
			s.b += Std.string(Std.string(l[0]));
			l = l[1];
		}
		s.b += Std.string("}");
		return s.b;
	}
	,iterator: function() {
		return { h : this.h, hasNext : function() {
			return this.h != null;
		}, next : function() {
			if(this.h == null) return null;
			var x = this.h[0];
			this.h = this.h[1];
			return x;
		}};
	}
	,remove: function(v) {
		var prev = null;
		var l = this.h;
		while(l != null) {
			if(l[0] == v) {
				if(prev == null) this.h = l[1]; else prev[1] = l[1];
				if(this.q == l) this.q = prev;
				this.length--;
				return true;
			}
			prev = l;
			l = l[1];
		}
		return false;
	}
	,clear: function() {
		this.h = null;
		this.q = null;
		this.length = 0;
	}
	,isEmpty: function() {
		return this.h == null;
	}
	,pop: function() {
		if(this.h == null) return null;
		var x = this.h[0];
		this.h = this.h[1];
		if(this.h == null) this.q = null;
		this.length--;
		return x;
	}
	,last: function() {
		return this.q == null?null:this.q[0];
	}
	,first: function() {
		return this.h == null?null:this.h[0];
	}
	,push: function(item) {
		var x = [item,this.h];
		this.h = x;
		if(this.q == null) this.q = x;
		this.length++;
	}
	,add: function(item) {
		var x = [item];
		if(this.h == null) this.h = x; else this.q[1] = x;
		this.q = x;
		this.length++;
	}
	,length: null
	,q: null
	,h: null
	,__class__: List
}
var Reflect = $hxClasses["Reflect"] = function() { }
Reflect.__name__ = ["Reflect"];
Reflect.hasField = function(o,field) {
	return Object.prototype.hasOwnProperty.call(o,field);
}
Reflect.field = function(o,field) {
	var v = null;
	try {
		v = o[field];
	} catch( e ) {
	}
	return v;
}
Reflect.setField = function(o,field,value) {
	o[field] = value;
}
Reflect.getProperty = function(o,field) {
	var tmp;
	return o == null?null:o.__properties__ && (tmp = o.__properties__["get_" + field])?o[tmp]():o[field];
}
Reflect.setProperty = function(o,field,value) {
	var tmp;
	if(o.__properties__ && (tmp = o.__properties__["set_" + field])) o[tmp](value); else o[field] = value;
}
Reflect.callMethod = function(o,func,args) {
	return func.apply(o,args);
}
Reflect.fields = function(o) {
	var a = [];
	if(o != null) {
		var hasOwnProperty = Object.prototype.hasOwnProperty;
		for( var f in o ) {
		if(hasOwnProperty.call(o,f)) a.push(f);
		}
	}
	return a;
}
Reflect.isFunction = function(f) {
	return typeof(f) == "function" && !(f.__name__ || f.__ename__);
}
Reflect.compare = function(a,b) {
	return a == b?0:a > b?1:-1;
}
Reflect.compareMethods = function(f1,f2) {
	if(f1 == f2) return true;
	if(!Reflect.isFunction(f1) || !Reflect.isFunction(f2)) return false;
	return f1.scope == f2.scope && f1.method == f2.method && f1.method != null;
}
Reflect.isObject = function(v) {
	if(v == null) return false;
	var t = typeof(v);
	return t == "string" || t == "object" && !v.__enum__ || t == "function" && (v.__name__ || v.__ename__);
}
Reflect.deleteField = function(o,f) {
	if(!Reflect.hasField(o,f)) return false;
	delete(o[f]);
	return true;
}
Reflect.copy = function(o) {
	var o2 = { };
	var _g = 0, _g1 = Reflect.fields(o);
	while(_g < _g1.length) {
		var f = _g1[_g];
		++_g;
		o2[f] = Reflect.field(o,f);
	}
	return o2;
}
Reflect.makeVarArgs = function(f) {
	return function() {
		var a = Array.prototype.slice.call(arguments);
		return f(a);
	};
}
var Std = $hxClasses["Std"] = function() { }
Std.__name__ = ["Std"];
Std["is"] = function(v,t) {
	return js.Boot.__instanceof(v,t);
}
Std.string = function(s) {
	return js.Boot.__string_rec(s,"");
}
Std["int"] = function(x) {
	return x | 0;
}
Std.parseInt = function(x) {
	var v = parseInt(x,10);
	if(v == 0 && (HxOverrides.cca(x,1) == 120 || HxOverrides.cca(x,1) == 88)) v = parseInt(x);
	if(isNaN(v)) return null;
	return v;
}
Std.parseFloat = function(x) {
	return parseFloat(x);
}
Std.random = function(x) {
	return Math.floor(Math.random() * x);
}
var StringBuf = $hxClasses["StringBuf"] = function() {
	this.b = "";
};
StringBuf.__name__ = ["StringBuf"];
StringBuf.prototype = {
	toString: function() {
		return this.b;
	}
	,addSub: function(s,pos,len) {
		this.b += HxOverrides.substr(s,pos,len);
	}
	,addChar: function(c) {
		this.b += String.fromCharCode(c);
	}
	,add: function(x) {
		this.b += Std.string(x);
	}
	,b: null
	,__class__: StringBuf
}
var StringTools = $hxClasses["StringTools"] = function() { }
StringTools.__name__ = ["StringTools"];
StringTools.urlEncode = function(s) {
	return encodeURIComponent(s);
}
StringTools.urlDecode = function(s) {
	return decodeURIComponent(s.split("+").join(" "));
}
StringTools.htmlEscape = function(s) {
	return s.split("&").join("&amp;").split("<").join("&lt;").split(">").join("&gt;");
}
StringTools.htmlUnescape = function(s) {
	return s.split("&gt;").join(">").split("&lt;").join("<").split("&amp;").join("&");
}
StringTools.startsWith = function(s,start) {
	return s.length >= start.length && HxOverrides.substr(s,0,start.length) == start;
}
StringTools.endsWith = function(s,end) {
	var elen = end.length;
	var slen = s.length;
	return slen >= elen && HxOverrides.substr(s,slen - elen,elen) == end;
}
StringTools.isSpace = function(s,pos) {
	var c = HxOverrides.cca(s,pos);
	return c >= 9 && c <= 13 || c == 32;
}
StringTools.ltrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,r)) r++;
	if(r > 0) return HxOverrides.substr(s,r,l - r); else return s;
}
StringTools.rtrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,l - r - 1)) r++;
	if(r > 0) return HxOverrides.substr(s,0,l - r); else return s;
}
StringTools.trim = function(s) {
	return StringTools.ltrim(StringTools.rtrim(s));
}
StringTools.rpad = function(s,c,l) {
	var sl = s.length;
	var cl = c.length;
	while(sl < l) if(l - sl < cl) {
		s += HxOverrides.substr(c,0,l - sl);
		sl = l;
	} else {
		s += c;
		sl += cl;
	}
	return s;
}
StringTools.lpad = function(s,c,l) {
	var ns = "";
	var sl = s.length;
	if(sl >= l) return s;
	var cl = c.length;
	while(sl < l) if(l - sl < cl) {
		ns += HxOverrides.substr(c,0,l - sl);
		sl = l;
	} else {
		ns += c;
		sl += cl;
	}
	return ns + s;
}
StringTools.replace = function(s,sub,by) {
	return s.split(sub).join(by);
}
StringTools.hex = function(n,digits) {
	var s = "";
	var hexChars = "0123456789ABCDEF";
	do {
		s = hexChars.charAt(n & 15) + s;
		n >>>= 4;
	} while(n > 0);
	if(digits != null) while(s.length < digits) s = "0" + s;
	return s;
}
StringTools.fastCodeAt = function(s,index) {
	return s.charCodeAt(index);
}
StringTools.isEOF = function(c) {
	return c != c;
}
var ValueType = $hxClasses["ValueType"] = { __ename__ : ["ValueType"], __constructs__ : ["TNull","TInt","TFloat","TBool","TObject","TFunction","TClass","TEnum","TUnknown"] }
ValueType.TNull = ["TNull",0];
ValueType.TNull.toString = $estr;
ValueType.TNull.__enum__ = ValueType;
ValueType.TInt = ["TInt",1];
ValueType.TInt.toString = $estr;
ValueType.TInt.__enum__ = ValueType;
ValueType.TFloat = ["TFloat",2];
ValueType.TFloat.toString = $estr;
ValueType.TFloat.__enum__ = ValueType;
ValueType.TBool = ["TBool",3];
ValueType.TBool.toString = $estr;
ValueType.TBool.__enum__ = ValueType;
ValueType.TObject = ["TObject",4];
ValueType.TObject.toString = $estr;
ValueType.TObject.__enum__ = ValueType;
ValueType.TFunction = ["TFunction",5];
ValueType.TFunction.toString = $estr;
ValueType.TFunction.__enum__ = ValueType;
ValueType.TClass = function(c) { var $x = ["TClass",6,c]; $x.__enum__ = ValueType; $x.toString = $estr; return $x; }
ValueType.TEnum = function(e) { var $x = ["TEnum",7,e]; $x.__enum__ = ValueType; $x.toString = $estr; return $x; }
ValueType.TUnknown = ["TUnknown",8];
ValueType.TUnknown.toString = $estr;
ValueType.TUnknown.__enum__ = ValueType;
var Type = $hxClasses["Type"] = function() { }
Type.__name__ = ["Type"];
Type.getClass = function(o) {
	if(o == null) return null;
	return o.__class__;
}
Type.getEnum = function(o) {
	if(o == null) return null;
	return o.__enum__;
}
Type.getSuperClass = function(c) {
	return c.__super__;
}
Type.getClassName = function(c) {
	var a = c.__name__;
	return a.join(".");
}
Type.getEnumName = function(e) {
	var a = e.__ename__;
	return a.join(".");
}
Type.resolveClass = function(name) {
	var cl = $hxClasses[name];
	if(cl == null || !cl.__name__) return null;
	return cl;
}
Type.resolveEnum = function(name) {
	var e = $hxClasses[name];
	if(e == null || !e.__ename__) return null;
	return e;
}
Type.createInstance = function(cl,args) {
	switch(args.length) {
	case 0:
		return new cl();
	case 1:
		return new cl(args[0]);
	case 2:
		return new cl(args[0],args[1]);
	case 3:
		return new cl(args[0],args[1],args[2]);
	case 4:
		return new cl(args[0],args[1],args[2],args[3]);
	case 5:
		return new cl(args[0],args[1],args[2],args[3],args[4]);
	case 6:
		return new cl(args[0],args[1],args[2],args[3],args[4],args[5]);
	case 7:
		return new cl(args[0],args[1],args[2],args[3],args[4],args[5],args[6]);
	case 8:
		return new cl(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7]);
	default:
		throw "Too many arguments";
	}
	return null;
}
Type.createEmptyInstance = function(cl) {
	function empty() {}; empty.prototype = cl.prototype;
	return new empty();
}
Type.createEnum = function(e,constr,params) {
	var f = Reflect.field(e,constr);
	if(f == null) throw "No such constructor " + constr;
	if(Reflect.isFunction(f)) {
		if(params == null) throw "Constructor " + constr + " need parameters";
		return f.apply(e,params);
	}
	if(params != null && params.length != 0) throw "Constructor " + constr + " does not need parameters";
	return f;
}
Type.createEnumIndex = function(e,index,params) {
	var c = e.__constructs__[index];
	if(c == null) throw index + " is not a valid enum constructor index";
	return Type.createEnum(e,c,params);
}
Type.getInstanceFields = function(c) {
	var a = [];
	for(var i in c.prototype) a.push(i);
	HxOverrides.remove(a,"__class__");
	HxOverrides.remove(a,"__properties__");
	return a;
}
Type.getClassFields = function(c) {
	var a = Reflect.fields(c);
	HxOverrides.remove(a,"__name__");
	HxOverrides.remove(a,"__interfaces__");
	HxOverrides.remove(a,"__properties__");
	HxOverrides.remove(a,"__super__");
	HxOverrides.remove(a,"prototype");
	return a;
}
Type.getEnumConstructs = function(e) {
	var a = e.__constructs__;
	return a.slice();
}
Type["typeof"] = function(v) {
	switch(typeof(v)) {
	case "boolean":
		return ValueType.TBool;
	case "string":
		return ValueType.TClass(String);
	case "number":
		if(Math.ceil(v) == v % 2147483648.0) return ValueType.TInt;
		return ValueType.TFloat;
	case "object":
		if(v == null) return ValueType.TNull;
		var e = v.__enum__;
		if(e != null) return ValueType.TEnum(e);
		var c = v.__class__;
		if(c != null) return ValueType.TClass(c);
		return ValueType.TObject;
	case "function":
		if(v.__name__ || v.__ename__) return ValueType.TObject;
		return ValueType.TFunction;
	case "undefined":
		return ValueType.TNull;
	default:
		return ValueType.TUnknown;
	}
}
Type.enumEq = function(a,b) {
	if(a == b) return true;
	try {
		if(a[0] != b[0]) return false;
		var _g1 = 2, _g = a.length;
		while(_g1 < _g) {
			var i = _g1++;
			if(!Type.enumEq(a[i],b[i])) return false;
		}
		var e = a.__enum__;
		if(e != b.__enum__ || e == null) return false;
	} catch( e ) {
		return false;
	}
	return true;
}
Type.enumConstructor = function(e) {
	return e[0];
}
Type.enumParameters = function(e) {
	return e.slice(2);
}
Type.enumIndex = function(e) {
	return e[1];
}
Type.allEnums = function(e) {
	var all = [];
	var cst = e.__constructs__;
	var _g = 0;
	while(_g < cst.length) {
		var c = cst[_g];
		++_g;
		var v = Reflect.field(e,c);
		if(!Reflect.isFunction(v)) all.push(v);
	}
	return all;
}
var Xml = $hxClasses["Xml"] = function() {
};
Xml.__name__ = ["Xml"];
Xml.Element = null;
Xml.PCData = null;
Xml.CData = null;
Xml.Comment = null;
Xml.DocType = null;
Xml.Prolog = null;
Xml.Document = null;
Xml.parse = function(str) {
	return haxe.xml.Parser.parse(str);
}
Xml.createElement = function(name) {
	var r = new Xml();
	r.nodeType = Xml.Element;
	r._children = new Array();
	r._attributes = new Hash();
	r.setNodeName(name);
	return r;
}
Xml.createPCData = function(data) {
	var r = new Xml();
	r.nodeType = Xml.PCData;
	r.setNodeValue(data);
	return r;
}
Xml.createCData = function(data) {
	var r = new Xml();
	r.nodeType = Xml.CData;
	r.setNodeValue(data);
	return r;
}
Xml.createComment = function(data) {
	var r = new Xml();
	r.nodeType = Xml.Comment;
	r.setNodeValue(data);
	return r;
}
Xml.createDocType = function(data) {
	var r = new Xml();
	r.nodeType = Xml.DocType;
	r.setNodeValue(data);
	return r;
}
Xml.createProlog = function(data) {
	var r = new Xml();
	r.nodeType = Xml.Prolog;
	r.setNodeValue(data);
	return r;
}
Xml.createDocument = function() {
	var r = new Xml();
	r.nodeType = Xml.Document;
	r._children = new Array();
	return r;
}
Xml.prototype = {
	toString: function() {
		if(this.nodeType == Xml.PCData) return this._nodeValue;
		if(this.nodeType == Xml.CData) return "<![CDATA[" + this._nodeValue + "]]>";
		if(this.nodeType == Xml.Comment) return "<!--" + this._nodeValue + "-->";
		if(this.nodeType == Xml.DocType) return "<!DOCTYPE " + this._nodeValue + ">";
		if(this.nodeType == Xml.Prolog) return "<?" + this._nodeValue + "?>";
		var s = new StringBuf();
		if(this.nodeType == Xml.Element) {
			s.b += Std.string("<");
			s.b += Std.string(this._nodeName);
			var $it0 = this._attributes.keys();
			while( $it0.hasNext() ) {
				var k = $it0.next();
				s.b += Std.string(" ");
				s.b += Std.string(k);
				s.b += Std.string("=\"");
				s.b += Std.string(this._attributes.get(k));
				s.b += Std.string("\"");
			}
			if(this._children.length == 0) {
				s.b += Std.string("/>");
				return s.b;
			}
			s.b += Std.string(">");
		}
		var $it1 = this.iterator();
		while( $it1.hasNext() ) {
			var x = $it1.next();
			s.b += Std.string(x.toString());
		}
		if(this.nodeType == Xml.Element) {
			s.b += Std.string("</");
			s.b += Std.string(this._nodeName);
			s.b += Std.string(">");
		}
		return s.b;
	}
	,insertChild: function(x,pos) {
		if(this._children == null) throw "bad nodetype";
		if(x._parent != null) HxOverrides.remove(x._parent._children,x);
		x._parent = this;
		this._children.splice(pos,0,x);
	}
	,removeChild: function(x) {
		if(this._children == null) throw "bad nodetype";
		var b = HxOverrides.remove(this._children,x);
		if(b) x._parent = null;
		return b;
	}
	,addChild: function(x) {
		if(this._children == null) throw "bad nodetype";
		if(x._parent != null) HxOverrides.remove(x._parent._children,x);
		x._parent = this;
		this._children.push(x);
	}
	,firstElement: function() {
		if(this._children == null) throw "bad nodetype";
		var cur = 0;
		var l = this._children.length;
		while(cur < l) {
			var n = this._children[cur];
			if(n.nodeType == Xml.Element) return n;
			cur++;
		}
		return null;
	}
	,firstChild: function() {
		if(this._children == null) throw "bad nodetype";
		return this._children[0];
	}
	,elementsNamed: function(name) {
		if(this._children == null) throw "bad nodetype";
		return { cur : 0, x : this._children, hasNext : function() {
			var k = this.cur;
			var l = this.x.length;
			while(k < l) {
				var n = this.x[k];
				if(n.nodeType == Xml.Element && n._nodeName == name) break;
				k++;
			}
			this.cur = k;
			return k < l;
		}, next : function() {
			var k = this.cur;
			var l = this.x.length;
			while(k < l) {
				var n = this.x[k];
				k++;
				if(n.nodeType == Xml.Element && n._nodeName == name) {
					this.cur = k;
					return n;
				}
			}
			return null;
		}};
	}
	,elements: function() {
		if(this._children == null) throw "bad nodetype";
		return { cur : 0, x : this._children, hasNext : function() {
			var k = this.cur;
			var l = this.x.length;
			while(k < l) {
				if(this.x[k].nodeType == Xml.Element) break;
				k += 1;
			}
			this.cur = k;
			return k < l;
		}, next : function() {
			var k = this.cur;
			var l = this.x.length;
			while(k < l) {
				var n = this.x[k];
				k += 1;
				if(n.nodeType == Xml.Element) {
					this.cur = k;
					return n;
				}
			}
			return null;
		}};
	}
	,iterator: function() {
		if(this._children == null) throw "bad nodetype";
		return { cur : 0, x : this._children, hasNext : function() {
			return this.cur < this.x.length;
		}, next : function() {
			return this.x[this.cur++];
		}};
	}
	,attributes: function() {
		if(this.nodeType != Xml.Element) throw "bad nodeType";
		return this._attributes.keys();
	}
	,exists: function(att) {
		if(this.nodeType != Xml.Element) throw "bad nodeType";
		return this._attributes.exists(att);
	}
	,remove: function(att) {
		if(this.nodeType != Xml.Element) throw "bad nodeType";
		this._attributes.remove(att);
	}
	,set: function(att,value) {
		if(this.nodeType != Xml.Element) throw "bad nodeType";
		this._attributes.set(att,value);
	}
	,get: function(att) {
		if(this.nodeType != Xml.Element) throw "bad nodeType";
		return this._attributes.get(att);
	}
	,getParent: function() {
		return this._parent;
	}
	,setNodeValue: function(v) {
		if(this.nodeType == Xml.Element || this.nodeType == Xml.Document) throw "bad nodeType";
		return this._nodeValue = v;
	}
	,getNodeValue: function() {
		if(this.nodeType == Xml.Element || this.nodeType == Xml.Document) throw "bad nodeType";
		return this._nodeValue;
	}
	,setNodeName: function(n) {
		if(this.nodeType != Xml.Element) throw "bad nodeType";
		return this._nodeName = n;
	}
	,getNodeName: function() {
		if(this.nodeType != Xml.Element) throw "bad nodeType";
		return this._nodeName;
	}
	,_parent: null
	,_children: null
	,_attributes: null
	,_nodeValue: null
	,_nodeName: null
	,parent: null
	,nodeValue: null
	,nodeName: null
	,nodeType: null
	,__class__: Xml
	,__properties__: {set_nodeName:"setNodeName",get_nodeName:"getNodeName",set_nodeValue:"setNodeValue",get_nodeValue:"getNodeValue",get_parent:"getParent"}
}
var com = com || {}
if(!com.wiris) com.wiris = {}
if(!com.wiris.chartparsing) com.wiris.chartparsing = {}
com.wiris.chartparsing.AmbiguitiesHandler = $hxClasses["com.wiris.chartparsing.AmbiguitiesHandler"] = function() { }
com.wiris.chartparsing.AmbiguitiesHandler.__name__ = ["com","wiris","chartparsing","AmbiguitiesHandler"];
com.wiris.chartparsing.AmbiguitiesHandler.prototype = {
	disambiguate: null
	,__class__: com.wiris.chartparsing.AmbiguitiesHandler
}
com.wiris.chartparsing.Category = $hxClasses["com.wiris.chartparsing.Category"] = function(name) {
	this.name = name;
	this.index = -1;
};
com.wiris.chartparsing.Category.__name__ = ["com","wiris","chartparsing","Category"];
com.wiris.chartparsing.Category.prototype = {
	toString: function() {
		return this.name;
	}
	,equals: function(o) {
		if(js.Boot.__instanceof(o,String)) return this.name == o;
		return o == this;
	}
	,lowlink: null
	,index: null
	,name: null
	,id: null
	,__class__: com.wiris.chartparsing.Category
}
com.wiris.chartparsing.CategoryChooser = $hxClasses["com.wiris.chartparsing.CategoryChooser"] = function() {
	this.singleCat = new Array();
	this.pairCat = new Array();
	this.ternCat = new Array();
};
com.wiris.chartparsing.CategoryChooser.__name__ = ["com","wiris","chartparsing","CategoryChooser"];
com.wiris.chartparsing.CategoryChooser.isFloating = function(str) {
	if(com.wiris.system.TypeTools.isFloating(str)) return true; else return com.wiris.chartparsing.CategoryChooser.isOmegaDouble(str);
}
com.wiris.chartparsing.CategoryChooser.isInteger = function(str) {
	var i;
	var _g1 = 0, _g = str.length;
	while(_g1 < _g) {
		var i1 = _g1++;
		var c = HxOverrides.cca(str,i1);
		if((c < 48 || c > 57) && (c < 1632 || c > 1641) && (c < 1776 || c > 1785)) return false;
	}
	return true;
}
com.wiris.chartparsing.CategoryChooser.isOmegaDouble = function(str) {
	return com.wiris.chartparsing.CategoryChooser.e1.match(str);
}
com.wiris.chartparsing.CategoryChooser.prototype = {
	getCategories: function(t,g) {
		this.init(g);
		var category = -1;
		var isInt = false;
		var isFloat = false;
		if(t == "variable" || t == "integer" || t == "floating") category = this.variable; else category = g.getTerminalByValue(t);
		if(js.Boot.__instanceof(t,String)) {
			var str = t;
			isInt = com.wiris.chartparsing.CategoryChooser.isInteger(str);
			isFloat = com.wiris.chartparsing.CategoryChooser.isFloating(str);
		}
		if(js.Boot.__instanceof(t,Float)) isFloat = true;
		if(js.Boot.__instanceof(t,Int)) isInt = true;
		if(isInt && this.integer != -1) {
			if(category < 0) category = this.integer; else return this.pairCategory(this.integer,category);
		} else if(isFloat && this.floating != -1) {
			if(category < 0) category = this.floating; else return this.pairCategory(this.floating,category);
		} else if(category < 0 && js.Boot.__instanceof(t,String)) category = this.variable;
		if(category >= 0) return this.singleCategory(category);
		return this.nullCategory();
	}
	,init: function(g) {
		if(this.grammar == null || this.grammar != g) {
			this.variable = g.getCategoryByName("variable");
			this.integer = g.getCategoryByName("integer");
			this.floating = g.getCategoryByName("floating");
			this.empty = g.getCategoryByName("empty");
			this.any = g.getCategoryByName("any");
			this.grammar = g;
		}
	}
	,nullCategory: function() {
		if(this.any != -1) {
			this.singleCat[0] = this.any;
			return this.singleCat;
		}
		return null;
	}
	,singleCategory: function(cat1) {
		if(this.any != -1) {
			this.pairCat[0] = cat1;
			this.pairCat[1] = this.any;
			return this.pairCat;
		}
		this.singleCat[0] = cat1;
		return this.singleCat;
	}
	,pairCategory: function(cat1,cat2) {
		if(this.any != -1) {
			this.ternCat[0] = cat1;
			this.ternCat[1] = cat2;
			this.ternCat[2] = this.any;
			return this.ternCat;
		}
		this.pairCat[0] = cat1;
		this.pairCat[1] = cat2;
		return this.pairCat;
	}
	,ternCat: null
	,pairCat: null
	,singleCat: null
	,any: null
	,empty: null
	,floating: null
	,integer: null
	,variable: null
	,grammar: null
	,__class__: com.wiris.chartparsing.CategoryChooser
}
com.wiris.chartparsing.Chart = $hxClasses["com.wiris.chartparsing.Chart"] = function(g) {
	this.grammar = g;
};
com.wiris.chartparsing.Chart.__name__ = ["com","wiris","chartparsing","Chart"];
com.wiris.chartparsing.Chart.integer2String = function(n,m,pre) {
	var sn = "" + n;
	var sm = "" + m;
	if(pre) while(sn.length < sm.length) sn = " " + sn; else while(sn.length < sm.length) sn += " ";
	return sn;
}
com.wiris.chartparsing.Chart.toString2 = function(g,edge,max) {
	var sb = new StringBuf();
	sb.b += Std.string(com.wiris.chartparsing.Chart.integer2String(edge.id,max,true) + ": ");
	sb.b += Std.string("(");
	sb.b += Std.string(edge.start);
	sb.b += Std.string(",");
	sb.b += Std.string(edge.stop);
	sb.b += Std.string(") ");
	var rule = "";
	if(edge.rule < com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) rule = "R" + com.wiris.chartparsing.Chart.integer2String(edge.rule,g.rules.length,false); else rule = "T" + com.wiris.chartparsing.Chart.integer2String(edge.rule - com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID,g.rules.length,false);
	sb.b += Std.string("[rule=" + rule + ",dot=" + edge.dot + "] ");
	if(edge.rule >= com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) {
		var str;
		str = g.ruleToString(edge.rule);
		sb.b += Std.string(str);
	} else {
		var r;
		var i;
		r = g.rules[edge.rule];
		sb.b += Std.string(g.ruleToString(r.lhs));
		sb.b += Std.string(" -> ");
		var _g1 = 0, _g = r.rhs.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			if(i1 > 0) sb.b += Std.string(" ");
			if(i1 == edge.dot) sb.b += Std.string(". ");
			sb.b += Std.string(g.ruleToString(r.rhs[i1]));
		}
	}
	sb.b += Std.string(" [prec=" + edge.precedence + ",id=" + edge.rule + "]");
	sb.b += Std.string(" (" + edge.start0 + "," + edge.end0 + "," + edge.edge0 + "|");
	sb.b += Std.string(edge.start1 + "," + edge.end1 + "," + edge.edge1 + ")");
	return sb.b;
}
com.wiris.chartparsing.Chart.staticShow = function(g,edge) {
	com.wiris.chartparsing.Logger.finest(com.wiris.chartparsing.Chart.toString2(g,edge,0));
}
com.wiris.chartparsing.Chart.prototype = {
	getUncompleteWithGap: function(i) {
		var s = new com.wiris.chartparsing.EdgeArray();
		var j = 0;
		while(j <= i) {
			var ea = this.getUncomplete(j,i);
			if(ea != null) s.addAll(ea);
			j++;
		}
		return s;
	}
	,findEdgeWithCategory: function(x0,x1,cat) {
		var i;
		var ea;
		var e;
		ea = this.getComplete(x0,x1);
		if(ea == null) return null;
		var _g1 = 0, _g = ea.n;
		while(_g1 < _g) {
			var i1 = _g1++;
			e = ea.array[i1];
			if(e.rule < com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) {
				var rule = this.grammar.rules[e.rule];
				if(rule.lhs == cat) return e;
			} else if(e.rule == cat) return e;
		}
		return null;
	}
	,getExpectedTerminals: function() {
		throw "This method is abstract. It must be implemented.";
		return null;
	}
	,getLastError: function() {
		throw "This method is abstract. It must be implemented.";
		return null;
	}
	,getNEdges: function() {
		throw "This method is abstract. It must be implemented.";
		return 0;
	}
	,getNVertices: function() {
		throw "This method is abstract. It must be implemented.";
		return 0;
	}
	,showCount: function() {
		throw "This method is abstract. It must be implemented.";
	}
	,show: function() {
		throw "This method is abstract. It must be implemented.";
	}
	,getEdge: function(id) {
		throw "This method is abstract. It must be implemented.";
		return null;
	}
	,getUncomplete: function(i,j) {
		throw "This method is abstract. It must be implemented.";
		return null;
	}
	,getComplete: function(i,j) {
		throw "This method is abstract. It must be implemented.";
		return null;
	}
	,grammar: null
	,__class__: com.wiris.chartparsing.Chart
}
com.wiris.chartparsing.Chart2 = $hxClasses["com.wiris.chartparsing.Chart2"] = function(g,n) {
	com.wiris.chartparsing.Chart.call(this,g);
	this.edges = new Array();
	this.setEdgeLimit(com.wiris.chartparsing.Chart2.DEFAULT_EDGE_LIMIT);
	n++;
	this.n_vertices = n;
	this.posTerminal = g.categories.length;
	this.sn = new Array();
	var i;
	var _g1 = 0, _g = this.n_vertices;
	while(_g1 < _g) {
		var i1 = _g1++;
		this.sn[i1] = new Array();
		var j;
		var _g3 = 0, _g2 = this.posTerminal;
		while(_g3 < _g2) {
			var j1 = _g3++;
			this.sn[i1][j1] = null;
		}
	}
	this.ts = new Array();
	var _g1 = 0, _g = this.n_vertices;
	while(_g1 < _g) {
		var i1 = _g1++;
		this.ts[i1] = new Array();
	}
	if(com.wiris.chartparsing.Chart2.OPTIMIZATION1) {
		this.tExpected = 0;
		this.expected = new Array();
	}
};
com.wiris.chartparsing.Chart2.__name__ = ["com","wiris","chartparsing","Chart2"];
com.wiris.chartparsing.Chart2.__super__ = com.wiris.chartparsing.Chart;
com.wiris.chartparsing.Chart2.prototype = $extend(com.wiris.chartparsing.Chart.prototype,{
	getNEdges: function() {
		return this.edges.length;
	}
	,setEdgeLimit: function(edgeLimit) {
		this.edgeLimit = edgeLimit;
	}
	,getExpectedTerminals: function() {
		var vsymbols = new com.wiris.chartparsing.VectorSet();
		if(com.wiris.chartparsing.Chart2.OPTIMIZATION1) {
			var i;
			var _g1 = 0, _g = this.expected.length;
			while(_g1 < _g) {
				var i1 = _g1++;
				var t = this.grammar.terminal[this.expected[i1] - com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID];
				if(js.Boot.__instanceof(t.value,String)) vsymbols.push("'" + Std.string(t) + "'"); else vsymbols.push("\"" + Std.string(t) + "\"");
			}
		}
		return vsymbols;
	}
	,expectedTerminals: function(i,B) {
		if(com.wiris.chartparsing.Chart2.OPTIMIZATION1) {
			if(i > this.tExpected) {
				com.wiris.util.type.Arrays.clear(this.expected);
				this.expected.push(B);
				this.tExpected = i;
			} else if(i == this.tExpected) {
				if(!com.wiris.system.ArrayEx.contains(this.expected,B)) this.expected.push(B);
			}
		}
	}
	,getLastError: function() {
		return this.lastError;
	}
	,findTerminal: function(i,terminal) {
		var ts0 = this.ts[i];
		var n = ts0.length;
		var j;
		var _g = 0;
		while(_g < n) {
			var j1 = _g++;
			if(ts0[j1] == terminal) return j1;
		}
		return -1;
	}
	,getNVertices: function() {
		return this.n_vertices;
	}
	,count: function(complete) {
		var i;
		var j;
		var n = 0;
		var _g1 = 0, _g = this.n_vertices;
		while(_g1 < _g) {
			var i1 = _g1++;
			var sn0 = this.sn[i1];
			var _g3 = 0, _g2 = sn0.length;
			while(_g3 < _g2) {
				var j1 = _g3++;
				var sn1 = sn0[j1];
				if(sn1 != null) {
					if(complete) n += sn1.complete.n; else n += sn1.uncomplete.n;
				}
			}
		}
		return n;
	}
	,toStringImpl: function(g,complete) {
		var sb = new StringBuf();
		var i;
		var j;
		var k;
		var ea;
		var _g1 = 0, _g = this.n_vertices;
		while(_g1 < _g) {
			var i1 = _g1++;
			var sn0 = this.sn[i1];
			var _g3 = 0, _g2 = sn0.length;
			while(_g3 < _g2) {
				var j1 = _g3++;
				var sn1 = sn0[j1];
				if(sn1 != null) {
					if(complete) ea = sn1.complete; else ea = sn1.uncomplete;
					if(ea != null) {
						var _g5 = 0, _g4 = ea.n;
						while(_g5 < _g4) {
							var k1 = _g5++;
							var e = ea.array[k1];
							sb.b += Std.string(com.wiris.chartparsing.Chart.toString2(g,e,this.edges.length));
							sb.b += Std.string("\n");
						}
					}
				}
			}
		}
		return sb.b;
	}
	,showCount: function() {
		com.wiris.chartparsing.Logger.finestln("-----------------");
		com.wiris.chartparsing.Logger.finestln("Complete: " + this.count(true));
		com.wiris.chartparsing.Logger.finestln("Uncomplete: " + this.count(false));
	}
	,toString: function() {
		var sb = new StringBuf();
		sb.b += Std.string("-----------------\n");
		sb.b += Std.string("Complete\n");
		sb.b += Std.string(this.toStringImpl(this.grammar,true));
		sb.b += Std.string("Uncomplete\n");
		sb.b += Std.string(this.toStringImpl(this.grammar,false));
		return sb.b;
	}
	,show: function() {
		com.wiris.chartparsing.Logger.finestln(this.toString());
	}
	,addTerminalImpl2: function(ts,i,terminal) {
		var n = ts[i].length;
		var ts0 = new Array();
		com.wiris.system.System.arraycopy(ts[i],0,ts0,0,n);
		ts[i] = ts0;
		ts[i][n] = terminal;
		return n;
	}
	,addTerminalImpl: function(i,terminal) {
		var m = this.addTerminalImpl2(this.ts,i,terminal);
		var n = this.sn[i].length;
		var sn1 = new com.wiris.chartparsing.SymbolNode();
		var sn0 = new Array();
		com.wiris.system.System.arraycopy(this.sn[i],0,sn0,0,n);
		this.sn[i] = sn0;
		this.sn[i][n] = sn1;
		return m;
	}
	,addTerminal: function(i,j,terminal) {
		var n = this.addTerminalImpl(i,terminal);
		var e = new com.wiris.chartparsing.Edge(i,j,terminal,1,0);
		var complete = this.sn[i][this.posTerminal + n].complete;
		complete.add(e);
		this.addNotify(e);
	}
	,changeNotify: function(id,e) {
		e.id = id;
		this.edges[id] = e;
	}
	,addNotify: function(e) {
		e.id = this.edges.length;
		this.edges.push(e);
		if(e.id > this.edgeLimit) throw new com.wiris.chartparsing.ChartParsingMemoryException("Input data is too big. Stop excecution because reached edge limit.");
	}
	,add: function(isComplete,lhs,e) {
		var b;
		if(isComplete) {
			if(this.sn[e.start][lhs] == null) this.sn[e.start][lhs] = new com.wiris.chartparsing.SymbolNode();
			var complete = this.sn[e.start][lhs].complete;
			b = complete.add(e);
		} else {
			if(this.grammar.isTerminalCategory(lhs)) {
				var B = this.findTerminal(e.stop,lhs);
				if(B < 0) {
					if(com.wiris.chartparsing.Chart2.OPTIMIZATION1) {
						this.expectedTerminals(e.stop,lhs);
						return false;
					}
					B = this.addTerminalImpl(e.stop,lhs);
					lhs = B + this.posTerminal;
				} else lhs = B + this.posTerminal;
			}
			if(this.sn[e.stop][lhs] == null) this.sn[e.stop][lhs] = new com.wiris.chartparsing.SymbolNode();
			var uncomplete = this.sn[e.stop][lhs].uncomplete;
			b = uncomplete.add(e);
		}
		if(b) this.addNotify(e);
		return b;
	}
	,getCompleteWithCategory: function(start,stop,lhs) {
		var ea = this.sn[start][lhs].complete;
		var i;
		var _g1 = 0, _g = ea.n;
		while(_g1 < _g) {
			var i1 = _g1++;
			if(ea.array[i1].stop == stop) return ea.array[i1];
		}
		return null;
	}
	,setConsidering: function(i,B,b) {
		var sn0 = this.sn[i];
		if(this.grammar.isTerminalCategory(B)) {
			if(com.wiris.chartparsing.Chart2.OPTIMIZATION1) throw "Expected non terminal symbol.";
			var j = this.findTerminal(i,B);
			B = this.posTerminal + j;
		}
		if(sn0[B] == null) sn0[B] = new com.wiris.chartparsing.SymbolNode();
		sn0[B].considered = b;
	}
	,isConsidered: function(i,B) {
		var sn0 = this.sn[i];
		if(this.grammar.isTerminalCategory(B)) {
			if(com.wiris.chartparsing.Chart2.OPTIMIZATION1) {
				this.expectedTerminals(i,B);
				return true;
			}
			var j = this.findTerminal(i,B);
			if(j < 0) j = this.addTerminalImpl(i,B);
			B = this.posTerminal + j;
		}
		var sn1 = sn0[B];
		if(sn1 != null) return sn1.considered; else return false;
	}
	,addUncompleteWithGap: function(lhs,e) {
		if(this.add(false,lhs,e)) return e;
		return null;
	}
	,addCompleteWithStart: function(lhs,e) {
		if(this.add(true,lhs,e)) return e;
		return null;
	}
	,getEdge2: function(complete,i,category) {
		var sn0;
		if(com.wiris.chartparsing.Rule.isNonTerminal(category)) sn0 = this.sn[i][category]; else {
			var j = this.findTerminal(i,category);
			if(j < 0) return null;
			sn0 = this.sn[i][this.posTerminal + j];
		}
		if(sn0 == null) return null;
		if(complete) return sn0.complete; else return sn0.uncomplete;
	}
	,getEdge: function(id) {
		return this.edges[id];
	}
	,getUncompleteWithGap2: function(stop,category) {
		return this.getEdge2(false,stop,category);
	}
	,getCompleteWithStart: function(start,category) {
		return this.getEdge2(true,start,category);
	}
	,getUncomplete: function(start,end) {
		var s = new com.wiris.chartparsing.EdgeArray();
		var i;
		var _g1 = 0, _g = this.posTerminal + this.ts[end].length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var sn0 = this.sn[end][i1];
			if(sn0 != null) {
				var ea = sn0.uncomplete;
				var j;
				var _g3 = 0, _g2 = ea.n;
				while(_g3 < _g2) {
					var j1 = _g3++;
					if(ea.array[j1].start == start) s.add(ea.array[j1]);
				}
			}
		}
		return s;
	}
	,getUncompleteWithGap: function(end) {
		var s = new com.wiris.chartparsing.EdgeArray();
		var i;
		var _g1 = 0, _g = this.posTerminal + this.ts[end].length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var sn0 = this.sn[end][i1];
			if(sn0 != null) {
				var ea = sn0.uncomplete;
				s.addAll(ea);
			}
		}
		return s;
	}
	,getComplete: function(start,stop) {
		var s = new com.wiris.chartparsing.EdgeArray();
		var i;
		var _g1 = 0, _g = this.posTerminal + this.ts[start].length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var sn0 = this.sn[start][i1];
			if(sn0 != null) {
				var ea = sn0.complete;
				var j;
				var _g3 = 0, _g2 = ea.n;
				while(_g3 < _g2) {
					var j1 = _g3++;
					if(ea.array[j1].stop == stop) s.add(ea.array[j1]);
				}
			}
		}
		return s;
	}
	,edgeLimit: null
	,tExpected: null
	,expected: null
	,lastError: null
	,edges: null
	,ts: null
	,sn: null
	,posTerminal: null
	,n_vertices: null
	,__class__: com.wiris.chartparsing.Chart2
});
com.wiris.chartparsing.ChartClassic = $hxClasses["com.wiris.chartparsing.ChartClassic"] = function(g,n) {
	com.wiris.chartparsing.Chart.call(this,g);
	this.edges = new Array();
	var i;
	n++;
	this.n_vertices = n;
	this.complete = new Array();
	this.uncomplete = new Array();
	var _g = 0;
	while(_g < n) {
		var i1 = _g++;
		this.complete[i1] = new Array();
		this.uncomplete[i1] = new Array();
	}
};
com.wiris.chartparsing.ChartClassic.__name__ = ["com","wiris","chartparsing","ChartClassic"];
com.wiris.chartparsing.ChartClassic.__super__ = com.wiris.chartparsing.Chart;
com.wiris.chartparsing.ChartClassic.prototype = $extend(com.wiris.chartparsing.Chart.prototype,{
	getNEdges: function() {
		return this.edges.length;
	}
	,getExpectedTerminals: function() {
		return new com.wiris.chartparsing.VectorSet();
	}
	,getLastError: function() {
		return null;
	}
	,getNVertices: function() {
		return this.n_vertices;
	}
	,count: function(eas) {
		var i;
		var j;
		var ea;
		var n = 0;
		var _g1 = 0, _g = this.n_vertices;
		while(_g1 < _g) {
			var i1 = _g1++;
			var _g3 = 0, _g2 = this.n_vertices;
			while(_g3 < _g2) {
				var j1 = _g3++;
				ea = eas[i1][j1];
				if(ea != null) n += ea.n;
			}
		}
		return n;
	}
	,showImpl: function(g,eas) {
		var i, j, k;
		var ea;
		var _g1 = 0, _g = this.n_vertices;
		while(_g1 < _g) {
			var i1 = _g1++;
			var _g3 = 0, _g2 = this.n_vertices;
			while(_g3 < _g2) {
				var j1 = _g3++;
				ea = eas[i1][j1];
				if(ea != null) {
					var _g5 = 0, _g4 = ea.n;
					while(_g5 < _g4) {
						var k1 = _g5++;
						com.wiris.chartparsing.Chart.staticShow(g,ea.array[k1]);
					}
				}
			}
		}
	}
	,showCount: function() {
		console.log("-----------------");
		console.log("Complete: " + this.count(this.complete));
		console.log("Uncomplete: " + this.count(this.uncomplete));
	}
	,show: function() {
		console.log("-----------------");
		console.log("Complete");
		this.showImpl(this.grammar,this.complete);
		console.log("Uncomplete");
		this.showImpl(this.grammar,this.uncomplete);
	}
	,add: function(ea,e) {
		if(ea[e.start][e.stop] == null) ea[e.start][e.stop] = new com.wiris.chartparsing.EdgeArray();
		var b = ea[e.start][e.stop].add(e);
		if(b) {
			e.id = this.edges.length;
			this.edges.push(e);
		}
		return b;
	}
	,change: function(ea,e,i) {
		var old = ea[e.start][e.stop].array[i];
		ea[e.start][e.stop].array[i] = e;
		e.id = old.id;
		this.edges[e.id] = e;
	}
	,addUncompleteEdge: function(start,end,rule,gap,prec) {
		var e = new com.wiris.chartparsing.Edge(start,end,rule,gap,prec);
		if(this.add(this.uncomplete,e)) return e;
		return null;
	}
	,changeCompleteEdge: function(start,end,rule,gap,i,prec) {
		var e = new com.wiris.chartparsing.Edge(start,end,rule,gap,prec);
		this.change(this.complete,e,i);
		return e;
	}
	,addCompleteEdge: function(start,end,rule,gap,prec) {
		var e = new com.wiris.chartparsing.Edge(start,end,rule,gap,prec);
		if(this.add(this.complete,e)) return e;
		return null;
	}
	,getEdge: function(id) {
		return this.edges[id];
	}
	,getUncomplete: function(i,j) {
		return this.uncomplete[i][j];
	}
	,getComplete: function(i,j) {
		return this.complete[i][j];
	}
	,n_vertices: null
	,edges: null
	,uncomplete: null
	,complete: null
	,__class__: com.wiris.chartparsing.ChartClassic
});
com.wiris.chartparsing.ChartNode = $hxClasses["com.wiris.chartparsing.ChartNode"] = function() {
	this.rule = -1;
};
com.wiris.chartparsing.ChartNode.__name__ = ["com","wiris","chartparsing","ChartNode"];
com.wiris.chartparsing.ChartNode.prototype = {
	toString: function() {
		if(this.isTerminal) return this.terminal.value.toString();
		return this.category.name;
	}
	,isEqual: function(str) {
		if(this.isTerminal) return this.terminal.isValueEqual(str); else return this.category.name == str;
	}
	,isEmpty: function() {
		return this.isTerminal && this.start == this.end;
	}
	,rule: null
	,end: null
	,start: null
	,children: null
	,terminal: null
	,category: null
	,isTerminal: null
	,__class__: com.wiris.chartparsing.ChartNode
}
if(!com.wiris.system) com.wiris.system = {}
com.wiris.system.Exception = $hxClasses["com.wiris.system.Exception"] = function(message,cause) {
	this.message = message;
};
com.wiris.system.Exception.__name__ = ["com","wiris","system","Exception"];
com.wiris.system.Exception.prototype = {
	getMessage: function() {
		return this.message;
	}
	,message: null
	,__class__: com.wiris.system.Exception
}
com.wiris.chartparsing.ChartParsingException = $hxClasses["com.wiris.chartparsing.ChartParsingException"] = function(str) {
	com.wiris.system.Exception.call(this,str);
};
com.wiris.chartparsing.ChartParsingException.__name__ = ["com","wiris","chartparsing","ChartParsingException"];
com.wiris.chartparsing.ChartParsingException.__super__ = com.wiris.system.Exception;
com.wiris.chartparsing.ChartParsingException.prototype = $extend(com.wiris.system.Exception.prototype,{
	getShortMessage: function() {
		return this.getMessage();
	}
	,__class__: com.wiris.chartparsing.ChartParsingException
});
com.wiris.chartparsing.ChartParsingMemoryException = $hxClasses["com.wiris.chartparsing.ChartParsingMemoryException"] = function(msg) {
	com.wiris.chartparsing.ChartParsingException.call(this,msg);
};
com.wiris.chartparsing.ChartParsingMemoryException.__name__ = ["com","wiris","chartparsing","ChartParsingMemoryException"];
com.wiris.chartparsing.ChartParsingMemoryException.__super__ = com.wiris.chartparsing.ChartParsingException;
com.wiris.chartparsing.ChartParsingMemoryException.prototype = $extend(com.wiris.chartparsing.ChartParsingException.prototype,{
	__class__: com.wiris.chartparsing.ChartParsingMemoryException
});
com.wiris.chartparsing.ChartTree = $hxClasses["com.wiris.chartparsing.ChartTree"] = function(grammar,goal,chart) {
	this.goal = goal;
	this.grammar = grammar;
	this.chart = chart;
};
com.wiris.chartparsing.ChartTree.__name__ = ["com","wiris","chartparsing","ChartTree"];
com.wiris.chartparsing.ChartTree.toString2 = function(cn,tokens) {
	var str;
	var i;
	str = "";
	if(cn.rule < com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) str += cn.rule + ":";
	if(!cn.isTerminal) str += Std.string(cn.category); else if(!cn.isEmpty()) str += "`" + tokens.getVector()[cn.start] + "`"; else str += "empty";
	if(cn.children.length > 0) {
		str += "( ";
		var _g1 = 0, _g = cn.children.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			if(i1 > 0) str += " ";
			str += com.wiris.chartparsing.ChartTree.toString2(cn.children[i1],tokens);
		}
		str += " )";
	}
	return str;
}
com.wiris.chartparsing.ChartTree.prototype = {
	getTree: function(e) {
		var ue, ce;
		var vec = new Array();
		var cn = new com.wiris.chartparsing.ChartNode();
		ue = e;
		if(!e.isTerminalRule()) {
			var i;
			var _g1 = 0, _g = this.grammar.rules[e.rule].rhs.length;
			while(_g1 < _g) {
				var i1 = _g1++;
				ce = this.chart.getEdge(ue.edge1);
				vec.splice(0,0,this.getTree(ce));
				ue = this.chart.getEdge(ue.edge0);
			}
			var rule = this.grammar.rules[e.rule];
			cn.category = this.grammar.categories[rule.lhs];
			cn.isTerminal = false;
		} else {
			cn.terminal = this.grammar.terminal[e.rule - com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID];
			cn.isTerminal = true;
		}
		cn.rule = e.rule;
		cn.start = e.start;
		cn.end = e.stop;
		cn.children = new Array();
		cn.children = vec.slice();
		return cn;
	}
	,toString3: function(cn,tokens,depth) {
		var str;
		var i;
		str = "";
		var _g = 0;
		while(_g < depth) {
			var i1 = _g++;
			str += "|  ";
		}
		if(!cn.isTerminal) str += Std.string(cn.category) + ":" + cn.rule; else if(!cn.isEmpty()) str += "`" + tokens.getVector()[cn.start] + "`"; else str += "empty";
		str += " (" + cn.start + "," + cn.end + ")";
		if(cn.children.length > 0) {
			str += "\n";
			var _g1 = 0, _g = cn.children.length;
			while(_g1 < _g) {
				var i1 = _g1++;
				str += this.toString3(cn.children[i1],tokens,depth + 1);
				if(i1 + 1 < cn.children.length) str += "\n";
			}
		}
		return str;
	}
	,goal: null
	,grammar: null
	,chart: null
	,__class__: com.wiris.chartparsing.ChartTree
}
com.wiris.chartparsing.ChartUtilsForClassic = $hxClasses["com.wiris.chartparsing.ChartUtilsForClassic"] = function(grammar,goal,chart) {
	this.goal = goal;
	this.grammar = grammar;
	this.chart = chart;
};
com.wiris.chartparsing.ChartUtilsForClassic.__name__ = ["com","wiris","chartparsing","ChartUtilsForClassic"];
com.wiris.chartparsing.ChartUtilsForClassic.prototype = {
	toRules: function(cn,tokens) {
		var str;
		var i;
		str = "";
		str += cn.rule;
		if(cn.children.length > 0) {
			str += "(";
			var _g1 = 0, _g = cn.children.length;
			while(_g1 < _g) {
				var i1 = _g1++;
				if(i1 > 0) str += " ";
				str += this.toRules(cn.children[i1],tokens);
			}
			str += ")";
		}
		return str;
	}
	,emptyChartNode: function(x0,x1) {
		var cn;
		cn = new com.wiris.chartparsing.ChartNode();
		cn.start = x0;
		cn.end = x1;
		cn.children = new Array();
		return cn;
	}
	,findImpl: function(x0,x1,i0,cs) {
		var i, j;
		var e;
		var cn, child0, cn0;
		if(x0 < x1 && i0 >= cs.length) return null;
		if(x0 >= x1) {
			if(i0 >= cs.length) return this.emptyChartNode(x0,x1); else return null;
		}
		i = x0 + 1;
		while(i <= x1) {
			e = this.chart.findEdgeWithCategory(x0,i,cs[i0]);
			if(e != null) {
				cn0 = this.findImpl(i,x1,i0 + 1,cs);
				if(cn0 != null) {
					child0 = this.find(x0,i,cs[i0]);
					cn = new com.wiris.chartparsing.ChartNode();
					cn.start = x0;
					cn.end = x1;
					var aux = cn0.children.slice();
					aux.splice(0,0,child0);
					cn.children = new Array();
					cn.children = aux.slice();
					return cn;
				}
			}
			i++;
		}
		return null;
	}
	,find: function(x0,x1,cat) {
		var e;
		e = this.chart.findEdgeWithCategory(x0,x1,cat);
		if(e.rule < com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) {
			var rule = this.grammar.rules[e.rule];
			var cn = this.findImpl(x0,x1,0,rule.rhs);
			cn.rule = e.rule;
			return cn;
		}
		var cn2 = new com.wiris.chartparsing.ChartNode();
		cn2.start = x0;
		cn2.end = x1;
		cn2.children = new Array();
		cn2.terminal = this.grammar.terminal[e.rule - com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID];
		cn2.isTerminal = true;
		return cn2;
	}
	,findRule: function(x0,x1,r) {
		var cn;
		cn = this.findImpl(x0,x1,0,r.rhs);
		cn.rule = r.id;
		return cn;
	}
	,getTree: function() {
		return this.find(0,this.chart.getNVertices() - 1,this.goal);
	}
	,goal: null
	,grammar: null
	,chart: null
	,__class__: com.wiris.chartparsing.ChartUtilsForClassic
}
com.wiris.chartparsing.Constants = $hxClasses["com.wiris.chartparsing.Constants"] = function() { }
com.wiris.chartparsing.Constants.__name__ = ["com","wiris","chartparsing","Constants"];
com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler = $hxClasses["com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler"] = function() {
};
com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.__name__ = ["com","wiris","chartparsing","DeepPriorityAmbiguitiesHandler"];
com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.__interfaces__ = [com.wiris.chartparsing.AmbiguitiesHandler];
com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.computePriorities = function(e1,e2,tdp) {
	var s1 = new Array();
	var s2 = new Array();
	var f1, f2;
	var g1, g2;
	f1 = e1;
	f2 = e2;
	var prio1 = -2147483648;
	var prio2 = -2147483648;
	var bothTerminal = false;
	s1.push(e1);
	s2.push(e2);
	while(s1.length > 0 && s2.length > 0) {
		f1 = s1[s1.length - 1];
		f2 = s2[s2.length - 1];
		g2 = com.wiris.util.type.Arrays.indexOfElement(s2,f1);
		if(g2 >= 0) {
			f2 = s2[g2];
			s2 = com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.subStack(s2,0,g2 + 1);
			g1 = -1;
		} else {
			g1 = com.wiris.util.type.Arrays.indexOfElement(s1,f2);
			if(g1 >= 0) {
				f1 = s1[g1];
				s1 = com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.subStack(s1,0,g1 + 1);
			}
		}
		if(g1 >= 0 || g2 >= 0 || bothTerminal) {
			prio1 = com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.back(tdp,s1,prio1);
			prio2 = com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.back(tdp,s2,prio2);
			bothTerminal = false;
		} else {
			f1 = com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.next0(tdp,s1);
			f2 = com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.next0(tdp,s2);
			bothTerminal = f1 == null && f2 == null;
		}
	}
	if(prio1 < prio2) return com.wiris.chartparsing.Constants.LOWER;
	if(prio1 > prio2) return com.wiris.chartparsing.Constants.GREATER;
	return com.wiris.chartparsing.Constants.UNKNOWN;
}
com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.subStack = function(s,from,to) {
	var r = new Array();
	var i;
	var _g = from;
	while(_g < to) {
		var i1 = _g++;
		r.push(s[i1]);
	}
	return r;
}
com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.next0 = function(tdp,v) {
	var c = tdp.getChart();
	var e = v[v.length - 1];
	if(e.rule >= com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) return null;
	if(e.start0 == e.end0) {
		var f = c.getEdge(e.edge1);
		v.push(f);
		return f;
	} else {
		v.push(c.getEdge(e.edge0));
		return com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.next0(tdp,v);
	}
}
com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.back = function(tdp,v,prio) {
	if(v.length == 0) return prio;
	var e = v.pop();
	var c = tdp.getChart();
	if(v.length == 0) return prio;
	var p = v[v.length - 1];
	while(p.edge1 == e.id) {
		var r = tdp.getGrammar().rules[p.rule];
		var o = r.getProperty("priority");
		if(o == null) o = "0";
		prio = com.wiris.util.type.IntegerTools.max(Std.parseInt(o),prio);
		v.pop();
		if(v.length == 0) return prio;
		e = p;
		p = v[v.length - 1];
	}
	var f = c.getEdge(p.edge1);
	v.push(f);
	return prio;
}
com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.prototype = {
	disambiguate: function(e0,e1,tdp) {
		var g = tdp.getGrammar();
		var r1 = g.rules[e0.rule];
		var r2 = g.rules[e1.rule];
		var o1 = r1.getProperty("deep_priorities");
		var o2 = r2.getProperty("deep_priorities");
		if(o1 == null || o2 == null) return com.wiris.chartparsing.Constants.UNKNOWN;
		var c = com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler.computePriorities(e0,e1,tdp);
		return c;
	}
	,__class__: com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler
}
com.wiris.chartparsing.Edge = $hxClasses["com.wiris.chartparsing.Edge"] = function(start,stop,rule,found,prec) {
	this.start = start;
	this.stop = stop;
	this.rule = rule;
	this.dot = found;
	this.precedence = prec;
	this.update();
	this.edge1 = 0;
};
com.wiris.chartparsing.Edge.__name__ = ["com","wiris","chartparsing","Edge"];
com.wiris.chartparsing.Edge.prototype = {
	getDotSymbol: function(g) {
		if(com.wiris.chartparsing.Rule.isNonTerminal(this.rule)) return g.rules[this.rule].rhs[this.dot]; else throw "Expected non terminal rule.";
	}
	,getLhs: function(g) {
		if(com.wiris.chartparsing.Rule.isNonTerminal(this.rule)) return g.rules[this.rule].lhs; else return this.rule;
	}
	,isComplete: function(g) {
		if(com.wiris.chartparsing.Rule.isNonTerminal(this.rule)) {
			var r = g.rules[this.rule];
			return r.rhs.length == this.dot;
		} else return true;
	}
	,isEqual: function(o) {
		if(js.Boot.__instanceof(o,com.wiris.chartparsing.Edge)) {
			var e;
			e = o;
			return this.start == e.start && this.stop == e.stop && this.rule == e.rule && this.dot == e.dot && this.start0 == e.start0 && this.end0 == e.end0 && this.start1 == e.start1 && this.end1 == e.end1;
		}
		return false;
	}
	,update: function() {
		this.hash = this.start + this.stop + this.rule + this.dot + this.start0 + this.end0 + this.start1 + this.end1;
	}
	,isTerminalRule: function() {
		return this.rule >= com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID;
	}
	,hash: null
	,edge1: null
	,end1: null
	,start1: null
	,edge0: null
	,end0: null
	,start0: null
	,id: null
	,precedence: null
	,dot: null
	,rule: null
	,stop: null
	,start: null
	,__class__: com.wiris.chartparsing.Edge
}
com.wiris.chartparsing.EdgeArray = $hxClasses["com.wiris.chartparsing.EdgeArray"] = function() {
	this.n = 0;
};
com.wiris.chartparsing.EdgeArray.__name__ = ["com","wiris","chartparsing","EdgeArray"];
com.wiris.chartparsing.EdgeArray.prototype = {
	addAll: function(ea) {
		var i;
		var _g1 = 0, _g = ea.n;
		while(_g1 < _g) {
			var i1 = _g1++;
			this.add(ea.array[i1]);
		}
	}
	,allocate: function() {
		if(this.array == null || this.array.length >= this.n) {
			var old = this.array;
			this.array = new Array();
			var i = 0;
			if(old != null) while(i < this.n) {
				this.array.push(old[i]);
				++i;
			}
			i = this.n + 10 - this.array.length;
			while(i >= 0) {
				this.array.push(null);
				--i;
			}
		}
	}
	,add: function(edge) {
		var i;
		var hash = edge.hash;
		var _g1 = 0, _g = this.n;
		while(_g1 < _g) {
			var i1 = _g1++;
			if(this.array[i1].hash == hash && this.array[i1].isEqual(edge)) return false;
		}
		this.allocate();
		this.array[this.n] = edge;
		this.n++;
		return true;
	}
	,n: null
	,array: null
	,__class__: com.wiris.chartparsing.EdgeArray
}
com.wiris.chartparsing.Grammar = $hxClasses["com.wiris.chartparsing.Grammar"] = function() { }
com.wiris.chartparsing.Grammar.__name__ = ["com","wiris","chartparsing","Grammar"];
com.wiris.chartparsing.Grammar.prototype = {
	rule2String: function(r) {
		var sb = new StringBuf();
		sb.b += Std.string("R" + r.id + ": " + this.categories[r.lhs].name);
		sb.b += Std.string(" -> ");
		var j;
		var _g1 = 0, _g = r.rhs.length;
		while(_g1 < _g) {
			var j1 = _g1++;
			var cat;
			cat = r.rhs[j1];
			if(cat < com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) sb.b += Std.string(this.categories[cat].name); else {
				var obj = this.terminal[cat - com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID];
				if(js.Boot.__instanceof(obj.value,String)) sb.b += Std.string("'" + Std.string(obj) + "'"); else sb.b += Std.string("[" + Std.string(obj) + "]");
			}
			sb.b += Std.string(" ");
		}
		var h = r.getProperties();
		if(h != null) {
			var en = h.keys();
			while(en.hasNext()) {
				var key = en.next();
				var value = r.getProperty(key);
				sb.b += Std.string(" " + key + "=");
				if(js.Boot.__instanceof(value,Array)) {
					var os = value;
					sb.b += Std.string("{");
					var _g1 = 0, _g = os.length;
					while(_g1 < _g) {
						var j1 = _g1++;
						if(j1 > 0) sb.b += Std.string(", ");
						sb.b += Std.string("" + os[j1]);
					}
					sb.b += Std.string("}");
				} else sb.b += Std.string("" + Std.string(value));
				if(en.hasNext()) sb.b += Std.string(",");
			}
		}
		sb.b += Std.string("[" + r.id + "]");
		return sb.b;
	}
	,strongconnect: function(v) {
		v.index = this.index;
		v.lowlink = this.index;
		this.index = this.index + 1;
		this.S.push(v);
		var i;
		var _g1 = 0, _g = this.ruleByCategory[v.id].length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var r = this.ruleByCategory[v.id][i1];
			var w = null;
			if(r.rhs.length > 1) {
				var j = r.rhs[r.rhs.length - 1];
				if(j < com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) w = this.categories[j];
			}
			if(w != null) {
				if(w.index == -1) {
					this.strongconnect(w);
					v.lowlink = com.wiris.common.WInteger.min(v.lowlink,w.lowlink);
				} else if(com.wiris.system.ArrayEx.contains(this.S,w)) v.lowlink = com.wiris.common.WInteger.min(v.lowlink,w.index);
			}
		}
		if(v.lowlink == v.index) {
			var w;
			w = this.S.pop();
			var cats = new StringBuf();
			var rules = new StringBuf();
			var y = w;
			var y0 = w;
			var finish = false;
			do {
				cats.b += Std.string(w);
				if(w.id == v.id) {
					w = y0;
					finish = true;
				} else {
					w = this.S.pop();
					cats.b += Std.string(" ");
				}
				var _g1 = 0, _g = this.ruleByCategory[y.id].length;
				while(_g1 < _g) {
					var i1 = _g1++;
					var r = this.ruleByCategory[y.id][i1];
					if(r.rhs.length > 1) {
						var j = r.rhs[r.rhs.length - 1];
						if(j == w.id) rules.b += Std.string(this.rule2String(r) + "\r\n");
					}
				}
				y = w;
			} while(!finish);
			var srules = rules.b;
			if(srules.length > 0) {
				this.rightRecursions.b += Std.string("[" + cats.b + "]\r\n");
				this.rightRecursions.b += Std.string(rules.b);
			}
		}
	}
	,getRightRecursions: function() {
		if(this.rightRecursions == null) {
			this.rightRecursions = new StringBuf();
			this.index = 0;
			this.S = new Array();
			var i;
			var _g1 = 0, _g = this.categories.length;
			while(_g1 < _g) {
				var i1 = _g1++;
				var v = this.categories[i1];
				if(v.index == -1) this.strongconnect(v);
			}
		}
		return this.rightRecursions.b;
	}
	,showRightRecursion: function() {
		var text = this.getRightRecursions();
		if(text.length > 0) console.log(text);
	}
	,rightRecursions: null
	,S: null
	,index: null
	,packRules: function() {
		var ar = new Array();
		var i;
		var _g1 = 0, _g = this.categories.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			ar.push(null);
		}
		var _g1 = 0, _g = this.rules.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var r = this.rules[i1];
			var lhs = r.lhs;
			if(lhs == -1) console.log(i1);
			if(ar[lhs] == null) ar[lhs] = new Array();
			ar[lhs].push(r);
		}
		this.ruleByCategory = new Array();
		var _g1 = 0, _g = this.categories.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			this.ruleByCategory[i1] = new Array();
			var array = ar[i1];
			this.ruleByCategory[i1] = array.slice();
		}
	}
	,fixDuplicates: function() {
		var ts = this.terminal;
		var res = new Array();
		var i;
		var _g1 = 0, _g = ts.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var j;
			var _g3 = i1 + 1, _g2 = ts.length;
			while(_g3 < _g2) {
				var j1 = _g3++;
				if(ts[i1].isValueEqual(ts[j1].value)) res[j1] = i1 + 1;
			}
		}
		var _g1 = 0, _g = this.rules.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var r;
			r = this.rules[i1];
			var j;
			var _g3 = 0, _g2 = r.rhs.length;
			while(_g3 < _g2) {
				var j1 = _g3++;
				if(this.isTerminalCategory(r.rhs[j1])) {
					var id = r.rhs[j1] - com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID;
					if(res[id] > 0) r.rhs[j1] = res[id] - 1 + com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID;
				}
			}
		}
	}
	,showCategories: function() {
		console.log("Categories");
		var i;
		var _g1 = 0, _g = this.categories.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			console.log(i1 + ": " + this.categories[i1].name);
		}
	}
	,showTerminal: function() {
		console.log("Terminals");
		var i;
		var _g1 = 0, _g = this.terminal.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			console.log(i1 + ": " + Std.string(this.terminal[i1]));
		}
	}
	,getTerminal: function(i) {
		return this.terminal[i - com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID];
	}
	,isTerminalCategory: function(n) {
		return n >= com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID;
	}
	,ruleToString: function(n) {
		if(n >= com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) return "'" + Std.string(this.terminal[n - com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID]) + "'"; else return this.categories[n].name;
	}
	,getCategoryByName: function(name) {
		var i;
		var _g1 = 0, _g = this.categories.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			if(this.categories[i1].name == name) return i1;
		}
		if(this.terminal != null) {
			var _g1 = 0, _g = this.terminal.length;
			while(_g1 < _g) {
				var i1 = _g1++;
				if(this.terminal[i1].isValueEqual(name)) return i1 + com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID;
			}
		}
		return -1;
	}
	,getTerminalByValue: function(value) {
		var i;
		var found = -1;
		var _g1 = 0, _g = this.terminal.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			if(this.terminal[i1].isValueEqual(value)) {
				found = i1 + com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID;
				return found;
			}
		}
		return found;
	}
	,ruleByCategory: null
	,terminal: null
	,rules: null
	,categories: null
	,__class__: com.wiris.chartparsing.Grammar
}
com.wiris.chartparsing.GrammarBuilder = $hxClasses["com.wiris.chartparsing.GrammarBuilder"] = function() {
	this.vterminal = new Array();
};
com.wiris.chartparsing.GrammarBuilder.__name__ = ["com","wiris","chartparsing","GrammarBuilder"];
com.wiris.chartparsing.GrammarBuilder.__super__ = com.wiris.chartparsing.Grammar;
com.wiris.chartparsing.GrammarBuilder.prototype = $extend(com.wiris.chartparsing.Grammar.prototype,{
	toString: function() {
		var i, j;
		var sb = new StringBuf();
		sb.b += Std.string("Categories\n");
		var _g1 = 0, _g = this.categories.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			sb.b += Std.string("C" + this.categories[i1].id + ": " + this.categories[i1].name + "\n");
		}
		sb.b += Std.string("\n");
		sb.b += Std.string("Terminals\n");
		var _g1 = 0, _g = this.terminal.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			sb.b += Std.string("T" + (this.terminal[i1].id - com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) + ": " + Std.string(this.terminal[i1].value.toString()) + "(" + com.wiris.system.Utf8.charCodeAt(this.terminal[i1].value.toString(),0) + ")\n");
		}
		sb.b += Std.string("\n");
		sb.b += Std.string("Rules\n");
		var _g1 = 0, _g = this.rules.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			sb.b += Std.string("R" + this.rules[i1].id + ": " + this.categories[this.rules[i1].lhs].name);
			sb.b += Std.string(" -> ");
			var r = this.rules[i1];
			var _g3 = 0, _g2 = this.rules[i1].rhs.length;
			while(_g3 < _g2) {
				var j1 = _g3++;
				var cat;
				cat = r.rhs[j1];
				if(cat < com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) sb.b += Std.string(this.categories[cat].name); else {
					var obj = this.terminal[cat - com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID];
					if(js.Boot.__instanceof(obj.value,String)) sb.b += Std.string("'" + Std.string(obj) + "'"); else sb.b += Std.string("[" + Std.string(obj) + "]");
				}
				sb.b += Std.string(" ");
			}
			var h = r.getProperties();
			if(h != null) {
				var en = h.keys();
				while(en.hasNext()) {
					var key = en.next();
					var value = r.getProperty(key);
					sb.b += Std.string(" " + key + "=");
					if(js.Boot.__instanceof(value,Array)) {
						var os = value;
						sb.b += Std.string("{");
						var _g3 = 0, _g2 = os.length;
						while(_g3 < _g2) {
							var j1 = _g3++;
							if(j1 > 0) sb.b += Std.string(", ");
							sb.b += Std.string("" + os[j1]);
						}
						sb.b += Std.string("}");
					} else sb.b += Std.string("" + Std.string(value));
					if(en.hasNext()) sb.b += Std.string(",");
				}
			}
			sb.b += Std.string("[" + i1 + "]");
			sb.b += Std.string("\n");
		}
		return sb.b;
	}
	,show: function() {
		com.wiris.chartparsing.Logger.finestln(this.toString());
	}
	,packRules: function() {
		var i;
		var _g1 = 0, _g = this.rules.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			this.rules[i1].id = i1;
		}
		this.terminal = new Array();
		var _g1 = 0, _g = this.vterminal.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			this.terminal[i1] = new com.wiris.chartparsing.Terminal();
			this.terminal[i1].id = i1 + com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID;
			this.terminal[i1].value = this.vterminal[i1];
		}
		com.wiris.chartparsing.Grammar.prototype.packRules.call(this);
	}
	,packCategories: function() {
		var i;
		var _g1 = 0, _g = this.categories.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			this.categories[i1].id = i1;
		}
	}
	,setRules: function(v) {
		this.rules = new Array();
		this.rules = v.slice();
	}
	,setCategories: function(v) {
		this.categories = new Array();
		this.categories = v.slice();
	}
	,newRule: function(lhs,rhs,prec) {
		var i;
		var irhs;
		var ilhs;
		ilhs = this.getCategoryByName(lhs);
		irhs = new Array();
		var _g1 = 0, _g = rhs.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var j;
			var o = rhs[i1];
			if(js.Boot.__instanceof(o,com.wiris.chartparsing.Category)) {
				var c = o;
				j = this.getCategoryByName(c.name);
				if(j < 0) throw "Unknown category " + c.name;
			} else {
				j = com.wiris.util.type.Arrays.indexOfElement(this.vterminal,o);
				if(j < 0) {
					j = this.vterminal.length;
					this.vterminal.push(o);
				}
				j += com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID;
			}
			irhs[i1] = j;
		}
		return new com.wiris.chartparsing.Rule(ilhs,irhs,prec);
	}
	,newRule1: function(lhs,rhs,prec) {
		var i;
		var irhs;
		var ilhs;
		ilhs = this.getCategoryByName(lhs);
		irhs = new Array();
		var _g1 = 0, _g = rhs.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var j;
			j = this.getCategoryByName(rhs[i1]);
			if(j < 0) {
				j = com.wiris.util.type.Arrays.indexOfElement(this.vterminal,rhs[i1]);
				if(j < 0) {
					j = this.vterminal.length;
					this.vterminal.push(rhs[i1]);
				}
				j += com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID;
			}
			irhs[i1] = j;
		}
		return new com.wiris.chartparsing.Rule(ilhs,irhs,prec);
	}
	,newRule6: function(lhs,rhs) {
		return this.newRule1(lhs,rhs,0);
	}
	,newRule5: function(lhs,rhs0,rhs1,rhs2,rhs3,prec) {
		return this.newRule1(lhs,[rhs0,rhs1,rhs2,rhs3],prec);
	}
	,newRule4: function(lhs,rhs0,rhs1,rhs2,prec) {
		return this.newRule1(lhs,[rhs0,rhs1,rhs2],prec);
	}
	,newRule3: function(lhs,rhs0,rhs1,prec) {
		return this.newRule1(lhs,[rhs0,rhs1],prec);
	}
	,newRule2: function(lhs,rhs0,prec) {
		return this.newRule1(lhs,[rhs0],prec);
	}
	,newRule10: function(lhs,rhs0,rhs1,rhs2,rhs3) {
		return this.newRule6(lhs,[rhs0,rhs1,rhs2,rhs3]);
	}
	,newRule9: function(lhs,rhs0,rhs1,rhs2) {
		return this.newRule6(lhs,[rhs0,rhs1,rhs2]);
	}
	,newRule8: function(lhs,rhs0,rhs1) {
		return this.newRule6(lhs,[rhs0,rhs1]);
	}
	,newRule7: function(lhs,rhs0) {
		return this.newRule6(lhs,[rhs0]);
	}
	,vterminal: null
	,__class__: com.wiris.chartparsing.GrammarBuilder
});
com.wiris.chartparsing.GrammarInverseBuilder = $hxClasses["com.wiris.chartparsing.GrammarInverseBuilder"] = function() {
};
com.wiris.chartparsing.GrammarInverseBuilder.__name__ = ["com","wiris","chartparsing","GrammarInverseBuilder"];
com.wiris.chartparsing.GrammarInverseBuilder.prototype = {
	findNumericParameter: function(ts,j) {
		var i;
		var _g1 = 0, _g = ts.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var x = ts[i1];
			if(js.Boot.__instanceof(x,com.wiris.chartparsing.TreeToken)) {
				var tk = x;
				if(tk.isParamNumber()) {
					var n = tk.getParamNumber() - 1;
					if(n == j) return i1;
				}
			}
		}
		return -1;
	}
	,invert: function(g) {
		this.grammar = g;
		var m = new com.wiris.chartparsing.GrammarBuilder();
		var cat = new Array();
		var i;
		var _g1 = 0, _g = g.categories.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var c = new com.wiris.chartparsing.Category(g.categories[i1].name);
			cat.push(c);
		}
		m.setCategories(cat);
		m.packCategories();
		var rules = new Array();
		var _g1 = 0, _g = g.rules.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var rule = g.rules[i1];
			if("false" == rule.getProperty("invert")) continue;
			try {
				var ts = rule.getProperty("transformation");
				var r;
				if(ts == null) {
					var os = new Array();
					var j;
					var _g3 = 0, _g2 = rule.rhs.length;
					while(_g3 < _g2) {
						var j1 = _g3++;
						var k = rule.rhs[j1];
						if(g.isTerminalCategory(k)) os[j1] = g.getTerminal(k).value; else os[j1] = g.categories[k];
					}
					r = m.newRule(g.categories[rule.lhs].name,os,rule.precedence);
					if(rule.rhsnames != null) {
						r.rhsnames = new Array();
						var _g3 = 0, _g2 = r.rhsnames.length;
						while(_g3 < _g2) {
							var j1 = _g3++;
							r.rhsnames[j1] = rule.rhsnames[j1];
						}
					}
				} else {
					var os;
					var names = new Array();
					var hasNames = false;
					var j;
					if(ts.length == 0) {
						os = new Array();
						os[0] = "empty";
					} else {
						os = new Array();
						var _g3 = 0, _g2 = ts.length;
						while(_g3 < _g2) {
							var j1 = _g3++;
							var x = ts[j1];
							if(js.Boot.__instanceof(x,com.wiris.chartparsing.TreeToken)) {
								var tk = x;
								var n = -1;
								if(tk.isParamNumber()) n = tk.getParamNumber() - 1; else if(tk.isParamName()) {
									var k;
									var _g5 = 0, _g4 = rule.rhsnames.length;
									while(_g5 < _g4) {
										var k1 = _g5++;
										if(tk.name == rule.rhsnames[k1]) n = k1;
									}
									names[j1] = tk.name;
									hasNames = true;
								}
								if(n >= 0) {
									var k = rule.rhs[n];
									if(!g.isTerminalCategory(k)) os[j1] = g.categories[k]; else os[j1] = g.getTerminal(k).value;
								}
							}
							if(os[j1] == null) os[j1] = x;
						}
					}
					r = m.newRule(g.categories[rule.lhs].name,os,rule.precedence);
					if(hasNames) r.rhsnames = names;
					os = new Array();
					var j2 = 0;
					var _g3 = 0, _g2 = rule.rhs.length;
					while(_g3 < _g2) {
						var j1 = _g3++;
						var k = rule.rhs[j1];
						var l = this.findNumericParameter(ts,j1);
						if(l >= 0) {
							var tt = com.wiris.chartparsing.TreeToken.newTreeToken2(l + 1);
							os[j2] = tt;
						} else if(rule.rhsnames != null && rule.rhsnames[j1] != null) {
							var tt = new com.wiris.chartparsing.TreeToken(rule.rhsnames[j1],true);
							os[j2] = tt;
						} else if(g.isTerminalCategory(k)) {
							os[j2] = g.getTerminal(k).value;
							if(os[j2] == "empty") {
								var newos = new Array();
								var n;
								var _g4 = 0;
								while(_g4 < j2) {
									var n1 = _g4++;
									newos[n1] = os[n1];
								}
								os = newos;
								j2--;
							}
						} else throw "Impossible to compute inverse due to category " + g.categories[k].name;
						j2++;
					}
					r.setProperty("transformation",os);
				}
				r.lhsname = rule.lhsname;
				var props = rule.getProperties();
				if(props != null) {
					var e = props.keys();
					while(e.hasNext()) {
						var key = e.next();
						var value = props.get(key);
						if(!(key == "transformation") && !(key == "priority") && !(key == "inverse_priority")) r.setProperty(key,value);
					}
					var ip = rule.getProperty("inverse_priority");
					var p = rule.getProperty("priority");
					if(ip != null) {
						r.setProperty("priority",ip);
						if(p != null) r.setProperty("inverse_priority",p); else r.setProperty("inverse_priority","0");
					} else if(p != null) r.setProperty("priority",p);
				}
				rules.push(r);
			} catch( ex ) {
				throw "Error processing rule number " + i1;
			}
		}
		m.setRules(rules);
		m.packRules();
		m.showRightRecursion();
		return m;
	}
	,grammar: null
	,__class__: com.wiris.chartparsing.GrammarInverseBuilder
}
com.wiris.chartparsing.GrammarReducedBuilder = $hxClasses["com.wiris.chartparsing.GrammarReducedBuilder"] = function() {
};
com.wiris.chartparsing.GrammarReducedBuilder.__name__ = ["com","wiris","chartparsing","GrammarReducedBuilder"];
com.wiris.chartparsing.GrammarReducedBuilder.prototype = {
	insertInSortedArray: function(n,a) {
		var k = 0;
		while(k < a.length && a[k] < n) k++;
		if(k == a.length) a.push(n); else if(a[k] > n) a.splice(k,0,n);
	}
	,inArray: function(key,a) {
		var i = HxOverrides.iter(a);
		while(i.hasNext()) if(key == i.next()) return true;
		return false;
	}
	,inCategoryArray: function(name,a) {
		var i = HxOverrides.iter(a);
		while(i.hasNext()) {
			var c = i.next();
			if(name == c.name) return true;
		}
		return false;
	}
	,inSortedArray: function(key,v) {
		var imin = 0;
		var imax = v.length - 1;
		while(imin < imax) {
			var imid = Math.floor((imin + imax) / 2);
			if(v[imid] < key) imin = imid + 1; else imax = imid;
		}
		return imax == imin && v[imin] == key;
	}
	,showRules: function(g) {
		console.log("==RULES==");
		var l;
		var _g1 = 0, _g = g.rules.length;
		while(_g1 < _g) {
			var l1 = _g1++;
			console.log(g.rule2String(g.rules[l1]));
		}
	}
	,reduce: function(g,p,cc) {
		var tokens = p.getVector();
		var cats = new Array();
		var i;
		var _g1 = 0, _g = tokens.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var tokencats = cc.getCategories(tokens[i1],g);
			if(tokencats != null) {
				var j;
				var _g3 = 0, _g2 = tokencats.length;
				while(_g3 < _g2) {
					var j1 = _g3++;
					this.insertInSortedArray(tokencats[j1],cats);
				}
			}
		}
		var empty = g.getCategoryByName("empty");
		if(empty != -1) this.insertInSortedArray(empty,cats);
		var r = new com.wiris.chartparsing.GrammarBuilder();
		var rules = new Array();
		var n = g.rules.length;
		var _g = 0;
		while(_g < n) {
			var i1 = _g++;
			var rule = g.rules[i1];
			var deleteRule = false;
			var j;
			var _g2 = 0, _g1 = rule.rhs.length;
			while(_g2 < _g1) {
				var j1 = _g2++;
				var id = rule.rhs[j1];
				if(g.isTerminalCategory(id) && !this.inSortedArray(id,cats)) {
					deleteRule = true;
					break;
				}
			}
			if(!deleteRule) rules.push(rule);
		}
		var sel = new Array();
		do {
			n = sel.length;
			i = rules.length - 1;
			while(i >= 0) {
				var rule = rules[i];
				var selRule = true;
				var j;
				var _g1 = 0, _g = rule.rhs.length;
				while(_g1 < _g) {
					var j1 = _g1++;
					var id = rule.rhs[j1];
					if(!g.isTerminalCategory(id)) {
						selRule = false;
						var k;
						var _g3 = 0, _g2 = sel.length;
						while(_g3 < _g2) {
							var k1 = _g3++;
							if(sel[k1].lhs == id) {
								selRule = true;
								break;
							}
						}
						if(!selRule) break;
					}
				}
				if(selRule) {
					sel.push(rule);
					HxOverrides.remove(rules,rule);
				}
				i--;
			}
		} while(sel.length > n);
		var newCategories = new Array();
		var _g1 = 0, _g = sel.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var name = g.categories[sel[i1].lhs].name;
			if(!this.inCategoryArray(name,newCategories)) {
				var c = new com.wiris.chartparsing.Category(name);
				newCategories.push(c);
			}
		}
		r.setCategories(newCategories);
		r.packCategories();
		var newRules = new Array();
		var _g1 = 0, _g = sel.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var rule = sel[i1];
			var lhs = g.categories[rule.lhs].name;
			var rhs = new Array();
			var j;
			var _g3 = 0, _g2 = rule.rhs.length;
			while(_g3 < _g2) {
				var j1 = _g3++;
				var id = rule.rhs[j1];
				if(g.isTerminalCategory(id)) rhs[j1] = g.getTerminal(id).value; else rhs[j1] = r.categories[r.getCategoryByName(g.categories[id].name)];
			}
			var newrule = r.newRule(lhs,rhs,rule.precedence);
			newrule.lhsname = rule.lhsname;
			newrule.rhsnames = rule.rhsnames;
			var props = rule.getProperties();
			if(props != null) {
				var it = props.keys();
				while(it.hasNext()) {
					var key = it.next();
					newrule.setProperty(key,props.get(key));
				}
			}
			newRules.push(newrule);
		}
		r.setRules(newRules);
		r.packRules();
		return r;
	}
	,__class__: com.wiris.chartparsing.GrammarReducedBuilder
}
com.wiris.chartparsing.GrammarSequentialBuilder = $hxClasses["com.wiris.chartparsing.GrammarSequentialBuilder"] = function() {
	com.wiris.chartparsing.GrammarBuilder.call(this);
	this.parsedRules = new Array();
	this.cat = new com.wiris.chartparsing.VectorSet();
	this.imported = new Array();
	this.currentAttributes = new Array();
	this.attributeLevel = -1;
};
com.wiris.chartparsing.GrammarSequentialBuilder.__name__ = ["com","wiris","chartparsing","GrammarSequentialBuilder"];
com.wiris.chartparsing.GrammarSequentialBuilder.__super__ = com.wiris.chartparsing.GrammarBuilder;
com.wiris.chartparsing.GrammarSequentialBuilder.prototype = $extend(com.wiris.chartparsing.GrammarBuilder.prototype,{
	archiveCurrentRule: function() {
		if(this.currentAttributes != null && this.currentAttributes.length > 0) {
			this.currentRule.properties = this.addAllHashes(this.currentAttributes);
			if(this.particularAttribute) {
				this.currentAttributes.pop();
				this.particularAttribute = false;
				--this.attributeLevel;
			}
		}
		if(this.currentTransformation != null) {
			this.currentRule.properties.set("transformation",this.toJavaObjectArray(this.currentTransformation));
			this.currentTransformation = null;
		}
		this.parsedRules.push(this.currentRule);
		this.currentRule = new com.wiris.chartparsing.ParsedRule();
	}
	,addAllHashes: function(ha) {
		var hh = new Hash();
		var i;
		var _g1 = 0, _g = ha.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var h = ha[i1];
			var it = h.keys();
			while(it.hasNext()) {
				var key = it.next();
				hh.set(key,h.get(key));
			}
		}
		return hh;
	}
	,skipBlanks: function() {
		while(this.nextChar() && this.isWhiteSpace()) {
		}
	}
	,toJavaObjectArray: function(a) {
		var aa = new Array();
		var i;
		var _g1 = 0, _g = a.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			aa[i1] = a[i1];
		}
		return aa;
	}
	,toJavaArray: function(a) {
		var aa = new Array();
		var i;
		var _g1 = 0, _g = a.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			aa[i1] = a[i1];
		}
		return aa;
	}
	,nextChar: function() {
		if(this.reuseChar) {
			this.reuseChar = false;
			return true;
		}
		if(this.it.hasNext()) {
			this.current = this.it.next();
			return true;
		}
		this.current = -1;
		return false;
	}
	,contains: function(a,b) {
		var i;
		var _g1 = 0, _g = a.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var aS = a[i1];
			if(b == aS) return true;
		}
		return false;
	}
	,importFile: function(file) {
		if(!this.contains(this.imported,file)) {
			this.imported.push(file);
			var s2 = com.wiris.system.Storage.newStorageWithParent(this.storage.getParent(),file);
			new com.wiris.chartparsing.GrammarSequentialBuilder().importFileFromStorage(s2,this.parsedRules,this.cat,this.imported,this.currentAttributes);
		}
	}
	,isWhiteSpace: function() {
		return this.current == com.wiris.util.xml.SAXParser.CHAR_SPACE || this.current == com.wiris.util.xml.SAXParser.CHAR_TAB;
	}
	,isLineBreak: function() {
		if(this.current == com.wiris.util.xml.SAXParser.CHAR_LINE_FEED) return true;
		if(this.current == com.wiris.util.xml.SAXParser.CHAR_CARRIAGE_RETURN) {
			if(this.nextChar() && this.current != com.wiris.util.xml.SAXParser.CHAR_LINE_FEED) this.reuseChar = true;
			return true;
		}
		return false;
	}
	,getWord: function() {
		var s = new StringBuf();
		if(this.current != -1) s.b += String.fromCharCode(this.current);
		while(this.nextChar() && !this.isLineBreak() && !this.isWhiteSpace()) s.b += String.fromCharCode(this.current);
		this.reuseChar = true;
		return s.b;
	}
	,setRulesArray: function() {
		this.rules = new Array();
		var i;
		var _g1 = 0, _g = this.parsedRules.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var rule = this.newRule6(this.parsedRules[i1].lhs,this.toJavaArray(this.parsedRules[i1].rhs));
			rule.properties = this.parsedRules[i1].properties;
			if(rule.properties != null) rule.isOptional = rule.properties.exists("optional");
			this.rules[i1] = rule;
		}
	}
	,setCategoriesArray: function() {
		var catVector = this.cat.getVector();
		this.categories = new Array();
		var i;
		var _g1 = 0, _g = catVector.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			this.categories[i1] = new com.wiris.chartparsing.Category(catVector[i1]);
		}
	}
	,parsedRules2Grammar: function() {
		this.setCategoriesArray();
		this.packCategories();
		this.setRulesArray();
		this.packRules();
	}
	,parseLhs: function(word) {
		if(word == "::=") this.state = com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_RHS; else {
			this.cat.push(word);
			this.currentRule.lhs = word;
		}
	}
	,parse: function() {
		this.state = com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING;
		this.it = com.wiris.system.Utf8.getIterator(this.s);
		this.currentRule = new com.wiris.chartparsing.ParsedRule();
		while(this.nextChar()) if(this.current == com.wiris.util.xml.SAXParser.CHAR_HASH) while(this.nextChar() && !this.isLineBreak()) {
		} else if(this.current == com.wiris.util.xml.SAXParser.CHAR_AT) {
			this.nextChar();
			var word = this.getWord();
			if(word == "import") this.state = com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_IMPORT;
		} else if(this.isWhiteSpace()) continue; else if(this.isLineBreak()) {
			if(this.state == com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_ATTRIBUTES) {
				this.state = com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING;
				continue;
			} else if(this.state == com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_RHS) this.state = com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING;
			if(this.currentRule.lhs == null) continue;
			this.archiveCurrentRule();
		} else if(this.current == com.wiris.util.xml.SAXParser.CHAR_OPEN_BRACKET) {
			if(this.state == com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_ATTRIBUTES || this.state == com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING && this.currentAttributes.length > 0) {
				this.state = com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING;
				this.particularAttribute = false;
			} else if(this.state == com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_RHS) {
				this.state = com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_RESULT;
				this.currentTransformation = new Array();
			}
		} else if(this.current == com.wiris.util.xml.SAXParser.CHAR_CLOSE_BRACKET) {
			if(this.state == com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_RESULT) this.state = com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING; else {
				this.state = com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING;
				this.currentAttributes.pop();
				--this.attributeLevel;
				this.particularAttribute = false;
			}
		} else {
			var word = this.getWord();
			if(this.state == com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_IMPORT) {
				this.importFile(word);
				this.state = com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING;
			} else if(this.state == com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING) {
				if(word == "attributes") {
					this.state = com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_ATTRIBUTES;
					++this.attributeLevel;
					this.currentAttributes.push(new Hash());
					this.particularAttribute = true;
				} else this.parseLhs(word);
			} else if(this.state == com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_ATTRIBUTES) {
				if(word == "=") {
					this.skipBlanks();
					var value = this.getWord();
					this.currentAttributes[this.attributeLevel].set(this.lastAttribute,value);
				} else {
					this.currentAttributes[this.attributeLevel].set(word,"true");
					this.lastAttribute = word;
				}
			} else if(this.state == com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_RHS) this.currentRule.rhs.push(word); else if(this.state == com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_RESULT) this.currentTransformation.push(word);
		}
		if(this.currentRule.lhs != null) this.archiveCurrentRule();
	}
	,loadStorage: function(storage) {
		this.storage = storage;
		this.s = storage.read();
		this.load();
	}
	,loadString: function(s) {
		this.s = s;
		this.load();
	}
	,load: function() {
		this.parse();
		this.parsedRules2Grammar();
	}
	,importFileFromStorage: function(storage,rules,cat,imported,attributes) {
		if(cat != null) this.cat = cat;
		if(rules != null) this.parsedRules = rules;
		if(imported != null) this.imported = imported;
		if(attributes != null) {
			this.currentAttributes = attributes;
			this.attributeLevel = this.currentAttributes.length - 1;
		}
		this.storage = storage;
		if(storage != null) {
			this.s = storage.read();
			this.parse();
		}
	}
	,currentRule: null
	,lastAttribute: null
	,currentTransformation: null
	,currentAttributes: null
	,cat: null
	,parsedRules: null
	,storage: null
	,attributeLevel: null
	,particularAttribute: null
	,imported: null
	,state: null
	,reuseChar: null
	,current: null
	,it: null
	,s: null
	,__class__: com.wiris.chartparsing.GrammarSequentialBuilder
});
com.wiris.chartparsing.Logger = $hxClasses["com.wiris.chartparsing.Logger"] = function() { }
com.wiris.chartparsing.Logger.__name__ = ["com","wiris","chartparsing","Logger"];
com.wiris.chartparsing.Logger.finest = function(str) {
	if(!com.wiris.chartparsing.Logger.silent) {
		if(com.wiris.chartparsing.Logger.buffer == null) com.wiris.chartparsing.Logger.buffer = new StringBuf();
		com.wiris.chartparsing.Logger.buffer.b += Std.string(str);
	}
}
com.wiris.chartparsing.Logger.finestInt = function(n) {
	com.wiris.chartparsing.Logger.finest("" + n);
}
com.wiris.chartparsing.Logger.finestEmpty = function() {
	com.wiris.chartparsing.Logger.finest("");
}
com.wiris.chartparsing.Logger.finestln = function(str) {
	if(!com.wiris.chartparsing.Logger.silent) {
		if(com.wiris.chartparsing.Logger.buffer != null) {
			com.wiris.chartparsing.Logger.buffer.b += Std.string(str);
			console.log(com.wiris.chartparsing.Logger.buffer.b);
			com.wiris.chartparsing.Logger.buffer = null;
		} else console.log(str);
	}
}
com.wiris.chartparsing.Logger.finestlnInt = function(n) {
	com.wiris.chartparsing.Logger.finestln("" + n);
}
com.wiris.chartparsing.Logger.finestlnEmpty = function() {
	com.wiris.chartparsing.Logger.finestln("");
}
com.wiris.chartparsing.Logger.setEnabled = function(b) {
	com.wiris.chartparsing.Logger.silent = !b;
}
com.wiris.chartparsing.ParsedRule = $hxClasses["com.wiris.chartparsing.ParsedRule"] = function() {
	this.rhs = new Array();
	this.properties = new Hash();
};
com.wiris.chartparsing.ParsedRule.__name__ = ["com","wiris","chartparsing","ParsedRule"];
com.wiris.chartparsing.ParsedRule.prototype = {
	properties: null
	,rhs: null
	,name: null
	,lhs: null
	,__class__: com.wiris.chartparsing.ParsedRule
}
com.wiris.chartparsing.ParserResult = $hxClasses["com.wiris.chartparsing.ParserResult"] = function(chart,grammar,goalCategory,tokens) {
	this.goalCategory = goalCategory;
	this.chart = chart;
	this.grammar = grammar;
	this.tokens = tokens;
	this.goal = grammar.getCategoryByName(goalCategory);
	this.ct = new com.wiris.chartparsing.ChartTree(grammar,this.goal,chart);
	this.resultEdge = chart.findEdgeWithCategory(0,chart.getNVertices() - 1,this.goal);
};
com.wiris.chartparsing.ParserResult.__name__ = ["com","wiris","chartparsing","ParserResult"];
com.wiris.chartparsing.ParserResult.getNiceErrorImpl = function(trace,tokens,a,b,errorMessage,expected) {
	var tok = tokens;
	var first;
	var sb = new StringBuf();
	first = true;
	while(tok != null) {
		var parent = tok.getParent();
		var str = sb.b;
		if(str.length > 0) sb.b += Std.string("\n");
		if(first) {
			first = false;
			var further = a;
			trace.push([a,b]);
			if(errorMessage != null) sb.b += Std.string(errorMessage);
			var fs = null;
			if(further != tok.getVector().length) {
				var obj = tok.getVector()[further];
				if(js.Boot.__instanceof(obj,String)) fs = "'" + Std.string(obj) + "'"; else fs = "\"" + Std.string(obj) + "\"";
			}
			if(expected != null) {
				sb.b += Std.string("Expected any of ");
				var i;
				var _g1 = 0, _g = expected.length;
				while(_g1 < _g) {
					var i1 = _g1++;
					if(i1 > 0) sb.b += Std.string(", ");
					sb.b += Std.string(expected[i1]);
				}
				if(fs != null) sb.b += Std.string(" but found symbol " + fs);
			} else if(fs != null) sb.b += Std.string("Unexpected symbol " + fs);
			sb.b += Std.string(".");
			if(parent == null) {
				if(further == tok.getVector().length) sb.b += Std.string(" By the end of input."); else sb.b += Std.string(" At " + tok.toStringPosition(a,b));
			} else {
				var n = tok.getVector().length;
				sb.b += Std.string(" At string: ");
				var i;
				var _g = 0;
				while(_g < n) {
					var i1 = _g++;
					if(i1 > 0) sb.b += Std.string(" ");
					if(i1 == a) sb.b += Std.string(">>>>>>>> ");
					if(i1 == b) sb.b += Std.string("<<<<<<<< ");
					sb.b += Std.string(tok.getVector()[i1]);
				}
			}
		} else {
			sb.b += Std.string("Error at ");
			if(a == tok.getVector().length) sb.b += Std.string("end of input."); else sb.b += Std.string(tok.toStringPosition(a,b));
		}
		var ps = tok.getParentPositions(a,b);
		if(ps != null) {
			a = ps[0];
			b = ps[1];
			trace.push([a,b]);
		}
		tok = parent;
	}
	return sb.b;
}
com.wiris.chartparsing.ParserResult.prototype = {
	getResultEdge: function() {
		return this.resultEdge;
	}
	,toString2: function(cn) {
		return this.ct.toString3(cn,this.tokens,0);
	}
	,toString: function(cn) {
		return com.wiris.chartparsing.ChartTree.toString2(cn,this.tokens);
	}
	,getException: function() {
		var trace = new Array();
		var cpe = this.chart.getLastError();
		if(cpe != null && js.Boot.__instanceof(cpe,com.wiris.chartparsing.SyntaxErrorException)) {
			var see = cpe;
			var ts = see.getTopPositions();
			console.log(cpe.getMessage());
			var str = com.wiris.chartparsing.ParserResult.getNiceErrorImpl(trace,this.tokens,ts[0],ts[1],null,null);
			return new com.wiris.chartparsing.SyntaxErrorException(str,trace);
		}
		if(cpe != null) return cpe;
		return new com.wiris.chartparsing.SyntaxErrorException(this.getNiceError(trace),trace);
	}
	,getTransformer: function() {
		return new com.wiris.chartparsing.Transformer(this.tokens,this.grammar,this.getTree());
	}
	,getTopPositions: function() {
		var tok = this.tokens;
		var further = this.getFurtherToken();
		var ps = [further,further + 1];
		while(tok != null) {
			ps = tok.getParentPositions(ps[0],ps[1]);
			tok = tok.getParent();
		}
		return ps;
	}
	,getNiceError: function(trace) {
		if(this.tokens != null) {
			var further = this.getFurtherToken();
			var a, b;
			a = further;
			b = further + 1;
			var expected = this.getExpected();
			return com.wiris.chartparsing.ParserResult.getNiceErrorImpl(trace,this.tokens,a,b,null,expected);
		}
		return "Syntax error.";
	}
	,getExpected: function() {
		var j, k;
		var ea = null;
		if(this.parserFinished()) return null;
		var vsymbols;
		vsymbols = this.chart.getExpectedTerminals();
		if(!com.wiris.chartparsing.Chart2.OPTIMIZATION1) {
			vsymbols = new com.wiris.chartparsing.VectorSet();
			k = this.getFurtherToken();
			ea = this.chart.getUncompleteWithGap(k);
			if(ea != null) {
				var _g1 = 0, _g = ea.n;
				while(_g1 < _g) {
					var j1 = _g1++;
					var e = ea.array[j1];
					var r = this.grammar.rules[e.rule];
					var cat = r.rhs[e.dot];
					if(cat < com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) {
					} else {
						var t = this.grammar.terminal[cat - com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID];
						if(js.Boot.__instanceof(t.value,String)) vsymbols.push("'" + Std.string(t) + "'"); else vsymbols.push("\"" + Std.string(t) + "\"");
					}
				}
			}
		}
		var resultArray = vsymbols.getVector();
		var result = new Array();
		result = resultArray.slice();
		return result;
	}
	,getFurtherToken: function() {
		var i, n;
		var ea = null;
		n = this.chart.getNVertices() - 1;
		if(this.parserFinished()) return n;
		var tokens = this.tokens.getVector();
		i = n;
		while(i > 0) {
			ea = this.chart.getUncompleteWithGap(i);
			if(ea != null && ea.n > 0) {
				var j;
				var max = 0;
				var _g1 = 0, _g = ea.n;
				while(_g1 < _g) {
					var j1 = _g1++;
					var e = ea.array[j1];
					var r = this.grammar.rules[e.rule];
					var k;
					var count = 0;
					var _g3 = e.dot, _g2 = r.rhs.length;
					while(_g3 < _g2) {
						var k1 = _g3++;
						if(this.grammar.isTerminalCategory(r.rhs[k1])) {
							var t = this.grammar.getTerminal(r.rhs[k1]);
							var candidate = tokens[i + count];
							if(t.isValueEqual(candidate)) {
								count++;
								if(max < count) max = count;
							} else break;
						}
					}
				}
				return i + max;
			}
			i--;
		}
		return i;
	}
	,parserFinished: function() {
		return this.resultEdge != null && this.chart.getLastError() == null;
	}
	,getTree: function() {
		var cn;
		cn = this.ct.getTree(this.resultEdge);
		return cn;
	}
	,tokens: null
	,goal: null
	,ct: null
	,resultEdge: null
	,grammar: null
	,chart: null
	,goalCategory: null
	,__class__: com.wiris.chartparsing.ParserResult
}
com.wiris.chartparsing.PriorityAmbiguitiesHandler = $hxClasses["com.wiris.chartparsing.PriorityAmbiguitiesHandler"] = function() {
};
com.wiris.chartparsing.PriorityAmbiguitiesHandler.__name__ = ["com","wiris","chartparsing","PriorityAmbiguitiesHandler"];
com.wiris.chartparsing.PriorityAmbiguitiesHandler.__interfaces__ = [com.wiris.chartparsing.AmbiguitiesHandler];
com.wiris.chartparsing.PriorityAmbiguitiesHandler.getBooleanAttribute = function(r,name) {
	var o = r.getProperty(name);
	if(o != null) return "true" == o;
	return false;
}
com.wiris.chartparsing.PriorityAmbiguitiesHandler.prototype = {
	disambiguate: function(e0,e1,tdp) {
		var g = tdp.getGrammar();
		var r1 = g.rules[e0.rule];
		var r2 = g.rules[e1.rule];
		var o1 = r1.getProperty("priority");
		var o2 = r2.getProperty("priority");
		if(o1 == null) o1 = "0";
		if(o2 == null) o2 = "0";
		var p1 = Std.parseInt(o1);
		var p2 = Std.parseInt(o2);
		var b = p1 - p2;
		if(b < 0) return com.wiris.chartparsing.Constants.LOWER;
		if(b > 0) return com.wiris.chartparsing.Constants.GREATER;
		var dpah = new com.wiris.chartparsing.DeepPriorityAmbiguitiesHandler();
		var c = dpah.disambiguate(e0,e1,tdp);
		if(c != com.wiris.chartparsing.Constants.UNKNOWN) return c;
		var left = false, right = false;
		b = e0.end0 - e1.end0;
		left = com.wiris.chartparsing.PriorityAmbiguitiesHandler.getBooleanAttribute(r1,"left_associative");
		if(com.wiris.chartparsing.PriorityAmbiguitiesHandler.getBooleanAttribute(r2,"left_associative") != left) return com.wiris.chartparsing.Constants.UNKNOWN;
		right = com.wiris.chartparsing.PriorityAmbiguitiesHandler.getBooleanAttribute(r1,"right_associative");
		if(com.wiris.chartparsing.PriorityAmbiguitiesHandler.getBooleanAttribute(r2,"right_associative") != right) return com.wiris.chartparsing.Constants.UNKNOWN;
		if(left != right) {
			if(b < 0) return left?com.wiris.chartparsing.Constants.LOWER:com.wiris.chartparsing.Constants.GREATER; else if(b > 0) return left?com.wiris.chartparsing.Constants.GREATER:com.wiris.chartparsing.Constants.LOWER;
		}
		return com.wiris.chartparsing.Constants.UNKNOWN;
	}
	,__class__: com.wiris.chartparsing.PriorityAmbiguitiesHandler
}
com.wiris.chartparsing.Rule = $hxClasses["com.wiris.chartparsing.Rule"] = function(lhs,rhs,prec) {
	this.lhs = lhs;
	this.rhs = rhs;
	this.precedence = prec;
	this.isOptional = false;
};
com.wiris.chartparsing.Rule.__name__ = ["com","wiris","chartparsing","Rule"];
com.wiris.chartparsing.Rule.newRule = function(lhs,lhsname,rhs,rhsnames,prec) {
	var rule = new com.wiris.chartparsing.Rule(lhs,rhs,prec);
	rule.isOptional = false;
	rule.lhsname = lhsname;
	rule.rhsnames = rhsnames;
	return rule;
}
com.wiris.chartparsing.Rule.isNonTerminal = function(n) {
	return n < com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID;
}
com.wiris.chartparsing.Rule.prototype = {
	getProperties: function() {
		return this.properties;
	}
	,buildPropertyImpl: function() {
		if(this.properties == null) this.properties = new Hash();
		return this.properties;
	}
	,getPropertyImpl: function() {
		if(this.properties == null) return com.wiris.chartparsing.Rule.staticProperties; else return this.properties;
	}
	,getProperty: function(name) {
		return this.getPropertyImpl().get(name);
	}
	,setProperty: function(name,value) {
		this.buildPropertyImpl().set(name,value);
		if(name == "optional") this.isOptional = true;
	}
	,isOptional: null
	,properties: null
	,precedence: null
	,rhsnames: null
	,rhs: null
	,lhsname: null
	,lhs: null
	,id: null
	,__class__: com.wiris.chartparsing.Rule
}
com.wiris.chartparsing.RuleFilterHandler = $hxClasses["com.wiris.chartparsing.RuleFilterHandler"] = function() { }
com.wiris.chartparsing.RuleFilterHandler.__name__ = ["com","wiris","chartparsing","RuleFilterHandler"];
com.wiris.chartparsing.RuleFilterHandler.prototype = {
	filter: null
	,__class__: com.wiris.chartparsing.RuleFilterHandler
}
com.wiris.chartparsing.SymbolNode = $hxClasses["com.wiris.chartparsing.SymbolNode"] = function() {
	this.complete = new com.wiris.chartparsing.EdgeArray();
	this.uncomplete = new com.wiris.chartparsing.EdgeArray();
};
com.wiris.chartparsing.SymbolNode.__name__ = ["com","wiris","chartparsing","SymbolNode"];
com.wiris.chartparsing.SymbolNode.prototype = {
	uncomplete: null
	,complete: null
	,considered: null
	,__class__: com.wiris.chartparsing.SymbolNode
}
com.wiris.chartparsing.SyntaxErrorException = $hxClasses["com.wiris.chartparsing.SyntaxErrorException"] = function(str,trace) {
	com.wiris.chartparsing.ChartParsingException.call(this,str);
	this.trace = trace;
};
com.wiris.chartparsing.SyntaxErrorException.__name__ = ["com","wiris","chartparsing","SyntaxErrorException"];
com.wiris.chartparsing.SyntaxErrorException.newSyntaxErrorException = function(str,a,b) {
	var trace = new Array();
	trace.push([a,b]);
	return new com.wiris.chartparsing.SyntaxErrorException(str,trace);
}
com.wiris.chartparsing.SyntaxErrorException.__super__ = com.wiris.chartparsing.ChartParsingException;
com.wiris.chartparsing.SyntaxErrorException.prototype = $extend(com.wiris.chartparsing.ChartParsingException.prototype,{
	getShortMessage: function() {
		if(this.trace == null) return this.getMessage();
		var msg = this.getMessage();
		msg = StringTools.replace(msg,"\r\n"," ");
		msg = StringTools.replace(msg,"\r"," ");
		msg = StringTools.replace(msg,"\n"," ");
		var sb = new StringBuf();
		sb.b += Std.string("Syntax error");
		var e = new EReg(".*characters from (\\d+) to (\\d+).*","");
		var e2 = new EReg(".*characters from \\(line (\\d+), column (\\d+)\\) to \\(line (\\d+), column (\\d+)\\).*","");
		var e3 = new EReg(".*but found symbol ['\"]([^'\"]*)['\"].*","");
		if(e.match(msg)) {
			sb.b += Std.string(" from character ");
			sb.b += Std.string(e.matched(1));
			sb.b += Std.string(" to character ");
			sb.b += Std.string(e.matched(2));
			sb.b += Std.string(".");
		} else if(e2.match(msg)) {
			sb.b += Std.string(" from line ");
			sb.b += Std.string(e2.matched(1));
			sb.b += Std.string(" column ");
			sb.b += Std.string(e2.matched(2));
			sb.b += Std.string(" to line ");
			sb.b += Std.string(e2.matched(3));
			sb.b += Std.string(" column ");
			sb.b += Std.string(e2.matched(4));
			sb.b += Std.string(".");
		} else if(msg.indexOf("by the end of input") != -1) sb.b += Std.string(" at the end of the input."); else sb.b += Std.string(".");
		if(e3.match(msg)) {
			sb.b += Std.string(" Unexpected '");
			sb.b += Std.string(e3.matched(1));
			sb.b += Std.string("'.");
		}
		return sb.b;
	}
	,getTopPositions: function() {
		if(this.trace == null) return null;
		return this.trace[this.trace.length - 1];
	}
	,getTrace: function() {
		return this.trace;
	}
	,trace: null
	,__class__: com.wiris.chartparsing.SyntaxErrorException
});
com.wiris.chartparsing.Terminal = $hxClasses["com.wiris.chartparsing.Terminal"] = function() {
};
com.wiris.chartparsing.Terminal.__name__ = ["com","wiris","chartparsing","Terminal"];
com.wiris.chartparsing.Terminal.compareTokens = function(a,b) {
	if(js.Boot.__instanceof(a,com.wiris.tokens.XMLToken) && js.Boot.__instanceof(b,com.wiris.tokens.XMLToken)) {
		var x = a;
		return x.isEqual(b);
	} else return a != null && a == b || a == null && b == null;
}
com.wiris.chartparsing.Terminal.prototype = {
	isValueEqual: function(o) {
		return com.wiris.chartparsing.Terminal.compareTokens(this.value,o);
	}
	,isSingleton: function() {
		return this.javaClass == null;
	}
	,toString: function() {
		return this.value.toString();
	}
	,javaClass: null
	,value: null
	,id: null
	,__class__: com.wiris.chartparsing.Terminal
}
com.wiris.chartparsing.TopDownParser = $hxClasses["com.wiris.chartparsing.TopDownParser"] = function() {
	this.ambiguitiesHandlerChain = new Array();
	this.ruleFilterHandlerChain = new Array();
	this.cc = new com.wiris.chartparsing.CategoryChooser();
};
com.wiris.chartparsing.TopDownParser.__name__ = ["com","wiris","chartparsing","TopDownParser"];
com.wiris.chartparsing.TopDownParser.newTopDownParser = function(g,goal) {
	return new com.wiris.chartparsing.TopDownParser2(g,goal);
}
com.wiris.chartparsing.TopDownParser.prototype = {
	tokensToString: function() {
		var sb = new StringBuf();
		var tokens = this.getTokens();
		if(tokens == null) return "";
		var v = tokens.getVector();
		if(v == null) return "";
		var i;
		var _g1 = 0, _g = v.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			sb.b += Std.string("(" + i1 + "," + (i1 + 1) + ") ");
			sb.b += Std.string(v[i1]);
			sb.b += Std.string("\n");
		}
		return sb.b;
	}
	,filter: function(r) {
		var n = this.ruleFilterHandlerChain.length;
		var i;
		var _g = 0;
		while(_g < n) {
			var i1 = _g++;
			var rfh = this.ruleFilterHandlerChain[i1];
			var b = rfh.filter(r,this);
			if(b != com.wiris.chartparsing.Constants.UNKNOWN) return b == 1;
		}
		return true;
	}
	,disambiguate: function(e0,e1) {
		var n = this.ambiguitiesHandlerChain.length;
		var i;
		var _g = 0;
		while(_g < n) {
			var i1 = _g++;
			var ah = this.ambiguitiesHandlerChain[i1];
			var b = ah.disambiguate(e0,e1,this);
			if(b != com.wiris.chartparsing.Constants.UNKNOWN) return b;
		}
		return com.wiris.chartparsing.Constants.UNKNOWN;
	}
	,setEdgeLimit: function(chartEdgeLimit) {
		throw "Not implemented.";
	}
	,setCategoryChooser: function(cc) {
		this.cc = cc;
	}
	,setRuleFilterHandler: function(handler) {
		this.ruleFilterHandlerChain.splice(0,0,handler);
	}
	,setAmbiguitiesHandler: function(handler) {
		this.ambiguitiesHandlerChain.splice(0,0,handler);
	}
	,lexicalLookup: function(tokens) {
		var t;
		var i;
		var variable;
		var integer;
		var empty;
		var tokenVector = tokens.getVector();
		var g = this.getGrammar();
		variable = g.getCategoryByName("variable");
		integer = g.getCategoryByName("integer");
		empty = g.getCategoryByName("empty");
		var _g1 = 0, _g = tokenVector.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			t = tokenVector[i1];
			var cs = this.cc.getCategories(t,g);
			if(cs == null) throw com.wiris.chartparsing.SyntaxErrorException.newSyntaxErrorException("No category found for token \"" + Std.string(t) + "\".",i1,i1 + 1);
			var j;
			var _g3 = 0, _g2 = cs.length;
			while(_g3 < _g2) {
				var j1 = _g3++;
				this.addTerminal(i1,i1 + 1,cs[j1]);
			}
			if(empty >= 0) this.addTerminal(i1,i1,empty);
		}
	}
	,addTerminal: function(i,j,category) {
		throw "This method is abstract. It must be implemented.";
	}
	,showStatistics: function() {
		throw "This method is abstract. It must be implemented.";
	}
	,getNIterations: function() {
		throw "This method is abstract. It must be implemented.";
		return 0;
	}
	,getGoal: function() {
		throw "This method is abstract. It must be implemented.";
		return 0;
	}
	,parse: function(t) {
		throw "This method is abstract. It must be implemented.";
	}
	,getGrammar: function() {
		throw "This method is abstract. It must be implemented.";
		return null;
	}
	,getResultTree: function() {
		throw "This method is abstract. It must be implemented.";
		return null;
	}
	,getTokens: function() {
		throw "This method is abstract. It must be implemented.";
		return null;
	}
	,getChart: function() {
		throw "This method is abstract. It must be implemented.";
		return null;
	}
	,cc: null
	,ruleFilterHandlerChain: null
	,ambiguitiesHandlerChain: null
	,__class__: com.wiris.chartparsing.TopDownParser
}
com.wiris.chartparsing.TopDownParser2 = $hxClasses["com.wiris.chartparsing.TopDownParser2"] = function(g,goal_category) {
	this.withPrecedence = true;
	com.wiris.chartparsing.TopDownParser.call(this);
	this.pending = new Array();
	this.g = g;
	this.sgoal = goal_category;
	this.goal = g.getCategoryByName(goal_category);
	this.maxEdges = -1;
};
com.wiris.chartparsing.TopDownParser2.__name__ = ["com","wiris","chartparsing","TopDownParser2"];
com.wiris.chartparsing.TopDownParser2.__super__ = com.wiris.chartparsing.TopDownParser;
com.wiris.chartparsing.TopDownParser2.prototype = $extend(com.wiris.chartparsing.TopDownParser.prototype,{
	profileInfo: function() {
		var sb = new StringBuf();
		sb.b += Std.string("=== Grammar info ===\r\n");
		sb.b += Std.string("Number of rules: " + this.g.rules.length + "\r\n");
		sb.b += Std.string("Number of categories: " + this.g.categories.length + "\r\n");
		sb.b += Std.string("Number of terminal symbols: " + this.g.terminal.length + "\r\n");
		sb.b += Std.string("=== Chart info ===\r\n");
		sb.b += Std.string("Number of tokens: " + this.tokens.getVector().length + "\r\n");
		sb.b += Std.string("Parse time: " + this.milli + " ms\r\n");
		sb.b += Std.string("Number of iterations: " + this.counter + "\r\n");
		sb.b += Std.string("Number of complete edges: " + this.chart.count(true) + "\r\n");
		sb.b += Std.string("Number of uncomplete edges: " + this.chart.count(false) + "\r\n");
		sb.b += Std.string("=== Grammar ===\r\n");
		sb.b += Std.string(this.g);
		sb.b += Std.string("=== Grammar (right recursions) ===\r\n");
		sb.b += Std.string(this.g.getRightRecursions());
		sb.b += Std.string("=== Chart ===\r\n");
		sb.b += Std.string(this.chart.toString());
		return sb.b;
	}
	,getNIterations: function() {
		return this.counter;
	}
	,setEdgeLimit: function(chartEdgeLimit) {
		this.maxEdges = chartEdgeLimit;
	}
	,tokensToString: function() {
		var sb = new StringBuf();
		if(this.tokens == null) return "";
		var v = this.tokens.getVector();
		if(v == null) return "";
		var i;
		var _g1 = 0, _g = v.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			sb.b += Std.string("(" + i1 + "," + (i1 + 1) + ") ");
			sb.b += Std.string(v[i1]);
			sb.b += Std.string("\n");
		}
		return sb.b;
	}
	,depends: function(e,e0) {
		var vec = new Array();
		var done;
		var child;
		child = e;
		do {
			done = true;
			var i = 0;
			var found = false;
			while(i < vec.length && !found) {
				if(child.isEqual(vec[i])) found = true;
				i++;
			}
			if(!found) {
				if(child == e0) return true;
				done = false;
				vec.push(child);
			}
			child = this.chart.getEdge(child.edge1);
		} while(!done);
		return false;
	}
	,topDown: function(B,stop) {
		if(B >= com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) return;
		var rs = this.g.ruleByCategory[B];
		var i;
		var _g1 = 0, _g = rs.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var r = rs[i1];
			var f = this.filterRules[r.id];
			if(f == 0) {
				var b = this.filter(r);
				if(b) f = 1; else f = -1;
				this.filterRules[r.id] = f;
			}
			if(f == 1) {
				if(com.wiris.chartparsing.TopDownParser2.DELAY_ADD) {
					var e = new com.wiris.chartparsing.Edge(stop,stop,r.id,0,r.precedence);
					this.addPending(e);
				} else this.addEdge(stop,stop,r.id,0,r.precedence);
			}
		}
	}
	,equalsEdge: function(e1,e2) {
		if(!e1.isEqual(e2)) return false;
		if(e1.start0 != e2.start0 || e1.start1 != e2.start1 || e1.end0 != e2.end0 || e1.end1 != e2.end1) return false;
		return true;
	}
	,check: function(e,ea) {
		if(ea != null) {
			var i;
			var _g1 = 0, _g = ea.n;
			while(_g1 < _g) {
				var i1 = _g1++;
				var e0 = ea.array[i1];
				if(this.equalsEdge(e0,e)) return true;
			}
		}
		return false;
	}
	,checkUncomplete: function(e) {
		var ea = this.chartClassic.getUncomplete(e.start,e.stop);
		if(!this.check(e,ea)) throw "Edge not found.";
	}
	,checkComplete: function(e) {
		var ea = this.chartClassic.getComplete(e.start,e.stop);
		if(!this.check(e,ea)) throw "Edge not found.";
	}
	,addPending: function(e) {
		if(com.wiris.chartparsing.TopDownParser2.CHECK_DURING) {
			var ea0 = this.chartClassic.getComplete(e.start,e.stop);
			var ea1 = this.chartClassic.getUncomplete(e.start,e.stop);
			if(!this.check(e,ea0) && !this.check(e,ea1)) throw "Edge not found.";
		}
		if(com.wiris.chartparsing.TopDownParser2.SORT_PENDING) {
			var i = this.pending.length - 1;
			if(i >= 0) {
				var e0 = this.pending[i];
				while(i >= 0 && e0.stop < e.stop) {
					i--;
					if(i >= 0) e0 = this.pending[i];
				}
			}
			i++;
			this.pending.splice(i,0,e);
		} else this.pending.push(e);
	}
	,showPending: function() {
		com.wiris.chartparsing.Logger.finestln("Pending:");
		var i;
		var _g1 = 0, _g = this.pending.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var e = this.pending[i1];
			com.wiris.chartparsing.Chart.staticShow(this.g,e);
		}
	}
	,getGoal: function() {
		return this.goal;
	}
	,getGrammar: function() {
		return this.g;
	}
	,topDownExpandCondition: function(i,B) {
		var cons;
		cons = this.chart.isConsidered(i,B);
		if(!cons) this.chart.setConsidering(i,B,true);
		return !cons;
	}
	,getResultTree: function() {
		var goalName = this.goal != -1?this.g.categories[this.goal].name:null;
		return new com.wiris.chartparsing.ParserResult(this.getChart(),this.g,goalName,this.getTokens());
	}
	,getTokens: function() {
		return this.tokens;
	}
	,getChart: function() {
		return this.chart;
	}
	,showStatistics: function() {
		com.wiris.chartparsing.Logger.finest("" + this.ticks);
		com.wiris.chartparsing.Logger.finestln(" ms");
		com.wiris.chartparsing.Logger.finestln("Ambiguities: " + this.ambiguities);
	}
	,addEdgeImpl: function(e) {
		if(e.isComplete(this.g)) {
			var lhs = e.getLhs(this.g);
			var ea = this.chart.getCompleteWithStart(e.start,lhs);
			if(ea != null) {
				var i;
				var _g1 = 0, _g = ea.n;
				while(_g1 < _g) {
					var i1 = _g1++;
					var e0;
					e0 = ea.array[i1];
					if(e0.stop == e.stop) {
						if(e.isEqual(e0)) return null;
						var b = this.disambiguate(e,e0);
						if(b == com.wiris.chartparsing.Constants.GREATER) {
							if(this.depends(e,e0)) {
								com.wiris.chartparsing.Chart.staticShow(this.g,e);
								com.wiris.chartparsing.Chart.staticShow(this.g,e0);
								return null;
							}
							if(com.wiris.chartparsing.TopDownParser2.CHECK_DURING) this.checkComplete(e);
							ea.array[i1] = e;
							this.chart.changeNotify(e0.id,e);
							return e;
						} else if(b == com.wiris.chartparsing.Constants.LOWER) return null; else {
							if(this.depends(e,e0)) return null;
							if(this.depends(e0,e)) {
								ea.array[i1] = e;
								this.chart.changeNotify(e0.id,e);
								return e;
							}
							throw com.wiris.chartparsing.SyntaxErrorException.newSyntaxErrorException("Ambiguity found. " + com.wiris.chartparsing.Chart.toString2(this.g,e,0) + " width " + com.wiris.chartparsing.Chart.toString2(this.g,e0,0),e.start,e.stop);
						}
					}
				}
			}
			if(com.wiris.chartparsing.TopDownParser2.CHECK_DURING) this.checkComplete(e);
			e = this.chart.addCompleteWithStart(lhs,e);
		} else {
			var B = e.getDotSymbol(this.g);
			if(com.wiris.chartparsing.TopDownParser2.CHECK_DURING) this.checkUncomplete(e);
			e = this.chart.addUncompleteWithGap(B,e);
		}
		if(!com.wiris.chartparsing.TopDownParser2.DELAY_ADD) {
			if(e != null) this.addPending(e);
		}
		return e;
	}
	,addEdge: function(start,end,rule,gap,prec) {
		var e;
		e = new com.wiris.chartparsing.Edge(start,end,rule,gap,prec);
		return this.addEdgeImpl(e);
	}
	,addTerminal: function(i,j,category) {
		this.chart.addTerminal(i,j,category);
	}
	,fundamentalRule: function(e1,e2) {
		var prec;
		prec = e1.precedence;
		var rule1 = this.g.rules[e1.rule];
		if(prec == 0 && rule1.rhs.length == 1) prec = e2.precedence;
		var s;
		if(com.wiris.chartparsing.TopDownParser2.DELAY_ADD) {
			s = new com.wiris.chartparsing.Edge(e1.start,e2.stop,e1.rule,e1.dot + 1,prec);
			if(s != null) {
				s.start0 = e1.start;
				s.end0 = e1.stop;
				s.edge0 = e1.id;
				s.start1 = e2.start;
				s.end1 = e2.stop;
				s.edge1 = e2.id;
				s.update();
			}
			this.addPending(s);
		} else {
			s = this.addEdge(e1.start,e2.stop,e1.rule,e1.dot + 1,prec);
			if(s != null) {
				s.start0 = e1.start;
				s.end0 = e1.stop;
				s.edge0 = e1.id;
				s.start1 = e2.start;
				s.end1 = e2.stop;
				s.edge1 = e2.id;
				s.update();
			}
		}
	}
	,process: function(e) {
		if(com.wiris.chartparsing.TopDownParser2.DELAY_ADD) {
			e = this.addEdgeImpl(e);
			if(e == null) return;
		}
		var e1, e2;
		if(e.isComplete(this.g)) {
			var lhs = e.getLhs(this.g);
			var ea = this.chart.getUncompleteWithGap2(e.start,lhs);
			e2 = e;
			var i;
			var _g1 = 0, _g = ea.n;
			while(_g1 < _g) {
				var i1 = _g1++;
				e1 = ea.array[i1];
				this.fundamentalRule(e1,e2);
			}
		} else {
			var B = e.getDotSymbol(this.g);
			var ea = this.chart.getCompleteWithStart(e.stop,B);
			e1 = e;
			var i;
			var _g1 = 0, _g = ea.n;
			while(_g1 < _g) {
				var i1 = _g1++;
				e2 = ea.array[i1];
				this.fundamentalRule(e1,e2);
			}
			if(this.topDownExpandCondition(e.stop,B)) this.topDown(B,e.stop);
		}
	}
	,parseString: function(str) {
		var p = com.wiris.tokens.PlainTokens.newPlainTokens(str);
		this.parse(p);
	}
	,parse: function(p) {
		var d0 = new Date();
		this.filterRules = com.wiris.util.type.Arrays.newIntArray(this.g.rules.length,0);
		this.tokens = p;
		var ts = p.getVector();
		if(com.wiris.chartparsing.TopDownParser2.CHECK_DURING || com.wiris.chartparsing.TopDownParser2.CHECK_AT_END) {
			var tdp = new com.wiris.chartparsing.TopDownParserClassic(this.g,this.sgoal);
			tdp.parse(new com.wiris.tokens.TokensVector(ts));
			this.chartClassic = tdp.getChart();
		}
		this.chart = new com.wiris.chartparsing.Chart2(this.g,ts.length);
		if(this.maxEdges > 0) this.chart.setEdgeLimit(this.maxEdges);
		try {
			this.lexicalLookup(p);
			this.topDown(this.goal,0);
			this.counter = 0;
			while(this.pending.length > 0) {
				this.counter++;
				var e = this.pending.pop();
				this.process(e);
			}
		} catch( ex ) {
			if( js.Boot.__instanceof(ex,com.wiris.chartparsing.ChartParsingException) ) {
				this.chart.lastError = ex;
			} else throw(ex);
		}
		var d1 = new Date();
		this.milli = d1.getTime() - d0.getTime();
	}
	,withPrecedence: null
	,milli: null
	,counter: null
	,filterRules: null
	,chartClassic: null
	,sgoal: null
	,pending: null
	,ticks: null
	,nIterations: null
	,ambiguities: null
	,tokens: null
	,maxEdges: null
	,chart: null
	,goal: null
	,g: null
	,__class__: com.wiris.chartparsing.TopDownParser2
});
com.wiris.chartparsing.TopDownParserClassic = $hxClasses["com.wiris.chartparsing.TopDownParserClassic"] = function(g,goal_category) {
	this.withPrecedence = true;
	com.wiris.chartparsing.TopDownParser.call(this);
	this.g = g;
	this.goal = g.getCategoryByName(goal_category);
};
com.wiris.chartparsing.TopDownParserClassic.__name__ = ["com","wiris","chartparsing","TopDownParserClassic"];
com.wiris.chartparsing.TopDownParserClassic.__super__ = com.wiris.chartparsing.TopDownParser;
com.wiris.chartparsing.TopDownParserClassic.prototype = $extend(com.wiris.chartparsing.TopDownParser.prototype,{
	getNIterations: function() {
		return this.counter;
	}
	,getGoal: function() {
		return this.goal;
	}
	,getGrammar: function() {
		return this.g;
	}
	,getResultTree: function() {
		return new com.wiris.chartparsing.ParserResult(this.getChart(),this.g,this.g.categories[this.goal].name,this.getTokens());
	}
	,getTokens: function() {
		return this.tokens;
	}
	,getChart: function() {
		return this.chart;
	}
	,showStatistics: function() {
		console.log(this.ticks);
		console.log(" ms");
		console.log("Ambiguities: " + this.ambiguities);
	}
	,addIncompleteEdge: function(start,end,rule,gap,prec) {
		var e;
		e = this.chart.addUncompleteEdge(start,end,rule,gap,prec);
		if(e != null) this.changed = true;
		return e;
	}
	,addCompleteEdge: function(start,end,rule,gap,prec) {
		var e;
		if(this.withPrecedence && rule < com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) {
			var ea = this.chart.getComplete(start,end);
			if(ea != null) {
				var i;
				var r = this.g.rules[rule];
				var _g1 = 0, _g = ea.n;
				while(_g1 < _g) {
					var i1 = _g1++;
					this.nIterations++;
					var e_ = ea.array[i1];
					if(e_.rule < com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) {
						var r_ = this.g.rules[e_.rule];
						if(r.lhs == r_.lhs) {
							if(!(r == r_) && prec == e_.precedence) {
								this.ambiguities++;
								console.log("Ambiguity: (" + start + "," + end + ") " + rule + "(" + prec + ")" + " & " + e_.rule + "(" + e_.precedence + ")");
								var ct = new com.wiris.chartparsing.ChartUtilsForClassic(this.g,r.lhs,this.chart);
								var cn;
								cn = ct.findRule(start,end,r);
								console.log(ct.toRules(cn,this.tokens) + " ");
								console.log(com.wiris.chartparsing.ChartTree.toString2(cn,this.tokens));
								cn = ct.findRule(start,end,r_);
								console.log(ct.toRules(cn,this.tokens) + " ");
								console.log(com.wiris.chartparsing.ChartTree.toString2(cn,this.tokens));
							}
							if(prec > e_.precedence) e = this.chart.changeCompleteEdge(start,end,rule,gap,i1,prec); else if(r.id < r_.id) e = this.chart.changeCompleteEdge(start,end,rule,gap,i1,prec); else e = null;
							return e;
						}
					}
				}
			}
		}
		e = this.chart.addCompleteEdge(start,end,rule,gap,prec);
		if(e != null) this.changed = true;
		return e;
	}
	,addEdge: function(start,end,rule,gap,prec) {
		var i, B;
		var complete;
		var r;
		var e;
		r = this.g.rules[rule];
		if(gap == r.rhs.length) return this.addCompleteEdge(start,end,rule,gap,prec);
		e = this.addIncompleteEdge(start,end,rule,gap,prec);
		if(e == null) return e;
		B = r.rhs[gap];
		if(B < com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID) {
			var _g1 = 0, _g = this.g.rules.length;
			while(_g1 < _g) {
				var i1 = _g1++;
				if(this.g.rules[i1].lhs == B) {
					this.nIterations++;
					this.addEdge(end,end,i1,0,this.g.rules[i1].precedence);
				}
			}
		}
		return e;
	}
	,addTerminal: function(i,j,category) {
		this.addCompleteEdge(i,j,category,1,0);
	}
	,combine: function(e1,e2) {
		var r1, r2;
		var rule1, rule2 = null;
		rule1 = this.g.rules[e1.rule];
		r1 = rule1.rhs[e1.dot];
		if(e2.isTerminalRule()) r2 = e2.rule; else {
			if(e2.rule < 0 || e2.rule >= this.g.rules.length) {
				var i;
				i = 33;
			}
			rule2 = this.g.rules[e2.rule];
			r2 = rule2.lhs;
		}
		if(r1 == r2) {
			var prec;
			prec = e1.precedence;
			if(prec == 0 && rule1.rhs.length == 1) prec = e2.precedence;
			var e;
			e = this.addEdge(e1.start,e2.stop,e1.rule,e1.dot + 1,prec);
			if(e != null) {
				e.start0 = e1.start;
				e.end0 = e1.stop;
				e.edge0 = e1.id;
				e.start1 = e2.start;
				e.end1 = e2.stop;
				e.edge1 = e2.id;
				e.update();
				return true;
			}
		}
		return false;
	}
	,fundamentalRule: function() {
		var n, i, j, k;
		var eij;
		var ejk;
		var changed = false;
		var b;
		n = this.chart.getNVertices();
		var _g = 0;
		while(_g < n) {
			var i1 = _g++;
			var _g1 = i1;
			while(_g1 < n) {
				var j1 = _g1++;
				var _g2 = j1;
				while(_g2 < n) {
					var k1 = _g2++;
					var n_eij, n_ejk;
					var eij_, ejk_;
					var l, m;
					eij_ = this.chart.getUncomplete(i1,j1);
					ejk_ = this.chart.getComplete(j1,k1);
					if(eij_ != null && ejk_ != null) {
						eij = eij_.array;
						ejk = ejk_.array;
						n_eij = eij_.n;
						n_ejk = ejk_.n;
						var _g3 = 0;
						while(_g3 < n_eij) {
							var l1 = _g3++;
							var _g4 = 0;
							while(_g4 < n_ejk) {
								var m1 = _g4++;
								this.nIterations++;
								b = this.combine(eij[l1],ejk[m1]);
								if(b) changed = true;
							}
						}
					}
				}
			}
		}
		return changed;
	}
	,parse: function(p) {
		this.tokens = p;
		var t;
		var variable, integer, i, category;
		var nChanged = 0;
		var ts = p.getVector();
		this.chart = new com.wiris.chartparsing.ChartClassic(this.g,ts.length);
		this.lexicalLookup(p);
		var _g1 = 0, _g = this.g.rules.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			if(this.g.rules[i1].lhs == this.goal) this.addEdge(0,0,i1,0,this.g.rules[i1].precedence);
		}
		var changed2;
		this.counter = 0;
		do {
			this.changed = false;
			this.fundamentalRule();
			nChanged++;
			this.counter++;
		} while(this.changed);
		this.chart.showCount();
	}
	,parseString: function(str) {
		var p = com.wiris.tokens.PlainTokens.newPlainTokens(str);
		this.parse(p);
	}
	,withPrecedence: null
	,counter: null
	,ticks: null
	,nIterations: null
	,ambiguities: null
	,tokens: null
	,changed: null
	,chart: null
	,goal: null
	,g: null
	,__class__: com.wiris.chartparsing.TopDownParserClassic
});
com.wiris.chartparsing.TransformEventHandler = $hxClasses["com.wiris.chartparsing.TransformEventHandler"] = function() { }
com.wiris.chartparsing.TransformEventHandler.__name__ = ["com","wiris","chartparsing","TransformEventHandler"];
com.wiris.chartparsing.TransformEventHandler.prototype = {
	endNodeTransform: null
	,endChildrenTransform: null
	,startNodeTransform: null
	,__class__: com.wiris.chartparsing.TransformEventHandler
}
com.wiris.chartparsing.TransformedToken = $hxClasses["com.wiris.chartparsing.TransformedToken"] = function(token,start,end) {
	this.token = token;
	this.start = start;
	this.end = end;
};
com.wiris.chartparsing.TransformedToken.__name__ = ["com","wiris","chartparsing","TransformedToken"];
com.wiris.chartparsing.TransformedToken.prototype = {
	end: null
	,start: null
	,token: null
	,__class__: com.wiris.chartparsing.TransformedToken
}
if(!com.wiris.tokens) com.wiris.tokens = {}
com.wiris.tokens.Tokens = $hxClasses["com.wiris.tokens.Tokens"] = function() { }
com.wiris.tokens.Tokens.__name__ = ["com","wiris","tokens","Tokens"];
com.wiris.tokens.Tokens.prototype = {
	toStringPosition: null
	,getParentPositions: null
	,getParent: null
	,getVector: null
	,__class__: com.wiris.tokens.Tokens
}
com.wiris.chartparsing.Transformer = $hxClasses["com.wiris.chartparsing.Transformer"] = function(parent,grammar,resultTree) {
	this.parent = parent;
	this.parentTokens = parent.getVector();
	this.grammar = grammar;
	this.tree = resultTree;
	this.pm = new com.wiris.tokens.PositionsMap();
	this.eventHandlers = new Array();
};
com.wiris.chartparsing.Transformer.__name__ = ["com","wiris","chartparsing","Transformer"];
com.wiris.chartparsing.Transformer.__interfaces__ = [com.wiris.tokens.Tokens];
com.wiris.chartparsing.Transformer.findTransformationTerminalPositions = function(i,c,result,ruleTransformation) {
	var start, end;
	if(i == 0 || result.length == 0) start = c.start; else start = result[result.length - 1].end;
	if(i == ruleTransformation.length - 1 || result.length == 0) end = c.end; else {
		var nextToken = ruleTransformation[i + 1];
		if(js.Boot.__instanceof(nextToken,com.wiris.chartparsing.TreeToken) && nextToken.isParamNumber()) end = c.children[nextToken.getParamNumber() - 1].start; else end = start;
	}
	if(start > end) {
		var aux = start;
		start = end;
		end = aux;
	}
	return [start,end];
}
com.wiris.chartparsing.Transformer.prototype = {
	toString: function() {
		return com.wiris.tokens.PlainTokens.toString2(this.getVector(),true);
	}
	,toStringPosition: function(begin,end) {
		var ps = this.pm.get(begin,end,false);
		return this.parent.toStringPosition(ps[0],ps[1]);
	}
	,getParentPositions: function(begin,end) {
		return this.pm.get(begin,end,false);
	}
	,getParent: function() {
		return this.parent;
	}
	,getVector: function() {
		return this.tokens;
	}
	,callEndNodeTransformEvent: function(c,transformation) {
		var i;
		var _g1 = 0, _g = this.eventHandlers.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var teh = this.eventHandlers[i1];
			teh.endNodeTransform(c,transformation);
		}
	}
	,callEndChildrenTransformEvent: function(c,childrenTransformation) {
		var i;
		var _g1 = 0, _g = this.eventHandlers.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var teh = this.eventHandlers[i1];
			teh.endChildrenTransform(c,childrenTransformation);
		}
	}
	,callStartNodeTransformEvent: function(c) {
		var i;
		var _g1 = 0, _g = this.eventHandlers.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var teh = this.eventHandlers[i1];
			teh.startNodeTransform(c);
		}
	}
	,transformNode: function(c,childrenTransformation) {
		var result = new Array();
		if(c.isTerminal) {
			var transformed;
			if(c.end - c.start == 1) {
				var token = this.parentTokens[c.start];
				transformed = new com.wiris.chartparsing.TransformedToken(token,c.start,c.end);
			} else if(c.end - c.start == 0) transformed = new com.wiris.chartparsing.TransformedToken(null,c.start,c.end); else throw "Corrupted terminal node: " + c.toString();
			result.push(transformed);
		} else {
			var rule = this.grammar.rules[c.rule];
			var ruleTransformation = rule.getProperty("transformation");
			if(ruleTransformation == null) {
				var i;
				var _g1 = 0, _g = childrenTransformation.length;
				while(_g1 < _g) {
					var i1 = _g1++;
					com.wiris.util.type.Arrays.addAll(result,childrenTransformation[i1]);
				}
			} else {
				var i;
				var _g1 = 0, _g = ruleTransformation.length;
				while(_g1 < _g) {
					var i1 = _g1++;
					var token = ruleTransformation[i1];
					if(js.Boot.__instanceof(token,com.wiris.chartparsing.TreeToken) && token.isParamNumber()) {
						var childrenIndex = token.getParamNumber() - 1;
						if(childrenIndex >= childrenTransformation.length || childrenIndex < 0) throw "Error index out of bounds in transformation rule: " + this.grammar.ruleToString(rule.lhs);
						com.wiris.util.type.Arrays.addAll(result,childrenTransformation[childrenIndex]);
					} else if(js.Boot.__instanceof(token,com.wiris.chartparsing.TreeToken) && token.isParamName()) {
						var name = token.name;
						var found = false;
						if(rule.rhsnames != null) {
							var j = 0;
							while(j < rule.rhsnames.length && !found) {
								if(name == rule.rhsnames[j]) {
									com.wiris.util.type.Arrays.addAll(result,childrenTransformation[j]);
									found = true;
								}
								j++;
							}
						}
						if(!found) throw "Error identifier \"" + name + "\" not found in transformation rule: " + this.grammar.ruleToString(rule.lhs);
					} else {
						var positions = com.wiris.chartparsing.Transformer.findTransformationTerminalPositions(i1,c,result,ruleTransformation);
						var transformed = new com.wiris.chartparsing.TransformedToken(ruleTransformation[i1],positions[0],positions[1]);
						result.push(transformed);
					}
				}
			}
		}
		return result;
	}
	,transformImpl: function(c) {
		this.callStartNodeTransformEvent(c);
		var childrenTransform = new Array();
		var i;
		var _g1 = 0, _g = c.children.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			childrenTransform[i1] = this.transformImpl(c.children[i1]);
		}
		this.callEndChildrenTransformEvent(c,childrenTransform);
		var t = this.transformNode(c,childrenTransform);
		this.callEndNodeTransformEvent(c,t);
		return t;
	}
	,addEventHandler: function(teh) {
		this.eventHandlers.push(teh);
	}
	,transform: function() {
		var transformedTokens = this.transformImpl(this.tree);
		this.tokens = new Array();
		var i;
		var _g1 = 0, _g = transformedTokens.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var tToken = transformedTokens[i1];
			this.tokens.push(tToken.token);
			this.pm.add(i1,i1 + 1,tToken.start,tToken.end);
		}
	}
	,tokens: null
	,eventHandlers: null
	,pm: null
	,tree: null
	,grammar: null
	,parentTokens: null
	,parent: null
	,__class__: com.wiris.chartparsing.Transformer
}
com.wiris.chartparsing.TreeConverter = $hxClasses["com.wiris.chartparsing.TreeConverter"] = function() { }
com.wiris.chartparsing.TreeConverter.__name__ = ["com","wiris","chartparsing","TreeConverter"];
com.wiris.chartparsing.TreeConverter.convert = function(g,terminals,transformation) {
	if(terminals) {
		var t = g.terminal;
		var i;
		var _g1 = 0, _g = t.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			if(t[i1].isSingleton()) t[i1].value = com.wiris.chartparsing.TreeConverter.transform(t[i1].value);
		}
	}
	if(transformation) {
		var r = g.rules;
		var i;
		var _g1 = 0, _g = r.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var ss = r[i1].getProperty("transformation");
			if(ss != null) {
				var j;
				var _g3 = 0, _g2 = ss.length;
				while(_g3 < _g2) {
					var j1 = _g3++;
					ss[j1] = com.wiris.chartparsing.TreeConverter.transform(ss[j1]);
					ss[j1] = com.wiris.chartparsing.TreeConverter.transform0(ss[j1]);
				}
				r[i1].setProperty("transformation",ss);
			}
		}
	}
}
com.wiris.chartparsing.TreeConverter.transform = function(obj) {
	if(js.Boot.__instanceof(obj,String)) {
		var name = obj;
		if(name == "(" || name == ")" || name == ",") return com.wiris.chartparsing.TreeToken.newTreeToken1(name);
		if(StringTools.startsWith(name,"$")) {
			name = HxOverrides.substr(name,1,null);
			if(com.wiris.system.TypeTools.isInteger(name)) {
				var n = Std.parseInt(name);
				return com.wiris.chartparsing.TreeToken.newTreeToken2(n);
			} else return new com.wiris.chartparsing.TreeToken(name,true);
		}
	}
	return obj;
}
com.wiris.chartparsing.TreeConverter.transform0 = function(obj) {
	if(js.Boot.__instanceof(obj,String)) {
		var name = obj;
		if(StringTools.startsWith(name,"\\")) {
			if(name == "\\n") return "\n"; else return HxOverrides.substr(name,1,null);
		}
	}
	return obj;
}
com.wiris.chartparsing.TreeToken = $hxClasses["com.wiris.chartparsing.TreeToken"] = function(name,param) {
	this.name = name;
	this.param = param;
};
com.wiris.chartparsing.TreeToken.__name__ = ["com","wiris","chartparsing","TreeToken"];
com.wiris.chartparsing.TreeToken.newTreeToken1 = function(name) {
	return new com.wiris.chartparsing.TreeToken(name,false);
}
com.wiris.chartparsing.TreeToken.newTreeToken2 = function(n) {
	var treeToken = new com.wiris.chartparsing.TreeToken(null,true);
	treeToken.paramNumber = n;
	return treeToken;
}
com.wiris.chartparsing.TreeToken.prototype = {
	getParamNumber: function() {
		return this.paramNumber;
	}
	,isParamName: function() {
		return this.name != null && this.param;
	}
	,isParamNumber: function() {
		return this.name == null;
	}
	,equals: function(obj) {
		if(js.Boot.__instanceof(obj,com.wiris.chartparsing.TreeToken)) {
			var xt = obj;
			if(this.name != null) return xt.name != null && this.name == xt.name;
			return xt.paramNumber == this.paramNumber;
		}
		return false;
	}
	,toString: function() {
		if(this.name != null) return "" + this.name; else return "" + "$" + this.paramNumber;
	}
	,paramNumber: null
	,param: null
	,name: null
	,__class__: com.wiris.chartparsing.TreeToken
}
com.wiris.chartparsing.VectorSet = $hxClasses["com.wiris.chartparsing.VectorSet"] = function() {
	this.internalVector = new Array();
};
com.wiris.chartparsing.VectorSet.__name__ = ["com","wiris","chartparsing","VectorSet"];
com.wiris.chartparsing.VectorSet.prototype = {
	size: function() {
		return this.internalVector.length;
	}
	,contains: function(element) {
		return com.wiris.system.ArrayEx.contains(this.internalVector,element);
	}
	,getVector: function() {
		return this.internalVector;
	}
	,iterator: function() {
		return HxOverrides.iter(this.internalVector);
	}
	,push: function(obj) {
		if(com.wiris.system.ArrayEx.contains(this.internalVector,obj)) return 0;
		this.internalVector.push(obj);
		return 0;
	}
	,internalVector: null
	,__class__: com.wiris.chartparsing.VectorSet
}
com.wiris.chartparsing.XMLConverter = $hxClasses["com.wiris.chartparsing.XMLConverter"] = function() { }
com.wiris.chartparsing.XMLConverter.__name__ = ["com","wiris","chartparsing","XMLConverter"];
com.wiris.chartparsing.XMLConverter.convert = function(g) {
	var t = g.terminal;
	var i;
	var _g1 = 0, _g = t.length;
	while(_g1 < _g) {
		var i1 = _g1++;
		if(t[i1].isSingleton() && js.Boot.__instanceof(t[i1].value,String)) {
			var name = t[i1].value;
			t[i1].value = com.wiris.chartparsing.XMLConverter.trim0(name);
		}
	}
	com.wiris.chartparsing.XMLConverter.convert2(g);
	var _g1 = 0, _g = t.length;
	while(_g1 < _g) {
		var i1 = _g1++;
		if(t[i1].isSingleton() && js.Boot.__instanceof(t[i1].value,String)) {
			var name = t[i1].value;
			if(StringTools.startsWith(name,"<") && StringTools.endsWith(name,">")) {
				if(!StringTools.startsWith(name,"</")) {
					var n = name.length;
					name = HxOverrides.substr(name,1,n - 2);
					t[i1].value = new com.wiris.tokens.XMLToken(name,com.wiris.tokens.XMLToken.BEGIN_ELEMENT);
				} else {
					var n = name.length;
					name = HxOverrides.substr(name,2,n - 3);
					t[i1].value = new com.wiris.tokens.XMLToken(name,com.wiris.tokens.XMLToken.END_ELEMENT);
				}
			}
		}
	}
	var _g1 = 0, _g = t.length;
	while(_g1 < _g) {
		var i1 = _g1++;
		if(t[i1].isSingleton() && js.Boot.__instanceof(t[i1].value,String)) {
			var name = t[i1].value;
			name = com.wiris.util.xml.WXmlUtils.filterMathMLEntities(name);
			t[i1].value = com.wiris.util.xml.WXmlUtils.htmlUnescape(name);
		}
	}
}
com.wiris.chartparsing.XMLConverter.convert2 = function(g) {
	var n = g.rules.length;
	var i;
	var _g = 0;
	while(_g < n) {
		var i1 = _g++;
		var r;
		var t;
		var insideBeginTag = false;
		var insideBeginTagState = com.wiris.chartparsing.XMLConverter.BEGIN_ATTR;
		r = g.rules[i1];
		var j;
		var _g2 = 0, _g1 = r.rhs.length;
		try {
			while(_g2 < _g1) {
				var j1 = _g2++;
				if(g.isTerminalCategory(r.rhs[j1])) t = g.terminal[r.rhs[j1] - com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID]; else t = null;
				if(insideBeginTag) switch(insideBeginTagState) {
				case com.wiris.chartparsing.XMLConverter.BEGIN_ATTR:
					if(t != null && t.value == ">") {
						com.wiris.chartparsing.XMLConverter.change(g,r,j1,new com.wiris.tokens.XMLToken(">",com.wiris.tokens.XMLToken.END_TAG_ELEMENT));
						insideBeginTag = false;
					} else insideBeginTagState = com.wiris.chartparsing.XMLConverter.EQUAL_SIGN;
					throw "__break__";
					break;
				case com.wiris.chartparsing.XMLConverter.EQUAL_SIGN:
					com.wiris.chartparsing.XMLConverter.check(t,"=");
					insideBeginTagState = com.wiris.chartparsing.XMLConverter.OPEN_QUOTE;
					throw "__break__";
					break;
				case com.wiris.chartparsing.XMLConverter.OPEN_QUOTE:
					com.wiris.chartparsing.XMLConverter.check(t,"\"");
					insideBeginTagState = com.wiris.chartparsing.XMLConverter.ATTRIBUTE_VALUE;
					com.wiris.chartparsing.XMLConverter.change(g,r,j1,new com.wiris.tokens.XMLToken("\"",com.wiris.tokens.XMLToken.OPEN_QUOTE));
					throw "__break__";
					break;
				default:
					if(t != null && t.value == "\"") {
						insideBeginTagState = com.wiris.chartparsing.XMLConverter.BEGIN_ATTR;
						com.wiris.chartparsing.XMLConverter.change(g,r,j1,new com.wiris.tokens.XMLToken("\"",com.wiris.tokens.XMLToken.CLOSE_QUOTE));
					}
					throw "__break__";
				} else if(t != null && js.Boot.__instanceof(t.value,String)) {
					var name = t.value;
					if(StringTools.startsWith(name,"<") && !StringTools.endsWith(name,">") && name.length > 1 && com.wiris.util.xml.WCharacterBase.isLetter(HxOverrides.cca(name,1))) {
						com.wiris.chartparsing.XMLConverter.change(g,r,j1,new com.wiris.tokens.XMLToken(HxOverrides.substr(name,1,null),com.wiris.tokens.XMLToken.BEGIN_TAG_ELEMENT));
						insideBeginTag = true;
					}
				}
			}
		} catch( e ) { if( e != "__break__" ) throw e; }
		if(r.lhsname != null) r.lhsname = com.wiris.chartparsing.XMLConverter.trim0(com.wiris.util.xml.WXmlUtils.htmlUnescape(com.wiris.util.xml.WXmlUtils.filterMathMLEntities(r.lhsname)));
	}
}
com.wiris.chartparsing.XMLConverter.change = function(g,r,j,o) {
	var t = g.getTerminalByValue(o);
	if(t < 0) t = com.wiris.chartparsing.XMLConverter.addTerminal(g,o);
	r.rhs[j] = t;
}
com.wiris.chartparsing.XMLConverter.addTerminal = function(g,o) {
	var n = g.terminal.length;
	var ts = new Array();
	com.wiris.system.System.arraycopy(g.terminal,0,ts,0,n);
	var t = new com.wiris.chartparsing.Terminal();
	t.value = o;
	t.id = n + com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID;
	ts[n] = t;
	g.terminal = ts;
	return n + com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID;
}
com.wiris.chartparsing.XMLConverter.check = function(t,str) {
	if(!(t.value == str)) throw "Expected " + Std.string(t.value) + " but found " + str;
}
com.wiris.chartparsing.XMLConverter.trim0 = function(name) {
	if(StringTools.startsWith(name,"\\")) return HxOverrides.substr(name,1,null);
	return name;
}
com.wiris.chartparsing.XMLConverter.trim1 = function(name) {
	var i, n;
	var s = new StringBuf();
	n = name.length;
	i = 0;
	while(i < n) {
		var c = HxOverrides.cca(name,i);
		if(c == com.wiris.util.xml.SAXParser.CHAR_AMPERSAND) {
			i++;
			var sb = new StringBuf();
			while(i < n && c != com.wiris.util.xml.SAXParser.CHAR_SEMICOLON) {
				c = HxOverrides.cca(name,i);
				if(c != com.wiris.util.xml.SAXParser.CHAR_SEMICOLON) sb.b += String.fromCharCode(c);
				i++;
			}
			var ent = com.wiris.chartparsing.XMLConverter.translateEntity(sb.b);
			s.b += Std.string(ent);
		} else {
			s.b += String.fromCharCode(c);
			i++;
		}
	}
	return s.b;
}
com.wiris.chartparsing.XMLConverter.translateEntity = function(ent) {
	if(ent == "lt") return "<";
	if(ent == "gt") return ">";
	if(ent == "amp") return "&";
	if(ent == "quot") return "\"";
	if(ent == "apos") return "'";
	var c;
	if(StringTools.startsWith(ent,"#")) {
		ent = HxOverrides.substr(ent,1,null);
		c = Std.parseInt(StringTools.startsWith(ent,"x")?"0" + ent:ent);
	} else {
		c = com.wiris.util.xml.WXmlUtils.resolveMathMLEntity(ent);
		if(c == -1) throw "Unknown entity &" + ent + ";";
	}
	return com.wiris.system.Utf8.uchr(c);
}
if(!com.wiris.common) com.wiris.common = {}
com.wiris.common.WInteger = $hxClasses["com.wiris.common.WInteger"] = function() { }
com.wiris.common.WInteger.__name__ = ["com","wiris","common","WInteger"];
com.wiris.common.WInteger.max = function(x,y) {
	if(x > y) return x;
	return y;
}
com.wiris.common.WInteger.min = function(x,y) {
	if(x < y) return x;
	return y;
}
com.wiris.common.WInteger.toHex = function(x,digits) {
	var s = "";
	while(x != 0 && digits > 0) {
		digits--;
		var d = x & 15;
		s = com.wiris.system.Utf8.uchr(d + (d >= 10?55:48)) + s;
		x = x >> 4;
	}
	while(digits-- > 0) s = "0" + s;
	return s;
}
com.wiris.common.WInteger.parseHex = function(str) {
	return Std.parseInt("0x" + str);
}
com.wiris.common.WInteger.isInteger = function(str) {
	str = StringTools.trim(str);
	var i = 0;
	var n = str.length;
	if(StringTools.startsWith(str,"-")) i++;
	if(StringTools.startsWith(str,"+")) i++;
	var c;
	while(i < n) {
		c = HxOverrides.cca(str,i);
		if(c < 48 || c > 57) return false;
		i++;
	}
	return true;
}
if(!com.wiris.settings) com.wiris.settings = {}
com.wiris.settings.PlatformSettings = $hxClasses["com.wiris.settings.PlatformSettings"] = function() { }
com.wiris.settings.PlatformSettings.__name__ = ["com","wiris","settings","PlatformSettings"];
com.wiris.settings.PlatformSettings.evenTokensBoxWidth = function() {
	return true;
}
com.wiris.system.ArrayEx = $hxClasses["com.wiris.system.ArrayEx"] = function() { }
com.wiris.system.ArrayEx.__name__ = ["com","wiris","system","ArrayEx"];
com.wiris.system.ArrayEx.contains = function(a,b) {
	var _g = 0;
	while(_g < a.length) {
		var x = a[_g];
		++_g;
		if(x == b) return true;
	}
	return false;
}
com.wiris.system.ArrayEx.indexOf = function(a,b) {
	var idx = 0;
	while(idx < a.length) {
		if(a[idx] == b) return idx;
		++idx;
	}
	return -1;
}
com.wiris.system.LocalStorageCache = $hxClasses["com.wiris.system.LocalStorageCache"] = function(code) {
	this.MAX_BYTES = 2097152;
	this.code = code;
	this.available = this.isLocalStorageAvailable();
	this.getItems();
};
com.wiris.system.LocalStorageCache.__name__ = ["com","wiris","system","LocalStorageCache"];
com.wiris.system.LocalStorageCache.prototype = {
	unserializeItems: function(s) {
		return haxe.Json.parse(s);
	}
	,serializeItems: function(a) {
		return haxe.Json.stringify(a);
	}
	,isLocalStorageAvailable: function() {
		try {
			var storage = this.getStorage();
			var x = this.getStorageName("__test__");
			storage.setItem(x,x);
			storage.removeItem(x);
			return true;
		} catch( e ) {
			return false;
		}
	}
	,getStorage: function() {
		return js.Lib.window.localStorage;
	}
	,saveItems: function() {
		var serialized = this.serializeItems(this.items);
		this.getStorage().setItem(this.getStorageName(com.wiris.system.LocalStorageCache.ITEMS_KEY),serialized);
	}
	,getItems: function() {
		try {
			var serialized = this.getItem(com.wiris.system.LocalStorageCache.ITEMS_KEY);
			if(serialized != null) this.items = this.unserializeItems(serialized); else this.items = new Array();
			this.totalLength = 0;
			var _g = 0, _g1 = this.items;
			while(_g < _g1.length) {
				var item = _g1[_g];
				++_g;
				this.totalLength += item.length;
			}
		} catch( e ) {
			this.clear();
		}
	}
	,getStorageName: function(name) {
		return this.code + "_" + name;
	}
	,exists: function(key) {
		return this.available && this.getItem(key) != null;
	}
	,removeItem: function(key,saveItems) {
		var _g = 0, _g1 = this.items;
		while(_g < _g1.length) {
			var item = _g1[_g];
			++_g;
			if(item.name == key) {
				HxOverrides.remove(this.items,item);
				this.totalLength -= item.length;
				this.getStorage().removeItem(this.getStorageName(name));
				if(saveItems == null || saveItems) this.saveItems();
			}
		}
	}
	,getItem: function(key) {
		return this.available?this.getStorage().getItem(this.getStorageName(key)):null;
	}
	,setItemImpl: function(key,data) {
		var item = { name : key, length : data.length};
		this.items.push(item);
		this.totalLength += item.length;
		this.saveItems();
		this.getStorage().setItem(this.getStorageName(key),data);
	}
	,clear: function() {
		var storage = this.getStorage();
		var i = storage.length - 1;
		while(i >= 0) {
			var key = storage.key(i);
			if(StringTools.startsWith(key,this.getStorageName(""))) storage.removeItem(key);
			i--;
		}
		this.items = new Array();
		this.totalLength = 0;
	}
	,setItem: function(key,data) {
		var len = data.length;
		if(this.available && len < this.MAX_BYTES) try {
			this.removeItem(key,false);
			while(this.totalLength + len > this.MAX_BYTES) this.removeItem(this.items[0].name,false);
			this.setItemImpl(key,data);
		} catch( e ) {
			this.clear();
			this.setItemImpl(key,data);
		}
	}
	,totalLength: null
	,items: null
	,code: null
	,MAX_BYTES: null
	,available: null
	,__class__: com.wiris.system.LocalStorageCache
}
com.wiris.system.Storage = $hxClasses["com.wiris.system.Storage"] = function(location) {
	location = StringTools.replace(location,"/",com.wiris.system.Storage.getDirectorySeparator());
	location = StringTools.replace(location,"\\",com.wiris.system.Storage.getDirectorySeparator());
	this.location = location;
};
com.wiris.system.Storage.__name__ = ["com","wiris","system","Storage"];
com.wiris.system.Storage.directorySeparator = null;
com.wiris.system.Storage.resourcesDir = null;
com.wiris.system.Storage.newResourceStorage = function(name) {
	return new com.wiris.system.Storage(name);
}
com.wiris.system.Storage.newStorage = function(name) {
	return new com.wiris.system.Storage(name);
}
com.wiris.system.Storage.newStorageWithParent = function(parent,name) {
	return new com.wiris.system.Storage(parent.location + com.wiris.system.Storage.getDirectorySeparator() + name);
}
com.wiris.system.Storage.getResourcesDir = function() {
	if(com.wiris.system.Storage.resourcesDir == null) com.wiris.system.Storage.setResourcesDir();
	return com.wiris.system.Storage.resourcesDir;
}
com.wiris.system.Storage.setResourcesDir = function() {
	com.wiris.system.Storage.resourcesDir = ".";
}
com.wiris.system.Storage.getDirectorySeparator = function() {
	if(com.wiris.system.Storage.directorySeparator == null) com.wiris.system.Storage.setDirectorySeparator();
	return com.wiris.system.Storage.directorySeparator;
}
com.wiris.system.Storage.setDirectorySeparator = function() {
	var sep;
	sep = "/";
	com.wiris.system.Storage.directorySeparator = sep;
}
com.wiris.system.Storage.getCurrentPath = function() {
	throw "Not implemented!";
	return null;
}
com.wiris.system.Storage.prototype = {
	setResourceObject: function(obj) {
	}
	,list: function() {
		throw "Not implemented!";
		return null;
	}
	,isDirectory: function() {
		throw "Not implemented!";
		return false;
	}
	,'delete': function() {
		throw "Not implemented!";
	}
	,toString: function() {
		return this.location;
	}
	,getParent: function() {
		var path = null;
		if(path == null) path = this.location;
		var index = path.lastIndexOf(com.wiris.system.Storage.getDirectorySeparator());
		path = index != -1?HxOverrides.substr(path,0,index):".";
		return new com.wiris.system.Storage(path);
	}
	,mkdirs: function() {
		throw "Not implemented!";
	}
	,getLocalCache: function() {
		if(this.localStorage == null) this.localStorage = new com.wiris.system.LocalStorageCache("wq");
		return this.localStorage;
	}
	,exists: function() {
		var exists = false;
		var names = haxe.Resource.listNames();
		var i;
		var _g1 = 0, _g = names.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			if(names[i1] == this.location) {
				exists = true;
				break;
			}
		}
		if(!exists && this.getLocalCache().exists(this.location)) exists = true;
		return exists;
	}
	,read: function() {
		if(this.getLocalCache().exists(this.location)) return this.getLocalCache().getItem(this.location);
		return haxe.io.Bytes.ofData(this.readBinary()).toString();
	}
	,readBinary: function() {
		var bytes;
		if(this.getLocalCache().exists(this.location)) bytes = haxe.io.Bytes.ofString(this.getLocalCache().getItem(this.location)); else bytes = haxe.Resource.getBytes(this.location);
		return bytes.b;
	}
	,write: function(s) {
		this.getLocalCache().setItem(this.location,s);
	}
	,writeBinary: function(bs) {
		var bytes = haxe.io.Bytes.ofData(bs);
		this.getLocalCache().setItem(this.location,bytes.toString());
	}
	,localStorage: null
	,location: null
	,__class__: com.wiris.system.Storage
}
com.wiris.system.StringEx = $hxClasses["com.wiris.system.StringEx"] = function() { }
com.wiris.system.StringEx.__name__ = ["com","wiris","system","StringEx"];
com.wiris.system.StringEx.substring = function(s,start,end) {
	if(end == null) return HxOverrides.substr(s,start,null);
	return HxOverrides.substr(s,start,end - start);
}
com.wiris.system.StringEx.compareTo = function(s1,s2) {
	if(s1 > s2) return 1;
	if(s1 < s2) return -1;
	return 0;
}
com.wiris.system.System = $hxClasses["com.wiris.system.System"] = function() { }
com.wiris.system.System.__name__ = ["com","wiris","system","System"];
com.wiris.system.System.arraycopy = function(src,srcPos,dest,destPos,n) {
	var _g = 0;
	while(_g < n) {
		var i = _g++;
		dest[destPos + i] = src[srcPos + i];
	}
}
com.wiris.system.TypeTools = $hxClasses["com.wiris.system.TypeTools"] = function() { }
com.wiris.system.TypeTools.__name__ = ["com","wiris","system","TypeTools"];
com.wiris.system.TypeTools.floatToString = function(value) {
	return "" + value;
}
com.wiris.system.TypeTools.isFloating = function(str) {
	var pattern = new EReg("^(\\d|\\d\\.|\\.\\d)","");
	return pattern.match(str);
}
com.wiris.system.TypeTools.isInteger = function(str) {
	var pattern = new EReg("^(\\d)","");
	return pattern.match(str);
}
com.wiris.system.TypeTools.isIdentifierPart = function(c) {
	var letterPattern = new EReg("[a-z]","i");
	var numberPattern = new EReg("[0-9]","");
	var str = String.fromCharCode(c);
	return letterPattern.match(str) || numberPattern.match(str) || str == "_";
}
com.wiris.system.TypeTools.isIdentifierStart = function(c) {
	var letterPattern = new EReg("[a-z]","i");
	var str = String.fromCharCode(c);
	return letterPattern.match(str) || str == "_";
}
com.wiris.system.TypeTools.isArray = function(o) {
	return js.Boot.__instanceof(o,Array);
}
com.wiris.system.TypeTools.isHash = function(o) {
	return js.Boot.__instanceof(o,Hash);
}
com.wiris.system.TypeTools.string2ByteData_iso8859_1 = function(str) {
	var data = new Array();
	var _g1 = 0, _g = str.length;
	while(_g1 < _g) {
		var i = _g1++;
		data.push(HxOverrides.cca(str,i));
	}
	var bytes = haxe.io.Bytes.ofData(data);
	return bytes;
}
com.wiris.system.Utf8 = $hxClasses["com.wiris.system.Utf8"] = function() {
};
com.wiris.system.Utf8.__name__ = ["com","wiris","system","Utf8"];
com.wiris.system.Utf8.findUTF8Position = function(s,position,carry8,carry16) {
	if(carry16 == null) carry16 = 0;
	if(carry8 == null) carry8 = 0;
	var i8 = carry8;
	var i16 = carry16;
	var n8 = s.length;
	while(i8 < n8 && i16 < position) {
		var charCode = HxOverrides.cca(s,i8);
		if(charCode < 55296 || charCode > 56319) ++i16;
		++i8;
	}
	return i8;
}
com.wiris.system.Utf8.getLength = function(s) {
	var i8 = 0;
	var n8 = s.length;
	var counter16 = 0;
	while(i8 < n8) {
		var charCode = HxOverrides.cca(s,i8);
		if(charCode < 55296 || charCode > 56319) ++counter16;
		++i8;
	}
	return counter16;
}
com.wiris.system.Utf8.charCodeAt = function(s,i) {
	var i8 = com.wiris.system.Utf8.findUTF8Position(s,i,null,null);
	var charCode = HxOverrides.cca(s,i8);
	return charCode < 55296 || charCode > 56319?charCode:(charCode - 55296) * 1024 + HxOverrides.cca(s,i8 + 1) - 56320 + 65536;
}
com.wiris.system.Utf8.charAt = function(s,i) {
	return com.wiris.system.Utf8.uchr(com.wiris.system.Utf8.charCodeAt(s,i));
}
com.wiris.system.Utf8.uchr = function(i) {
	var s = new haxe.Utf8();
	if(i < 65536) s.__b += String.fromCharCode(i); else if(i <= 1114111) {
		s.__b += String.fromCharCode((i >> 10) + 55232);
		s.__b += String.fromCharCode((i & 1023) + 56320);
	} else throw "Invalid code point.";
	return s.__b;
}
com.wiris.system.Utf8.sub = function(s,pos,len) {
	var start = com.wiris.system.Utf8.findUTF8Position(s,pos,null,null);
	var end = com.wiris.system.Utf8.findUTF8Position(s,pos + len,start,pos);
	return HxOverrides.substr(s,start,end - start);
}
com.wiris.system.Utf8.toBytes = function(s) {
	return haxe.io.Bytes.ofString(s).b;
}
com.wiris.system.Utf8.fromBytes = function(s) {
	var bs = haxe.io.Bytes.ofData(s);
	return bs.toString();
}
com.wiris.system.Utf8.getIterator = function(s) {
	return new com.wiris.system._Utf8.StringIterator(s);
}
com.wiris.system.Utf8.prototype = {
	__class__: com.wiris.system.Utf8
}
if(!com.wiris.system._Utf8) com.wiris.system._Utf8 = {}
com.wiris.system._Utf8.StringIterator = $hxClasses["com.wiris.system._Utf8.StringIterator"] = function(s) {
	this.source = s;
	this.n = this.source.length;
	this.offset = 0;
};
com.wiris.system._Utf8.StringIterator.__name__ = ["com","wiris","system","_Utf8","StringIterator"];
com.wiris.system._Utf8.StringIterator.prototype = {
	next: function() {
		var c = HxOverrides.cca(this.source,this.offset++);
		if(c >= 55296 && c < 57344) {
			var c2 = HxOverrides.cca(this.source,this.offset++);
			c = ((c & 1023) << 10 | c2 & 1023) + 65536;
		}
		return c;
	}
	,nextByte: function() {
		return HxOverrides.cca(this.source,this.offset++);
	}
	,hasNext: function() {
		return this.offset < this.n;
	}
	,source: null
	,n: null
	,offset: null
	,__class__: com.wiris.system._Utf8.StringIterator
}
com.wiris.tokens.LineCounter = $hxClasses["com.wiris.tokens.LineCounter"] = function(str) {
	this.d = -1;
	this.vec = new Array();
	this.str = str;
	this.line = 1;
	this.i = 0;
	this.n = str.length;
	while(this.i < this.n) {
		this.read();
		this.i++;
	}
};
com.wiris.tokens.LineCounter.__name__ = ["com","wiris","tokens","LineCounter"];
com.wiris.tokens.LineCounter.prototype = {
	getLocationImpl: function(n) {
		if(n < 0 || n >= this.vec.length) return [-1,-1];
		return this.vec[n];
	}
	,getLocation: function(n,begin) {
		return this.getLocationImpl(2 * n + (begin?0:1));
	}
	,newLine: function() {
		this.line++;
		this.column = 0;
	}
	,read: function() {
		var c = this.read0();
		if(c == com.wiris.util.xml.SAXParser.CHAR_LESS_THAN) this.vec.push([this.line,this.column]);
		if(c == com.wiris.util.xml.SAXParser.CHAR_GREATER_THAN) {
			if(this.d == com.wiris.util.xml.SAXParser.CHAR_BAR) {
				var r = this.vec[this.vec.length - 1];
				this.vec.push([this.line,this.column + 1]);
				this.vec.push(r);
			}
			if(this.d == com.wiris.util.xml.SAXParser.CHAR_INTERROGATION) {
			} else this.vec.push([this.line,this.column + 1]);
		}
		if(c == com.wiris.util.xml.SAXParser.CHAR_INTERROGATION && this.d == com.wiris.util.xml.SAXParser.CHAR_LESS_THAN) com.wiris.util.type.Arrays.clear(this.vec);
		if(c == 10) {
			if(this.d != 13) {
				this.d = c;
				this.newLine();
			} else this.d = 0;
		} else if(c == 13) {
			this.d = c;
			if(this.d != 10) {
				this.d = c;
				this.newLine();
			} else this.d = 0;
		} else {
			this.column++;
			this.d = c;
		}
		return c;
	}
	,read0: function() {
		if(this.i < this.n) return HxOverrides.cca(this.str,this.i);
		return -1;
	}
	,str: null
	,n: null
	,i: null
	,d: null
	,vec: null
	,column: null
	,line: null
	,__class__: com.wiris.tokens.LineCounter
}
com.wiris.tokens.PlainTokens = $hxClasses["com.wiris.tokens.PlainTokens"] = function() {
	this.storeBlanks = false;
	this.tokens = new Array();
	this.pm = new com.wiris.tokens.PositionsMap();
};
com.wiris.tokens.PlainTokens.__name__ = ["com","wiris","tokens","PlainTokens"];
com.wiris.tokens.PlainTokens.__interfaces__ = [com.wiris.tokens.Tokens];
com.wiris.tokens.PlainTokens.newPlainTokens = function(str) {
	var plainTokens = new com.wiris.tokens.PlainTokens();
	plainTokens.parse(str);
	return plainTokens;
}
com.wiris.tokens.PlainTokens.getLinesImpl = function(str) {
	var c, d;
	c = 0;
	var count = 0;
	var i;
	var _g1 = 0, _g = str.length;
	while(_g1 < _g) {
		var i1 = _g1++;
		d = c;
		c = HxOverrides.cca(str,i1);
		if(c == 13 && d != 10) {
			count++;
			d = 0;
		}
		if(c == 10 && d != 13) {
			count++;
			d = 0;
		}
	}
	return count;
}
com.wiris.tokens.PlainTokens.getLines = function(v,n) {
	var acum = 0;
	var i;
	var _g = 0;
	while(_g < n) {
		var i1 = _g++;
		acum += com.wiris.tokens.PlainTokens.getLinesImpl(v[i1]);
	}
	return acum;
}
com.wiris.tokens.PlainTokens.toString2 = function(v,space) {
	var sb = new StringBuf();
	var emptySB = true;
	var i;
	var _g1 = 0, _g = v.length;
	while(_g1 < _g) {
		var i1 = _g1++;
		if(v[i1] != null) {
			if(space && !emptySB) sb.b += Std.string(" ");
			sb.b += Std.string(v[i1].toString());
			emptySB = false;
		}
	}
	return sb.b;
}
com.wiris.tokens.PlainTokens.prototype = {
	reset: function() {
		this.i = this.i1;
		this.c = this.c1;
	}
	,mark: function() {
		this.i1 = this.i;
		this.c1 = this.c;
	}
	,toStringPosition: function(a,b) {
		return null;
	}
	,getParentPositions: function(a,b) {
		return this.pm.getOutter(a,b);
	}
	,getParent: function() {
		return null;
	}
	,nextChar: function() {
		if(this.i < this.n) {
			this.c = HxOverrides.cca(this.str,this.i);
			this.i++;
		} else this.c = 65535;
	}
	,isValid: function(c) {
		return c != 65535;
	}
	,isBlank: function(c) {
		return c == com.wiris.util.xml.SAXParser.CHAR_SPACE || c == com.wiris.util.xml.SAXParser.CHAR_LINE_FEED || c == com.wiris.util.xml.SAXParser.CHAR_CARRIAGE_RETURN || c == com.wiris.util.xml.SAXParser.CHAR_TAB || c == 65279;
	}
	,getString: function() {
		var sb = new StringBuf();
		var i0 = this.i;
		if(this.isValid(this.c) && this.c == com.wiris.util.xml.SAXParser.CHAR_DOUBLE_QUOT) {
			sb.b += String.fromCharCode(this.c);
			var d = this.c;
			this.nextChar();
			while(this.isValid(this.c) && (d == com.wiris.util.xml.SAXParser.CHAR_BACKSLASH || this.c != com.wiris.util.xml.SAXParser.CHAR_DOUBLE_QUOT)) {
				sb.b += String.fromCharCode(this.c);
				d = this.c;
				this.nextChar();
			}
			sb.b += String.fromCharCode(this.c);
			this.nextChar();
		}
		var str = sb.b;
		if(str.length > 0) {
			this.push(i0,str);
			return true;
		}
		return false;
	}
	,getSymbol: function() {
		var sb = new StringBuf();
		var i0 = this.i;
		while(this.isValid(this.c) && !com.wiris.system.TypeTools.isIdentifierPart(this.c) && !this.isBlank(this.c)) {
			sb.b += String.fromCharCode(this.c);
			this.nextChar();
		}
		var str = sb.b;
		if(str.length > 0) {
			this.push(i0,str);
			return true;
		}
		return false;
	}
	,getNumber: function() {
		var sb = new StringBuf();
		var i0 = this.i;
		while(this.isValid(this.c) && com.wiris.util.xml.WCharacterBase.isDigit(this.c)) {
			sb.b += String.fromCharCode(this.c);
			this.nextChar();
		}
		if(this.isValid(this.c) && this.c == com.wiris.util.xml.SAXParser.CHAR_DOT) {
			sb.b += String.fromCharCode(this.c);
			this.nextChar();
			while(this.isValid(this.c) && com.wiris.util.xml.WCharacterBase.isDigit(this.c)) {
				sb.b += String.fromCharCode(this.c);
				this.nextChar();
			}
		}
		var str = sb.b;
		if(str.length > 0) {
			this.push(i0,str);
			return true;
		}
		return false;
	}
	,pushToken: function(i0,i1,str) {
		var k = this.tokens.length;
		this.pm.add(k,k + 1,i0,i1);
		this.tokens.push(str);
	}
	,push: function(i0,str) {
		var i1 = this.i - 1;
		if(!this.isValid(this.c)) i1 = this.n;
		this.pushToken(i0 - 1,i1,str);
	}
	,getIdent: function() {
		var sb = new StringBuf();
		var i0 = this.i;
		if(this.isValid(this.c) && com.wiris.system.TypeTools.isIdentifierStart(this.c)) {
			sb.b += String.fromCharCode(this.c);
			this.nextChar();
			while(this.isValid(this.c) && com.wiris.system.TypeTools.isIdentifierPart(this.c)) {
				sb.b += String.fromCharCode(this.c);
				this.nextChar();
			}
		}
		var str = sb.b;
		if(str.length > 0) {
			this.push(i0,str);
			return true;
		}
		return false;
	}
	,getComment0: function() {
		var sb = new StringBuf();
		if(this.isValid(this.c) && this.c == com.wiris.util.xml.SAXParser.CHAR_HASH) {
			sb.b += String.fromCharCode(this.c);
			this.nextChar();
			while(this.isValid(this.c) && this.c != com.wiris.util.xml.SAXParser.CHAR_LINE_FEED && this.c != com.wiris.util.xml.SAXParser.CHAR_CARRIAGE_RETURN) {
				sb.b += String.fromCharCode(this.c);
				this.nextChar();
			}
		}
		var str = sb.b;
		if(str.length > 0) return str;
		return null;
	}
	,getBlank0: function() {
		var sb = new StringBuf();
		while(this.isValid(this.c) && this.isBlank(this.c)) {
			sb.b += String.fromCharCode(this.c);
			this.nextChar();
		}
		var str = sb.b;
		if(str.length > 0) return str;
		return null;
	}
	,getBlankOrComment: function() {
		var sb = new StringBuf();
		var s;
		while(true) {
			s = this.getBlank0();
			if(s != null) {
				sb.b += Std.string(s);
				continue;
			}
			s = this.getComment0();
			if(s != null) {
				sb.b += Std.string(s);
				continue;
			}
			break;
		}
		var str = sb.b;
		if(str.length > 0) {
			if(this.storeBlanks) this.tokens.push(str);
			return true;
		}
		return false;
	}
	,getVector: function() {
		return this.tokens;
	}
	,onParse: function() {
		return false;
	}
	,parse: function(str) {
		this.str = str;
		this.i = 0;
		this.n = str.length;
		this.nextChar();
		while(this.isValid(this.c)) {
			var j = this.i;
			if(this.getBlankOrComment()) continue;
			if(this.onParse()) continue;
			if(this.getIdent()) continue;
			if(this.getNumber()) continue;
			if(this.getSymbol()) continue;
			if(j == this.i && this.isValid(this.c)) throw "Nothing happened for '" + this.c + "'.";
		}
	}
	,pm: null
	,storeBlanks: null
	,tokens: null
	,str: null
	,c1: null
	,i1: null
	,c: null
	,n: null
	,i: null
	,__class__: com.wiris.tokens.PlainTokens
}
com.wiris.tokens.PositionsMap = $hxClasses["com.wiris.tokens.PositionsMap"] = function() {
	this.leftPos = new Array();
	this.rightPos = new Array();
};
com.wiris.tokens.PositionsMap.__name__ = ["com","wiris","tokens","PositionsMap"];
com.wiris.tokens.PositionsMap.prototype = {
	shiftOutterVec: function(a,from,offset) {
		var n = a.length;
		var i;
		var _g = 0;
		while(_g < n) {
			var i1 = _g++;
			var p = a[i1];
			if(p[1] >= from) {
				p[1] = p[1] + offset;
				a[i1] = p;
			}
		}
	}
	,shiftOutter: function(from,offset) {
		this.shiftOutterVec(this.leftPos,from,offset);
		this.shiftOutterVec(this.rightPos,from,offset);
	}
	,maxMin: function(a,b,max) {
		if(max) return Math.max(a,b);
		return Math.min(a,b);
	}
	,getImpl: function(vec,x,inv,max) {
		var M = 0;
		var MSet = false;
		var n = vec.length;
		var a, b;
		if(!inv) {
			a = 0;
			b = 1;
		} else {
			a = 1;
			b = 0;
		}
		var i;
		var _g = 0;
		while(_g < n) {
			var i1 = _g++;
			var ps = vec[i1];
			if(ps[a] == x) {
				if(MSet) M = this.maxMin(M,ps[b],max); else {
					M = ps[b];
					MSet = true;
				}
			}
		}
		return MSet?M:-1;
	}
	,find: function(vec,a,b,inv,max) {
		var M = 0;
		var MSet = false;
		var m;
		var inc;
		var binc;
		if(a < b) {
			inc = 1;
			binc = true;
		} else {
			inc = -1;
			binc = false;
		}
		var x = a;
		while(binc && x <= b || !binc && x >= b) {
			m = this.getImpl(vec,x,inv,max);
			if(m >= 0) {
				if(MSet) M = this.maxMin(m,M,max); else {
					M = m;
					MSet = true;
				}
			}
			var MM = MSet?M:-1;
			if(MM >= 0) return MM;
			x += inc;
		}
		return MSet?M:-1;
	}
	,get: function(a,b,inv) {
		var a0, b0;
		if(a > b) return this.get(b,a,inv);
		a0 = this.find(this.leftPos,a,0,inv,false);
		if(a0 < 0) a0 = this.find(this.rightPos,a,0,inv,false);
		b0 = this.find(this.rightPos,b,inv?this.max1:this.max0,inv,true);
		if(b0 < 0) b0 = this.find(this.leftPos,b,inv?this.max1:this.max0,inv,true);
		if(a0 < 0 && b0 >= 0) a0 = b0;
		if(b0 < 0 && a0 >= 0) b0 = a0;
		if(a0 < 0 && b0 < 0) {
			a0 = 0;
			b0 = inv?this.max1:this.max0;
		}
		if(a0 <= b0) return [a0,b0]; else return [b0,a0];
	}
	,getInverse: function(c,d) {
		return this.get(c,d,true);
	}
	,getOutter: function(c,d) {
		return this.get(c,d,false);
	}
	,addImpl: function(vec,a,b) {
		vec.push([a,b]);
		if(vec.length == 1) {
			this.max0 = a;
			this.max1 = b;
		} else {
			if(a > this.max0) this.max0 = a;
			if(b > this.max1) this.max1 = b;
		}
	}
	,add: function(a,b,c,d) {
		this.addImpl(this.leftPos,a,c);
		this.addImpl(this.rightPos,b,d);
	}
	,max1: null
	,max0: null
	,rightPos: null
	,leftPos: null
	,__class__: com.wiris.tokens.PositionsMap
}
if(!com.wiris.util) com.wiris.util = {}
if(!com.wiris.util.xml) com.wiris.util.xml = {}
com.wiris.util.xml.ContentHandler = $hxClasses["com.wiris.util.xml.ContentHandler"] = function() { }
com.wiris.util.xml.ContentHandler.__name__ = ["com","wiris","util","xml","ContentHandler"];
com.wiris.util.xml.ContentHandler.prototype = {
	endDocument: null
	,startDocument: null
	,characters: null
	,endElement: null
	,startElement: null
	,__class__: com.wiris.util.xml.ContentHandler
}
com.wiris.tokens.SAXTokenizer = $hxClasses["com.wiris.tokens.SAXTokenizer"] = function(source,sourceName,split,ignoreAtts) {
	this.col = 0;
	this.line = 0;
	this.token = 0;
	this.lastNoTextToken = 0;
	this.lastNoTextCol = 0;
	this.lastNoTextLine = 0;
	this.lastToken = 0;
	this.lastCol = 0;
	this.lastLine = 0;
	this.parsing = true;
	this.tokens = new Array();
	this.sb = new StringBuf();
	this.pm = new com.wiris.tokens.PositionsMap();
	if(sourceName != null) this.setFileName(sourceName);
	this.setIgnoreAttributes(ignoreAtts);
	this.setSplitChars(split);
	this.sxp = new com.wiris.util.xml.SAXParser();
	this.sxp.addEntityResolver(new com.wiris.util.xml.MathMLEntityResolver());
	this.sxp.parse(source,this);
};
com.wiris.tokens.SAXTokenizer.__name__ = ["com","wiris","tokens","SAXTokenizer"];
com.wiris.tokens.SAXTokenizer.__interfaces__ = [com.wiris.util.xml.ContentHandler,com.wiris.tokens.Tokens];
com.wiris.tokens.SAXTokenizer.getInt = function(x) {
	var left = x >> 32;
	var right = x & -1;
	return [left,right];
}
com.wiris.tokens.SAXTokenizer.newSaxTokenizerSplitCharacters = function(source,sourceName) {
	return new com.wiris.tokens.SAXTokenizer(source,sourceName,true,null);
}
com.wiris.tokens.SAXTokenizer.newSAXTokenizer = function(source,sourceName) {
	return new com.wiris.tokens.SAXTokenizer(source,sourceName,false,null);
}
com.wiris.tokens.SAXTokenizer.newSAXTokenizerWithIgnoreAttributes = function(source,sourceName,ignoreAtts) {
	return new com.wiris.tokens.SAXTokenizer(source,sourceName,false,ignoreAtts);
}
com.wiris.tokens.SAXTokenizer.prototype = {
	removeNamespace: function(name) {
		var pos;
		if((pos = name.indexOf(":")) != -1) name = HxOverrides.substr(name,pos + 1,null);
		return name;
	}
	,isIgnoredAttribute: function(qname) {
		if(this.ignoreAtts != null) {
			var i;
			var _g1 = 0, _g = this.ignoreAtts.length;
			while(_g1 < _g) {
				var i1 = _g1++;
				if(this.ignoreAtts[i1] == qname) return true;
			}
		}
		return false;
	}
	,getVector: function() {
		this.ensureNoParsing();
		return this.tokens;
	}
	,getParent: function() {
		return null;
	}
	,setSplitChars: function(splitChars) {
		this.splitChars = splitChars;
	}
	,isSplitChars: function() {
		return this.splitChars;
	}
	,toStringPosition: function(begin,end) {
		var ls = this.pm.getOutter(begin,end);
		if(ls == null) return "unknown";
		var str;
		str = "characters from ";
		var lc;
		lc = com.wiris.tokens.SAXTokenizer.getInt(ls[0]);
		str += "(line " + lc[0] + ", column " + lc[1] + ")";
		str += " to ";
		lc = com.wiris.tokens.SAXTokenizer.getInt(ls[1]);
		str += "(line " + lc[0] + ", column " + lc[1] + ")";
		if(this.fileName != null) str += " at file '" + this.fileName + "'";
		return str;
	}
	,getParentPositions: function(begin,end) {
		return this.pm.getOutter(begin,end);
	}
	,getLong: function(line,col) {
		var l = line << 32;
		l += col;
		return l;
	}
	,setTokenPosition: function(lastToken,token,line0,col0,line1,col1) {
		this.pm.add(lastToken,token,this.getLong(line0,col0),this.getLong(line1,col1));
	}
	,setTextTokenPosition: function(tag,lastToken,token) {
		var c0 = this.lc.getLocation(tag - 1,false);
		var c1 = this.lc.getLocation(tag,true);
		this.setTokenPosition(lastToken,token,c0[0],c0[1],c1[0],c1[1]);
	}
	,setTagTokenPosition: function(tag,lastToken,token) {
		var c0 = this.lc.getLocation(tag,true);
		var c1 = this.lc.getLocation(tag,false);
		this.setTokenPosition(lastToken,token,c0[0],c0[1],c1[0],c1[1]);
	}
	,setLocator: function() {
		this.token = this.tokens.length;
		this.line = this.sxp.getLineNumber();
		this.col = this.sxp.getColumnNumber();
	}
	,setLastLocator: function(text) {
		this.lastLine = this.sxp.getLineNumber();
		this.lastCol = this.sxp.getColumnNumber();
		this.lastToken = this.tokens.length;
		if(!text) {
			this.lastNoTextLine = this.lastLine;
			this.lastNoTextCol = this.lastCol;
			this.lastNoTextToken = this.tokens.length;
		}
	}
	,ensureNoParsing: function() {
		if(this.parsing) throw "Already parsing.";
	}
	,isParsing: function() {
		return this.parsing;
	}
	,add: function(str,type) {
		if(type == com.wiris.tokens.XMLToken.TEXT) this.tokens.push(str); else this.tokens.push(new com.wiris.tokens.XMLToken(str,type));
	}
	,flushCharacters: function() {
		var str = this.sb.b;
		if(str.length == 0) return;
		if(StringTools.trim(str).length != 0) {
			if(!this.isSplitChars()) {
				this.add(str,com.wiris.tokens.XMLToken.TEXT);
				if(this.lc != null) this.setTextTokenPosition(this.tag - 1,this.lastToken,this.tokens.length); else this.setTokenPosition(this.lastToken,this.tokens.length,this.lastNoTextLine,this.lastNoTextCol,this.lastLine,this.lastCol);
			} else {
				var i;
				var _g1 = 0, _g = str.length;
				while(_g1 < _g) {
					var i1 = _g1++;
					this.add("" + str.charAt(i1),com.wiris.tokens.XMLToken.TEXT);
					if(this.lc != null) this.setTextTokenPosition(this.tag - 1,this.lastToken,this.tokens.length); else this.setTokenPosition(this.lastToken,this.tokens.length,this.lastNoTextLine,this.lastNoTextCol,this.lastLine,this.lastCol);
				}
			}
		}
		this.sb = new StringBuf();
	}
	,showLocation: function(str,tag) {
		if(this.lc == null) return;
		var c0 = this.lc.getLocation(tag,true);
		var c1 = this.lc.getLocation(tag,false);
		console.log("<" + str + ">: " + c0[0] + ":" + c0[1] + "-->" + c1[0] + ":" + c1[1]);
	}
	,showTextLocation: function(str,tag) {
		if(this.lc == null) return;
		var c0 = this.lc.getLocation(tag - 1,false);
		var c1 = this.lc.getLocation(tag,true);
		console.log(str + ": " + c0[0] + ":" + c0[1] + "-->" + c1[0] + ":" + c1[1]);
	}
	,processingInstruction: function(target,data) {
		this.tag++;
		this.setLastLocator(false);
	}
	,characters: function(content) {
		this.setLastLocator(true);
		this.sb.b += Std.string(content);
	}
	,endElement: function(uri,localName,qName) {
		this.tag++;
		this.flushCharacters();
		var name;
		this.setLocator();
		name = localName != null && localName.length > 0?localName:qName;
		name = this.removeNamespace(name);
		this.add(name,com.wiris.tokens.XMLToken.END_ELEMENT);
		if(this.lc != null) this.setTagTokenPosition(this.tag - 1,this.lastToken,this.tokens.length); else this.setTokenPosition(this.lastToken,this.tokens.length,this.lastLine,this.lastCol,this.line,this.col);
		this.setLastLocator(false);
		this.depth--;
		if(this.depth == 0) this.parsing = false;
	}
	,addAttribute: function(name,value) {
		this.add(name,com.wiris.tokens.XMLToken.TEXT);
		this.add("=",com.wiris.tokens.XMLToken.TEXT);
		this.add("\"",com.wiris.tokens.XMLToken.OPEN_QUOTE);
		if(value != null && value.length != 0) this.add(value,com.wiris.tokens.XMLToken.TEXT);
		this.add("\"",com.wiris.tokens.XMLToken.CLOSE_QUOTE);
	}
	,startElement: function(uri,localName,qName,atts) {
		this.tag++;
		this.depth++;
		this.flushCharacters();
		var name;
		this.setLocator();
		name = localName != null && localName.length > 0?localName:qName;
		name = this.removeNamespace(name);
		if(atts != null && atts.getLength() > 0) {
			var v = new Array();
			var i;
			var _g1 = 0, _g = atts.getLength();
			while(_g1 < _g) {
				var i1 = _g1++;
				var qname = atts.getName(i1);
				if(!this.isIgnoredAttribute(qname)) com.wiris.util.type.Arrays.insertSorted(v,qname);
			}
			if(v.length > 0) {
				var ss = new Array();
				var _g1 = 0, _g = v.length;
				while(_g1 < _g) {
					var i1 = _g1++;
					ss[i1] = v[i1];
				}
				this.add(name,com.wiris.tokens.XMLToken.BEGIN_TAG_ELEMENT);
				var _g1 = 0, _g = ss.length;
				while(_g1 < _g) {
					var i1 = _g1++;
					var key, value;
					key = ss[i1];
					value = atts.getValueFromName(ss[i1]);
					if(StringTools.startsWith(key,"xmlns:") && atts.getValueFromName(key) == com.wiris.tokens.SAXTokenizer.MATHML_NAMESPACE) key = "xmlns";
					this.addAttribute(key,value);
				}
				this.add(">",com.wiris.tokens.XMLToken.END_TAG_ELEMENT);
			} else this.add(name,com.wiris.tokens.XMLToken.BEGIN_ELEMENT);
		} else this.add(name,com.wiris.tokens.XMLToken.BEGIN_ELEMENT);
		if(this.lc != null) this.setTagTokenPosition(this.tag - 1,this.lastToken,this.tokens.length); else this.setTokenPosition(this.lastToken,this.tokens.length,this.lastLine,this.lastCol,this.line,this.col);
		this.setLastLocator(false);
	}
	,endDocument: function() {
		this.parsing = false;
	}
	,startDocument: function() {
		this.tag = 0;
		this.setLastLocator(false);
	}
	,setFileName: function(fileName) {
		this.fileName = fileName;
	}
	,setIgnoreAttributes: function(names) {
		this.ignoreAtts = names;
	}
	,sxp: null
	,ignoreAtts: null
	,depth: null
	,tag: null
	,lc: null
	,splitChars: null
	,fileName: null
	,pm: null
	,col: null
	,line: null
	,token: null
	,lastNoTextToken: null
	,lastNoTextCol: null
	,lastNoTextLine: null
	,lastToken: null
	,lastCol: null
	,lastLine: null
	,sb: null
	,parsing: null
	,pos: null
	,tokens: null
	,__class__: com.wiris.tokens.SAXTokenizer
}
com.wiris.tokens.TokensVector = $hxClasses["com.wiris.tokens.TokensVector"] = function(v) {
	this.v = v;
};
com.wiris.tokens.TokensVector.__name__ = ["com","wiris","tokens","TokensVector"];
com.wiris.tokens.TokensVector.__interfaces__ = [com.wiris.tokens.Tokens];
com.wiris.tokens.TokensVector.prototype = {
	toStringPosition: function(a,b) {
		return "Positions from " + a + " to " + b;
	}
	,getParentPositions: function(a,b) {
		return null;
	}
	,getParent: function() {
		return null;
	}
	,getVector: function() {
		return this.v;
	}
	,v: null
	,__class__: com.wiris.tokens.TokensVector
}
com.wiris.tokens.XMLToken = $hxClasses["com.wiris.tokens.XMLToken"] = function(name,type) {
	this.name = name;
	this.type = type;
};
com.wiris.tokens.XMLToken.__name__ = ["com","wiris","tokens","XMLToken"];
com.wiris.tokens.XMLToken.prototype = {
	isEqual: function(o) {
		if(js.Boot.__instanceof(o,com.wiris.tokens.XMLToken)) {
			var t = o;
			return this.type == t.type && this.name == t.name;
		}
		return false;
	}
	,toString: function() {
		if(this.type == com.wiris.tokens.XMLToken.BEGIN_ELEMENT) return "<" + this.name + ">";
		if(this.type == com.wiris.tokens.XMLToken.END_ELEMENT) return "</" + this.name + ">";
		if(this.type == com.wiris.tokens.XMLToken.BEGIN_TAG_ELEMENT) return "<" + this.name + " "; else return this.name;
	}
	,type: null
	,name: null
	,__class__: com.wiris.tokens.XMLToken
}
if(!com.wiris.util.type) com.wiris.util.type = {}
com.wiris.util.type.Arrays = $hxClasses["com.wiris.util.type.Arrays"] = function() {
};
com.wiris.util.type.Arrays.__name__ = ["com","wiris","util","type","Arrays"];
com.wiris.util.type.Arrays.newIntArray = function(length,initValue) {
	var data = new Array();
	--length;
	while(length >= 0) {
		data[length] = initValue;
		--length;
	}
	return data;
}
com.wiris.util.type.Arrays.indexOfElement = function(array,element) {
	var i = 0;
	var n = array.length;
	while(i < n) {
		if(array[i] != null && array[i] == element) return i;
		++i;
	}
	return -1;
}
com.wiris.util.type.Arrays.fromIterator = function(iterator) {
	var array = new Array();
	while(iterator.hasNext()) array.push(iterator.next());
	return array;
}
com.wiris.util.type.Arrays.fromCSV = function(s) {
	var words = s.split(",");
	var i = 0;
	while(i < words.length) {
		var w = StringTools.trim(words[i]);
		if(w.length > 0) {
			words[i] = w;
			++i;
		} else words.splice(i,1);
	}
	return words;
}
com.wiris.util.type.Arrays.contains = function(array,element) {
	return com.wiris.util.type.Arrays.indexOfElement(array,element) >= 0;
}
com.wiris.util.type.Arrays.indexOfElementArray = function(array,element) {
	var i;
	var _g1 = 0, _g = array.length;
	while(_g1 < _g) {
		var i1 = _g1++;
		if(array[i1] != null && array[i1] == element) return i1;
	}
	return -1;
}
com.wiris.util.type.Arrays.indexOfElementInt = function(array,element) {
	var i;
	var _g1 = 0, _g = array.length;
	while(_g1 < _g) {
		var i1 = _g1++;
		if(array[i1] == element) return i1;
	}
	return -1;
}
com.wiris.util.type.Arrays.containsArray = function(array,element) {
	return com.wiris.util.type.Arrays.indexOfElementArray(array,element) >= 0;
}
com.wiris.util.type.Arrays.containsInt = function(array,element) {
	return com.wiris.util.type.Arrays.indexOfElementInt(array,element) >= 0;
}
com.wiris.util.type.Arrays.clear = function(a) {
	var i = a.length - 1;
	while(i >= 0) {
		HxOverrides.remove(a,a[i]);
		i--;
	}
}
com.wiris.util.type.Arrays.sort = function(elements,comparator) {
	com.wiris.util.type.Arrays.quicksort(elements,0,elements.length - 1,comparator);
}
com.wiris.util.type.Arrays.insertSorted = function(a,e) {
	com.wiris.util.type.Arrays.insertSortedImpl(a,e,false);
}
com.wiris.util.type.Arrays.insertSortedSet = function(a,e) {
	com.wiris.util.type.Arrays.insertSortedImpl(a,e,true);
}
com.wiris.util.type.Arrays.insertSortedImpl = function(a,e,set) {
	var imin = 0;
	var imax = a.length;
	while(imin < imax) {
		var imid = Math.floor((imax + imin) / 2);
		var cmp = Reflect.compare(a[imid],e);
		if(cmp == 0) {
			if(set) return; else {
				imin = imid;
				imax = imid;
			}
		} else if(cmp < 0) imin = imid + 1; else imax = imid;
	}
	a.splice(imin,0,e);
}
com.wiris.util.type.Arrays.copyArray = function(a) {
	var b = new Array();
	var i = HxOverrides.iter(a);
	while(i.hasNext()) b.push(i.next());
	return b;
}
com.wiris.util.type.Arrays.addAll = function(baseArray,additionArray) {
	var i = HxOverrides.iter(additionArray);
	while(i.hasNext()) baseArray.push(i.next());
}
com.wiris.util.type.Arrays.quicksort = function(elements,lower,higher,comparator) {
	if(lower < higher) {
		var p = com.wiris.util.type.Arrays.partition(elements,lower,higher,comparator);
		com.wiris.util.type.Arrays.quicksort(elements,lower,p - 1,comparator);
		com.wiris.util.type.Arrays.quicksort(elements,p,higher,comparator);
	}
}
com.wiris.util.type.Arrays.partition = function(elements,lower,higher,comparator) {
	var pivot = elements[higher];
	var i = lower - 1;
	var j = lower;
	while(j < higher) {
		if(comparator.compare(pivot,elements[j]) == 1) {
			i++;
			if(i != j) {
				var swapper = elements[i];
				elements[i] = elements[j];
				elements[j] = swapper;
			}
		}
		j++;
	}
	var finalSwap = elements[i + 1];
	elements[i + 1] = elements[higher];
	elements[higher] = finalSwap;
	return i + 1;
}
com.wiris.util.type.Arrays.prototype = {
	__class__: com.wiris.util.type.Arrays
}
com.wiris.util.type.Comparator = $hxClasses["com.wiris.util.type.Comparator"] = function() { }
com.wiris.util.type.Comparator.__name__ = ["com","wiris","util","type","Comparator"];
com.wiris.util.type.Comparator.prototype = {
	compare: null
	,__class__: com.wiris.util.type.Comparator
}
com.wiris.util.type.IntegerTools = $hxClasses["com.wiris.util.type.IntegerTools"] = function() { }
com.wiris.util.type.IntegerTools.__name__ = ["com","wiris","util","type","IntegerTools"];
com.wiris.util.type.IntegerTools.max = function(x,y) {
	return x > y?x:y;
}
com.wiris.util.type.IntegerTools.min = function(x,y) {
	return x < y?x:y;
}
com.wiris.util.type.IntegerTools.clamp = function(x,a,b) {
	return com.wiris.util.type.IntegerTools.min(com.wiris.util.type.IntegerTools.max(a,x),b);
}
com.wiris.util.type.IntegerTools.isInt = function(x) {
	return new EReg("[\\+\\-]?\\d+","").match(x);
}
com.wiris.util.xml.Attributes = $hxClasses["com.wiris.util.xml.Attributes"] = function() {
	this.names = new Array();
	this.values = new Hash();
};
com.wiris.util.xml.Attributes.__name__ = ["com","wiris","util","xml","Attributes"];
com.wiris.util.xml.Attributes.prototype = {
	getLength: function() {
		return this.names.length;
	}
	,add: function(name,value) {
		if(com.wiris.util.type.Arrays.indexOfElement(this.names,name) == -1) this.names.push(name);
		this.values.set(name,value);
	}
	,getValueFromName: function(name) {
		return this.values.get(name);
	}
	,getValue: function(i) {
		return this.values.get(this.getName(i));
	}
	,getName: function(i) {
		return this.names[i];
	}
	,values: null
	,names: null
	,__class__: com.wiris.util.xml.Attributes
}
com.wiris.util.xml.EntityResolver = $hxClasses["com.wiris.util.xml.EntityResolver"] = function() { }
com.wiris.util.xml.EntityResolver.__name__ = ["com","wiris","util","xml","EntityResolver"];
com.wiris.util.xml.EntityResolver.prototype = {
	resolveEntity: null
	,__class__: com.wiris.util.xml.EntityResolver
}
com.wiris.util.xml.MathMLEntityResolver = $hxClasses["com.wiris.util.xml.MathMLEntityResolver"] = function() {
};
com.wiris.util.xml.MathMLEntityResolver.__name__ = ["com","wiris","util","xml","MathMLEntityResolver"];
com.wiris.util.xml.MathMLEntityResolver.__interfaces__ = [com.wiris.util.xml.EntityResolver];
com.wiris.util.xml.MathMLEntityResolver.prototype = {
	resolveEntity: function(name) {
		return com.wiris.util.xml.WXmlUtils.resolveMathMLEntity(name);
	}
	,__class__: com.wiris.util.xml.MathMLEntityResolver
}
com.wiris.util.xml.SAXParser = $hxClasses["com.wiris.util.xml.SAXParser"] = function() {
	this.lineNumber = -1;
	this.columnNumber = -1;
	this.entityResolvers = new Array();
};
com.wiris.util.xml.SAXParser.__name__ = ["com","wiris","util","xml","SAXParser"];
com.wiris.util.xml.SAXParser.isValidInitCharacter = function(c) {
	return com.wiris.util.xml.WCharacterBase.isLetter(c) || c == com.wiris.util.xml.SAXParser.CHAR_UNDERSCORE || c == com.wiris.util.xml.SAXParser.CHAR_COLON;
}
com.wiris.util.xml.SAXParser.isValidCharacter = function(c) {
	return com.wiris.util.xml.WCharacterBase.isLetter(c) || com.wiris.util.xml.WCharacterBase.isDigit(c) || c == com.wiris.util.xml.SAXParser.CHAR_UNDERSCORE || c == com.wiris.util.xml.SAXParser.CHAR_HYPHEN || c == com.wiris.util.xml.SAXParser.CHAR_DOT || c == com.wiris.util.xml.SAXParser.CHAR_COLON;
}
com.wiris.util.xml.SAXParser.formatLineEnds = function(data) {
	if(data == "") return data;
	var sb = new StringBuf();
	var it = com.wiris.system.Utf8.getIterator(data);
	var carriageReturn = false;
	while(it.hasNext()) {
		var c = it.next();
		if(c == com.wiris.util.xml.SAXParser.CHAR_CARRIAGE_RETURN) {
			carriageReturn = true;
			sb.b += String.fromCharCode(com.wiris.util.xml.SAXParser.CHAR_LINE_FEED);
		} else if(carriageReturn) {
			carriageReturn = false;
			if(c != com.wiris.util.xml.SAXParser.CHAR_LINE_FEED) sb.b += String.fromCharCode(c);
		} else sb.b += String.fromCharCode(c);
	}
	return sb.b;
}
com.wiris.util.xml.SAXParser.prototype = {
	ignoreSpaces: function() {
		while(this.currentIsBlank()) this.nextChar();
	}
	,currentIsBlank: function() {
		return this.current == com.wiris.util.xml.SAXParser.CHAR_SPACE || this.current == com.wiris.util.xml.SAXParser.CHAR_LINE_FEED || this.current == com.wiris.util.xml.SAXParser.CHAR_CARRIAGE_RETURN || this.current == com.wiris.util.xml.SAXParser.CHAR_TAB;
	}
	,searchString: function(search) {
		if(search == "") return true;
		var it = com.wiris.system.Utf8.getIterator(search);
		var notFirst = false;
		var searchChar = it.next();
		while(this.current != -1) {
			if(this.current == searchChar) {
				if(!it.hasNext()) return true;
				searchChar = it.next();
				notFirst = true;
			} else if(notFirst) {
				it = com.wiris.system.Utf8.getIterator(search);
				searchChar = it.next();
				notFirst = false;
			}
			this.nextChar();
		}
		return false;
	}
	,nextChar: function() {
		if(this.iterator.hasNext()) {
			this.last = this.current;
			this.current = this.iterator.next();
			this.index += com.wiris.system.Utf8.uchr(this.current).length;
			if(this.last == com.wiris.util.xml.SAXParser.CHAR_LINE_FEED || this.last == com.wiris.util.xml.SAXParser.CHAR_CARRIAGE_RETURN && this.current != com.wiris.util.xml.SAXParser.CHAR_LINE_FEED) {
				this.columnNumber = 1;
				this.lineNumber++;
			} else this.columnNumber++;
		} else this.current = -1;
	}
	,parseEntities: function(pcdata) {
		if(pcdata == null || pcdata == "") return "";
		var in1 = pcdata.indexOf("&");
		var in2;
		if(in1 == -1) return pcdata;
		in2 = pcdata.indexOf(";",in1);
		var parsed = new StringBuf();
		parsed.b += Std.string(HxOverrides.substr(pcdata,0,in1));
		while(in2 != -1 && in1 < pcdata.length && in2 < pcdata.length) {
			in1++;
			var entity = HxOverrides.substr(pcdata,in1,in2 - in1);
			in2++;
			if(entity == "quot") parsed.b += Std.string("\""); else if(entity == "lt") parsed.b += Std.string("<"); else if(entity == "gt") parsed.b += Std.string(">"); else if(entity == "apos") parsed.b += Std.string("'"); else if(entity == "amp") parsed.b += Std.string("&"); else if(HxOverrides.cca(entity,0) == com.wiris.util.xml.SAXParser.CHAR_HASH) {
				var newvalue;
				var utfvalue = 0;
				if(HxOverrides.cca(entity,1) == com.wiris.util.xml.SAXParser.CHAR_X) {
					var value = HxOverrides.substr(entity,2,null);
					utfvalue = Std.parseInt("0x" + value);
				} else {
					var value = HxOverrides.substr(entity,1,null);
					utfvalue = Std.parseInt(value);
				}
				if(utfvalue == 0) throw "Invalid numeric entity.";
				newvalue = com.wiris.system.Utf8.uchr(utfvalue);
				parsed.b += Std.string(newvalue);
			} else {
				var r = 0;
				var sol = -1;
				while(r < this.entityResolvers.length && sol == -1) {
					sol = this.entityResolvers[r].resolveEntity(entity);
					r++;
				}
				if(sol != -1) parsed.b += Std.string(com.wiris.system.Utf8.uchr(sol)); else parsed.b += Std.string("&" + entity + ";");
			}
			in1 = pcdata.indexOf("&",in2);
			if(in1 == -1) {
				parsed.b += Std.string(HxOverrides.substr(pcdata,in2,null));
				in2 = pcdata.length;
			} else {
				parsed.b += Std.string(HxOverrides.substr(pcdata,in2,in1 - in2));
				in2 = pcdata.indexOf(";",in1);
			}
		}
		return parsed.b;
	}
	,parse: function(source,c) {
		if(source.length > 0) {
			this.lineNumber = 1;
			this.columnNumber = 0;
		}
		this.xml = source;
		this.iterator = com.wiris.system.Utf8.getIterator(this.xml);
		c.startDocument();
		var state = com.wiris.util.xml.SAXParser.IGNORE_SPACES;
		var nextState = com.wiris.util.xml.SAXParser.BEGIN;
		var names = new Array();
		var attribName;
		var attribs = new com.wiris.util.xml.Attributes();
		this.index = 0;
		var lastIndex = 0;
		var characters = new StringBuf();
		this.nextChar();
		while(this.current != -1) {
			if(state == com.wiris.util.xml.SAXParser.BEGIN) {
				if(this.current == com.wiris.util.xml.SAXParser.CHAR_LESS_THAN) {
					state = com.wiris.util.xml.SAXParser.BEGIN_NODE;
					nextState = com.wiris.util.xml.SAXParser.BEGIN;
				} else throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
			} else if(state == com.wiris.util.xml.SAXParser.BEGIN_NODE) {
				if(this.current == com.wiris.util.xml.SAXParser.CHAR_EXCLAMATION) {
					this.nextChar();
					if(this.current == com.wiris.util.xml.SAXParser.CHAR_HYPHEN) {
						this.nextChar();
						if(this.current == com.wiris.util.xml.SAXParser.CHAR_HYPHEN) {
							state = com.wiris.util.xml.SAXParser.COMMENT;
							continue;
						} else throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
					} else if(this.current == com.wiris.util.xml.SAXParser.CHAR_OPEN_SQUARE_BRACKET) {
						if(this.searchString("CDATA[")) state = com.wiris.util.xml.SAXParser.CDATA; else throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
					} else throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
				} else {
					var ch = characters.b;
					if(!(ch == "")) {
						this.columnNumber -= 2;
						c.characters(ch);
						this.columnNumber += 2;
					}
					characters = new StringBuf();
					if(this.current == com.wiris.util.xml.SAXParser.CHAR_INTERROGATION) state = com.wiris.util.xml.SAXParser.HEADER; else if(this.current == com.wiris.util.xml.SAXParser.CHAR_BAR) state = com.wiris.util.xml.SAXParser.TAG_NAME_CLOSE; else if(com.wiris.util.xml.SAXParser.isValidInitCharacter(this.current)) {
						state = com.wiris.util.xml.SAXParser.TAG_NAME;
						continue;
					} else throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
				}
			} else if(state == com.wiris.util.xml.SAXParser.TAG_NAME) {
				var sb = new StringBuf();
				while(com.wiris.util.xml.SAXParser.isValidCharacter(this.current)) {
					sb.b += String.fromCharCode(this.current);
					this.nextChar();
				}
				var tagName = sb.b;
				names.push(tagName);
				if(this.currentIsBlank()) {
					state = com.wiris.util.xml.SAXParser.IGNORE_SPACES;
					nextState = com.wiris.util.xml.SAXParser.BODY;
				} else if(this.current == com.wiris.util.xml.SAXParser.CHAR_BAR) {
					state = com.wiris.util.xml.SAXParser.BODY;
					continue;
				} else if(this.current == com.wiris.util.xml.SAXParser.CHAR_GREATER_THAN) {
					c.startElement("","",tagName,new com.wiris.util.xml.Attributes());
					state = com.wiris.util.xml.SAXParser.CHILDS;
				} else throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
			} else if(state == com.wiris.util.xml.SAXParser.TAG_NAME_CLOSE) {
				var sb = new StringBuf();
				while(com.wiris.util.xml.SAXParser.isValidCharacter(this.current)) {
					sb.b += String.fromCharCode(this.current);
					this.nextChar();
				}
				var tagName = sb.b;
				this.ignoreSpaces();
				var name = names[names.length - 1];
				if(this.current == com.wiris.util.xml.SAXParser.CHAR_GREATER_THAN && tagName == name) {
					names.pop();
					c.endElement("","",tagName);
					state = com.wiris.util.xml.SAXParser.CHILDS;
				} else throw "Expected </" + tagName + ">";
			} else if(state == com.wiris.util.xml.SAXParser.IGNORE_SPACES) {
				if(!this.currentIsBlank()) {
					state = nextState;
					continue;
				}
			} else if(state == com.wiris.util.xml.SAXParser.COMMENT) {
				if(this.searchString("-->")) state = nextState; else throw "Comment not closed.";
			} else if(state == com.wiris.util.xml.SAXParser.BODY) {
				if(this.current == com.wiris.util.xml.SAXParser.CHAR_BAR) {
					this.nextChar();
					if(this.current == com.wiris.util.xml.SAXParser.CHAR_GREATER_THAN) {
						var tagName = names.pop();
						c.startElement("","",tagName,attribs);
						attribs = new com.wiris.util.xml.Attributes();
						c.endElement("","",tagName);
						state = com.wiris.util.xml.SAXParser.CHILDS;
					} else throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
				} else if(this.current == com.wiris.util.xml.SAXParser.CHAR_GREATER_THAN) {
					c.startElement("","",names[names.length - 1],attribs);
					attribs = new com.wiris.util.xml.Attributes();
					state = com.wiris.util.xml.SAXParser.CHILDS;
				} else if(com.wiris.util.xml.SAXParser.isValidInitCharacter(this.current)) {
					state = com.wiris.util.xml.SAXParser.ATTRIB;
					continue;
				} else throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
			} else if(state == com.wiris.util.xml.SAXParser.HEADER) {
				if(this.searchString("?>")) {
					state = com.wiris.util.xml.SAXParser.IGNORE_SPACES;
					nextState = com.wiris.util.xml.SAXParser.BEGIN;
				} else throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
			} else if(state == com.wiris.util.xml.SAXParser.ATTRIB) {
				if(this.searchString("=")) {
					attribName = HxOverrides.substr(this.xml,lastIndex,this.index - lastIndex - 1);
					this.nextChar();
					this.ignoreSpaces();
					lastIndex = this.index;
					if(this.current == com.wiris.util.xml.SAXParser.CHAR_DOUBLE_QUOT) {
						this.nextChar();
						if(!this.searchString("\"")) throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
					} else if(this.current == com.wiris.util.xml.SAXParser.CHAR_QUOT) {
						this.nextChar();
						if(!this.searchString("'")) throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
					} else throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
					var value = HxOverrides.substr(this.xml,lastIndex,this.index - lastIndex - 1);
					value = com.wiris.util.xml.SAXParser.formatLineEnds(value);
					if(attribs.getValueFromName(attribName) != null) throw "Attribute " + attribName + " already used in this tag."; else attribs.add(attribName,this.parseEntities(value));
				} else throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
				state = com.wiris.util.xml.SAXParser.IGNORE_SPACES;
				nextState = com.wiris.util.xml.SAXParser.BODY;
			} else if(state == com.wiris.util.xml.SAXParser.CHILDS) {
				if(this.searchString("<")) {
					var pcdata = HxOverrides.substr(this.xml,lastIndex,this.index - lastIndex - 1);
					var parsedPCData = this.parseEntities(pcdata);
					parsedPCData = com.wiris.util.xml.SAXParser.formatLineEnds(parsedPCData);
					characters.b += Std.string(parsedPCData);
					state = com.wiris.util.xml.SAXParser.BEGIN_NODE;
					nextState = com.wiris.util.xml.SAXParser.CHILDS;
				} else if(this.current != -1) throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
			} else if(state == com.wiris.util.xml.SAXParser.CDATA) {
				if(this.searchString("]]>")) {
					var cdata = HxOverrides.substr(this.xml,lastIndex,this.index - lastIndex - 3);
					cdata = com.wiris.util.xml.SAXParser.formatLineEnds(cdata);
					characters.b += Std.string(cdata);
					state = com.wiris.util.xml.SAXParser.CHILDS;
					nextState = com.wiris.util.xml.SAXParser.BEGIN;
				} else throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
			}
			lastIndex = this.index;
			this.nextChar();
		}
		var remainder = characters.b;
		if(!(remainder == "")) c.characters(remainder);
		if(names.length > 0) throw com.wiris.util.xml.SAXParser.MALFORMED_XML;
		c.endDocument();
	}
	,addEntityResolver: function(e) {
		this.entityResolvers.push(e);
	}
	,getColumnNumber: function() {
		return this.columnNumber;
	}
	,getLineNumber: function() {
		return this.lineNumber;
	}
	,iterator: null
	,xml: null
	,last: null
	,current: null
	,index: null
	,entityResolvers: null
	,columnNumber: null
	,lineNumber: null
	,__class__: com.wiris.util.xml.SAXParser
}
com.wiris.util.xml.WCharacterBase = $hxClasses["com.wiris.util.xml.WCharacterBase"] = function() { }
com.wiris.util.xml.WCharacterBase.__name__ = ["com","wiris","util","xml","WCharacterBase"];
com.wiris.util.xml.WCharacterBase.isDigit = function(c) {
	if(48 <= c && c <= 57) return true;
	if(1632 <= c && c <= 1641) return true;
	if(1776 <= c && c <= 1785) return true;
	if(2790 <= c && c <= 2799) return true;
	return false;
}
com.wiris.util.xml.WCharacterBase.isIdentifier = function(c) {
	return com.wiris.util.xml.WCharacterBase.isLetter(c) || com.wiris.util.xml.WCharacterBase.isCombiningCharacter(c) || c == 95;
}
com.wiris.util.xml.WCharacterBase.isLarge = function(c) {
	return com.wiris.util.xml.WCharacterBase.binarySearch(com.wiris.util.xml.WCharacterBase.largeOps,c);
}
com.wiris.util.xml.WCharacterBase.isVeryLarge = function(c) {
	return com.wiris.util.xml.WCharacterBase.binarySearch(com.wiris.util.xml.WCharacterBase.veryLargeOps,c);
}
com.wiris.util.xml.WCharacterBase.isBinaryOp = function(c) {
	return com.wiris.util.xml.WCharacterBase.binarySearch(com.wiris.util.xml.WCharacterBase.binaryOps,c);
}
com.wiris.util.xml.WCharacterBase.isRelation = function(c) {
	return com.wiris.util.xml.WCharacterBase.binarySearch(com.wiris.util.xml.WCharacterBase.relations,c);
}
com.wiris.util.xml.WCharacterBase.binarySearch = function(v,c) {
	var min = 0;
	var max = v.length - 1;
	do {
		var mid = Math.floor((min + max) / 2);
		var cc = v[mid];
		if(c == cc) return true; else if(c < cc) max = mid - 1; else min = mid + 1;
	} while(min <= max);
	return false;
}
com.wiris.util.xml.WCharacterBase.initAccentsDictionary = function() {
	if(com.wiris.util.xml.WCharacterBase.accentsDictionary != null) return;
	var h = new Hash();
	h.set("A",[192,193,194,195,196,197,256,258,260,461,478,480,506,512,514,550,570,7680,7840,7842,7844,7846,7848,7850,7852,7854,7856,7858,7860,7862,9398,11375,65313]);
	h.set("AA",[42802]);
	h.set("AE",[198,482,508]);
	h.set("AO",[42804]);
	h.set("AU",[42806]);
	h.set("AV",[42808,42810]);
	h.set("AY",[42812]);
	h.set("B",[385,386,579,7682,7684,7686,9399,65314]);
	h.set("C",[199,262,264,266,268,391,571,7688,9400,42814,65315]);
	h.set("D",[208,270,272,393,394,395,7690,7692,7694,7696,7698,9401,42873,65316]);
	h.set("DZ",[452,497]);
	h.set("Dz",[453,498]);
	h.set("E",[200,201,202,203,274,276,278,280,282,398,400,516,518,552,7700,7702,7704,7706,7708,7864,7866,7868,7870,7872,7874,7876,7878,9402,65317]);
	h.set("F",[401,7710,9403,42875,65318]);
	h.set("G",[284,286,288,290,403,484,486,500,7712,9404,42877,42878,42912,65319]);
	h.set("H",[292,294,542,7714,7716,7718,7720,7722,9405,11367,11381,42893,65320]);
	h.set("I",[204,205,206,207,296,298,300,302,304,407,463,520,522,7724,7726,7880,7882,9406,65321]);
	h.set("J",[308,584,9407,65322]);
	h.set("K",[310,408,488,7728,7730,7732,9408,11369,42816,42818,42820,42914,65323]);
	h.set("L",[313,315,317,319,321,573,7734,7736,7738,7740,9409,11360,11362,42822,42824,42880,65324]);
	h.set("LJ",[455]);
	h.set("Lj",[456]);
	h.set("M",[412,7742,7744,7746,9410,11374,65325]);
	h.set("N",[209,323,325,327,413,504,544,7748,7750,7752,7754,9411,42896,42916,65326]);
	h.set("NJ",[458]);
	h.set("Nj",[459]);
	h.set("O",[210,211,212,213,214,216,332,334,336,390,415,416,465,490,492,510,524,526,554,556,558,560,7756,7758,7760,7762,7884,7886,7888,7890,7892,7894,7896,7898,7900,7902,7904,7906,9412,42826,42828,65327]);
	h.set("OI",[418]);
	h.set("OO",[42830]);
	h.set("OU",[546]);
	h.set("OE",[140,338]);
	h.set("oe",[156,339]);
	h.set("P",[420,7764,7766,9413,11363,42832,42834,42836,65328]);
	h.set("Q",[586,9414,42838,42840,65329]);
	h.set("R",[340,342,344,528,530,588,7768,7770,7772,7774,9415,11364,42842,42882,42918,65330]);
	h.set("S",[346,348,350,352,536,7776,7778,7780,7782,7784,7838,9416,11390,42884,42920,65331]);
	h.set("T",[354,356,358,428,430,538,574,7786,7788,7790,7792,9417,42886,65332]);
	h.set("TZ",[42792]);
	h.set("U",[217,218,219,220,360,362,364,366,368,370,431,467,469,471,473,475,532,534,580,7794,7796,7798,7800,7802,7908,7910,7912,7914,7916,7918,7920,9418,65333]);
	h.set("V",[434,581,7804,7806,9419,42846,65334]);
	h.set("VY",[42848]);
	h.set("W",[372,7808,7810,7812,7814,7816,9420,11378,65335]);
	h.set("X",[7818,7820,9421,65336]);
	h.set("Y",[221,374,376,435,562,590,7822,7922,7924,7926,7928,7934,9422,65337]);
	h.set("Z",[377,379,381,437,548,7824,7826,7828,9423,11371,11391,42850,65338]);
	h.set("a",[224,225,226,227,228,229,257,259,261,462,479,481,507,513,515,551,592,7681,7834,7841,7843,7845,7847,7849,7851,7853,7855,7857,7859,7861,7863,9424,11365,65345]);
	h.set("aa",[42803]);
	h.set("ae",[230,483,509]);
	h.set("ao",[42805]);
	h.set("au",[42807]);
	h.set("av",[42809,42811]);
	h.set("ay",[42813]);
	h.set("b",[384,387,595,7683,7685,7687,9425,65346]);
	h.set("c",[231,263,265,267,269,392,572,7689,8580,9426,42815,65347]);
	h.set("d",[271,273,396,598,599,7691,7693,7695,7697,7699,9427,42874,65348]);
	h.set("dz",[454,499]);
	h.set("e",[232,233,234,235,275,277,279,281,283,477,517,519,553,583,603,7701,7703,7705,7707,7709,7865,7867,7869,7871,7873,7875,7877,7879,9428,65349]);
	h.set("f",[402,7711,9429,42876,65350]);
	h.set("g",[285,287,289,291,485,487,501,608,7545,7713,9430,42879,42913,65351]);
	h.set("h",[293,295,543,613,7715,7717,7719,7721,7723,7830,9431,11368,11382,65352]);
	h.set("hv",[405]);
	h.set("i",[236,237,238,239,297,299,301,303,305,464,521,523,616,7725,7727,7881,7883,9432,65353]);
	h.set("j",[309,496,585,9433,65354]);
	h.set("k",[311,409,489,7729,7731,7733,9434,11370,42817,42819,42821,42915,65355]);
	h.set("l",[314,316,318,320,322,383,410,619,7735,7737,7739,7741,9435,11361,42823,42825,42881,65356]);
	h.set("lj",[457]);
	h.set("m",[623,625,7743,7745,7747,9436,65357]);
	h.set("n",[241,324,326,328,329,414,505,626,7749,7751,7753,7755,9437,42897,42917,65358]);
	h.set("nj",[460]);
	h.set("o",[242,243,244,245,246,248,333,335,337,417,466,491,493,511,525,527,555,557,559,561,596,629,7757,7759,7761,7763,7885,7887,7889,7891,7893,7895,7897,7899,7901,7903,7905,7907,9438,42827,42829,65359]);
	h.set("oi",[419]);
	h.set("ou",[547]);
	h.set("oo",[42831]);
	h.set("p",[421,7549,7765,7767,9439,42833,42835,42837,65360]);
	h.set("q",[587,9440,42839,42841,65361]);
	h.set("r",[341,343,345,529,531,589,637,7769,7771,7773,7775,9441,42843,42883,42919,65362]);
	h.set("s",[223,347,349,351,353,537,575,7777,7779,7781,7783,7785,7835,9442,42885,42921,65363]);
	h.set("t",[355,357,359,429,539,648,7787,7789,7791,7793,7831,9443,11366,42887,65364]);
	h.set("tz",[42793]);
	h.set("u",[249,250,251,252,361,363,365,367,369,371,432,468,470,472,474,476,533,535,649,7795,7797,7799,7801,7803,7909,7911,7913,7915,7917,7919,7921,9444,65365]);
	h.set("v",[651,652,7805,7807,9445,42847,65366]);
	h.set("vy",[42849]);
	h.set("w",[373,7809,7811,7813,7815,7817,7832,9446,11379,65367]);
	h.set("x",[7819,7821,9447,65368]);
	h.set("y",[253,255,375,436,563,591,7823,7833,7923,7925,7927,7929,7935,9448,65369]);
	h.set("z",[378,380,382,438,549,576,7825,7827,7829,9449,11372,42851,65370]);
	com.wiris.util.xml.WCharacterBase.accentsDictionary = h;
}
com.wiris.util.xml.WCharacterBase.getCategoriesUnicode = function() {
	var categoriesUnicode = new Hash();
	categoriesUnicode.set(com.wiris.util.xml.WCharacterBase.SYMBOL_CATEGORY,"SymbolUnicodeCategory");
	categoriesUnicode.set(com.wiris.util.xml.WCharacterBase.PUNCTUATION_CATEGORY,"PunctuationUnicodeCategory");
	categoriesUnicode.set(com.wiris.util.xml.WCharacterBase.LETTER_CATEGORY,"LetterUnicodeCategory");
	categoriesUnicode.set(com.wiris.util.xml.WCharacterBase.MARK_CATEGORY,"MarkUnicodeCategory");
	categoriesUnicode.set(com.wiris.util.xml.WCharacterBase.NUMBER_CATEGORY,"NumberUnicodeCategory");
	categoriesUnicode.set(com.wiris.util.xml.WCharacterBase.PHONETICAL_CATEGORY,"PhoneticalUnicodeCategory");
	categoriesUnicode.set(com.wiris.util.xml.WCharacterBase.OTHER_CATEGORY,"OtherUnicodeCategory");
	return categoriesUnicode;
}
com.wiris.util.xml.WCharacterBase.getUnicodeCategoryList = function(category) {
	var indexStart = com.wiris.util.xml.WCharacterBase.UNICODES_WITH_CATEGORIES.indexOf("@" + category + ":");
	var unicodes = HxOverrides.substr(com.wiris.util.xml.WCharacterBase.UNICODES_WITH_CATEGORIES,indexStart + 3,null);
	var indexEnd = unicodes.indexOf("@");
	unicodes = HxOverrides.substr(unicodes,0,indexEnd);
	return com.wiris.util.xml.WCharacterBase.getUnicodesRangedStringList(unicodes);
}
com.wiris.util.xml.WCharacterBase.getUnicodesRangedStringList = function(unicodesRangedList) {
	var inputList = unicodesRangedList.split(",");
	var unicodeList = new Array();
	var i = 0;
	while(i < inputList.length) {
		var actual_range = inputList[i];
		actual_range = StringTools.replace(actual_range," ","");
		if(actual_range.indexOf("-") != -1) {
			var firstRangeValueHex = com.wiris.util.xml.WCharacterBase.hexStringToUnicode(actual_range.split("-")[0]);
			var lastRangeValueHex = com.wiris.util.xml.WCharacterBase.hexStringToUnicode(actual_range.split("-")[1]);
			var actualValue = firstRangeValueHex;
			while(actualValue <= lastRangeValueHex) {
				unicodeList.push(com.wiris.system.Utf8.uchr(actualValue));
				actualValue++;
			}
		} else {
			var actualValue = com.wiris.util.xml.WCharacterBase.hexStringToUnicode(actual_range);
			unicodeList.push(com.wiris.system.Utf8.uchr(actualValue));
		}
		i++;
	}
	return unicodeList;
}
com.wiris.util.xml.WCharacterBase.hexStringToUnicode = function(unicode) {
	return Std.parseInt("0x" + unicode);
}
com.wiris.util.xml.WCharacterBase.getMirror = function(str) {
	var mirroredStr = "";
	var i = 0;
	while(i < str.length) {
		var c = HxOverrides.cca(str,i);
		var j = 0;
		while(j < com.wiris.util.xml.WCharacterBase.mirrorDictionary.length) {
			if(c == com.wiris.util.xml.WCharacterBase.mirrorDictionary[j]) {
				c = com.wiris.util.xml.WCharacterBase.mirrorDictionary[j + 1];
				break;
			}
			j += 2;
		}
		mirroredStr += com.wiris.system.Utf8.uchr(c);
		++i;
	}
	return mirroredStr;
}
com.wiris.util.xml.WCharacterBase.isStretchyLTR = function(c) {
	var i = 0;
	while(i < com.wiris.util.xml.WCharacterBase.horizontalLTRStretchyChars.length) {
		if(c == com.wiris.util.xml.WCharacterBase.horizontalLTRStretchyChars[i]) return true;
		++i;
	}
	return false;
}
com.wiris.util.xml.WCharacterBase.getNegated = function(c) {
	var i = 0;
	while(i < com.wiris.util.xml.WCharacterBase.negations.length) {
		if(com.wiris.util.xml.WCharacterBase.negations[i] == c) return com.wiris.util.xml.WCharacterBase.negations[i + 1];
		i += 2;
	}
	return -1;
}
com.wiris.util.xml.WCharacterBase.getNotNegated = function(c) {
	var i = 1;
	while(i < com.wiris.util.xml.WCharacterBase.negations.length) {
		if(com.wiris.util.xml.WCharacterBase.negations[i] == c) return com.wiris.util.xml.WCharacterBase.negations[i - 1];
		i += 2;
	}
	return -1;
}
com.wiris.util.xml.WCharacterBase.isCombining = function(s) {
	var it = com.wiris.system.Utf8.getIterator(s);
	while(it.hasNext()) if(!com.wiris.util.xml.WCharacterBase.isCombiningCharacter(it.next())) return false;
	return true;
}
com.wiris.util.xml.WCharacterBase.isCombiningCharacter = function(c) {
	return c >= 768 && c <= 879 || c >= 6832 && c <= 6911 || c >= 7616 && c <= 7679 && (c >= 8400 && c <= 8447) && (c >= 65056 && c <= 65071);
}
com.wiris.util.xml.WCharacterBase.isLetter = function(c) {
	if(com.wiris.util.xml.WCharacterBase.isDigit(c)) return false;
	if(65 <= c && c <= 90) return true;
	if(97 <= c && c <= 122) return true;
	if(192 <= c && c <= 696 && c != 215 && c != 247) return true;
	if(867 <= c && c <= 1521) return true;
	if(1552 <= c && c <= 8188) return true;
	if(c == 8472 || c == 8467 || com.wiris.util.xml.WCharacterBase.isDoubleStruck(c) || com.wiris.util.xml.WCharacterBase.isFraktur(c) || com.wiris.util.xml.WCharacterBase.isScript(c)) return true;
	if(com.wiris.util.xml.WCharacterBase.isChinese(c)) return true;
	if(com.wiris.util.xml.WCharacterBase.isKorean(c)) return true;
	return false;
}
com.wiris.util.xml.WCharacterBase.isUnicodeMathvariant = function(c) {
	return com.wiris.util.xml.WCharacterBase.isDoubleStruck(c) || com.wiris.util.xml.WCharacterBase.isFraktur(c) || com.wiris.util.xml.WCharacterBase.isScript(c);
}
com.wiris.util.xml.WCharacterBase.isRequiredByQuizzes = function(c) {
	return c == 120128 || c == 8450 || c == 8461 || c == 8469 || c == 8473 || c == 8474 || c == 8477 || c == 8484;
}
com.wiris.util.xml.WCharacterBase.isDoubleStruck = function(c) {
	return c >= 120120 && c <= 120171 || c == 8450 || c == 8461 || c == 8469 || c == 8473 || c == 8474 || c == 8477 || c == 8484;
}
com.wiris.util.xml.WCharacterBase.isFraktur = function(c) {
	return c >= 120068 && c <= 120119 || c == 8493 || c == 8460 || c == 8465 || c == 8476 || c == 8488;
}
com.wiris.util.xml.WCharacterBase.isScript = function(c) {
	return c >= 119964 && c <= 120015 || c == 8458 || c == 8459 || c == 8466 || c == 8464 || c == 8499 || c == 8500 || c == 8492 || c == 8495 || c == 8496 || c == 8497 || c == 8475;
}
com.wiris.util.xml.WCharacterBase.isLowerCase = function(c) {
	return c >= 97 && c <= 122 || c >= 224 && c <= 255 || c >= 591 && c >= 659 || c >= 661 && c <= 687 || c >= 940 && c <= 974;
}
com.wiris.util.xml.WCharacterBase.isWord = function(c) {
	if(com.wiris.util.xml.WCharacterBase.isDevanagari(c) || com.wiris.util.xml.WCharacterBase.isChinese(c) || com.wiris.util.xml.WCharacterBase.isHebrew(c) || com.wiris.util.xml.WCharacterBase.isThai(c) || com.wiris.util.xml.WCharacterBase.isGujarati(c) || com.wiris.util.xml.WCharacterBase.isKorean(c)) return true;
	return false;
}
com.wiris.util.xml.WCharacterBase.isArabianString = function(s) {
	var i = s.length - 1;
	while(i >= 0) {
		if(!com.wiris.util.xml.WCharacterBase.isArabian(HxOverrides.cca(s,i))) return false;
		--i;
	}
	return true;
}
com.wiris.util.xml.WCharacterBase.isArabian = function(c) {
	if(c >= 1536 && c <= 1791 && !com.wiris.util.xml.WCharacterBase.isDigit(c)) return true;
	return false;
}
com.wiris.util.xml.WCharacterBase.isHebrew = function(c) {
	if(c >= 1424 && c <= 1535) return true;
	return false;
}
com.wiris.util.xml.WCharacterBase.isChinese = function(c) {
	if(c >= 13312 && c <= 40959) return true;
	return false;
}
com.wiris.util.xml.WCharacterBase.isKorean = function(c) {
	if(c >= 12593 && c <= 52044) return true;
	return false;
}
com.wiris.util.xml.WCharacterBase.isGreek = function(c) {
	if(c >= 945 && c <= 969) return true; else if(c >= 913 && c <= 937 && c != 930) return true; else if(c == 977 || c == 981 || c == 982) return true;
	return false;
}
com.wiris.util.xml.WCharacterBase.isDevanagari = function(c) {
	if(c >= 2304 && c < 2431) return true;
	return false;
}
com.wiris.util.xml.WCharacterBase.isGujarati = function(c) {
	if(c >= 2689 && c < 2788 || c == 2800 || c == 2801) return true;
	return false;
}
com.wiris.util.xml.WCharacterBase.isThai = function(c) {
	if(3585 <= c && c < 3676) return true;
	return false;
}
com.wiris.util.xml.WCharacterBase.isDevanagariString = function(s) {
	var i = s.length - 1;
	while(i >= 0) {
		if(!com.wiris.util.xml.WCharacterBase.isDevanagari(HxOverrides.cca(s,i))) return false;
		--i;
	}
	return true;
}
com.wiris.util.xml.WCharacterBase.isRTL = function(c) {
	if(com.wiris.util.xml.WCharacterBase.isHebrew(c) || com.wiris.util.xml.WCharacterBase.isArabian(c)) return true;
	return false;
}
com.wiris.util.xml.WCharacterBase.isTallLetter = function(c) {
	if(97 <= c && c <= 122 || 945 <= c && c <= 969) return com.wiris.util.xml.WCharacterBase.binarySearch(com.wiris.util.xml.WCharacterBase.tallLetters,c);
	return true;
}
com.wiris.util.xml.WCharacterBase.isLongLetter = function(c) {
	if(97 <= c && c <= 122 || 945 <= c && c <= 969) return com.wiris.util.xml.WCharacterBase.binarySearch(com.wiris.util.xml.WCharacterBase.longLetters,c); else if(65 <= c && c <= 90) return false;
	return true;
}
com.wiris.util.xml.WCharacterBase.isLTRNumber = function(text) {
	var i = 0;
	var n = com.wiris.system.Utf8.getLength(text);
	while(i < n) {
		if(!com.wiris.util.xml.WCharacterBase.isDigit(com.wiris.system.Utf8.charCodeAt(text,i))) return false;
		++i;
	}
	return true;
}
com.wiris.util.xml.WCharacterBase.isSuperscript = function(c) {
	return c == 178 || c == 179 || c == 185 || c >= 8304 && c <= 8319 && c != 8306 && c != 8307;
}
com.wiris.util.xml.WCharacterBase.isSubscript = function(c) {
	return c >= 8320 && c <= 8348 && c != 8335;
}
com.wiris.util.xml.WCharacterBase.isSuperscriptOrSubscript = function(c) {
	return com.wiris.util.xml.WCharacterBase.isSuperscript(c) || com.wiris.util.xml.WCharacterBase.isSubscript(c);
}
com.wiris.util.xml.WCharacterBase.normalizeSubSuperScript = function(c) {
	var i = 0;
	var n = com.wiris.util.xml.WCharacterBase.subSuperScriptDictionary.length;
	while(i < n) {
		if(com.wiris.util.xml.WCharacterBase.subSuperScriptDictionary[i] == c) return com.wiris.util.xml.WCharacterBase.subSuperScriptDictionary[i + 1];
		i += 2;
	}
	return c;
}
com.wiris.util.xml.WCharacterBase.isInvisible = function(c) {
	return com.wiris.util.xml.WCharacterBase.binarySearch(com.wiris.util.xml.WCharacterBase.invisible,c);
}
com.wiris.util.xml.WCharacterBase.isHorizontalOperator = function(c) {
	return com.wiris.util.xml.WCharacterBase.binarySearch(com.wiris.util.xml.WCharacterBase.horizontalOperators,c);
}
com.wiris.util.xml.WCharacterBase.latin2Greek = function(l) {
	var index = -1;
	if(l < 100) index = com.wiris.util.xml.WCharacterBase.latinLetters.indexOf("@00" + l + "@"); else if(l < 1000) index = com.wiris.util.xml.WCharacterBase.latinLetters.indexOf("@0" + l + "@"); else index = com.wiris.util.xml.WCharacterBase.latinLetters.indexOf("@" + l + "@");
	if(index != -1) {
		var s = HxOverrides.substr(com.wiris.util.xml.WCharacterBase.greekLetters,index + 1,4);
		return Std.parseInt(s);
	}
	return l;
}
com.wiris.util.xml.WCharacterBase.greek2Latin = function(g) {
	var index = -1;
	if(g < 100) index = com.wiris.util.xml.WCharacterBase.greekLetters.indexOf("@00" + g + "@"); else if(g < 1000) index = com.wiris.util.xml.WCharacterBase.greekLetters.indexOf("@0" + g + "@"); else index = com.wiris.util.xml.WCharacterBase.greekLetters.indexOf("@" + g + "@");
	if(index != -1) {
		var s = HxOverrides.substr(com.wiris.util.xml.WCharacterBase.latinLetters,index + 1,4);
		return Std.parseInt(s);
	}
	return g;
}
com.wiris.util.xml.WCharacterBase.isOp = function(c) {
	return com.wiris.util.xml.WCharacterBase.isLarge(c) || com.wiris.util.xml.WCharacterBase.isVeryLarge(c) || com.wiris.util.xml.WCharacterBase.isBinaryOp(c) || com.wiris.util.xml.WCharacterBase.isRelation(c) || c == HxOverrides.cca(".",0) || c == HxOverrides.cca(",",0) || c == HxOverrides.cca(":",0);
}
com.wiris.util.xml.WCharacterBase.isTallAccent = function(c) {
	var i = 0;
	while(i < com.wiris.util.xml.WCharacterBase.tallAccents.length) {
		if(c == com.wiris.util.xml.WCharacterBase.tallAccents[i]) return true;
		++i;
	}
	return false;
}
com.wiris.util.xml.WCharacterBase.isDisplayedWithStix = function(c) {
	if(c >= 592 && c <= 687) return true;
	if(c >= 688 && c <= 767) return true;
	if(c >= 8215 && c <= 8233 || c >= 8241 && c <= 8303) return true;
	if(c >= 8304 && c <= 8351) return true;
	if(c >= 8400 && c <= 8447) return true;
	if(c >= 8448 && c <= 8527) return true;
	if(c >= 8528 && c <= 8591) return true;
	if(c >= 8592 && c <= 8703) return true;
	if(c >= 8704 && c <= 8959) return true;
	if(c >= 8960 && c <= 9215) return true;
	if(c >= 9312 && c <= 9471) return true;
	if(c >= 9472 && c <= 9599) return true;
	if(c >= 9600 && c <= 9631) return true;
	if(c >= 9632 && c <= 9727) return true;
	if(c >= 9728 && c <= 9983) return true;
	if(c >= 9984 && c <= 10175) return true;
	if(c >= 10176 && c <= 10223) return true;
	if(c >= 10224 && c <= 10239) return true;
	if(c >= 10240 && c <= 10495) return true;
	if(c >= 10496 && c <= 10623) return true;
	if(c >= 10624 && c <= 10751) return true;
	if(c >= 10752 && c <= 11007) return true;
	if(c >= 11008 && c <= 11263) return true;
	if(c >= 12288 && c <= 12351) return true;
	if(c >= 57344 && c <= 65535) return true;
	if(c >= 119808 && c <= 119963 || c >= 120224 && c <= 120831) return true;
	if(c == 12398 || c == 42791 || c == 42898) return true;
	return false;
}
com.wiris.util.xml.WCharacterBase.latinToDoublestruck = function(codepoint) {
	if(codepoint == 67) return 8450; else if(codepoint == 72) return 8461; else if(codepoint == 78) return 8469; else if(codepoint == 80) return 8473; else if(codepoint == 81) return 8474; else if(codepoint == 82) return 8477; else if(codepoint == 90) return 8484; else if(codepoint >= com.wiris.util.xml.WCharacterBase.LATIN_CAPITAL_LETTER_A && codepoint <= com.wiris.util.xml.WCharacterBase.LATIN_CAPITAL_LETTER_Z) return codepoint + (com.wiris.util.xml.WCharacterBase.MATHEMATICAL_DOUBLE_STRUCK_CAPITAL_A - com.wiris.util.xml.WCharacterBase.LATIN_CAPITAL_LETTER_A); else if(codepoint >= com.wiris.util.xml.WCharacterBase.LATIN_SMALL_LETTER_A && codepoint <= com.wiris.util.xml.WCharacterBase.LATIN_SMALL_LETTER_Z) return codepoint + (com.wiris.util.xml.WCharacterBase.MATHEMATICAL_DOUBLE_STRUCK_SMALL_A - com.wiris.util.xml.WCharacterBase.LATIN_SMALL_LETTER_A); else if(codepoint >= com.wiris.util.xml.WCharacterBase.DIGIT_ZERO && codepoint <= com.wiris.util.xml.WCharacterBase.DIGIT_NINE) return codepoint + (com.wiris.util.xml.WCharacterBase.MATHEMATICAL_DOUBLE_STRUCK_DIGIT_ZERO - com.wiris.util.xml.WCharacterBase.DIGIT_ZERO); else return codepoint;
}
com.wiris.util.xml.WCharacterBase.latinToScript = function(codepoint) {
	if(codepoint == 66) return 8492; else if(codepoint == 69) return 8496; else if(codepoint == 70) return 8497; else if(codepoint == 72) return 8459; else if(codepoint == 73) return 8464; else if(codepoint == 76) return 8466; else if(codepoint == 77) return 8499; else if(codepoint == 82) return 8475; else if(codepoint == 101) return 8495; else if(codepoint == 103) return 8458; else if(codepoint == 111) return 8500; else if(codepoint >= com.wiris.util.xml.WCharacterBase.LATIN_CAPITAL_LETTER_A && codepoint <= com.wiris.util.xml.WCharacterBase.LATIN_CAPITAL_LETTER_Z) return codepoint + (com.wiris.util.xml.WCharacterBase.MATHEMATICAL_SCRIPT_CAPITAL_A - com.wiris.util.xml.WCharacterBase.LATIN_CAPITAL_LETTER_A); else if(codepoint >= com.wiris.util.xml.WCharacterBase.LATIN_SMALL_LETTER_A && codepoint <= com.wiris.util.xml.WCharacterBase.LATIN_SMALL_LETTER_Z) return codepoint + (com.wiris.util.xml.WCharacterBase.MATHEMATICAL_SCRIPT_SMALL_A - com.wiris.util.xml.WCharacterBase.LATIN_SMALL_LETTER_A); else return codepoint;
}
com.wiris.util.xml.WCharacterBase.latinToFraktur = function(codepoint) {
	if(codepoint == 67) return 8493; else if(codepoint == 72) return 8460; else if(codepoint == 73) return 8465; else if(codepoint == 82) return 8476; else if(codepoint == 90) return 8488; else if(codepoint >= com.wiris.util.xml.WCharacterBase.LATIN_CAPITAL_LETTER_A && codepoint <= com.wiris.util.xml.WCharacterBase.LATIN_CAPITAL_LETTER_Z) return codepoint + (com.wiris.util.xml.WCharacterBase.MATHEMATICAL_FRAKTUR_CAPITAL_A - com.wiris.util.xml.WCharacterBase.LATIN_CAPITAL_LETTER_A); else if(codepoint >= com.wiris.util.xml.WCharacterBase.LATIN_SMALL_LETTER_A && codepoint <= com.wiris.util.xml.WCharacterBase.LATIN_SMALL_LETTER_Z) return codepoint + (com.wiris.util.xml.WCharacterBase.MATHEMATICAL_FRAKTUR_SMALL_A - com.wiris.util.xml.WCharacterBase.LATIN_SMALL_LETTER_A); else return codepoint;
}
com.wiris.util.xml.WCharacterBase.stripAccent = function(c) {
	com.wiris.util.xml.WCharacterBase.initAccentsDictionary();
	if(c >= 128) {
		var i = com.wiris.util.xml.WCharacterBase.accentsDictionary.keys();
		while(i.hasNext()) {
			var s = i.next();
			var chars = com.wiris.util.xml.WCharacterBase.accentsDictionary.get(s);
			if(com.wiris.util.xml.WCharacterBase.binarySearch(chars,c)) return s;
		}
		return com.wiris.system.Utf8.uchr(c);
	} else return com.wiris.system.Utf8.uchr(c);
}
com.wiris.util.xml.WEntities = $hxClasses["com.wiris.util.xml.WEntities"] = function() { }
com.wiris.util.xml.WEntities.__name__ = ["com","wiris","util","xml","WEntities"];
com.wiris.util.xml.WXmlUtils = $hxClasses["com.wiris.util.xml.WXmlUtils"] = function() { }
com.wiris.util.xml.WXmlUtils.__name__ = ["com","wiris","util","xml","WXmlUtils"];
com.wiris.util.xml.WXmlUtils.getElementContent = function(element) {
	var sb = new StringBuf();
	if(element.nodeType == Xml.Document || element.nodeType == Xml.Element) {
		var i = element.iterator();
		while(i.hasNext()) sb.b += Std.string(i.next().toString());
	}
	return sb.b;
}
com.wiris.util.xml.WXmlUtils.hasSameAttributes = function(a,b) {
	if(a == null && b == null) return true; else if(a == null || b == null) return false;
	var iteratorA = a.attributes();
	var iteratorB = b.attributes();
	while(iteratorA.hasNext()) {
		if(!iteratorB.hasNext()) return false;
		iteratorB.next();
		var attr = iteratorA.next();
		if(!(com.wiris.util.xml.WXmlUtils.getAttribute(a,attr) == com.wiris.util.xml.WXmlUtils.getAttribute(b,attr))) return false;
	}
	return !iteratorB.hasNext();
}
com.wiris.util.xml.WXmlUtils.getElementsByAttributeValue = function(nodeList,attributeName,attributeValue) {
	var nodes = new Array();
	while(nodeList.hasNext()) {
		var node = nodeList.next();
		if(node.nodeType == Xml.Element && attributeValue == com.wiris.util.xml.WXmlUtils.getAttribute(node,attributeName)) nodes.push(node);
	}
	return nodes;
}
com.wiris.util.xml.WXmlUtils.getElementsByTagName = function(nodeList,tagName) {
	var nodes = new Array();
	while(nodeList.hasNext()) {
		var node = nodeList.next();
		if(node.nodeType == Xml.Element && node.getNodeName() == tagName) nodes.push(node);
	}
	return nodes;
}
com.wiris.util.xml.WXmlUtils.getElements = function(node) {
	var nodes = new Array();
	var nodeList = node.iterator();
	while(nodeList.hasNext()) {
		var item = nodeList.next();
		if(item.nodeType == Xml.Element) nodes.push(item);
	}
	return nodes;
}
com.wiris.util.xml.WXmlUtils.getDocumentElement = function(doc) {
	var nodeList = doc.iterator();
	while(nodeList.hasNext()) {
		var node = nodeList.next();
		if(node.nodeType == Xml.Element) return node;
	}
	return null;
}
com.wiris.util.xml.WXmlUtils.getAttribute = function(node,attributeName) {
	var value = node.get(attributeName);
	if(value == null) return null;
	if(com.wiris.settings.PlatformSettings.PARSE_XML_ENTITIES) return com.wiris.util.xml.WXmlUtils.htmlUnescape(value);
	return value;
}
com.wiris.util.xml.WXmlUtils.setAttribute = function(node,name,value) {
	if(value != null && com.wiris.settings.PlatformSettings.PARSE_XML_ENTITIES) value = com.wiris.util.xml.WXmlUtils.htmlEscape(value);
	node.set(name,value);
}
com.wiris.util.xml.WXmlUtils.getNodeValue = function(node) {
	var value = node.getNodeValue();
	if(value == null) return null;
	if(com.wiris.settings.PlatformSettings.PARSE_XML_ENTITIES && node.nodeType == Xml.PCData) return com.wiris.util.xml.WXmlUtils.htmlUnescape(value);
	return value;
}
com.wiris.util.xml.WXmlUtils.createPCData = function(node,text) {
	if(com.wiris.settings.PlatformSettings.PARSE_XML_ENTITIES) text = com.wiris.util.xml.WXmlUtils.htmlEscape(text);
	return Xml.createPCData(text);
}
com.wiris.util.xml.WXmlUtils.escapeXmlEntities = function(s) {
	s = StringTools.replace(s,"&","&amp;");
	s = StringTools.replace(s,"<","&lt;");
	s = StringTools.replace(s,">","&gt;");
	s = StringTools.replace(s,"\"","&quot;");
	s = StringTools.replace(s,"'","&apos;");
	return s;
}
com.wiris.util.xml.WXmlUtils.htmlEscape = function(input) {
	var output = StringTools.replace(input,"&","&amp;");
	output = StringTools.replace(output,"<","&lt;");
	output = StringTools.replace(output,">","&gt;");
	output = StringTools.replace(output,"\"","&quot;");
	output = StringTools.replace(output,"&apos;","'");
	return output;
}
com.wiris.util.xml.WXmlUtils.htmlUnescape = function(input) {
	var output = "";
	var start = 0;
	var position = input.indexOf("&",start);
	while(position != -1) {
		output += HxOverrides.substr(input,start,position - start);
		if(input.charAt(position + 1) == "#") {
			var startPosition = position + 2;
			var endPosition = input.indexOf(";",startPosition);
			if(endPosition != -1) {
				var number = HxOverrides.substr(input,startPosition,endPosition - startPosition);
				if(StringTools.startsWith(number,"x")) number = "0" + number;
				var charCode = Std.parseInt(number);
				output += com.wiris.system.Utf8.uchr(charCode);
				start = endPosition + 1;
			} else {
				output += "&";
				start = position + 1;
			}
		} else {
			output += "&";
			start = position + 1;
		}
		position = input.indexOf("&",start);
	}
	output += HxOverrides.substr(input,start,input.length - start);
	output = StringTools.replace(output,"&lt;","<");
	output = StringTools.replace(output,"&gt;",">");
	output = StringTools.replace(output,"&quot;","\"");
	output = StringTools.replace(output,"&apos;","'");
	output = StringTools.replace(output,"&amp;","&");
	return output;
}
com.wiris.util.xml.WXmlUtils.parseXML = function(xml) {
	xml = com.wiris.util.xml.WXmlUtils.filterMathMLEntities(xml);
	var x = Xml.parse(xml);
	return x;
}
com.wiris.util.xml.WXmlUtils.safeParseXML = function(xml) {
	try {
		return com.wiris.util.xml.WXmlUtils.parseXML(xml);
	} catch( e ) {
		return Xml.createDocument();
	}
}
com.wiris.util.xml.WXmlUtils.serializeXML = function(xml) {
	var s = xml.toString();
	s = com.wiris.util.xml.WXmlUtils.filterMathMLEntities(s);
	return s;
}
com.wiris.util.xml.WXmlUtils.resolveEntities = function(text) {
	com.wiris.util.xml.WXmlUtils.initEntities();
	var sb = new StringBuf();
	var i = 0;
	var n = text.length;
	while(i < n) {
		var c = com.wiris.util.xml.WXmlUtils.getUtf8Char(text,i);
		if(c == 60 && i + 12 < n && HxOverrides.cca(text,i + 1) == 33) {
			if(HxOverrides.substr(text,i,9) == "<![CDATA[") {
				var e = text.indexOf("]]>",i);
				if(e != -1) {
					sb.b += Std.string(HxOverrides.substr(text,i,e - i + 3));
					i = e + 3;
					continue;
				}
			}
		}
		if(c > 127) {
			var special = com.wiris.system.Utf8.uchr(c);
			sb.b += Std.string(special);
			i += special.length - 1;
		} else if(c == 38) {
			i++;
			c = HxOverrides.cca(text,i);
			if(com.wiris.util.xml.WXmlUtils.isNameStart(c)) {
				var name = new StringBuf();
				name.b += String.fromCharCode(c);
				i++;
				c = HxOverrides.cca(text,i);
				while(com.wiris.util.xml.WXmlUtils.isNameChar(c)) {
					name.b += String.fromCharCode(c);
					i++;
					c = HxOverrides.cca(text,i);
				}
				var ent = name.b;
				if(c == 59 && com.wiris.util.xml.WXmlUtils.entities.exists(ent) && !com.wiris.util.xml.WXmlUtils.isXmlEntity(ent)) {
					var val = com.wiris.util.xml.WXmlUtils.entities.get(ent);
					sb.b += Std.string(com.wiris.system.Utf8.uchr(Std.parseInt(val)));
				} else {
					sb.b += Std.string("&");
					sb.b += Std.string(name);
					sb.b += String.fromCharCode(c);
				}
			} else if(c == 35) {
				i++;
				c = HxOverrides.cca(text,i);
				if(c == 120) {
					var hex = new StringBuf();
					i++;
					c = HxOverrides.cca(text,i);
					while(com.wiris.util.xml.WXmlUtils.isHexDigit(c)) {
						hex.b += String.fromCharCode(c);
						i++;
						c = HxOverrides.cca(text,i);
					}
					var hent = hex.b;
					if(c == 59 && !com.wiris.util.xml.WXmlUtils.isXmlEntity("#x" + hent)) {
						var dec = Std.parseInt("0x" + hent);
						sb.b += Std.string(com.wiris.system.Utf8.uchr(dec));
					} else {
						sb.b += Std.string("&#x");
						sb.b += Std.string(hent);
						sb.b += String.fromCharCode(c);
					}
				} else if(48 <= c && c <= 57) {
					var dec = new StringBuf();
					while(48 <= c && c <= 57) {
						dec.b += String.fromCharCode(c);
						i++;
						c = HxOverrides.cca(text,i);
					}
					if(c == 59 && !com.wiris.util.xml.WXmlUtils.isXmlEntity("#" + Std.string(dec))) sb.b += Std.string(com.wiris.system.Utf8.uchr(Std.parseInt(dec.b))); else {
						sb.b += Std.string("&#" + dec.b);
						sb.b += String.fromCharCode(c);
					}
				}
			}
		} else sb.b += String.fromCharCode(c);
		i++;
	}
	return sb.b;
}
com.wiris.util.xml.WXmlUtils.filterMathMLEntities = function(text) {
	text = com.wiris.util.xml.WXmlUtils.resolveEntities(text);
	text = com.wiris.util.xml.WXmlUtils.nonAsciiToEntities(text);
	return text;
}
com.wiris.util.xml.WXmlUtils.getUtf8Char = function(text,i) {
	var c = HxOverrides.cca(text,i);
	var d = c;
	if(com.wiris.settings.PlatformSettings.UTF8_CONVERSION) {
		if(d > 127) {
			var j = 0;
			c = 128;
			do {
				c = c >> 1;
				j++;
			} while((d & c) != 0);
			d = c - 1 & d;
			while(--j > 0) {
				i++;
				c = HxOverrides.cca(text,i);
				d = (d << 6) + (c & 63);
			}
		}
	} else if(d >= 55296 && d <= 56319) {
		c = HxOverrides.cca(text,i + 1);
		d = (d - 55296 << 10) + (c - 56320) + 65536;
	}
	return d;
}
com.wiris.util.xml.WXmlUtils.nonAsciiToEntities = function(s) {
	var sb = new StringBuf();
	var i = 0;
	var n = s.length;
	while(i < n) {
		var c = com.wiris.util.xml.WXmlUtils.getUtf8Char(s,i);
		if(c > 127) {
			var hex = com.wiris.common.WInteger.toHex(c,5);
			var j = 0;
			while(j < hex.length) {
				if(!(HxOverrides.substr(hex,j,1) == "0")) {
					hex = HxOverrides.substr(hex,j,null);
					break;
				}
				++j;
			}
			sb.b += Std.string("&#x" + hex + ";");
			i += com.wiris.system.Utf8.uchr(c).length;
		} else {
			sb.b += String.fromCharCode(c);
			i++;
		}
	}
	return sb.b;
}
com.wiris.util.xml.WXmlUtils.isNameStart = function(c) {
	if(65 <= c && c <= 90) return true;
	if(97 <= c && c <= 122) return true;
	if(c == 95 || c == 58) return true;
	return false;
}
com.wiris.util.xml.WXmlUtils.isNameChar = function(c) {
	if(com.wiris.util.xml.WXmlUtils.isNameStart(c)) return true;
	if(48 <= c && c <= 57) return true;
	if(c == 46 || c == 45) return true;
	return false;
}
com.wiris.util.xml.WXmlUtils.isHexDigit = function(c) {
	if(c >= 48 && c <= 57) return true;
	if(c >= 65 && c <= 70) return true;
	if(c >= 97 && c <= 102) return true;
	return false;
}
com.wiris.util.xml.WXmlUtils.resolveMathMLEntity = function(name) {
	com.wiris.util.xml.WXmlUtils.initEntities();
	if(com.wiris.util.xml.WXmlUtils.entities.exists(name)) {
		var code = com.wiris.util.xml.WXmlUtils.entities.get(name);
		return Std.parseInt(code);
	}
	return -1;
}
com.wiris.util.xml.WXmlUtils.initEntities = function() {
	if(com.wiris.util.xml.WXmlUtils.entities == null) {
		var e = com.wiris.util.xml.WEntities.MATHML_ENTITIES;
		com.wiris.util.xml.WXmlUtils.entities = new Hash();
		var start = 0;
		var mid;
		while((mid = e.indexOf("@",start)) != -1) {
			var name = HxOverrides.substr(e,start,mid - start);
			mid++;
			start = e.indexOf("@",mid);
			if(start == -1) break;
			var value = HxOverrides.substr(e,mid,start - mid);
			var num = Std.parseInt("0x" + value);
			com.wiris.util.xml.WXmlUtils.entities.set(name,"" + num);
			start++;
		}
	}
}
com.wiris.util.xml.WXmlUtils.getText = function(xml) {
	if(xml.nodeType == Xml.PCData) return xml.getNodeValue();
	var r = "";
	var iter = xml.iterator();
	while(iter.hasNext()) r += com.wiris.util.xml.WXmlUtils.getText(iter.next());
	return r;
}
com.wiris.util.xml.WXmlUtils.getInnerText = function(xml) {
	if(xml.nodeType == Xml.PCData || xml.nodeType == Xml.CData) return com.wiris.util.xml.WXmlUtils.getNodeValue(xml);
	var r = "";
	var iter = xml.iterator();
	while(iter.hasNext()) r += com.wiris.util.xml.WXmlUtils.getInnerText(iter.next());
	return r;
}
com.wiris.util.xml.WXmlUtils.setText = function(xml,text) {
	if(xml.nodeType != Xml.Element) return;
	var it = xml.iterator();
	if(it.hasNext()) {
		var child = it.next();
		if(child.nodeType == Xml.PCData) xml.removeChild(child);
	}
	xml.addChild(Xml.createPCData(text));
}
com.wiris.util.xml.WXmlUtils.copyXml = function(elem) {
	return com.wiris.util.xml.WXmlUtils.importXml(elem,elem);
}
com.wiris.util.xml.WXmlUtils.copyChildren = function(from,to) {
	var children = from.iterator();
	while(children.hasNext()) to.addChild(com.wiris.util.xml.WXmlUtils.importXml(children.next(),to));
}
com.wiris.util.xml.WXmlUtils.importXml = function(elem,model) {
	var n = null;
	if(elem.nodeType == Xml.Element) {
		n = Xml.createElement(elem.getNodeName());
		var keys = elem.attributes();
		while(keys.hasNext()) {
			var key = keys.next();
			n.set(key,elem.get(key));
		}
		var children = elem.iterator();
		while(children.hasNext()) n.addChild(com.wiris.util.xml.WXmlUtils.importXml(children.next(),model));
	} else if(elem.nodeType == Xml.Document) n = com.wiris.util.xml.WXmlUtils.importXml(elem.firstElement(),model); else if(elem.nodeType == Xml.CData) n = Xml.createCData(elem.getNodeValue()); else if(elem.nodeType == Xml.PCData) n = Xml.createPCData(elem.getNodeValue()); else throw "Unsupported node type: " + Std.string(elem.nodeType);
	return n;
}
com.wiris.util.xml.WXmlUtils.importXmlWithoutChildren = function(elem,model) {
	var n = null;
	if(elem.nodeType == Xml.Element) {
		n = Xml.createElement(elem.getNodeName());
		var keys = elem.attributes();
		while(keys.hasNext()) {
			var key = keys.next();
			n.set(key,elem.get(key));
		}
	} else if(elem.nodeType == Xml.CData) n = Xml.createCData(elem.getNodeValue()); else if(elem.nodeType == Xml.PCData) n = Xml.createPCData(elem.getNodeValue()); else throw "Unsupported node type: " + Std.string(elem.nodeType);
	return n;
}
com.wiris.util.xml.WXmlUtils.copyXmlNamespace = function(elem,customNamespace,prefixAttributes) {
	return com.wiris.util.xml.WXmlUtils.importXmlNamespace(elem,elem,customNamespace,prefixAttributes);
}
com.wiris.util.xml.WXmlUtils.importXmlNamespace = function(elem,model,customNamespace,prefixAttributes) {
	var n = null;
	if(elem.nodeType == Xml.Element) {
		n = Xml.createElement(customNamespace + ":" + elem.getNodeName());
		var keys = elem.attributes();
		while(keys.hasNext()) {
			var key = keys.next();
			var keyNamespaced = key;
			if(prefixAttributes && key.indexOf(":") == -1 && key.indexOf("xmlns") == -1) keyNamespaced = customNamespace + ":" + key;
			n.set(keyNamespaced,elem.get(key));
		}
		var children = elem.iterator();
		while(children.hasNext()) n.addChild(com.wiris.util.xml.WXmlUtils.importXmlNamespace(children.next(),model,customNamespace,prefixAttributes));
	} else if(elem.nodeType == Xml.Document) n = com.wiris.util.xml.WXmlUtils.importXmlNamespace(elem.firstElement(),model,customNamespace,prefixAttributes); else if(elem.nodeType == Xml.CData) n = Xml.createCData(elem.getNodeValue()); else if(elem.nodeType == Xml.PCData) n = Xml.createPCData(elem.getNodeValue()); else throw "Unsupported node type: " + Std.string(elem.nodeType);
	return n;
}
com.wiris.util.xml.WXmlUtils.indentXml = function(xml,space) {
	var depth = 0;
	var opentag = new EReg("^<([\\w-_]+)[^>]*>$","");
	var autotag = new EReg("^<([\\w-_]+)[^>]*/>$","");
	var closetag = new EReg("^</([\\w-_]+)>$","");
	var cdata = new EReg("^<!\\[CDATA\\[[^\\]]*\\]\\]>$","");
	var res = new StringBuf();
	var end = 0;
	var start;
	var text;
	while(end < xml.length && (start = xml.indexOf("<",end)) != -1) {
		text = start > end;
		if(text) res.b += Std.string(HxOverrides.substr(xml,end,start - end));
		end = xml.indexOf(">",start) + 1;
		var aux = HxOverrides.substr(xml,start,end - start);
		if(autotag.match(aux)) {
			res.b += Std.string("\n");
			var i;
			var _g = 0;
			while(_g < depth) {
				var i1 = _g++;
				res.b += Std.string(space);
			}
			res.b += Std.string(aux);
		} else if(opentag.match(aux)) {
			res.b += Std.string("\n");
			var i;
			var _g = 0;
			while(_g < depth) {
				var i1 = _g++;
				res.b += Std.string(space);
			}
			res.b += Std.string(aux);
			depth++;
		} else if(closetag.match(aux)) {
			depth--;
			if(!text) {
				res.b += Std.string("\n");
				var i;
				var _g = 0;
				while(_g < depth) {
					var i1 = _g++;
					res.b += Std.string(space);
				}
			}
			res.b += Std.string(aux);
		} else if(cdata.match(aux)) res.b += Std.string(aux); else {
			console.log("WARNING! malformed XML at character " + end + ":" + xml);
			res.b += Std.string(aux);
		}
	}
	return StringTools.trim(res.b);
}
com.wiris.util.xml.WXmlUtils.isXmlEntity = function(ent) {
	if(HxOverrides.cca(ent,0) == 35) {
		var c;
		if(HxOverrides.cca(ent,1) == 120) c = Std.parseInt("0x" + HxOverrides.substr(ent,2,null)); else c = Std.parseInt(HxOverrides.substr(ent,1,null));
		return c == 34 || c == 38 || c == 39 || c == 60 || c == 62;
	} else return ent == "amp" || ent == "lt" || ent == "gt" || ent == "quot" || ent == "apos";
}
com.wiris.util.xml.WXmlUtils.normalizeWhitespace = function(s) {
	return s != null?com.wiris.util.xml.WXmlUtils.WHITESPACE_COLLAPSE_REGEX.replace(StringTools.trim(s)," "):null;
}
if(!com.wiris.webwork) com.wiris.webwork = {}
com.wiris.webwork.MathML2Webwork = $hxClasses["com.wiris.webwork.MathML2Webwork"] = function() {
	this.thisLock = { };
};
com.wiris.webwork.MathML2Webwork.__name__ = ["com","wiris","webwork","MathML2Webwork"];
com.wiris.webwork.MathML2Webwork.main = function() {
	var args = [];
	var m2w = new com.wiris.webwork.MathML2Webwork();
	var s1 = "<math/>";
	try {
		var s2 = m2w.mathML2Webwork(s1);
		console.log(s2);
		var s3 = m2w.webwork2MathML(s2);
		console.log(s3);
	} catch( e ) {
		if( js.Boot.__instanceof(e,com.wiris.system.Exception) ) {
			throw e;
		} else throw(e);
	}
}
com.wiris.webwork.MathML2Webwork.prototype = {
	stripAnnotations: function(mathml) {
		var formula = com.wiris.util.xml.WXmlUtils.parseXML(mathml);
		var semantics = formula.firstChild();
		while(semantics != null && !(semantics.getNodeName() == "semantics")) semantics = semantics.firstChild();
		if(semantics != null) {
			var content = semantics.firstChild();
			if(content.getNodeName() == "annotation" || content.getNodeName() == "annotation-xml") content = null;
			var parent = semantics.getParent();
			if(content != null) parent.insertChild(content,0);
			parent.removeChild(semantics);
		}
		return formula.toString();
	}
	,mathMLTokensToString: function(v) {
		var sb = new StringBuf();
		var i = HxOverrides.iter(v);
		var attribute = false;
		var tag = false;
		var token = null;
		var lastToken;
		while(i.hasNext()) {
			var nextToken = i.next();
			if(nextToken != null) {
				lastToken = token;
				token = nextToken.toString();
				if(attribute && !(token == "\"") || !tag && !StringTools.startsWith(token,"<")) token = com.wiris.util.xml.WXmlUtils.htmlEscape(token);
				if(StringTools.startsWith(token,"<")) tag = true;
				if(StringTools.endsWith(token,">")) tag = false;
				if(tag && token == "\"") attribute = !attribute;
				if(lastToken != null) {
					var m = lastToken.length;
					if(attribute && com.wiris.util.xml.WCharacterBase.isLetter(com.wiris.system.Utf8.charCodeAt(lastToken,m - 1)) && com.wiris.util.xml.WCharacterBase.isLetter(com.wiris.system.Utf8.charCodeAt(token,0))) sb.b += Std.string(" ");
				}
				sb.b += Std.string(token);
				if(tag && StringTools.startsWith(token,"<") || token == "\"" && !attribute) sb.b += Std.string(" ");
			}
		}
		return sb.b;
	}
	,isTokenFormedByLetters: function(o) {
		if(js.Boot.__instanceof(o,String)) {
			var token = js.Boot.__cast(o , String);
			if(token.length == 0) return false;
			var it = com.wiris.system.Utf8.getIterator(token);
			while(it.hasNext()) {
				var c = it.next();
				if(!com.wiris.util.xml.WCharacterBase.isLetter(c)) return false;
			}
			return true;
		} else return false;
	}
	,textTokensToString: function(a) {
		var sb = new StringBuf();
		var i;
		var lastToken = null;
		var _g1 = 0, _g = a.length;
		while(_g1 < _g) {
			var i1 = _g1++;
			var tokenObject = a[i1];
			if(tokenObject == null) continue;
			if(lastToken != null && this.isTokenFormedByLetters(lastToken) && this.isTokenFormedByLetters(tokenObject) || tokenObject == "U" || lastToken != null && lastToken == "U") sb.b += Std.string(" ");
			sb.b += Std.string(tokenObject);
			lastToken = tokenObject;
		}
		return sb.b;
	}
	,getGrammarStorage: function() {
		if(this.grammarStorage == null) this.grammarStorage = com.wiris.system.Storage.newResourceStorage(com.wiris.webwork.MathML2Webwork.MATHML_TO_WEBWORK_GRAMMAR_FILE);
		return this.grammarStorage;
	}
	,loadW2M: function() {
		if(this.w2m == null) {
			this.loadM2W();
			var gib = new com.wiris.chartparsing.GrammarInverseBuilder();
			this.w2m = gib.invert(this.m2w);
			this.w2m.fixDuplicates();
		}
	}
	,loadM2W: function() {
		if(this.m2w == null) {
			var gb = new com.wiris.chartparsing.GrammarSequentialBuilder();
			try {
				gb.loadStorage(this.getGrammarStorage());
			} catch( e ) {
				if( js.Boot.__instanceof(e,com.wiris.system.Exception) ) {
					throw e;
				} else throw(e);
			}
			com.wiris.chartparsing.XMLConverter.convert(gb);
			com.wiris.chartparsing.TreeConverter.convert(gb,false,true);
			gb.fixDuplicates();
			this.m2w = gb;
		}
	}
	,isMathMLEmpty: function(m) {
		return m == null || StringTools.trim(m) == "" || com.wiris.webwork.MathML2Webwork.emptyMmlRe.match(m);
	}
	,webwork2MathML: function(webwork) {
		var mml;
		if(webwork == null || StringTools.trim(webwork) == "") mml = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"/>"; else {
			this.loadW2M();
			var t;
			t = com.wiris.webwork.WebworkTokens.newWebworkTokens(webwork);
			var cc = new com.wiris.chartparsing.CategoryChooser();
			var g = new com.wiris.chartparsing.GrammarReducedBuilder().reduce(this.w2m,t,cc);
			var tdp = com.wiris.chartparsing.TopDownParser.newTopDownParser(g,"math");
			tdp.setAmbiguitiesHandler(new com.wiris.chartparsing.PriorityAmbiguitiesHandler());
			try {
				tdp.setCategoryChooser(cc);
				tdp.parse(t);
			} catch( e ) {
				if( js.Boot.__instanceof(e,com.wiris.system.Exception) ) {
					throw e;
				} else throw(e);
			}
			var pr = tdp.getResultTree();
			if(!pr.parserFinished()) {
				var ce = pr.getException();
				if(js.Boot.__instanceof(ce,com.wiris.chartparsing.ChartParsingMemoryException)) mml = "Error: Exhausted memory limit when converting from WebWork to MathML."; else mml = ce.getShortMessage();
				throw new com.wiris.system.Exception(mml,ce);
			} else {
				var tr = pr.getTransformer();
				tr.transform();
				var tokens = tr.getVector();
				mml = this.mathMLTokensToString(tokens);
			}
		}
		return mml;
	}
	,mathML2Webwork: function(mathml) {
		var webwork;
		if(mathml.indexOf("semantics") > -1) mathml = this.stripAnnotations(mathml);
		if(this.isMathMLEmpty(mathml)) webwork = ""; else {
			this.loadM2W();
			var t;
			try {
				t = com.wiris.tokens.SAXTokenizer.newSAXTokenizer(StringTools.trim(mathml),"MathML input");
			} catch( e ) {
				throw new com.wiris.system.Exception(e);
			}
			var cc = new com.wiris.chartparsing.CategoryChooser();
			var g = new com.wiris.chartparsing.GrammarReducedBuilder().reduce(this.m2w,t,cc);
			var tdp = com.wiris.chartparsing.TopDownParser.newTopDownParser(g,"math");
			tdp.setAmbiguitiesHandler(new com.wiris.chartparsing.PriorityAmbiguitiesHandler());
			try {
				tdp.setCategoryChooser(cc);
				tdp.parse(t);
			} catch( e ) {
				if( js.Boot.__instanceof(e,com.wiris.system.Exception) ) {
					throw e;
				} else throw(e);
			}
			var pr = tdp.getResultTree();
			if(!pr.parserFinished()) {
				var ce = pr.getException();
				if(js.Boot.__instanceof(ce,com.wiris.chartparsing.ChartParsingMemoryException)) webwork = "Error: Exhausted memory limit when converting from MathML to WebWork."; else webwork = ce.getShortMessage();
				throw new com.wiris.system.Exception(webwork,ce);
			} else {
				var tr = pr.getTransformer();
				tr.transform();
				var tokens = tr.getVector();
				webwork = this.textTokensToString(tokens);
			}
		}
		return webwork;
	}
	,grammarStorage: null
	,thisLock: null
	,w2m: null
	,m2w: null
	,__class__: com.wiris.webwork.MathML2Webwork
}
com.wiris.webwork.WebworkTokens = $hxClasses["com.wiris.webwork.WebworkTokens"] = function() {
	com.wiris.tokens.PlainTokens.call(this);
};
com.wiris.webwork.WebworkTokens.__name__ = ["com","wiris","webwork","WebworkTokens"];
com.wiris.webwork.WebworkTokens.newWebworkTokens = function(str) {
	var wwt = new com.wiris.webwork.WebworkTokens();
	wwt.parse(str);
	return wwt;
}
com.wiris.webwork.WebworkTokens.__super__ = com.wiris.tokens.PlainTokens;
com.wiris.webwork.WebworkTokens.prototype = $extend(com.wiris.tokens.PlainTokens.prototype,{
	getNumber: function() {
		var sb = new StringBuf();
		var i0 = this.i;
		while(this.isValid(this.c) && com.wiris.util.xml.WCharacterBase.isDigit(this.c)) {
			sb.b += String.fromCharCode(this.c);
			this.nextChar();
		}
		var str = sb.b;
		if(str.length > 0) {
			this.push(i0,str);
			return true;
		}
		return false;
	}
	,getSymbol: function() {
		if(this.isValid(this.c) && !com.wiris.system.TypeTools.isIdentifierPart(this.c) && !this.isBlank(this.c)) {
			this.push(this.i,com.wiris.system.Utf8.uchr(this.c));
			this.nextChar();
			return true;
		}
		return false;
	}
	,__class__: com.wiris.webwork.WebworkTokens
});
var haxe = haxe || {}
haxe.Int32 = $hxClasses["haxe.Int32"] = function() { }
haxe.Int32.__name__ = ["haxe","Int32"];
haxe.Int32.make = function(a,b) {
	return a << 16 | b;
}
haxe.Int32.ofInt = function(x) {
	return x | 0;
}
haxe.Int32.clamp = function(x) {
	return x | 0;
}
haxe.Int32.toInt = function(x) {
	if((x >> 30 & 1) != x >>> 31) throw "Overflow " + Std.string(x);
	return x;
}
haxe.Int32.toNativeInt = function(x) {
	return x;
}
haxe.Int32.add = function(a,b) {
	return a + b | 0;
}
haxe.Int32.sub = function(a,b) {
	return a - b | 0;
}
haxe.Int32.mul = function(a,b) {
	return a * (b & 65535) + (a * (b >>> 16) << 16 | 0) | 0;
}
haxe.Int32.div = function(a,b) {
	return a / b | 0;
}
haxe.Int32.mod = function(a,b) {
	return a % b;
}
haxe.Int32.shl = function(a,b) {
	return a << b;
}
haxe.Int32.shr = function(a,b) {
	return a >> b;
}
haxe.Int32.ushr = function(a,b) {
	return a >>> b;
}
haxe.Int32.and = function(a,b) {
	return a & b;
}
haxe.Int32.or = function(a,b) {
	return a | b;
}
haxe.Int32.xor = function(a,b) {
	return a ^ b;
}
haxe.Int32.neg = function(a) {
	return -a;
}
haxe.Int32.isNeg = function(a) {
	return a < 0;
}
haxe.Int32.isZero = function(a) {
	return a == 0;
}
haxe.Int32.complement = function(a) {
	return ~a;
}
haxe.Int32.compare = function(a,b) {
	return a - b;
}
haxe.Int32.ucompare = function(a,b) {
	if(a < 0) return b < 0?~b - ~a:1;
	return b < 0?-1:a - b;
}
haxe.Json = $hxClasses["haxe.Json"] = function() {
};
haxe.Json.__name__ = ["haxe","Json"];
haxe.Json.parse = function(text) {
	return new haxe.Json().doParse(text);
}
haxe.Json.stringify = function(value) {
	return new haxe.Json().toString(value);
}
haxe.Json.prototype = {
	parseString: function() {
		var start = this.pos;
		var buf = new StringBuf();
		while(true) {
			var c = this.str.charCodeAt(this.pos++);
			if(c == 34) break;
			if(c == 92) {
				buf.b += HxOverrides.substr(this.str,start,this.pos - start - 1);
				c = this.str.charCodeAt(this.pos++);
				switch(c) {
				case 114:
					buf.b += String.fromCharCode(13);
					break;
				case 110:
					buf.b += String.fromCharCode(10);
					break;
				case 116:
					buf.b += String.fromCharCode(9);
					break;
				case 98:
					buf.b += String.fromCharCode(8);
					break;
				case 102:
					buf.b += String.fromCharCode(12);
					break;
				case 47:case 92:case 34:
					buf.b += String.fromCharCode(c);
					break;
				case 117:
					var uc = Std.parseInt("0x" + HxOverrides.substr(this.str,this.pos,4));
					this.pos += 4;
					buf.b += String.fromCharCode(uc);
					break;
				default:
					throw "Invalid escape sequence \\" + String.fromCharCode(c) + " at position " + (this.pos - 1);
				}
				start = this.pos;
			} else if(c != c) throw "Unclosed string";
		}
		buf.b += HxOverrides.substr(this.str,start,this.pos - start - 1);
		return buf.b;
	}
	,parseRec: function() {
		while(true) {
			var c = this.str.charCodeAt(this.pos++);
			switch(c) {
			case 32:case 13:case 10:case 9:
				break;
			case 123:
				var obj = { }, field = null, comma = null;
				while(true) {
					var c1 = this.str.charCodeAt(this.pos++);
					switch(c1) {
					case 32:case 13:case 10:case 9:
						break;
					case 125:
						if(field != null || comma == false) this.invalidChar();
						return obj;
					case 58:
						if(field == null) this.invalidChar();
						obj[field] = this.parseRec();
						field = null;
						comma = true;
						break;
					case 44:
						if(comma) comma = false; else this.invalidChar();
						break;
					case 34:
						if(comma) this.invalidChar();
						field = this.parseString();
						break;
					default:
						this.invalidChar();
					}
				}
				break;
			case 91:
				var arr = [], comma = null;
				while(true) {
					var c1 = this.str.charCodeAt(this.pos++);
					switch(c1) {
					case 32:case 13:case 10:case 9:
						break;
					case 93:
						if(comma == false) this.invalidChar();
						return arr;
					case 44:
						if(comma) comma = false; else this.invalidChar();
						break;
					default:
						if(comma) this.invalidChar();
						this.pos--;
						arr.push(this.parseRec());
						comma = true;
					}
				}
				break;
			case 116:
				var save = this.pos;
				if(this.str.charCodeAt(this.pos++) != 114 || this.str.charCodeAt(this.pos++) != 117 || this.str.charCodeAt(this.pos++) != 101) {
					this.pos = save;
					this.invalidChar();
				}
				return true;
			case 102:
				var save = this.pos;
				if(this.str.charCodeAt(this.pos++) != 97 || this.str.charCodeAt(this.pos++) != 108 || this.str.charCodeAt(this.pos++) != 115 || this.str.charCodeAt(this.pos++) != 101) {
					this.pos = save;
					this.invalidChar();
				}
				return false;
			case 110:
				var save = this.pos;
				if(this.str.charCodeAt(this.pos++) != 117 || this.str.charCodeAt(this.pos++) != 108 || this.str.charCodeAt(this.pos++) != 108) {
					this.pos = save;
					this.invalidChar();
				}
				return null;
			case 34:
				return this.parseString();
			case 48:case 49:case 50:case 51:case 52:case 53:case 54:case 55:case 56:case 57:case 45:
				this.pos--;
				if(!this.reg_float.match(HxOverrides.substr(this.str,this.pos,null))) throw "Invalid float at position " + this.pos;
				var v = this.reg_float.matched(0);
				this.pos += v.length;
				var f = Std.parseFloat(v);
				var i = f | 0;
				return i == f?i:f;
			default:
				this.invalidChar();
			}
		}
	}
	,nextChar: function() {
		return this.str.charCodeAt(this.pos++);
	}
	,invalidChar: function() {
		this.pos--;
		throw "Invalid char " + this.str.charCodeAt(this.pos) + " at position " + this.pos;
	}
	,doParse: function(str) {
		this.reg_float = new EReg("^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?","");
		this.str = str;
		this.pos = 0;
		return this.parseRec();
	}
	,quote: function(s) {
		this.buf.b += Std.string("\"");
		var i = 0;
		while(true) {
			var c = s.charCodeAt(i++);
			if(c != c) break;
			switch(c) {
			case 34:
				this.buf.b += Std.string("\\\"");
				break;
			case 92:
				this.buf.b += Std.string("\\\\");
				break;
			case 10:
				this.buf.b += Std.string("\\n");
				break;
			case 13:
				this.buf.b += Std.string("\\r");
				break;
			case 9:
				this.buf.b += Std.string("\\t");
				break;
			case 8:
				this.buf.b += Std.string("\\b");
				break;
			case 12:
				this.buf.b += Std.string("\\f");
				break;
			default:
				this.buf.b += String.fromCharCode(c);
			}
		}
		this.buf.b += Std.string("\"");
	}
	,toStringRec: function(v) {
		var $e = (Type["typeof"](v));
		switch( $e[1] ) {
		case 8:
			this.buf.b += Std.string("\"???\"");
			break;
		case 4:
			this.objString(v);
			break;
		case 1:
		case 2:
			this.buf.b += Std.string(v);
			break;
		case 5:
			this.buf.b += Std.string("\"<fun>\"");
			break;
		case 6:
			var c = $e[2];
			if(c == String) this.quote(v); else if(c == Array) {
				var v1 = v;
				this.buf.b += Std.string("[");
				var len = v1.length;
				if(len > 0) {
					this.toStringRec(v1[0]);
					var i = 1;
					while(i < len) {
						this.buf.b += Std.string(",");
						this.toStringRec(v1[i++]);
					}
				}
				this.buf.b += Std.string("]");
			} else if(c == Hash) {
				var v1 = v;
				var o = { };
				var $it0 = v1.keys();
				while( $it0.hasNext() ) {
					var k = $it0.next();
					o[k] = v1.get(k);
				}
				this.objString(o);
			} else this.objString(v);
			break;
		case 7:
			var e = $e[2];
			this.buf.b += Std.string(v[1]);
			break;
		case 3:
			this.buf.b += Std.string(v?"true":"false");
			break;
		case 0:
			this.buf.b += Std.string("null");
			break;
		}
	}
	,objString: function(v) {
		this.fieldsString(v,Reflect.fields(v));
	}
	,fieldsString: function(v,fields) {
		var first = true;
		this.buf.b += Std.string("{");
		var _g = 0;
		while(_g < fields.length) {
			var f = fields[_g];
			++_g;
			var value = Reflect.field(v,f);
			if(Reflect.isFunction(value)) continue;
			if(first) first = false; else this.buf.b += Std.string(",");
			this.quote(f);
			this.buf.b += Std.string(":");
			this.toStringRec(value);
		}
		this.buf.b += Std.string("}");
	}
	,toString: function(v) {
		this.buf = new StringBuf();
		this.toStringRec(v);
		return this.buf.b;
	}
	,reg_float: null
	,pos: null
	,str: null
	,buf: null
	,__class__: haxe.Json
}
haxe.Resource = $hxClasses["haxe.Resource"] = function() { }
haxe.Resource.__name__ = ["haxe","Resource"];
haxe.Resource.content = null;
haxe.Resource.listNames = function() {
	var names = new Array();
	var _g = 0, _g1 = haxe.Resource.content;
	while(_g < _g1.length) {
		var x = _g1[_g];
		++_g;
		names.push(x.name);
	}
	return names;
}
haxe.Resource.getString = function(name) {
	var _g = 0, _g1 = haxe.Resource.content;
	while(_g < _g1.length) {
		var x = _g1[_g];
		++_g;
		if(x.name == name) {
			if(x.str != null) return x.str;
			var b = haxe.Unserializer.run(x.data);
			return b.toString();
		}
	}
	return null;
}
haxe.Resource.getBytes = function(name) {
	var _g = 0, _g1 = haxe.Resource.content;
	while(_g < _g1.length) {
		var x = _g1[_g];
		++_g;
		if(x.name == name) {
			if(x.str != null) return haxe.io.Bytes.ofString(x.str);
			return haxe.Unserializer.run(x.data);
		}
	}
	return null;
}
haxe.Serializer = $hxClasses["haxe.Serializer"] = function() {
	this.buf = new StringBuf();
	this.cache = new Array();
	this.useCache = haxe.Serializer.USE_CACHE;
	this.useEnumIndex = haxe.Serializer.USE_ENUM_INDEX;
	this.shash = new Hash();
	this.scount = 0;
};
haxe.Serializer.__name__ = ["haxe","Serializer"];
haxe.Serializer.run = function(v) {
	var s = new haxe.Serializer();
	s.serialize(v);
	return s.toString();
}
haxe.Serializer.prototype = {
	serializeException: function(e) {
		this.buf.b += Std.string("x");
		this.serialize(e);
	}
	,serialize: function(v) {
		var $e = (Type["typeof"](v));
		switch( $e[1] ) {
		case 0:
			this.buf.b += Std.string("n");
			break;
		case 1:
			if(v == 0) {
				this.buf.b += Std.string("z");
				return;
			}
			this.buf.b += Std.string("i");
			this.buf.b += Std.string(v);
			break;
		case 2:
			if(Math.isNaN(v)) this.buf.b += Std.string("k"); else if(!Math.isFinite(v)) this.buf.b += Std.string(v < 0?"m":"p"); else {
				this.buf.b += Std.string("d");
				this.buf.b += Std.string(v);
			}
			break;
		case 3:
			this.buf.b += Std.string(v?"t":"f");
			break;
		case 6:
			var c = $e[2];
			if(c == String) {
				this.serializeString(v);
				return;
			}
			if(this.useCache && this.serializeRef(v)) return;
			switch(c) {
			case Array:
				var ucount = 0;
				this.buf.b += Std.string("a");
				var l = v.length;
				var _g = 0;
				while(_g < l) {
					var i = _g++;
					if(v[i] == null) ucount++; else {
						if(ucount > 0) {
							if(ucount == 1) this.buf.b += Std.string("n"); else {
								this.buf.b += Std.string("u");
								this.buf.b += Std.string(ucount);
							}
							ucount = 0;
						}
						this.serialize(v[i]);
					}
				}
				if(ucount > 0) {
					if(ucount == 1) this.buf.b += Std.string("n"); else {
						this.buf.b += Std.string("u");
						this.buf.b += Std.string(ucount);
					}
				}
				this.buf.b += Std.string("h");
				break;
			case List:
				this.buf.b += Std.string("l");
				var v1 = v;
				var $it0 = v1.iterator();
				while( $it0.hasNext() ) {
					var i = $it0.next();
					this.serialize(i);
				}
				this.buf.b += Std.string("h");
				break;
			case Date:
				var d = v;
				this.buf.b += Std.string("v");
				this.buf.b += Std.string(HxOverrides.dateStr(d));
				break;
			case Hash:
				this.buf.b += Std.string("b");
				var v1 = v;
				var $it1 = v1.keys();
				while( $it1.hasNext() ) {
					var k = $it1.next();
					this.serializeString(k);
					this.serialize(v1.get(k));
				}
				this.buf.b += Std.string("h");
				break;
			case IntHash:
				this.buf.b += Std.string("q");
				var v1 = v;
				var $it2 = v1.keys();
				while( $it2.hasNext() ) {
					var k = $it2.next();
					this.buf.b += Std.string(":");
					this.buf.b += Std.string(k);
					this.serialize(v1.get(k));
				}
				this.buf.b += Std.string("h");
				break;
			case haxe.io.Bytes:
				var v1 = v;
				var i = 0;
				var max = v1.length - 2;
				var charsBuf = new StringBuf();
				var b64 = haxe.Serializer.BASE64;
				while(i < max) {
					var b1 = v1.b[i++];
					var b2 = v1.b[i++];
					var b3 = v1.b[i++];
					charsBuf.b += Std.string(b64.charAt(b1 >> 2));
					charsBuf.b += Std.string(b64.charAt((b1 << 4 | b2 >> 4) & 63));
					charsBuf.b += Std.string(b64.charAt((b2 << 2 | b3 >> 6) & 63));
					charsBuf.b += Std.string(b64.charAt(b3 & 63));
				}
				if(i == max) {
					var b1 = v1.b[i++];
					var b2 = v1.b[i++];
					charsBuf.b += Std.string(b64.charAt(b1 >> 2));
					charsBuf.b += Std.string(b64.charAt((b1 << 4 | b2 >> 4) & 63));
					charsBuf.b += Std.string(b64.charAt(b2 << 2 & 63));
				} else if(i == max + 1) {
					var b1 = v1.b[i++];
					charsBuf.b += Std.string(b64.charAt(b1 >> 2));
					charsBuf.b += Std.string(b64.charAt(b1 << 4 & 63));
				}
				var chars = charsBuf.b;
				this.buf.b += Std.string("s");
				this.buf.b += Std.string(chars.length);
				this.buf.b += Std.string(":");
				this.buf.b += Std.string(chars);
				break;
			default:
				this.cache.pop();
				if(v.hxSerialize != null) {
					this.buf.b += Std.string("C");
					this.serializeString(Type.getClassName(c));
					this.cache.push(v);
					v.hxSerialize(this);
					this.buf.b += Std.string("g");
				} else {
					this.buf.b += Std.string("c");
					this.serializeString(Type.getClassName(c));
					this.cache.push(v);
					this.serializeFields(v);
				}
			}
			break;
		case 4:
			if(this.useCache && this.serializeRef(v)) return;
			this.buf.b += Std.string("o");
			this.serializeFields(v);
			break;
		case 7:
			var e = $e[2];
			if(this.useCache && this.serializeRef(v)) return;
			this.cache.pop();
			this.buf.b += Std.string(this.useEnumIndex?"j":"w");
			this.serializeString(Type.getEnumName(e));
			if(this.useEnumIndex) {
				this.buf.b += Std.string(":");
				this.buf.b += Std.string(v[1]);
			} else this.serializeString(v[0]);
			this.buf.b += Std.string(":");
			var l = v.length;
			this.buf.b += Std.string(l - 2);
			var _g = 2;
			while(_g < l) {
				var i = _g++;
				this.serialize(v[i]);
			}
			this.cache.push(v);
			break;
		case 5:
			throw "Cannot serialize function";
			break;
		default:
			throw "Cannot serialize " + Std.string(v);
		}
	}
	,serializeFields: function(v) {
		var _g = 0, _g1 = Reflect.fields(v);
		while(_g < _g1.length) {
			var f = _g1[_g];
			++_g;
			this.serializeString(f);
			this.serialize(Reflect.field(v,f));
		}
		this.buf.b += Std.string("g");
	}
	,serializeRef: function(v) {
		var vt = typeof(v);
		var _g1 = 0, _g = this.cache.length;
		while(_g1 < _g) {
			var i = _g1++;
			var ci = this.cache[i];
			if(typeof(ci) == vt && ci == v) {
				this.buf.b += Std.string("r");
				this.buf.b += Std.string(i);
				return true;
			}
		}
		this.cache.push(v);
		return false;
	}
	,serializeString: function(s) {
		var x = this.shash.get(s);
		if(x != null) {
			this.buf.b += Std.string("R");
			this.buf.b += Std.string(x);
			return;
		}
		this.shash.set(s,this.scount++);
		this.buf.b += Std.string("y");
		s = StringTools.urlEncode(s);
		this.buf.b += Std.string(s.length);
		this.buf.b += Std.string(":");
		this.buf.b += Std.string(s);
	}
	,toString: function() {
		return this.buf.b;
	}
	,useEnumIndex: null
	,useCache: null
	,scount: null
	,shash: null
	,cache: null
	,buf: null
	,__class__: haxe.Serializer
}
haxe.Unserializer = $hxClasses["haxe.Unserializer"] = function(buf) {
	this.buf = buf;
	this.length = buf.length;
	this.pos = 0;
	this.scache = new Array();
	this.cache = new Array();
	var r = haxe.Unserializer.DEFAULT_RESOLVER;
	if(r == null) {
		r = Type;
		haxe.Unserializer.DEFAULT_RESOLVER = r;
	}
	this.setResolver(r);
};
haxe.Unserializer.__name__ = ["haxe","Unserializer"];
haxe.Unserializer.initCodes = function() {
	var codes = new Array();
	var _g1 = 0, _g = haxe.Unserializer.BASE64.length;
	while(_g1 < _g) {
		var i = _g1++;
		codes[haxe.Unserializer.BASE64.charCodeAt(i)] = i;
	}
	return codes;
}
haxe.Unserializer.run = function(v) {
	return new haxe.Unserializer(v).unserialize();
}
haxe.Unserializer.prototype = {
	unserialize: function() {
		switch(this.buf.charCodeAt(this.pos++)) {
		case 110:
			return null;
		case 116:
			return true;
		case 102:
			return false;
		case 122:
			return 0;
		case 105:
			return this.readDigits();
		case 100:
			var p1 = this.pos;
			while(true) {
				var c = this.buf.charCodeAt(this.pos);
				if(c >= 43 && c < 58 || c == 101 || c == 69) this.pos++; else break;
			}
			return Std.parseFloat(HxOverrides.substr(this.buf,p1,this.pos - p1));
		case 121:
			var len = this.readDigits();
			if(this.buf.charCodeAt(this.pos++) != 58 || this.length - this.pos < len) throw "Invalid string length";
			var s = HxOverrides.substr(this.buf,this.pos,len);
			this.pos += len;
			s = StringTools.urlDecode(s);
			this.scache.push(s);
			return s;
		case 107:
			return Math.NaN;
		case 109:
			return Math.NEGATIVE_INFINITY;
		case 112:
			return Math.POSITIVE_INFINITY;
		case 97:
			var buf = this.buf;
			var a = new Array();
			this.cache.push(a);
			while(true) {
				var c = this.buf.charCodeAt(this.pos);
				if(c == 104) {
					this.pos++;
					break;
				}
				if(c == 117) {
					this.pos++;
					var n = this.readDigits();
					a[a.length + n - 1] = null;
				} else a.push(this.unserialize());
			}
			return a;
		case 111:
			var o = { };
			this.cache.push(o);
			this.unserializeObject(o);
			return o;
		case 114:
			var n = this.readDigits();
			if(n < 0 || n >= this.cache.length) throw "Invalid reference";
			return this.cache[n];
		case 82:
			var n = this.readDigits();
			if(n < 0 || n >= this.scache.length) throw "Invalid string reference";
			return this.scache[n];
		case 120:
			throw this.unserialize();
			break;
		case 99:
			var name = this.unserialize();
			var cl = this.resolver.resolveClass(name);
			if(cl == null) throw "Class not found " + name;
			var o = Type.createEmptyInstance(cl);
			this.cache.push(o);
			this.unserializeObject(o);
			return o;
		case 119:
			var name = this.unserialize();
			var edecl = this.resolver.resolveEnum(name);
			if(edecl == null) throw "Enum not found " + name;
			var e = this.unserializeEnum(edecl,this.unserialize());
			this.cache.push(e);
			return e;
		case 106:
			var name = this.unserialize();
			var edecl = this.resolver.resolveEnum(name);
			if(edecl == null) throw "Enum not found " + name;
			this.pos++;
			var index = this.readDigits();
			var tag = Type.getEnumConstructs(edecl)[index];
			if(tag == null) throw "Unknown enum index " + name + "@" + index;
			var e = this.unserializeEnum(edecl,tag);
			this.cache.push(e);
			return e;
		case 108:
			var l = new List();
			this.cache.push(l);
			var buf = this.buf;
			while(this.buf.charCodeAt(this.pos) != 104) l.add(this.unserialize());
			this.pos++;
			return l;
		case 98:
			var h = new Hash();
			this.cache.push(h);
			var buf = this.buf;
			while(this.buf.charCodeAt(this.pos) != 104) {
				var s = this.unserialize();
				h.set(s,this.unserialize());
			}
			this.pos++;
			return h;
		case 113:
			var h = new IntHash();
			this.cache.push(h);
			var buf = this.buf;
			var c = this.buf.charCodeAt(this.pos++);
			while(c == 58) {
				var i = this.readDigits();
				h.set(i,this.unserialize());
				c = this.buf.charCodeAt(this.pos++);
			}
			if(c != 104) throw "Invalid IntHash format";
			return h;
		case 118:
			var d = HxOverrides.strDate(HxOverrides.substr(this.buf,this.pos,19));
			this.cache.push(d);
			this.pos += 19;
			return d;
		case 115:
			var len = this.readDigits();
			var buf = this.buf;
			if(this.buf.charCodeAt(this.pos++) != 58 || this.length - this.pos < len) throw "Invalid bytes length";
			var codes = haxe.Unserializer.CODES;
			if(codes == null) {
				codes = haxe.Unserializer.initCodes();
				haxe.Unserializer.CODES = codes;
			}
			var i = this.pos;
			var rest = len & 3;
			var size = (len >> 2) * 3 + (rest >= 2?rest - 1:0);
			var max = i + (len - rest);
			var bytes = haxe.io.Bytes.alloc(size);
			var bpos = 0;
			while(i < max) {
				var c1 = codes[buf.charCodeAt(i++)];
				var c2 = codes[buf.charCodeAt(i++)];
				bytes.b[bpos++] = (c1 << 2 | c2 >> 4) & 255;
				var c3 = codes[buf.charCodeAt(i++)];
				bytes.b[bpos++] = (c2 << 4 | c3 >> 2) & 255;
				var c4 = codes[buf.charCodeAt(i++)];
				bytes.b[bpos++] = (c3 << 6 | c4) & 255;
			}
			if(rest >= 2) {
				var c1 = codes[buf.charCodeAt(i++)];
				var c2 = codes[buf.charCodeAt(i++)];
				bytes.b[bpos++] = (c1 << 2 | c2 >> 4) & 255;
				if(rest == 3) {
					var c3 = codes[buf.charCodeAt(i++)];
					bytes.b[bpos++] = (c2 << 4 | c3 >> 2) & 255;
				}
			}
			this.pos += len;
			this.cache.push(bytes);
			return bytes;
		case 67:
			var name = this.unserialize();
			var cl = this.resolver.resolveClass(name);
			if(cl == null) throw "Class not found " + name;
			var o = Type.createEmptyInstance(cl);
			this.cache.push(o);
			o.hxUnserialize(this);
			if(this.buf.charCodeAt(this.pos++) != 103) throw "Invalid custom data";
			return o;
		default:
		}
		this.pos--;
		throw "Invalid char " + this.buf.charAt(this.pos) + " at position " + this.pos;
	}
	,unserializeEnum: function(edecl,tag) {
		if(this.buf.charCodeAt(this.pos++) != 58) throw "Invalid enum format";
		var nargs = this.readDigits();
		if(nargs == 0) return Type.createEnum(edecl,tag);
		var args = new Array();
		while(nargs-- > 0) args.push(this.unserialize());
		return Type.createEnum(edecl,tag,args);
	}
	,unserializeObject: function(o) {
		while(true) {
			if(this.pos >= this.length) throw "Invalid object";
			if(this.buf.charCodeAt(this.pos) == 103) break;
			var k = this.unserialize();
			if(!js.Boot.__instanceof(k,String)) throw "Invalid object key";
			var v = this.unserialize();
			o[k] = v;
		}
		this.pos++;
	}
	,readDigits: function() {
		var k = 0;
		var s = false;
		var fpos = this.pos;
		while(true) {
			var c = this.buf.charCodeAt(this.pos);
			if(c != c) break;
			if(c == 45) {
				if(this.pos != fpos) break;
				s = true;
				this.pos++;
				continue;
			}
			if(c < 48 || c > 57) break;
			k = k * 10 + (c - 48);
			this.pos++;
		}
		if(s) k *= -1;
		return k;
	}
	,get: function(p) {
		return this.buf.charCodeAt(p);
	}
	,getResolver: function() {
		return this.resolver;
	}
	,setResolver: function(r) {
		if(r == null) this.resolver = { resolveClass : function(_) {
			return null;
		}, resolveEnum : function(_) {
			return null;
		}}; else this.resolver = r;
	}
	,resolver: null
	,scache: null
	,cache: null
	,length: null
	,pos: null
	,buf: null
	,__class__: haxe.Unserializer
}
haxe.Utf8 = $hxClasses["haxe.Utf8"] = function(size) {
	this.__b = "";
};
haxe.Utf8.__name__ = ["haxe","Utf8"];
haxe.Utf8.iter = function(s,chars) {
	var _g1 = 0, _g = s.length;
	while(_g1 < _g) {
		var i = _g1++;
		chars(HxOverrides.cca(s,i));
	}
}
haxe.Utf8.encode = function(s) {
	throw "Not implemented";
	return s;
}
haxe.Utf8.decode = function(s) {
	throw "Not implemented";
	return s;
}
haxe.Utf8.charCodeAt = function(s,index) {
	return HxOverrides.cca(s,index);
}
haxe.Utf8.validate = function(s) {
	return true;
}
haxe.Utf8.compare = function(a,b) {
	return a > b?1:a == b?0:-1;
}
haxe.Utf8.sub = function(s,pos,len) {
	return HxOverrides.substr(s,pos,len);
}
haxe.Utf8.prototype = {
	toString: function() {
		return this.__b;
	}
	,addChar: function(c) {
		this.__b += String.fromCharCode(c);
	}
	,__b: null
	,__class__: haxe.Utf8
}
if(!haxe.io) haxe.io = {}
haxe.io.Bytes = $hxClasses["haxe.io.Bytes"] = function(length,b) {
	this.length = length;
	this.b = b;
};
haxe.io.Bytes.__name__ = ["haxe","io","Bytes"];
haxe.io.Bytes.alloc = function(length) {
	var a = new Array();
	var _g = 0;
	while(_g < length) {
		var i = _g++;
		a.push(0);
	}
	return new haxe.io.Bytes(length,a);
}
haxe.io.Bytes.ofString = function(s) {
	var a = new Array();
	var _g1 = 0, _g = s.length;
	while(_g1 < _g) {
		var i = _g1++;
		var c = s.charCodeAt(i);
		if(c <= 127) a.push(c); else if(c <= 2047) {
			a.push(192 | c >> 6);
			a.push(128 | c & 63);
		} else if(c <= 65535) {
			a.push(224 | c >> 12);
			a.push(128 | c >> 6 & 63);
			a.push(128 | c & 63);
		} else {
			a.push(240 | c >> 18);
			a.push(128 | c >> 12 & 63);
			a.push(128 | c >> 6 & 63);
			a.push(128 | c & 63);
		}
	}
	return new haxe.io.Bytes(a.length,a);
}
haxe.io.Bytes.ofData = function(b) {
	return new haxe.io.Bytes(b.length,b);
}
haxe.io.Bytes.prototype = {
	getData: function() {
		return this.b;
	}
	,toHex: function() {
		var s = new StringBuf();
		var chars = [];
		var str = "0123456789abcdef";
		var _g1 = 0, _g = str.length;
		while(_g1 < _g) {
			var i = _g1++;
			chars.push(HxOverrides.cca(str,i));
		}
		var _g1 = 0, _g = this.length;
		while(_g1 < _g) {
			var i = _g1++;
			var c = this.b[i];
			s.b += String.fromCharCode(chars[c >> 4]);
			s.b += String.fromCharCode(chars[c & 15]);
		}
		return s.b;
	}
	,toString: function() {
		return this.readString(0,this.length);
	}
	,readString: function(pos,len) {
		if(pos < 0 || len < 0 || pos + len > this.length) throw haxe.io.Error.OutsideBounds;
		var s = "";
		var b = this.b;
		var fcc = String.fromCharCode;
		var i = pos;
		var max = pos + len;
		while(i < max) {
			var c = b[i++];
			if(c < 128) {
				if(c == 0) break;
				s += fcc(c);
			} else if(c < 224) s += fcc((c & 63) << 6 | b[i++] & 127); else if(c < 240) {
				var c2 = b[i++];
				s += fcc((c & 31) << 12 | (c2 & 127) << 6 | b[i++] & 127);
			} else {
				var c2 = b[i++];
				var c3 = b[i++];
				s += fcc((c & 15) << 18 | (c2 & 127) << 12 | c3 << 6 & 127 | b[i++] & 127);
			}
		}
		return s;
	}
	,compare: function(other) {
		var b1 = this.b;
		var b2 = other.b;
		var len = this.length < other.length?this.length:other.length;
		var _g = 0;
		while(_g < len) {
			var i = _g++;
			if(b1[i] != b2[i]) return b1[i] - b2[i];
		}
		return this.length - other.length;
	}
	,sub: function(pos,len) {
		if(pos < 0 || len < 0 || pos + len > this.length) throw haxe.io.Error.OutsideBounds;
		return new haxe.io.Bytes(len,this.b.slice(pos,pos + len));
	}
	,blit: function(pos,src,srcpos,len) {
		if(pos < 0 || srcpos < 0 || len < 0 || pos + len > this.length || srcpos + len > src.length) throw haxe.io.Error.OutsideBounds;
		var b1 = this.b;
		var b2 = src.b;
		if(b1 == b2 && pos > srcpos) {
			var i = len;
			while(i > 0) {
				i--;
				b1[i + pos] = b2[i + srcpos];
			}
			return;
		}
		var _g = 0;
		while(_g < len) {
			var i = _g++;
			b1[i + pos] = b2[i + srcpos];
		}
	}
	,set: function(pos,v) {
		this.b[pos] = v & 255;
	}
	,get: function(pos) {
		return this.b[pos];
	}
	,b: null
	,length: null
	,__class__: haxe.io.Bytes
}
haxe.io.BytesBuffer = $hxClasses["haxe.io.BytesBuffer"] = function() {
	this.b = new Array();
};
haxe.io.BytesBuffer.__name__ = ["haxe","io","BytesBuffer"];
haxe.io.BytesBuffer.prototype = {
	getBytes: function() {
		var bytes = new haxe.io.Bytes(this.b.length,this.b);
		this.b = null;
		return bytes;
	}
	,addBytes: function(src,pos,len) {
		if(pos < 0 || len < 0 || pos + len > src.length) throw haxe.io.Error.OutsideBounds;
		var b1 = this.b;
		var b2 = src.b;
		var _g1 = pos, _g = pos + len;
		while(_g1 < _g) {
			var i = _g1++;
			this.b.push(b2[i]);
		}
	}
	,add: function(src) {
		var b1 = this.b;
		var b2 = src.b;
		var _g1 = 0, _g = src.length;
		while(_g1 < _g) {
			var i = _g1++;
			this.b.push(b2[i]);
		}
	}
	,addByte: function($byte) {
		this.b.push($byte);
	}
	,b: null
	,__class__: haxe.io.BytesBuffer
}
haxe.io.Eof = $hxClasses["haxe.io.Eof"] = function() {
};
haxe.io.Eof.__name__ = ["haxe","io","Eof"];
haxe.io.Eof.prototype = {
	toString: function() {
		return "Eof";
	}
	,__class__: haxe.io.Eof
}
haxe.io.Error = $hxClasses["haxe.io.Error"] = { __ename__ : ["haxe","io","Error"], __constructs__ : ["Blocked","Overflow","OutsideBounds","Custom"] }
haxe.io.Error.Blocked = ["Blocked",0];
haxe.io.Error.Blocked.toString = $estr;
haxe.io.Error.Blocked.__enum__ = haxe.io.Error;
haxe.io.Error.Overflow = ["Overflow",1];
haxe.io.Error.Overflow.toString = $estr;
haxe.io.Error.Overflow.__enum__ = haxe.io.Error;
haxe.io.Error.OutsideBounds = ["OutsideBounds",2];
haxe.io.Error.OutsideBounds.toString = $estr;
haxe.io.Error.OutsideBounds.__enum__ = haxe.io.Error;
haxe.io.Error.Custom = function(e) { var $x = ["Custom",3,e]; $x.__enum__ = haxe.io.Error; $x.toString = $estr; return $x; }
haxe.io.Input = $hxClasses["haxe.io.Input"] = function() { }
haxe.io.Input.__name__ = ["haxe","io","Input"];
haxe.io.Input.prototype = {
	getDoubleSig: function(bytes) {
		return Std.parseInt((((bytes[1] & 15) << 16 | bytes[2] << 8 | bytes[3]) * Math.pow(2,32)).toString()) + Std.parseInt(((bytes[4] >> 7) * Math.pow(2,31)).toString()) + Std.parseInt(((bytes[4] & 127) << 24 | bytes[5] << 16 | bytes[6] << 8 | bytes[7]).toString());
	}
	,readString: function(len) {
		var b = haxe.io.Bytes.alloc(len);
		this.readFullBytes(b,0,len);
		return b.toString();
	}
	,readInt32: function() {
		var ch1 = this.readByte();
		var ch2 = this.readByte();
		var ch3 = this.readByte();
		var ch4 = this.readByte();
		return this.bigEndian?(ch1 << 8 | ch2) << 16 | (ch3 << 8 | ch4):(ch4 << 8 | ch3) << 16 | (ch2 << 8 | ch1);
	}
	,readUInt30: function() {
		var ch1 = this.readByte();
		var ch2 = this.readByte();
		var ch3 = this.readByte();
		var ch4 = this.readByte();
		if((this.bigEndian?ch1:ch4) >= 64) throw haxe.io.Error.Overflow;
		return this.bigEndian?ch4 | ch3 << 8 | ch2 << 16 | ch1 << 24:ch1 | ch2 << 8 | ch3 << 16 | ch4 << 24;
	}
	,readInt31: function() {
		var ch1, ch2, ch3, ch4;
		if(this.bigEndian) {
			ch4 = this.readByte();
			ch3 = this.readByte();
			ch2 = this.readByte();
			ch1 = this.readByte();
		} else {
			ch1 = this.readByte();
			ch2 = this.readByte();
			ch3 = this.readByte();
			ch4 = this.readByte();
		}
		if((ch4 & 128) == 0 != ((ch4 & 64) == 0)) throw haxe.io.Error.Overflow;
		return ch1 | ch2 << 8 | ch3 << 16 | ch4 << 24;
	}
	,readUInt24: function() {
		var ch1 = this.readByte();
		var ch2 = this.readByte();
		var ch3 = this.readByte();
		return this.bigEndian?ch3 | ch2 << 8 | ch1 << 16:ch1 | ch2 << 8 | ch3 << 16;
	}
	,readInt24: function() {
		var ch1 = this.readByte();
		var ch2 = this.readByte();
		var ch3 = this.readByte();
		var n = this.bigEndian?ch3 | ch2 << 8 | ch1 << 16:ch1 | ch2 << 8 | ch3 << 16;
		if((n & 8388608) != 0) return n - 16777216;
		return n;
	}
	,readUInt16: function() {
		var ch1 = this.readByte();
		var ch2 = this.readByte();
		return this.bigEndian?ch2 | ch1 << 8:ch1 | ch2 << 8;
	}
	,readInt16: function() {
		var ch1 = this.readByte();
		var ch2 = this.readByte();
		var n = this.bigEndian?ch2 | ch1 << 8:ch1 | ch2 << 8;
		if((n & 32768) != 0) return n - 65536;
		return n;
	}
	,readInt8: function() {
		var n = this.readByte();
		if(n >= 128) return n - 256;
		return n;
	}
	,readDouble: function() {
		var bytes = [];
		bytes.push(this.readByte());
		bytes.push(this.readByte());
		bytes.push(this.readByte());
		bytes.push(this.readByte());
		bytes.push(this.readByte());
		bytes.push(this.readByte());
		bytes.push(this.readByte());
		bytes.push(this.readByte());
		if(this.bigEndian) bytes.reverse();
		var sign = 1 - (bytes[0] >> 7 << 1);
		var exp = (bytes[0] << 4 & 2047 | bytes[1] >> 4) - 1023;
		var sig = this.getDoubleSig(bytes);
		if(sig == 0 && exp == -1023) return 0.0;
		return sign * (1.0 + Math.pow(2,-52) * sig) * Math.pow(2,exp);
	}
	,readFloat: function() {
		var bytes = [];
		bytes.push(this.readByte());
		bytes.push(this.readByte());
		bytes.push(this.readByte());
		bytes.push(this.readByte());
		if(this.bigEndian) bytes.reverse();
		var sign = 1 - (bytes[0] >> 7 << 1);
		var exp = (bytes[0] << 1 & 255 | bytes[1] >> 7) - 127;
		var sig = (bytes[1] & 127) << 16 | bytes[2] << 8 | bytes[3];
		if(sig == 0 && exp == -127) return 0.0;
		return sign * (1 + Math.pow(2,-23) * sig) * Math.pow(2,exp);
	}
	,readLine: function() {
		var buf = new StringBuf();
		var last;
		var s;
		try {
			while((last = this.readByte()) != 10) buf.b += String.fromCharCode(last);
			s = buf.b;
			if(HxOverrides.cca(s,s.length - 1) == 13) s = HxOverrides.substr(s,0,-1);
		} catch( e ) {
			if( js.Boot.__instanceof(e,haxe.io.Eof) ) {
				s = buf.b;
				if(s.length == 0) throw e;
			} else throw(e);
		}
		return s;
	}
	,readUntil: function(end) {
		var buf = new StringBuf();
		var last;
		while((last = this.readByte()) != end) buf.b += String.fromCharCode(last);
		return buf.b;
	}
	,read: function(nbytes) {
		var s = haxe.io.Bytes.alloc(nbytes);
		var p = 0;
		while(nbytes > 0) {
			var k = this.readBytes(s,p,nbytes);
			if(k == 0) throw haxe.io.Error.Blocked;
			p += k;
			nbytes -= k;
		}
		return s;
	}
	,readFullBytes: function(s,pos,len) {
		while(len > 0) {
			var k = this.readBytes(s,pos,len);
			pos += k;
			len -= k;
		}
	}
	,readAll: function(bufsize) {
		if(bufsize == null) bufsize = 16384;
		var buf = haxe.io.Bytes.alloc(bufsize);
		var total = new haxe.io.BytesBuffer();
		try {
			while(true) {
				var len = this.readBytes(buf,0,bufsize);
				if(len == 0) throw haxe.io.Error.Blocked;
				total.addBytes(buf,0,len);
			}
		} catch( e ) {
			if( js.Boot.__instanceof(e,haxe.io.Eof) ) {
			} else throw(e);
		}
		return total.getBytes();
	}
	,setEndian: function(b) {
		this.bigEndian = b;
		return b;
	}
	,close: function() {
	}
	,readBytes: function(s,pos,len) {
		var k = len;
		var b = s.b;
		if(pos < 0 || len < 0 || pos + len > s.length) throw haxe.io.Error.OutsideBounds;
		while(k > 0) {
			b[pos] = this.readByte();
			pos++;
			k--;
		}
		return len;
	}
	,readByte: function() {
		return (function($this) {
			var $r;
			throw "Not implemented";
			return $r;
		}(this));
	}
	,bigEndian: null
	,__class__: haxe.io.Input
	,__properties__: {set_bigEndian:"setEndian"}
}
haxe.io.Output = $hxClasses["haxe.io.Output"] = function() { }
haxe.io.Output.__name__ = ["haxe","io","Output"];
haxe.io.Output.prototype = {
	writeString: function(s) {
		var b = haxe.io.Bytes.ofString(s);
		this.writeFullBytes(b,0,b.length);
	}
	,writeInput: function(i,bufsize) {
		if(bufsize == null) bufsize = 4096;
		var buf = haxe.io.Bytes.alloc(bufsize);
		try {
			while(true) {
				var len = i.readBytes(buf,0,bufsize);
				if(len == 0) throw haxe.io.Error.Blocked;
				var p = 0;
				while(len > 0) {
					var k = this.writeBytes(buf,p,len);
					if(k == 0) throw haxe.io.Error.Blocked;
					p += k;
					len -= k;
				}
			}
		} catch( e ) {
			if( js.Boot.__instanceof(e,haxe.io.Eof) ) {
			} else throw(e);
		}
	}
	,prepare: function(nbytes) {
	}
	,writeInt32: function(x) {
		if(this.bigEndian) {
			this.writeByte(haxe.Int32.toInt(x >>> 24));
			this.writeByte(haxe.Int32.toInt(x >>> 16) & 255);
			this.writeByte(haxe.Int32.toInt(x >>> 8) & 255);
			this.writeByte(haxe.Int32.toInt(x & (255 | 0)));
		} else {
			this.writeByte(haxe.Int32.toInt(x & (255 | 0)));
			this.writeByte(haxe.Int32.toInt(x >>> 8) & 255);
			this.writeByte(haxe.Int32.toInt(x >>> 16) & 255);
			this.writeByte(haxe.Int32.toInt(x >>> 24));
		}
	}
	,writeUInt30: function(x) {
		if(x < 0 || x >= 1073741824) throw haxe.io.Error.Overflow;
		if(this.bigEndian) {
			this.writeByte(x >>> 24);
			this.writeByte(x >> 16 & 255);
			this.writeByte(x >> 8 & 255);
			this.writeByte(x & 255);
		} else {
			this.writeByte(x & 255);
			this.writeByte(x >> 8 & 255);
			this.writeByte(x >> 16 & 255);
			this.writeByte(x >>> 24);
		}
	}
	,writeInt31: function(x) {
		if(x < -1073741824 || x >= 1073741824) throw haxe.io.Error.Overflow;
		if(this.bigEndian) {
			this.writeByte(x >>> 24);
			this.writeByte(x >> 16 & 255);
			this.writeByte(x >> 8 & 255);
			this.writeByte(x & 255);
		} else {
			this.writeByte(x & 255);
			this.writeByte(x >> 8 & 255);
			this.writeByte(x >> 16 & 255);
			this.writeByte(x >>> 24);
		}
	}
	,writeUInt24: function(x) {
		if(x < 0 || x >= 16777216) throw haxe.io.Error.Overflow;
		if(this.bigEndian) {
			this.writeByte(x >> 16);
			this.writeByte(x >> 8 & 255);
			this.writeByte(x & 255);
		} else {
			this.writeByte(x & 255);
			this.writeByte(x >> 8 & 255);
			this.writeByte(x >> 16);
		}
	}
	,writeInt24: function(x) {
		if(x < -8388608 || x >= 8388608) throw haxe.io.Error.Overflow;
		this.writeUInt24(x & 16777215);
	}
	,writeUInt16: function(x) {
		if(x < 0 || x >= 65536) throw haxe.io.Error.Overflow;
		if(this.bigEndian) {
			this.writeByte(x >> 8);
			this.writeByte(x & 255);
		} else {
			this.writeByte(x & 255);
			this.writeByte(x >> 8);
		}
	}
	,writeInt16: function(x) {
		if(x < -32768 || x >= 32768) throw haxe.io.Error.Overflow;
		this.writeUInt16(x & 65535);
	}
	,writeInt8: function(x) {
		if(x < -128 || x >= 128) throw haxe.io.Error.Overflow;
		this.writeByte(x & 255);
	}
	,writeDouble: function(x) {
		if(x == 0.0) {
			this.writeByte(0);
			this.writeByte(0);
			this.writeByte(0);
			this.writeByte(0);
			this.writeByte(0);
			this.writeByte(0);
			this.writeByte(0);
			this.writeByte(0);
			return;
		}
		var exp = Math.floor(Math.log(Math.abs(x)) / haxe.io.Output.LN2);
		var sig = Math.floor(Math.abs(x) / Math.pow(2,exp) * Math.pow(2,52));
		var sig_h = sig & 34359738367;
		var sig_l = Math.floor(sig / Math.pow(2,32));
		var b1 = exp + 1023 >> 4 | (exp > 0?x < 0?128:64:x < 0?128:0), b2 = exp + 1023 << 4 & 255 | sig_l >> 16 & 15, b3 = sig_l >> 8 & 255, b4 = sig_l & 255, b5 = sig_h >> 24 & 255, b6 = sig_h >> 16 & 255, b7 = sig_h >> 8 & 255, b8 = sig_h & 255;
		if(this.bigEndian) {
			this.writeByte(b8);
			this.writeByte(b7);
			this.writeByte(b6);
			this.writeByte(b5);
			this.writeByte(b4);
			this.writeByte(b3);
			this.writeByte(b2);
			this.writeByte(b1);
		} else {
			this.writeByte(b1);
			this.writeByte(b2);
			this.writeByte(b3);
			this.writeByte(b4);
			this.writeByte(b5);
			this.writeByte(b6);
			this.writeByte(b7);
			this.writeByte(b8);
		}
	}
	,writeFloat: function(x) {
		if(x == 0.0) {
			this.writeByte(0);
			this.writeByte(0);
			this.writeByte(0);
			this.writeByte(0);
			return;
		}
		var exp = Math.floor(Math.log(Math.abs(x)) / haxe.io.Output.LN2);
		var sig = Math.floor(Math.abs(x) / Math.pow(2,exp) * 8388608) & 8388607;
		var b1 = exp + 127 >> 1 | (exp > 0?x < 0?128:64:x < 0?128:0), b2 = exp + 127 << 7 & 255 | sig >> 16 & 127, b3 = sig >> 8 & 255, b4 = sig & 255;
		if(this.bigEndian) {
			this.writeByte(b4);
			this.writeByte(b3);
			this.writeByte(b2);
			this.writeByte(b1);
		} else {
			this.writeByte(b1);
			this.writeByte(b2);
			this.writeByte(b3);
			this.writeByte(b4);
		}
	}
	,writeFullBytes: function(s,pos,len) {
		while(len > 0) {
			var k = this.writeBytes(s,pos,len);
			pos += k;
			len -= k;
		}
	}
	,write: function(s) {
		var l = s.length;
		var p = 0;
		while(l > 0) {
			var k = this.writeBytes(s,p,l);
			if(k == 0) throw haxe.io.Error.Blocked;
			p += k;
			l -= k;
		}
	}
	,setEndian: function(b) {
		this.bigEndian = b;
		return b;
	}
	,close: function() {
	}
	,flush: function() {
	}
	,writeBytes: function(s,pos,len) {
		var k = len;
		var b = s.b;
		if(pos < 0 || len < 0 || pos + len > s.length) throw haxe.io.Error.OutsideBounds;
		while(k > 0) {
			this.writeByte(b[pos]);
			pos++;
			k--;
		}
		return len;
	}
	,writeByte: function(c) {
		throw "Not implemented";
	}
	,bigEndian: null
	,__class__: haxe.io.Output
	,__properties__: {set_bigEndian:"setEndian"}
}
if(!haxe.xml) haxe.xml = {}
haxe.xml.Parser = $hxClasses["haxe.xml.Parser"] = function() { }
haxe.xml.Parser.__name__ = ["haxe","xml","Parser"];
haxe.xml.Parser.parse = function(str) {
	var doc = Xml.createDocument();
	haxe.xml.Parser.doParse(str,0,doc);
	return doc;
}
haxe.xml.Parser.doParse = function(str,p,parent) {
	if(p == null) p = 0;
	var xml = null;
	var state = 1;
	var next = 1;
	var aname = null;
	var start = 0;
	var nsubs = 0;
	var nbrackets = 0;
	var c = str.charCodeAt(p);
	while(!(c != c)) {
		switch(state) {
		case 0:
			switch(c) {
			case 10:case 13:case 9:case 32:
				break;
			default:
				state = next;
				continue;
			}
			break;
		case 1:
			switch(c) {
			case 60:
				state = 0;
				next = 2;
				break;
			default:
				start = p;
				state = 13;
				continue;
			}
			break;
		case 13:
			if(c == 60) {
				var child = Xml.createPCData(HxOverrides.substr(str,start,p - start));
				parent.addChild(child);
				nsubs++;
				state = 0;
				next = 2;
			}
			break;
		case 17:
			if(c == 93 && str.charCodeAt(p + 1) == 93 && str.charCodeAt(p + 2) == 62) {
				var child = Xml.createCData(HxOverrides.substr(str,start,p - start));
				parent.addChild(child);
				nsubs++;
				p += 2;
				state = 1;
			}
			break;
		case 2:
			switch(c) {
			case 33:
				if(str.charCodeAt(p + 1) == 91) {
					p += 2;
					if(HxOverrides.substr(str,p,6).toUpperCase() != "CDATA[") throw "Expected <![CDATA[";
					p += 5;
					state = 17;
					start = p + 1;
				} else if(str.charCodeAt(p + 1) == 68 || str.charCodeAt(p + 1) == 100) {
					if(HxOverrides.substr(str,p + 2,6).toUpperCase() != "OCTYPE") throw "Expected <!DOCTYPE";
					p += 8;
					state = 16;
					start = p + 1;
				} else if(str.charCodeAt(p + 1) != 45 || str.charCodeAt(p + 2) != 45) throw "Expected <!--"; else {
					p += 2;
					state = 15;
					start = p + 1;
				}
				break;
			case 63:
				state = 14;
				start = p;
				break;
			case 47:
				if(parent == null) throw "Expected node name";
				start = p + 1;
				state = 0;
				next = 10;
				break;
			default:
				state = 3;
				start = p;
				continue;
			}
			break;
		case 3:
			if(!(c >= 97 && c <= 122 || c >= 65 && c <= 90 || c >= 48 && c <= 57 || c == 58 || c == 46 || c == 95 || c == 45)) {
				if(p == start) throw "Expected node name";
				xml = Xml.createElement(HxOverrides.substr(str,start,p - start));
				parent.addChild(xml);
				state = 0;
				next = 4;
				continue;
			}
			break;
		case 4:
			switch(c) {
			case 47:
				state = 11;
				nsubs++;
				break;
			case 62:
				state = 9;
				nsubs++;
				break;
			default:
				state = 5;
				start = p;
				continue;
			}
			break;
		case 5:
			if(!(c >= 97 && c <= 122 || c >= 65 && c <= 90 || c >= 48 && c <= 57 || c == 58 || c == 46 || c == 95 || c == 45)) {
				var tmp;
				if(start == p) throw "Expected attribute name";
				tmp = HxOverrides.substr(str,start,p - start);
				aname = tmp;
				if(xml.exists(aname)) throw "Duplicate attribute";
				state = 0;
				next = 6;
				continue;
			}
			break;
		case 6:
			switch(c) {
			case 61:
				state = 0;
				next = 7;
				break;
			default:
				throw "Expected =";
			}
			break;
		case 7:
			switch(c) {
			case 34:case 39:
				state = 8;
				start = p;
				break;
			default:
				throw "Expected \"";
			}
			break;
		case 8:
			if(c == str.charCodeAt(start)) {
				var val = HxOverrides.substr(str,start + 1,p - start - 1);
				xml.set(aname,val);
				state = 0;
				next = 4;
			}
			break;
		case 9:
			p = haxe.xml.Parser.doParse(str,p,xml);
			start = p;
			state = 1;
			break;
		case 11:
			switch(c) {
			case 62:
				state = 1;
				break;
			default:
				throw "Expected >";
			}
			break;
		case 12:
			switch(c) {
			case 62:
				if(nsubs == 0) parent.addChild(Xml.createPCData(""));
				return p;
			default:
				throw "Expected >";
			}
			break;
		case 10:
			if(!(c >= 97 && c <= 122 || c >= 65 && c <= 90 || c >= 48 && c <= 57 || c == 58 || c == 46 || c == 95 || c == 45)) {
				if(start == p) throw "Expected node name";
				var v = HxOverrides.substr(str,start,p - start);
				if(v != parent.getNodeName()) throw "Expected </" + parent.getNodeName() + ">";
				state = 0;
				next = 12;
				continue;
			}
			break;
		case 15:
			if(c == 45 && str.charCodeAt(p + 1) == 45 && str.charCodeAt(p + 2) == 62) {
				parent.addChild(Xml.createComment(HxOverrides.substr(str,start,p - start)));
				p += 2;
				state = 1;
			}
			break;
		case 16:
			if(c == 91) nbrackets++; else if(c == 93) nbrackets--; else if(c == 62 && nbrackets == 0) {
				parent.addChild(Xml.createDocType(HxOverrides.substr(str,start,p - start)));
				state = 1;
			}
			break;
		case 14:
			if(c == 63 && str.charCodeAt(p + 1) == 62) {
				p++;
				var str1 = HxOverrides.substr(str,start + 1,p - start - 2);
				parent.addChild(Xml.createProlog(str1));
				state = 1;
			}
			break;
		}
		c = str.charCodeAt(++p);
	}
	if(state == 1) {
		start = p;
		state = 13;
	}
	if(state == 13) {
		if(p != start || nsubs == 0) parent.addChild(Xml.createPCData(HxOverrides.substr(str,start,p - start)));
		return p;
	}
	throw "Unexpected end";
}
haxe.xml.Parser.isValidChar = function(c) {
	return c >= 97 && c <= 122 || c >= 65 && c <= 90 || c >= 48 && c <= 57 || c == 58 || c == 46 || c == 95 || c == 45;
}
var js = js || {}
js.Boot = $hxClasses["js.Boot"] = function() { }
js.Boot.__name__ = ["js","Boot"];
js.Boot.__unhtml = function(s) {
	return s.split("&").join("&amp;").split("<").join("&lt;").split(">").join("&gt;");
}
js.Boot.__trace = function(v,i) {
	var msg = i != null?i.fileName + ":" + i.lineNumber + ": ":"";
	msg += js.Boot.__string_rec(v,"");
	var d;
	if(typeof(document) != "undefined" && (d = document.getElementById("haxe:trace")) != null) d.innerHTML += js.Boot.__unhtml(msg) + "<br/>"; else if(typeof(console) != "undefined" && console.log != null) console.log(msg);
}
js.Boot.__clear_trace = function() {
	var d = document.getElementById("haxe:trace");
	if(d != null) d.innerHTML = "";
}
js.Boot.isClass = function(o) {
	return o.__name__;
}
js.Boot.isEnum = function(e) {
	return e.__ename__;
}
js.Boot.getClass = function(o) {
	return o.__class__;
}
js.Boot.__string_rec = function(o,s) {
	if(o == null) return "null";
	if(s.length >= 5) return "<...>";
	var t = typeof(o);
	if(t == "function" && (o.__name__ || o.__ename__)) t = "object";
	switch(t) {
	case "object":
		if(o instanceof Array) {
			if(o.__enum__) {
				if(o.length == 2) return o[0];
				var str = o[0] + "(";
				s += "\t";
				var _g1 = 2, _g = o.length;
				while(_g1 < _g) {
					var i = _g1++;
					if(i != 2) str += "," + js.Boot.__string_rec(o[i],s); else str += js.Boot.__string_rec(o[i],s);
				}
				return str + ")";
			}
			var l = o.length;
			var i;
			var str = "[";
			s += "\t";
			var _g = 0;
			while(_g < l) {
				var i1 = _g++;
				str += (i1 > 0?",":"") + js.Boot.__string_rec(o[i1],s);
			}
			str += "]";
			return str;
		}
		var tostr;
		try {
			tostr = o.toString;
		} catch( e ) {
			return "???";
		}
		if(tostr != null && tostr != Object.toString) {
			var s2 = o.toString();
			if(s2 != "[object Object]") return s2;
		}
		var k = null;
		var str = "{\n";
		s += "\t";
		var hasp = o.hasOwnProperty != null;
		for( var k in o ) { ;
		if(hasp && !o.hasOwnProperty(k)) {
			continue;
		}
		if(k == "prototype" || k == "__class__" || k == "__super__" || k == "__interfaces__" || k == "__properties__") {
			continue;
		}
		if(str.length != 2) str += ", \n";
		str += s + k + " : " + js.Boot.__string_rec(o[k],s);
		}
		s = s.substring(1);
		str += "\n" + s + "}";
		return str;
	case "function":
		return "<function>";
	case "string":
		return o;
	default:
		return String(o);
	}
}
js.Boot.__interfLoop = function(cc,cl) {
	if(cc == null) return false;
	if(cc == cl) return true;
	var intf = cc.__interfaces__;
	if(intf != null) {
		var _g1 = 0, _g = intf.length;
		while(_g1 < _g) {
			var i = _g1++;
			var i1 = intf[i];
			if(i1 == cl || js.Boot.__interfLoop(i1,cl)) return true;
		}
	}
	return js.Boot.__interfLoop(cc.__super__,cl);
}
js.Boot.__instanceof = function(o,cl) {
	try {
		if(o instanceof cl) {
			if(cl == Array) return o.__enum__ == null;
			return true;
		}
		if(js.Boot.__interfLoop(o.__class__,cl)) return true;
	} catch( e ) {
		if(cl == null) return false;
	}
	switch(cl) {
	case Int:
		return Math.ceil(o%2147483648.0) === o;
	case Float:
		return typeof(o) == "number";
	case Bool:
		return o === true || o === false;
	case String:
		return typeof(o) == "string";
	case Dynamic:
		return true;
	default:
		if(o == null) return false;
		if(cl == Class && o.__name__ != null) return true; else null;
		if(cl == Enum && o.__ename__ != null) return true; else null;
		return o.__enum__ == cl;
	}
}
js.Boot.__cast = function(o,t) {
	if(js.Boot.__instanceof(o,t)) return o; else throw "Cannot cast " + Std.string(o) + " to " + Std.string(t);
}
js.Lib = $hxClasses["js.Lib"] = function() { }
js.Lib.__name__ = ["js","Lib"];
js.Lib.document = null;
js.Lib.window = null;
js.Lib.debug = function() {
	debugger;
}
js.Lib.alert = function(v) {
	alert(js.Boot.__string_rec(v,""));
}
js.Lib.eval = function(code) {
	return eval(code);
}
js.Lib.setErrorHandler = function(f) {
	js.Lib.onerror = f;
}
if(Array.prototype.indexOf) HxOverrides.remove = function(a,o) {
	var i = a.indexOf(o);
	if(i == -1) return false;
	a.splice(i,1);
	return true;
}; else null;
Math.__name__ = ["Math"];
Math.NaN = Number.NaN;
Math.NEGATIVE_INFINITY = Number.NEGATIVE_INFINITY;
Math.POSITIVE_INFINITY = Number.POSITIVE_INFINITY;
$hxClasses.Math = Math;
Math.isFinite = function(i) {
	return isFinite(i);
};
Math.isNaN = function(i) {
	return isNaN(i);
};
String.prototype.__class__ = $hxClasses.String = String;
String.__name__ = ["String"];
Array.prototype.__class__ = $hxClasses.Array = Array;
Array.__name__ = ["Array"];
Date.prototype.__class__ = $hxClasses.Date = Date;
Date.__name__ = ["Date"];
var Int = $hxClasses.Int = { __name__ : ["Int"]};
var Dynamic = $hxClasses.Dynamic = { __name__ : ["Dynamic"]};
var Float = $hxClasses.Float = Number;
Float.__name__ = ["Float"];
var Bool = $hxClasses.Bool = Boolean;
Bool.__ename__ = ["Bool"];
var Class = $hxClasses.Class = { __name__ : ["Class"]};
var Enum = { };
var Void = $hxClasses.Void = { __ename__ : ["Void"]};
Xml.Element = "element";
Xml.PCData = "pcdata";
Xml.CData = "cdata";
Xml.Comment = "comment";
Xml.DocType = "doctype";
Xml.Prolog = "prolog";
Xml.Document = "document";
if(typeof(JSON) != "undefined") haxe.Json = JSON;
haxe.Resource.content = [{ name : "grammar_webwork.txt", data : "s5090:I1RyYW5zbGF0aW9uIGZyb20gTWF0aE1MIHRvIFdlYndvcmsuDQoNCiNSb290IHJ1bGUNCmF0dHJpYnV0ZXMgcHJpb3JpdHkgPSAxDQoJbWF0aCA6Oj0gPG1hdGggeG1sbnMgXD0gIiBodHRwOi8vd3d3LnczLm9yZy8xOTk4L01hdGgvTWF0aE1MICIgPiBFIDwvbWF0aD4geyAkOCB9DQptYXRoIDo6PSA8bWF0aD4gRSA8L21hdGg%IHsgJDIgfQ0KDQojUGFyZW50aGVzZXMgYXJvdW5kIGV4cHJlc3Npb25zDQphdHRyaWJ1dGVzIHByaW9yaXR5ID0gMg0KCUEgOjo9IDxtZmVuY2VkPiA8bXJvdz4gRSA8L21yb3c%IDwvbWZlbmNlZD4geyBcKCAkMyBcKSB9DQphdHRyaWJ1dGVzIHByaW9yaXR5ID0gLTENCglBIDo6PSA8bWZlbmNlZD4gRSA8L21mZW5jZWQ%IHsgXCggJDIgXCkgfQ0KDQojVmVjdG9ycyBhbmQgaW50ZXJ2YWxzDQpBIDo6PSA8bWZlbmNlZCBjbG9zZSBcPSAiIFBDICIgb3BlbiBcPSAiIFBPICIgPiA8bXJvdz4gRSA8L21yb3c%IDwvbWZlbmNlZD4geyAkMTAgJDE0ICQ1IH0NCmF0dHJpYnV0ZXMgcHJpb3JpdHkgPSAxIHsNCglBIDo6PSA8bWZlbmNlZCBvcGVuIFw9ICIgUE8gIiA%IDxtcm93PiBFIDwvbXJvdz4gPC9tZmVuY2VkPiB7ICQ1ICQ5IFwpIH0NCglBIDo6PSA8bWZlbmNlZCBjbG9zZSBcPSAiIFBDICIgPiA8bXJvdz4gRSA8L21yb3c%IDwvbWZlbmNlZD4geyBcKCAkOSAkNSB9DQp9DQphdHRyaWJ1dGVzIGludmVyc2VfcHJpb3JpdHkgPSAtMQ0KCUEgOjo9IDxtbz4gUE8gPC9tbz4gRSA8bW8%IFBDIDwvbW8%IHsgJDIgJDQgJDYgfQ0KDQojUGFyZW50aGVzZXMgYXJvdW5kIGEgc2luZ2xlIHN5bWJvbA0KQSA6Oj0gPG1mZW5jZWQ%IE5VTSA8L21mZW5jZWQ%IHsgXCggJDIgXCkgfQ0KQSA6Oj0gPG1mZW5jZWQ%IFZBUiA8L21mZW5jZWQ%IHsgXCggJDIgXCkgfQ0KYXR0cmlidXRlcyBwcmlvcml0eSA9IC0xIHsNCglBIDo6PSA8bWZlbmNlZCBjbG9zZSBcPSAiIFBDICIgb3BlbiBcPSAiIFBPICIgPiBOVU0gPC9tZmVuY2VkPiB7ICQxMCAkMTMgJDUgfQ0KCUEgOjo9IDxtZmVuY2VkIGNsb3NlIFw9ICIgUEMgIiBvcGVuIFw9ICIgUE8gIiA%IFZBUiA8L21mZW5jZWQ%IHsgJDEwICQxMyAkNSB9DQp9DQoJDQojQ29uY2F0ZW5hdGlvbiBvZiBleHByZXNzaW9ucw0KYXR0cmlidXRlcyByaWdodF9hc3NvY2lhdGl2ZSBwcmlvcml0eSA9IDENCglFIDo6PSBFIEUNCg0KIyBOdW1iZXJzDQpOVU0gOjo9IDxtbj4gaW50ZWdlciA8L21uPiB7ICQyIH0NCmF0dHJpYnV0ZXMgcmlnaHRfYXNzb2NpYXRpdmUNCglOVU0gOjo9IE5VTSA8bW8%IFNFUCA8L21vPiBOVU0geyAkMSAkMyAkNSB9DQoNCiNEZWNpbWFsIHNlcGFyYXRvcnMNClNFUCA6Oj0gLg0KYXR0cmlidXRlcyBwcmlvcml0eSA9IDENCglTRVAgOjo9ICwNClNFUCA6Oj0gJw0KDQojIElkZW50aWZpZXJzDQpWQVIgOjo9IDxtaT4gdmFyaWFibGUgPC9taT4geyAkMiB9DQphdHRyaWJ1dGVzIGludmVyc2VfcHJpb3JpdHkgPSAtMTANCglWQVIgOjo9IDxtaSBtYXRodmFyaWFudCBcPSAiIG5vcm1hbCAiID4gdmFyaWFibGUgPC9taT4geyAkOCB9DQojU3BlY2lhbCBpZGVudGlmaWVycyAocGksIGUsIGksIHJlYWwgbnVtYmVycy4uLikNCmF0dHJpYnV0ZXMgcHJpb3JpdHkgPSAyDQoJVkFSIDo6PSA8bWkgbWF0aHZhcmlhbnQgXD0gIiBub3JtYWwgIiA%IFZBUkNIQVIgPC9taT4geyAkOCB9DQoNClZBUkNIQVIgOjo9ICYjeDNjMDsgeyBwaSB9DQpWQVJDSEFSIDo6PSBlDQpWQVJDSEFSIDo6PSBpDQpWQVJDSEFSIDo6PSAmI3gyMTFkOyB7IFIgfQ0KDQojRW5zdXJlIHRoYXQgZSBhbmQgaSBjYW4gYWxzbyBiZSBpZGVudGlmaWVycyBpbiBNYXRoTUwNCmF0dHJpYnV0ZXMgaW52ZXJzZV9wcmlvcml0eSA9IC0xDQp7DQoJVkFSIDo6PSA8bWk%IGUgPC9taT4geyBlIH0NCglWQVIgOjo9IDxtaT4gaSA8L21pPiB7IGkgfQ0KfQ0KDQpBIDo6PSBOVU0NCkEgOjo9IFZBUg0KQSA6Oj0gPG1yb3c%IEEgPC9tcm93PiB7ICQyIH0NCiNFbnN1cmUgdGhhdCBudW1iZXJzIHdpdGhpbiBhbiBtcm93IHN0YXkgdG9nZXRoZXIuIEV4YW1wbGU6IDxtYXRoPjxtc3VwPjxtbj4yPC9tbj48bXJvdz48bW4%MTwvbW4%PG1vPi48L21vPjxtbj4xPC9tbj48L21yb3c%PC9tc3VwPjwvbWF0aD4gLS0%IDJeKDEuMSkNCmF0dHJpYnV0ZXMgcHJpb3JpdHkgPSAxIGludmVyc2VfcHJpb3JpdHkgPSAtMQ0KCUEgOjo9IDxtcm93PiBOVU0gPC9tcm93PiB7IFwoICQyIFwpIH0NCmF0dHJpYnV0ZXMgcHJpb3JpdHkgPSAtMQ0KCUEgOjo9IDxtcm93PiBFIDwvbXJvdz4geyBcKCAkMiBcKSB9DQoNCkUgOjo9IEENCg0KDQojT3BlcmF0b3JzDQpFIDo6PSA8bW8%IEMgPC9tbz4geyAkMiB9DQphdHRyaWJ1dGVzIHByaW9yaXR5ID0gMg0Kew0KCUMgOjo9ICYjeGI3OyB7ICogfQ0KCUMgOjo9ICYjeDIyMWU7IHsgSW5mIH0NCglDIDo6PSAmI3gyMjJhOyB7IFUgfQkNCn0NCiNPdGhlciBwcm9kdWN0IHN5bWJvbHMNCmF0dHJpYnV0ZXMgcHJpb3JpdHkgPSAxDQp7DQoJQyA6Oj0gJiN4MjJjNTsgeyAqIH0NCglDIDo6PSAmI3gyMDYyOyB7ICogfQ0KCUMgOjo9ICYjeGQ3OyB7ICogfQ0KfQ0KQyA6Oj0gKw0KQyA6Oj0gLQ0KQyA6Oj0gKg0KQyA6Oj0gXD0NCkMgOjo9ICENCkMgOjo9IHwNCkMgOjo9ICwNCkMgOjo9ICcNCiNEaWZmZXJlbmNlIG9mIHNldHMNCmF0dHJpYnV0ZXMgaW52ZXJzZV9wcmlvcml0eSA9IC0xDQoJQyA6Oj0gXFwgeyAtIH0NCg0KUE8gOjo9IFx7DQpQQyA6Oj0gXH0NClBPIDo6PSBbDQpQQyA6Oj0gXQ0KUE8gOjo9ICZsdDsgeyA8IH0NClBDIDo6PSAmZ3Q7IHsgPiB9DQpQTyA6Oj0gXCgNClBDIDo6PSBcKQ0KDQojRXhwb25lbnRzIGFuZCBmcmFjdGlvbnMNCmF0dHJpYnV0ZXMgcHJpb3JpdHkgPSAyDQoJRSA6Oj0gPG1mcmFjPiBBIEEgPC9tZnJhYz4geyAkMiAvICQzIH0NCmF0dHJpYnV0ZXMgcmlnaHRfYXNzb2NpYXRpdmUgcHJpb3JpdHkgPSAyDQoJQSA6Oj0gPG1zdXA%IEEgQSA8L21zdXA%IHsgJDIgXiAkMyB9DQojU3BlY2lhbCBleHBvbmVudCB3aGVuIHRoZXJlIGFyZSBwYXJlbnRoZXNlcyBpbnZvbHZlZA0KYXR0cmlidXRlcyBpbnZlcnNlX3ByaW9yaXR5ID0gLTMNCglFIDo6PSA8bW8%IFBPIDwvbW8%IEUgPG1zdXA%IDxtbz4gUEMgPC9tbz4gQSA8L21zdXA%IHsgJDIgJDQgJDcgXiAkOSB9DQoNCmF0dHJpYnV0ZXMgcHJpb3JpdHkgPSAyIGludmVyc2VfcHJpb3JpdHkgPSAwDQp7DQoJQSA6Oj0gPG1yb290PiBBIEEgPC9tcm9vdD4geyAkMiBeICggMSAvICQzICkgfQ0KfQ0KDQojU3F1YXJlIHJvb3QNCmF0dHJpYnV0ZXMgcHJpb3JpdHkgPSA1DQoJQSA6Oj0gPG1zcXJ0PiBFIDwvbXNxcnQ%IHsgc3FydCBcKCAkMiBcKSB9DQoJDQojQWJzb2x1dGUgdmFsdWUNCmF0dHJpYnV0ZXMgcHJpb3JpdHkgPSA1DQoJQSA6Oj0gPG1mZW5jZWQgY2xvc2UgXD0gIiB8ICIgb3BlbiBcPSAiIHwgIiA%IDxtcm93PiBFIDwvbXJvdz4gPC9tZmVuY2VkPiB7IGFicyBcKCAkMTQgXCkgfQ0KQSA6Oj0gPG1mZW5jZWQgY2xvc2UgXD0gIiB8ICIgb3BlbiBcPSAiIHwgIiA%IEUgPC9tZmVuY2VkPiB7IGFicyBcKCAkMTMgXCkgfQ0KYXR0cmlidXRlcyBpbnZlcnNlX3ByaW9yaXR5ID0gLTENCglBIDo6PSA8bW8%IHwgPC9tbz4gRSA8bW8%IHwgPC9tbz4geyBhYnMgXCggJDQgXCkgfQ0KDQojU3BlY2lhbCBydWxlIGZvciBsb2dhcml0aG0gb2YgYXJiaXRyYXJ5IGJhc2UNCmF0dHJpYnV0ZXMgaW52ZXJzZV9wcmlvcml0eSA9IC01DQoJRSA6Oj0gPG1zdWI%IDxtaT4gbG9nIDwvbWk%IEEgPC9tc3ViPiBBIHsgXCggbG9nICQ3IFwpIC8gXCggbG9nICQ1IFwpIH0NCkEgOjo9IDxtaT4gbG9nIDwvbWk%IHsgJDIgfQ"}];
if(typeof document != "undefined") js.Lib.document = document;
if(typeof window != "undefined") {
	js.Lib.window = window;
	js.Lib.window.onerror = function(msg,url,line) {
		var f = js.Lib.onerror;
		if(f == null) return false;
		return f(msg,[url + ":" + line]);
	};
}
com.wiris.chartparsing.CategoryChooser.e1 = new EReg("^-?[0-9]+\\.[0-9]*(\\*10\\^(\\([\\+\\-]?[0-9]+\\)|[\\+\\-]?[0-9]+))?$","");
com.wiris.chartparsing.Chart2.OPTIMIZATION1 = true;
com.wiris.chartparsing.Chart2.DEFAULT_EDGE_LIMIT = 600000;
com.wiris.chartparsing.Constants.LOWER = 1;
com.wiris.chartparsing.Constants.GREATER = -1;
com.wiris.chartparsing.Constants.UNKNOWN = 0;
com.wiris.chartparsing.Constants.ACCEPT = 1;
com.wiris.chartparsing.Constants.IGNORE = -1;
com.wiris.chartparsing.Grammar.FIRST_TERMINAL_ID = 1073741824;
com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING = 0;
com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_ATTRIBUTES = 1;
com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_RESULT = 2;
com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_RHS = 3;
com.wiris.chartparsing.GrammarSequentialBuilder.STATE_PARSING_IMPORT = 4;
com.wiris.chartparsing.Logger.silent = true;
com.wiris.chartparsing.Logger.buffer = null;
com.wiris.chartparsing.Rule.staticProperties = new Hash();
com.wiris.chartparsing.TopDownParser2.DELAY_ADD = true;
com.wiris.chartparsing.TopDownParser2.CHECK_DURING = false;
com.wiris.chartparsing.TopDownParser2.CHECK_AT_END = false;
com.wiris.chartparsing.TopDownParser2.SORT_PENDING = false;
com.wiris.chartparsing.XMLConverter.BEGIN_ATTR = 0;
com.wiris.chartparsing.XMLConverter.EQUAL_SIGN = 1;
com.wiris.chartparsing.XMLConverter.OPEN_QUOTE = 2;
com.wiris.chartparsing.XMLConverter.ATTRIBUTE_VALUE = 3;
com.wiris.settings.PlatformSettings.IS_JAVA = false;
com.wiris.settings.PlatformSettings.IS_CSHARP = false;
com.wiris.settings.PlatformSettings.PARSE_XML_ENTITIES = true;
com.wiris.settings.PlatformSettings.UTF8_CONVERSION = false;
com.wiris.settings.PlatformSettings.IS_JAVASCRIPT = true;
com.wiris.settings.PlatformSettings.IS_FLASH = false;
com.wiris.system.LocalStorageCache.ITEMS_KEY = "_items";
com.wiris.tokens.SAXTokenizer.MATHML_NAMESPACE = "http://www.w3.org/1998/Math/MathML";
com.wiris.tokens.XMLToken.BEGIN_ELEMENT = 0;
com.wiris.tokens.XMLToken.END_ELEMENT = 1;
com.wiris.tokens.XMLToken.TEXT = 2;
com.wiris.tokens.XMLToken.EQUAL_SIGN = 3;
com.wiris.tokens.XMLToken.QUOTE = 8;
com.wiris.tokens.XMLToken.OPEN_QUOTE = com.wiris.tokens.XMLToken.QUOTE;
com.wiris.tokens.XMLToken.CLOSE_QUOTE = com.wiris.tokens.XMLToken.QUOTE;
com.wiris.tokens.XMLToken.BEGIN_TAG_ELEMENT = 6;
com.wiris.tokens.XMLToken.END_TAG_ELEMENT = 7;
com.wiris.util.xml.SAXParser.CHAR_HASH = 35;
com.wiris.util.xml.SAXParser.CHAR_AT = 64;
com.wiris.util.xml.SAXParser.CHAR_OPEN_BRACKET = 123;
com.wiris.util.xml.SAXParser.CHAR_CLOSE_BRACKET = 125;
com.wiris.util.xml.SAXParser.CHAR_LINE_FEED = 10;
com.wiris.util.xml.SAXParser.CHAR_CARRIAGE_RETURN = 13;
com.wiris.util.xml.SAXParser.CHAR_SPACE = 32;
com.wiris.util.xml.SAXParser.CHAR_TAB = 9;
com.wiris.util.xml.SAXParser.CHAR_BACKSLASH = 92;
com.wiris.util.xml.SAXParser.CHAR_DOUBLE_QUOT = 34;
com.wiris.util.xml.SAXParser.CHAR_DOT = 46;
com.wiris.util.xml.SAXParser.CHAR_LESS_THAN = 60;
com.wiris.util.xml.SAXParser.CHAR_GREATER_THAN = 62;
com.wiris.util.xml.SAXParser.CHAR_BAR = 47;
com.wiris.util.xml.SAXParser.CHAR_EXCLAMATION = 33;
com.wiris.util.xml.SAXParser.CHAR_INTERROGATION = 63;
com.wiris.util.xml.SAXParser.CHAR_QUOT = 39;
com.wiris.util.xml.SAXParser.CHAR_OPEN_SQUARE_BRACKET = 91;
com.wiris.util.xml.SAXParser.CHAR_HYPHEN = 45;
com.wiris.util.xml.SAXParser.CHAR_UNDERSCORE = 95;
com.wiris.util.xml.SAXParser.CHAR_COLON = 58;
com.wiris.util.xml.SAXParser.CHAR_X = 120;
com.wiris.util.xml.SAXParser.CHAR_AMPERSAND = 38;
com.wiris.util.xml.SAXParser.CHAR_SEMICOLON = 59;
com.wiris.util.xml.SAXParser.BEGIN = 0;
com.wiris.util.xml.SAXParser.BEGIN_NODE = 1;
com.wiris.util.xml.SAXParser.TAG_NAME = 2;
com.wiris.util.xml.SAXParser.ATTRIB = 3;
com.wiris.util.xml.SAXParser.BODY = 4;
com.wiris.util.xml.SAXParser.HEADER = 5;
com.wiris.util.xml.SAXParser.COMMENT = 6;
com.wiris.util.xml.SAXParser.IGNORE_SPACES = 7;
com.wiris.util.xml.SAXParser.CHILDS = 8;
com.wiris.util.xml.SAXParser.TAG_NAME_CLOSE = 9;
com.wiris.util.xml.SAXParser.CDATA = 10;
com.wiris.util.xml.SAXParser.MALFORMED_XML = "Error: Malformed xml file.";
com.wiris.util.xml.WCharacterBase.NEGATIVE_THIN_SPACE = 57344;
com.wiris.util.xml.WCharacterBase.ROOT = 61696;
com.wiris.util.xml.WCharacterBase.ROOT_VERTICAL = 61727;
com.wiris.util.xml.WCharacterBase.ROOT_NO_TAIL = 61728;
com.wiris.util.xml.WCharacterBase.ROOT_NO_TAIL_VERTICAL = 61759;
com.wiris.util.xml.WCharacterBase.ROOT_LEFT_TAIL = 61760;
com.wiris.util.xml.WCharacterBase.ROOT_VERTICAL_LINE = 61761;
com.wiris.util.xml.WCharacterBase.ROUND_BRACKET_LEFT = 40;
com.wiris.util.xml.WCharacterBase.ROUND_BRACKET_RIGHT = 41;
com.wiris.util.xml.WCharacterBase.COMMA = 44;
com.wiris.util.xml.WCharacterBase.FULL_STOP = 46;
com.wiris.util.xml.WCharacterBase.SQUARE_BRACKET_LEFT = 91;
com.wiris.util.xml.WCharacterBase.SQUARE_BRACKET_RIGHT = 93;
com.wiris.util.xml.WCharacterBase.CIRCUMFLEX_ACCENT = 94;
com.wiris.util.xml.WCharacterBase.LOW_LINE = 95;
com.wiris.util.xml.WCharacterBase.CURLY_BRACKET_LEFT = 123;
com.wiris.util.xml.WCharacterBase.VERTICAL_BAR = 124;
com.wiris.util.xml.WCharacterBase.CURLY_BRACKET_RIGHT = 125;
com.wiris.util.xml.WCharacterBase.TILDE = 126;
com.wiris.util.xml.WCharacterBase.MACRON = 175;
com.wiris.util.xml.WCharacterBase.COMBINING_LOW_LINE = 818;
com.wiris.util.xml.WCharacterBase.MODIFIER_LETTER_CIRCUMFLEX_ACCENT = 710;
com.wiris.util.xml.WCharacterBase.CARON = 711;
com.wiris.util.xml.WCharacterBase.EN_QUAD = 8192;
com.wiris.util.xml.WCharacterBase.EM_QUAD = 8193;
com.wiris.util.xml.WCharacterBase.EN_SPACE = 8194;
com.wiris.util.xml.WCharacterBase.EM_SPACE = 8195;
com.wiris.util.xml.WCharacterBase.THICK_SPACE = 8196;
com.wiris.util.xml.WCharacterBase.MID_SPACE = 8197;
com.wiris.util.xml.WCharacterBase.SIX_PER_EM_SPACE = 8198;
com.wiris.util.xml.WCharacterBase.FIGIRE_SPACE = 8199;
com.wiris.util.xml.WCharacterBase.PUNCTUATION_SPACE = 8200;
com.wiris.util.xml.WCharacterBase.THIN_SPACE = 8201;
com.wiris.util.xml.WCharacterBase.HAIR_SPACE = 8202;
com.wiris.util.xml.WCharacterBase.ZERO_WIDTH_SPACE = 8203;
com.wiris.util.xml.WCharacterBase.ZERO_WIDTH_NON_JOINER = 8204;
com.wiris.util.xml.WCharacterBase.ZERO_WIDTH_JOINER = 8205;
com.wiris.util.xml.WCharacterBase.DOUBLE_VERTICAL_BAR = 8214;
com.wiris.util.xml.WCharacterBase.DOUBLE_HORIZONTAL_BAR = 9552;
com.wiris.util.xml.WCharacterBase.NARROW_NO_BREAK_SPACE = 8239;
com.wiris.util.xml.WCharacterBase.MEDIUM_MATHEMATICAL_SPACE = 8287;
com.wiris.util.xml.WCharacterBase.WORD_JOINER = 8288;
com.wiris.util.xml.WCharacterBase.PLANCKOVER2PI = 8463;
com.wiris.util.xml.WCharacterBase.LEFTWARDS_ARROW = 8592;
com.wiris.util.xml.WCharacterBase.UPWARDS_ARROW = 8593;
com.wiris.util.xml.WCharacterBase.RIGHTWARDS_ARROW = 8594;
com.wiris.util.xml.WCharacterBase.DOWNWARDS_ARROW = 8595;
com.wiris.util.xml.WCharacterBase.LEFTRIGHT_ARROW = 8596;
com.wiris.util.xml.WCharacterBase.UP_DOWN_ARROW = 8597;
com.wiris.util.xml.WCharacterBase.LEFTWARDS_ARROW_FROM_BAR = 8612;
com.wiris.util.xml.WCharacterBase.RIGHTWARDS_ARROW_FROM_BAR = 8614;
com.wiris.util.xml.WCharacterBase.LEFTWARDS_ARROW_WITH_HOOK = 8617;
com.wiris.util.xml.WCharacterBase.RIGHTWARDS_ARROW_WITH_HOOK = 8618;
com.wiris.util.xml.WCharacterBase.LEFTWARDS_HARPOON_WITH_BARB_UPWARDS = 8636;
com.wiris.util.xml.WCharacterBase.RIGHTWARDS_HARPOON_WITH_BARB_UPWARDS = 8640;
com.wiris.util.xml.WCharacterBase.LEFTWARDS_DOUBLE_ARROW = 8656;
com.wiris.util.xml.WCharacterBase.RIGHTWARDS_DOUBLE_ARROW = 8658;
com.wiris.util.xml.WCharacterBase.LEFT_RIGHT_DOUBLE_ARROW = 8660;
com.wiris.util.xml.WCharacterBase.LEFTWARDS_ARROW_OVER_RIGHTWARDS_ARROW = 8646;
com.wiris.util.xml.WCharacterBase.RIGHTWARDS_ARROW_OVER_LEFTWARDS_ARROW = 8644;
com.wiris.util.xml.WCharacterBase.LEFTWARDS_HARPOON_OVER_RIGHTWARDS_HARPOON = 8651;
com.wiris.util.xml.WCharacterBase.RIGHTWARDS_HARPOON_OVER_LEFTWARDS_HARPOON = 8652;
com.wiris.util.xml.WCharacterBase.RIGHTWARDS_ARROW_ABOVE_SHORT_LEFTWARDS_ARROW = 10562;
com.wiris.util.xml.WCharacterBase.SHORT_RIGHTWARDS_ARROW_ABOVE_LEFTWARDS_ARROW = 10564;
com.wiris.util.xml.WCharacterBase.LONG_RIGHTWARDS_ARROW = 10230;
com.wiris.util.xml.WCharacterBase.LONG_LEFTWARDS_ARROW = 10229;
com.wiris.util.xml.WCharacterBase.LONG_LEFT_RIGHT_ARROW = 10231;
com.wiris.util.xml.WCharacterBase.LONG_LEFTWARDS_DOUBLE_ARROW = 10232;
com.wiris.util.xml.WCharacterBase.LONG_RIGHTWARDS_DOUBLE_ARROW = 10233;
com.wiris.util.xml.WCharacterBase.LONG_LEFT_RIGHT_DOUBLE_ARROW = 10234;
com.wiris.util.xml.WCharacterBase.TILDE_OPERATOR = 8764;
com.wiris.util.xml.WCharacterBase.LEFT_CEILING = 8968;
com.wiris.util.xml.WCharacterBase.RIGHT_CEILING = 8969;
com.wiris.util.xml.WCharacterBase.LEFT_FLOOR = 8970;
com.wiris.util.xml.WCharacterBase.RIGHT_FLOOR = 8971;
com.wiris.util.xml.WCharacterBase.TOP_PARENTHESIS = 9180;
com.wiris.util.xml.WCharacterBase.BOTTOM_PARENTHESIS = 9181;
com.wiris.util.xml.WCharacterBase.TOP_SQUARE_BRACKET = 9140;
com.wiris.util.xml.WCharacterBase.BOTTOM_SQUARE_BRACKET = 9141;
com.wiris.util.xml.WCharacterBase.TOP_CURLY_BRACKET = 9182;
com.wiris.util.xml.WCharacterBase.BOTTOM_CURLY_BRACKET = 9183;
com.wiris.util.xml.WCharacterBase.MATHEMATICAL_LEFT_ANGLE_BRACKET = 10216;
com.wiris.util.xml.WCharacterBase.MATHEMATICAL_RIGHT_ANGLE_BRACKET = 10217;
com.wiris.util.xml.WCharacterBase.DOUBLE_STRUCK_ITALIC_CAPITAL_D = 8517;
com.wiris.util.xml.WCharacterBase.DOUBLE_STRUCK_ITALIC_SMALL_D = 8518;
com.wiris.util.xml.WCharacterBase.DOUBLE_STRUCK_ITALIC_SMALL_E = 8519;
com.wiris.util.xml.WCharacterBase.DOUBLE_STRUCK_ITALIC_SMALL_I = 8520;
com.wiris.util.xml.WCharacterBase.EPSILON = 949;
com.wiris.util.xml.WCharacterBase.VAREPSILON = 1013;
com.wiris.util.xml.WCharacterBase.DIGIT_ZERO = 48;
com.wiris.util.xml.WCharacterBase.DIGIT_NINE = 57;
com.wiris.util.xml.WCharacterBase.LATIN_CAPITAL_LETTER_A = 65;
com.wiris.util.xml.WCharacterBase.LATIN_CAPITAL_LETTER_Z = 90;
com.wiris.util.xml.WCharacterBase.LATIN_SMALL_LETTER_A = 97;
com.wiris.util.xml.WCharacterBase.LATIN_SMALL_LETTER_Z = 122;
com.wiris.util.xml.WCharacterBase.MATHEMATICAL_SCRIPT_CAPITAL_A = 119964;
com.wiris.util.xml.WCharacterBase.MATHEMATICAL_SCRIPT_SMALL_A = 119990;
com.wiris.util.xml.WCharacterBase.MATHEMATICAL_FRAKTUR_CAPITAL_A = 120068;
com.wiris.util.xml.WCharacterBase.MATHEMATICAL_FRAKTUR_SMALL_A = 120094;
com.wiris.util.xml.WCharacterBase.MATHEMATICAL_DOUBLE_STRUCK_CAPITAL_A = 120120;
com.wiris.util.xml.WCharacterBase.MATHEMATICAL_DOUBLE_STRUCK_SMALL_A = 120146;
com.wiris.util.xml.WCharacterBase.MATHEMATICAL_DOUBLE_STRUCK_DIGIT_ZERO = 120792;
com.wiris.util.xml.WCharacterBase.binaryOps = [43,45,47,177,183,215,247,8226,8722,8723,8724,8726,8727,8728,8743,8744,8745,8746,8760,8768,8846,8851,8852,8853,8854,8855,8856,8857,8858,8859,8861,8862,8863,8864,8865,8890,8891,8900,8901,8902,8903,8905,8906,8907,8908,8910,8911,8914,8915,8966,9021,9675,10678,10789,10794,10797,10798,10799,10804,10805,10812,10815,10835,10836,10837,10838,10846,10847,10851];
com.wiris.util.xml.WCharacterBase.relations = [60,61,62,8592,8593,8594,8595,8596,8597,8598,8599,8600,8601,8602,8603,8604,8605,8606,8608,8610,8611,8614,8617,8618,8619,8620,8621,8622,8624,8625,8627,8630,8631,8636,8637,8638,8639,8640,8641,8642,8643,8644,8645,8646,8647,8648,8649,8650,8651,8652,8653,8654,8655,8656,8657,8658,8659,8660,8661,8666,8667,8669,8693,8712,8713,8715,8716,8733,8739,8740,8741,8742,8764,8765,8769,8770,8771,8772,8773,8774,8775,8776,8777,8778,8779,8781,8782,8783,8784,8785,8786,8787,8788,8789,8790,8791,8793,8794,8795,8796,8799,8800,8801,8802,8804,8805,8806,8807,8808,8809,8810,8811,8812,8814,8815,8816,8817,8818,8819,8820,8821,8822,8823,8824,8825,8826,8827,8828,8829,8830,8831,8832,8833,8834,8835,8836,8837,8838,8839,8840,8841,8842,8843,8847,8848,8849,8850,8866,8867,8869,8871,8872,8873,8874,8875,8876,8877,8878,8879,8882,8883,8884,8885,8886,8887,8888,8904,8909,8912,8913,8918,8919,8920,8921,8922,8923,8926,8927,8930,8931,8934,8935,8936,8937,8938,8939,8940,8941,8994,8995,9123,10229,10230,10231,10232,10233,10234,10236,10239,10501,10514,10515,10531,10532,10533,10534,10535,10536,10537,10538,10547,10550,10551,10560,10561,10562,10564,10567,10574,10575,10576,10577,10578,10579,10580,10581,10582,10583,10584,10585,10586,10587,10588,10589,10590,10591,10592,10593,10606,10607,10608,10620,10621,10869,10877,10878,10885,10886,10887,10888,10889,10890,10891,10892,10901,10902,10909,10910,10913,10914,10927,10928,10933,10934,10935,10936,10937,10938,10949,10950,10955,10956,10987,11005];
com.wiris.util.xml.WCharacterBase.largeOps = [8719,8720,8721,8896,8897,8898,8899,10756,10757,10758,10759,10760];
com.wiris.util.xml.WCharacterBase.veryLargeOps = [8747,8748,8749,8750,8751,8752,8753,8754,8755,10763,10764,10765,10766,10767,10768,10774,10775,10776,10777,10778,10779,10780];
com.wiris.util.xml.WCharacterBase.tallLetters = [98,100,102,104,105,106,107,108,116,946,948,950,952,955,958];
com.wiris.util.xml.WCharacterBase.longLetters = [103,106,112,113,121,946,947,950,951,956,958,961,962,966,967,968];
com.wiris.util.xml.WCharacterBase.negations = [61,8800,8801,8802,8764,8769,8712,8713,8715,8716,8834,8836,8835,8837,8838,8840,8839,8841,62,8815,60,8814,8805,8817,8804,8816,10878,8817,10877,8816,8776,8777,8771,8772,8773,8775,8849,8930,8850,8931,8707,8708,8741,8742];
com.wiris.util.xml.WCharacterBase.mirrorDictionary = [40,41,41,40,60,62,62,60,91,93,93,91,123,125,125,123,171,187,187,171,3898,3899,3899,3898,3900,3901,3901,3900,5787,5788,5788,5787,8249,8250,8250,8249,8261,8262,8262,8261,8317,8318,8318,8317,8333,8334,8334,8333,8712,8715,8713,8716,8714,8717,8715,8712,8716,8713,8717,8714,8725,10741,8764,8765,8765,8764,8771,8909,8786,8787,8787,8786,8788,8789,8789,8788,8804,8805,8805,8804,8806,8807,8807,8806,8808,8809,8809,8808,8810,8811,8811,8810,8814,8815,8815,8814,8816,8817,8817,8816,8818,8819,8819,8818,8820,8821,8821,8820,8822,8823,8823,8822,8824,8825,8825,8824,8826,8827,8827,8826,8828,8829,8829,8828,8830,8831,8831,8830,8832,8833,8833,8832,8834,8835,8835,8834,8836,8837,8837,8836,8838,8839,8839,8838,8840,8841,8841,8840,8842,8843,8843,8842,8847,8848,8848,8847,8849,8850,8850,8849,8856,10680,8866,8867,8867,8866,8870,10974,8872,10980,8873,10979,8875,10981,8880,8881,8881,8880,8882,8883,8883,8882,8884,8885,8885,8884,8886,8887,8887,8886,8905,8906,8906,8905,8907,8908,8908,8907,8909,8771,8912,8913,8913,8912,8918,8919,8919,8918,8920,8921,8921,8920,8922,8923,8923,8922,8924,8925,8925,8924,8926,8927,8927,8926,8928,8929,8929,8928,8930,8931,8931,8930,8932,8933,8933,8932,8934,8935,8935,8934,8936,8937,8937,8936,8938,8939,8939,8938,8940,8941,8941,8940,8944,8945,8945,8944,8946,8954,8947,8955,8948,8956,8950,8957,8951,8958,8954,8946,8955,8947,8956,8948,8957,8950,8958,8951,8968,8969,8969,8968,8970,8971,8971,8970,9001,9002,9002,9001,10088,10089,10089,10088,10090,10091,10091,10090,10092,10093,10093,10092,10094,10095,10095,10094,10096,10097,10097,10096,10098,10099,10099,10098,10100,10101,10101,10100,10179,10180,10180,10179,10181,10182,10182,10181,10184,10185,10185,10184,10187,10189,10189,10187,10197,10198,10198,10197,10205,10206,10206,10205,10210,10211,10211,10210,10212,10213,10213,10212,10214,10215,10215,10214,10216,10217,10217,10216,10218,10219,10219,10218,10220,10221,10221,10220,10222,10223,10223,10222,10627,10628,10628,10627,10629,10630,10630,10629,10631,10632,10632,10631,10633,10634,10634,10633,10635,10636,10636,10635,10637,10640,10638,10639,10639,10638,10640,10637,10641,10642,10642,10641,10643,10644,10644,10643,10645,10646,10646,10645,10647,10648,10648,10647,10680,8856,10688,10689,10689,10688,10692,10693,10693,10692,10703,10704,10704,10703,10705,10706,10706,10705,10708,10709,10709,10708,10712,10713,10713,10712,10714,10715,10715,10714,10741,8725,10744,10745,10745,10744,10748,10749,10749,10748,10795,10796,10796,10795,10797,10798,10798,10797,10804,10805,10805,10804,10812,10813,10813,10812,10852,10853,10853,10852,10873,10874,10874,10873,10877,10878,10878,10877,10879,10880,10880,10879,10881,10882,10882,10881,10883,10884,10884,10883,10891,10892,10892,10891,10897,10898,10898,10897,10899,10900,10900,10899,10901,10902,10902,10901,10903,10904,10904,10903,10905,10906,10906,10905,10907,10908,10908,10907,10913,10914,10914,10913,10918,10919,10919,10918,10920,10921,10921,10920,10922,10923,10923,10922,10924,10925,10925,10924,10927,10928,10928,10927,10931,10932,10932,10931,10939,10940,10940,10939,10941,10942,10942,10941,10943,10944,10944,10943,10945,10946,10946,10945,10947,10948,10948,10947,10949,10950,10950,10949,10957,10958,10958,10957,10959,10960,10960,10959,10961,10962,10962,10961,10963,10964,10964,10963,10965,10966,10966,10965,10974,8870,10979,8873,10980,8872,10981,8875,10988,10989,10989,10988,10999,11000,11000,10999,11001,11002,11002,11001,11778,11779,11779,11778,11780,11781,11781,11780,11785,11786,11786,11785,11788,11789,11789,11788,11804,11805,11805,11804,11808,11809,11809,11808,11810,11811,11811,11810,11812,11813,11813,11812,11814,11815,11815,11814,11816,11817,11817,11816,12296,12297,12297,12296,12298,12299,12299,12298,12300,12301,12301,12300,12302,12303,12303,12302,12304,12305,12305,12304,12308,12309,12309,12308,12310,12311,12311,12310,12312,12313,12313,12312,12314,12315,12315,12314,65113,65114,65114,65113,65115,65116,65116,65115,65117,65118,65118,65117,65124,65125,65125,65124,65288,65289,65289,65288,65308,65310,65310,65308,65339,65341,65341,65339,65371,65373,65373,65371,65375,65376,65376,65375,65378,65379,65379,65378,9115,9118,9116,9119,9117,9120,9118,9115,9119,9116,9120,9117,9121,9124,9122,9125,9123,9126,9124,9121,9125,9122,9126,9123,9127,9131,9130,9134,9129,9133,9131,9127,9134,9130,9133,9129,9128,9132,9132,9128];
com.wiris.util.xml.WCharacterBase.subSuperScriptDictionary = [178,50,179,51,185,49,8304,48,8305,105,8308,52,8309,53,8310,54,8311,55,8312,56,8313,57,8314,43,8315,45,8316,61,8317,40,8318,41,8319,110,8320,48,8321,49,8322,50,8323,51,8324,52,8325,53,8326,54,8327,55,8328,56,8329,57,8330,43,8331,45,8332,61,8333,40,8334,41,8336,97,8337,101,8338,111,8339,120,8340,601,8341,104,8342,107,8343,108,8344,109,8345,110,8346,112,8347,115,8348,116];
com.wiris.util.xml.WCharacterBase.accentsDictionary = null;
com.wiris.util.xml.WCharacterBase.horizontalLTRStretchyChars = [com.wiris.util.xml.WCharacterBase.LEFTWARDS_ARROW,com.wiris.util.xml.WCharacterBase.RIGHTWARDS_ARROW,com.wiris.util.xml.WCharacterBase.LEFTRIGHT_ARROW,com.wiris.util.xml.WCharacterBase.LEFTWARDS_ARROW_FROM_BAR,com.wiris.util.xml.WCharacterBase.RIGHTWARDS_ARROW_FROM_BAR,com.wiris.util.xml.WCharacterBase.LEFTWARDS_ARROW_WITH_HOOK,com.wiris.util.xml.WCharacterBase.RIGHTWARDS_ARROW_WITH_HOOK,com.wiris.util.xml.WCharacterBase.LEFTWARDS_HARPOON_WITH_BARB_UPWARDS,com.wiris.util.xml.WCharacterBase.RIGHTWARDS_HARPOON_WITH_BARB_UPWARDS,com.wiris.util.xml.WCharacterBase.LEFTWARDS_DOUBLE_ARROW,com.wiris.util.xml.WCharacterBase.RIGHTWARDS_DOUBLE_ARROW,com.wiris.util.xml.WCharacterBase.TOP_CURLY_BRACKET,com.wiris.util.xml.WCharacterBase.BOTTOM_CURLY_BRACKET,com.wiris.util.xml.WCharacterBase.TOP_PARENTHESIS,com.wiris.util.xml.WCharacterBase.BOTTOM_PARENTHESIS,com.wiris.util.xml.WCharacterBase.TOP_SQUARE_BRACKET,com.wiris.util.xml.WCharacterBase.BOTTOM_SQUARE_BRACKET,com.wiris.util.xml.WCharacterBase.LEFTWARDS_ARROW_OVER_RIGHTWARDS_ARROW,com.wiris.util.xml.WCharacterBase.RIGHTWARDS_ARROW_OVER_LEFTWARDS_ARROW,com.wiris.util.xml.WCharacterBase.LEFTWARDS_HARPOON_OVER_RIGHTWARDS_HARPOON,com.wiris.util.xml.WCharacterBase.RIGHTWARDS_HARPOON_OVER_LEFTWARDS_HARPOON];
com.wiris.util.xml.WCharacterBase.tallAccents = [com.wiris.util.xml.WCharacterBase.LEFTWARDS_ARROW_OVER_RIGHTWARDS_ARROW,com.wiris.util.xml.WCharacterBase.RIGHTWARDS_ARROW_OVER_LEFTWARDS_ARROW,com.wiris.util.xml.WCharacterBase.LEFTWARDS_HARPOON_OVER_RIGHTWARDS_HARPOON,com.wiris.util.xml.WCharacterBase.RIGHTWARDS_HARPOON_OVER_LEFTWARDS_HARPOON];
com.wiris.util.xml.WCharacterBase.PUNCTUATION_CATEGORY = "P";
com.wiris.util.xml.WCharacterBase.OTHER_CATEGORY = "C";
com.wiris.util.xml.WCharacterBase.LETTER_CATEGORY = "L";
com.wiris.util.xml.WCharacterBase.MARK_CATEGORY = "M";
com.wiris.util.xml.WCharacterBase.NUMBER_CATEGORY = "N";
com.wiris.util.xml.WCharacterBase.SYMBOL_CATEGORY = "S";
com.wiris.util.xml.WCharacterBase.PHONETICAL_CATEGORY = "F";
com.wiris.util.xml.WCharacterBase.UNICODES_WITH_CATEGORIES = "@P:21-23,25-2A,2C-2F,3A-3B,3F-40,5B-5D,5F,7B,7D,A1,A7,AB,B6-B7,BB,BF,37E,387,55A-55F,589-58A,5BE,5C0,5C3,5C6,5F3-5F4,609-60A,60C-60D,61B,61E-61F,66A-66D,6D4,E4F,E5A-E5B,2010-2022,2025-2026,2030-203E,2040,2043,2047,204E-2051,2057,205E,2308-230B,2329-232A,2772-2773,27C5-27C6,27E6-27EF,2983-2998,29D8-29DB,29FC-29FD,2E17,3030,FD3E-FD3F@C:AD,600-603,6DD,200B-200F,202A-202E,206A-206F@L:41-5A,61-7A,AA,B5,BA,C0-D6,D8-F6,F8-2C1,2C6-2D1,2E0-2E4,2EC,2EE,370-374,376-377,37A-37D,386,388-38A,38C,38E-3A1,3A3-3F5,3F7-481,48A-527,531-556,559,561-587,5D0-5EA,5F0-5F2,620-64A,66E-66F,671-6D3,6D5,6E5-6E6,6EE-6EF,6FA-6FC,6FF,750-77F,E01-E30,E32-E33,E40-E46,1D00-1DBF,1E00-1F15,1F18-1F1D,1F20-1F45,1F48-1F4D,1F50-1F57,1F59,1F5B,1F5D,1F5F-1F7D,1F80-1FB4,1FB6-1FBC,1FBE,1FC2-1FC4,1FC6-1FCC,1FD0-1FD3,1FD6-1FDB,1FE0-1FEC,1FF2-1FF4,1FF6-1FFC,207F,2090-2094,2102,2107,210A-2113,2115,2119-211D,2124,2126,2128,212B-212D,212F-2138,213C-213F,2145-2149,214E,2184,2C60-2C7F,306E,A717-A71F,A727,A788,A78B-A78C,A792,FB00-FB04,FB13-FB17,FB1D,FB1F-FB28,FB2A-FB36,FB38-FB3C,FB3E,FB40-FB41,FB43-FB44,FB46-FBB1,FBD3-FBE9,FBFC-FBFF,FC5E-FC63,FC6A,FC6D,FC70,FC73,FC91,FC94,FDF2,FE70-FE74,FE76-FEFC,1D400-1D454,1D456-1D49C,1D49E-1D49F,1D4A2,1D4A5-1D4A6,1D4A9-1D4AC,1D4AE-1D4B9,1D4BB,1D4BD-1D4C3,1D4C5-1D505,1D507-1D50A,1D50D-1D514,1D516-1D51C,1D51E-1D539,1D53B-1D53E,1D540-1D544,1D546,1D54A-1D550,1D552-1D6A5,1D6A8-1D6C0,1D6C2-1D6DA,1D6DC-1D6FA,1D6FC-1D714,1D716-1D734,1D736-1D74E,1D750-1D76E,1D770-1D788,1D78A-1D7A8,1D7AA-1D7C2,1D7C4-1D7C9@M:300-36F,483-489,591-5BD,5BF,5C1-5C2,5C4-5C5,5C7,610-61A,64B-65F,670,6D6-6DC,6DF-6E4,6E7-6E8,6EA-6ED,E31,E34-E3A,E47-E4E,1DC0-1DC1,1DC3,1DCA,1DFE-1DFF,20D0-20D2,20D6-20D7,20DB-20DF,20E1,20E4-20F0,FB1E,FE20-FE23@N:30-39,B2-B3,B9,BC-BE,660-669,6F0-6F9,E50-E59,2070,2074-2079,2080-2089,2153-215E,2460-2468,24EA,2780-2793,1D7CE-1D7FF@S:24,2B,3C-3E,5E,60,7C,7E,A2-A6,A8-A9,AC,AE-B1,B4,B8,D7,F7,2C2-2C5,2D2-2DF,2E5-2EB,2ED,2EF-2FF,375,384-385,3F6,482,58F,606-608,60B,60E-60F,6DE,6E9,6FD-6FE,E3F,1FBD,1FBF-1FC1,1FCD-1FCF,1FDD-1FDF,1FED-1FEF,1FFD-1FFE,2044,2052,20A0-20BA,2105,2116-2118,211E,2120,2122,2125,2127,2129,212E,2140-2144,214A-214B,214D,2190-21EA,21F4-2300,2302,2305-2306,230C-2313,2315-231A,231C-2323,232C-232E,2332,2336,233D,233F-2340,2353,2370,237C,2393-2394,23AF,23B4-23B6,23CE,23D0,23DC-23E7,2423,24B6-24E9,2500,2502,2506,2508,250A,250C,2510,2514,2518,251C,2524,252C,2534,253C,2550-256C,2571-2572,2580,2584,2588,258C,2590-2593,25A0-25FF,2605-2606,2609,260C,260E,2612,2621,2639-2644,2646-2649,2660-2667,2669-266B,266D-266F,267E,2680-2689,26A0,26A5,26AA-26AC,26B2,26E2,2702,2709,2713,2720,272A,2736,273D,279B,27C0-27C4,27C7-27C9,27CB-27CD,27D0-27E5,27F0-27FF,2900-2982,2999-29D7,29DC-29FB,29FE-2AFF,2B12-2B4C,2B50-2B54,3012,A720-A721,A789-A78A,FB29,FBB2-FBC1,FDFC,FFFC-FFFD,1D6C1,1D6DB,1D6FB,1D715,1D735,1D74F,1D76F,1D789,1D7A9,1D7C3@F:70,62,74,64,288,256,63,25F,6B,261,71,262,294,6D,271,6E,273,272,14B,274,72,280,27E,27D,278,3B2,66,76,3B8,F0,73,7A,283,292,282,290,E7,29D,78,263,3C7,281,127,295,68,266,26C,26E,28B,279,27B,6A,270,6C,26D,28E,29F,1A5,253,1AD,257,188,284,199,260,2A0,29B,28D,77,265,29C,2A1-2A2,267,298,1C0,1C3,1C2,1C1,27A,255,291,2C71,287,297,296,286,293,27C,2E2,1AB,26B,67,2A6,2A3,2A7,2A4,2A8,2A5,1DBF,1D4A,1D91,1BB,29E,2E3,19E,19B,3BB,17E,161,1F0,10D,69,65,25B,61,251,254,6F,75,79,F8,153,276,252,28C,264,26F,268,289,26A,28F,28A,259,275,250,E6,25C,25A,131,25E,29A,258,277,269,2BC,325,30A,32C,2B0,324,330,33C,32A,33A-33B,339,31C,31F-320,308,33D,318-319,2DE,2B7,2B2,2E0,2E4,303,207F,2E1,31A,334,31D,2D4,31E,2D5,329,32F,361,35C,322,2F9,2C,2BB,307,2D7,2D6,2B8,323,321,32B,2C8,2CC,2D0-2D1,306,2E,7C,2016,203F,2197-2198,30B,301,304,300,30F,A71B-A71C,2E5-2E9,30C,302,1DC4-1DC5,1DC8,311,2C7,2C6,316,2CE,317,2CF,2AD,2A9-2AB,274D,2A,56,46,57,43,4C,4A,152,398,1D191,1D18F,31-33,346,34D,34A-34C,348-349,5C,34E,2193,2191,2EC,1DB9,362,347,2B6,2ED,2F1-2F2,2F7,41-42,44-45,47-49,4B,4D-55,58-5B,5D,2F,28-29,7B,7D@";
com.wiris.util.xml.WCharacterBase.invisible = [8289,8290,8291];
com.wiris.util.xml.WCharacterBase.horizontalOperators = [175,818,8592,8594,8596,8612,8614,8617,8618,8636,8637,8640,8641,8644,8646,8651,8652,8656,8658,8660,8764,9140,9141,9180,9181,9182,9183,9552,10562,10564,10602,10605];
com.wiris.util.xml.WCharacterBase.latinLetters = "@0065@0066@0067@0068@0069@0070@0071@0072@0073@0074@0075@0076@0077@0078@0079@0080@0081@0082@0083@0084@0085@0086@0087@0088@0089@0090" + "@0097@0098@0099@0100@0101@0102@0103@0104@0105@0106@0107@0108@0109@0110@0111@0112@0113@0114@0115@0116@0117@0118@0119@0120@0121@0122@";
com.wiris.util.xml.WCharacterBase.greekLetters = "@0913@0914@0935@0916@0917@0934@0915@0919@0921@0977@0922@0923@0924@0925@0927@0928@0920@0929@0931@0932@0933@0962@0937@0926@0936@0918" + "@0945@0946@0967@0948@0949@0966@0947@0951@0953@0966@0954@0955@0956@0957@0959@0960@0952@0961@0963@0964@0965@0982@0969@0958@0968@0950@";
com.wiris.util.xml.WEntities.s1 = "boxDL@02557@boxDl@02556@boxdL@02555@boxdl@02510@boxDR@02554@boxDr@02553@boxdR@02552@boxdr@0250C@boxH@02550@boxh@02500@boxHD@02566@boxHd@02564@boxhD@02565@boxhd@0252C@boxHU@02569@boxHu@02567@boxhU@02568@boxhu@02534@boxUL@0255D@boxUl@0255C@boxuL@0255B@boxul@02518@boxUR@0255A@boxUr@02559@boxuR@02558@boxur@02514@boxV@02551@boxv@02502@boxVH@0256C@boxVh@0256B@boxvH@0256A@boxvh@0253C@boxVL@02563@boxVl@02562@boxvL@02561@boxvl@02524@boxVR@02560@boxVr@0255F@boxvR@0255E@boxvr@0251C@Acy@00410@acy@00430@Bcy@00411@bcy@00431@CHcy@00427@chcy@00447@Dcy@00414@dcy@00434@Ecy@0042D@ecy@0044D@Fcy@00424@fcy@00444@Gcy@00413@gcy@00433@HARDcy@0042A@hardcy@0044A@Icy@00418@icy@00438@IEcy@00415@iecy@00435@IOcy@00401@iocy@00451@Jcy@00419@jcy@00439@Kcy@0041A@kcy@0043A@KHcy@00425@khcy@00445@Lcy@0041B@lcy@0043B@Mcy@0041C@mcy@0043C@Ncy@0041D@ncy@0043D@numero@02116@Ocy@0041E@ocy@0043E@Pcy@0041F@pcy@0043F@Rcy@00420@rcy@00440@Scy@00421@scy@00441@SHCHcy@00429@shchcy@00449@SHcy@00428@shcy@00448@SOFTcy@0042C@softcy@0044C@Tcy@00422@tcy@00442@TScy@00426@tscy@00446@Ucy@00423@ucy@00443@Vcy@00412@vcy@00432@YAcy@0042F@yacy@0044F@Ycy@0042B@ycy@0044B@YUcy@0042E@yucy@0044E@Zcy@00417@zcy@00437@ZHcy@00416@zhcy@00436@DJcy@00402@djcy@00452@DScy@00405@dscy@00455@DZcy@0040F@dzcy@0045F@GJcy@00403@gjcy@00453@Iukcy@00406@iukcy@00456@Jsercy@00408@jsercy@00458@Jukcy@00404@jukcy@00454@KJcy@0040C@kjcy@0045C@LJcy@00409@ljcy@00459@NJcy@0040A@njcy@0045A@TSHcy@0040B@tshcy@0045B@Ubrcy@0040E@ubrcy@0045E@YIcy@00407@yicy@00457@acute@000B4@breve@002D8@caron@002C7@cedil@000B8@circ@002C6@dblac@002DD@die@000A8@dot@002D9@grave@00060@macr@000AF@ogon@002DB@ring@002DA@tilde@002DC@uml@000A8@Aacute@000C1@aacute@000E1@Acirc@000C2@acirc@000E2@AElig@000C6@aelig@000E6@Agrave@000C0@agrave@000E0@Aring@000C5@aring@000E5@Atilde@000C3@atilde@000E3@Auml@000C4@auml@000E4@Ccedil@000C7@ccedil@000E7@Eacute@000C9@eacute@000E9@Ecirc@000CA@ecirc@000EA@Egrave@000C8@egrave@000E8@ETH@000D0@eth@000F0@Euml@000CB@euml@000EB@Iacute@000CD@iacute@000ED@Icirc@000CE@icirc@000EE@Igrave@000CC@igrave@000EC@Iuml@000CF@iuml@000EF@Ntilde@000D1@ntilde@000F1@Oacute@000D3@oacute@000F3@Ocirc@000D4@ocirc@000F4@Ograve@000D2@ograve@000F2@Oslash@000D8@oslash@000F8@Otilde@000D5@otilde@000F5@Ouml@000D6@ouml@000F6@szlig@000DF@THORN@000DE@thorn@000FE@Uacute@000DA@uacute@000FA@Ucirc@000DB@ucirc@000FB@Ugrave@000D9@ugrave@000F9@Uuml@000DC@uuml@000FC@Yacute@000DD@yacute@000FD@yuml@000FF@Abreve@00102@abreve@00103@Amacr@00100@amacr@00101@Aogon@00104@aogon@00105@Cacute@00106@cacute@00107@Ccaron@0010C@ccaron@0010D@Ccirc@00108@ccirc@00109@Cdot@0010A@cdot@0010B@Dcaron@0010E@dcaron@0010F@Dstrok@00110@dstrok@00111@Ecaron@0011A@ecaron@0011B@Edot@00116@edot@00117@Emacr@00112@emacr@00113@ENG@0014A@eng@0014B@Eogon@00118@eogon@00119@gacute@001F5@Gbreve@0011E@gbreve@0011F@Gcedil@00122@Gcirc@0011C@gcirc@0011D@Gdot@00120@gdot@00121@Hcirc@00124@hcirc@00125@Hstrok@00126@hstrok@00127@Idot@00130@IJlig@00132@ijlig@00133@Imacr@0012A@imacr@0012B@inodot@00131@Iogon@0012E@iogon@0012F@Itilde@00128@itilde@00129@Jcirc@00134@jcirc@00135@Kcedil@00136@kcedil@00137@kgreen@00138@Lacute@00139@lacute@0013A@Lcaron@0013D@lcaron@0013E@Lcedil@0013B@lcedil@0013C@Lmidot@0013F@lmidot@00140@Lstrok@00141@lstrok@00142@Nacute@00143@nacute@00144@napos@00149@Ncaron@00147@ncaron@00148@Ncedil@00145@ncedil@00146@Odblac@00150@odblac@00151@OElig@00152@oelig@00153@Omacr@0014C@omacr@0014D@Racute@00154@racute@00155@Rcaron@00158@rcaron@00159@Rcedil@00156@rcedil@00157@Sacute@0015A@sacute@0015B@Scaron@00160@scaron@00161@Scedil@0015E@scedil@0015F@Scirc@0015C@scirc@0015D@Tcaron@00164@tcaron@00165@Tcedil@00162@tcedil@00163@Tstrok@00166@tstrok@00167@Ubreve@0016C@ubreve@0016D@Udblac@00170@udblac@00171@Umacr@0016A@umacr@0016B@Uogon@00172@uogon@00173@Uring@0016E@uring@0016F@Utilde@00168@utilde@00169@Wcirc@00174@wcirc@00175@Ycirc@00176@ycirc@00177@Yuml@00178@Zacute@00179@zacute@0017A@Zcaron@0017D@zcaron@0017E@Zdot@0017B@zdot@0017C@apos@00027@ast@0002A@brvbar@000A6@bsol@0005C@cent@000A2@colon@0003A@comma@0002C@commat@00040@copy@000A9@curren@000A4@darr@02193@deg@000B0@divide@000F7@dollar@00024@equals@0003D@excl@00021@frac12@000BD@frac14@000BC@frac18@0215B@frac34@000BE@frac38@0215C@frac58@0215D@frac78@0215E@gt@0003E@half@000BD@horbar@02015@hyphen@02010@iexcl@000A1@iquest@000BF@laquo@000AB@larr@02190@lcub@0007B@ldquo@0201C@lowbar@0005F@lpar@00028@lsqb@0005B@lsquo@02018@micro@000B5@middot@000B7@nbsp@000A0@not@000AC@num@00023@ohm@02126@ordf@000AA@ordm@000BA@para@000B6@percnt@00025@period@0002E@plus@0002B@plusmn@000B1@pound@000A3@quest@0003F@quot@00022@raquo@000BB@rarr@02192@rcub@0007D@rdquo@0201D@reg@000AE@rpar@00029@rsqb@0005D@rsquo@02019@sect@000A7@semi@0003B@shy@000AD@sol@0002F@sung@0266A@sup1@000B9@sup2@000B2@sup3@000B3@times@000D7@trade@02122@uarr@02191@verbar@0007C@yen@000A5@blank@02423@blk12@02592@blk14@02591@blk34@02593@block@02588@bull@02022@caret@02041@check@02713@cir@025CB@clubs@02663@copysr@02117@cross@02717@Dagger@02021@dagger@02020@dash@02010@diams@02666@dlcrop@0230D@drcrop@0230C@dtri@025BF@dtrif@025BE@emsp@02003@emsp13@02004@emsp14@02005@ensp@02002@female@02640@ffilig@0FB03@fflig@0FB00@ffllig@0FB04@filig@0FB01@flat@0266D@fllig@0FB02@frac13@02153@frac15@02155@frac16@02159@frac23@02154@frac25@02156@frac35@02157@frac45@02158@frac56@0215A@hairsp@0200A@hearts@02665@hellip@02026@hybull@02043@incare@02105@ldquor@0201E@lhblk@02584@loz@025CA@lozf@029EB@lsquor@0201A@ltri@025C3@ltrif@025C2@male@02642@malt@02720@marker@025AE@mdash@02014@mldr@02026@natur@0266E@ndash@02013@nldr@02025@numsp@02007@phone@0260E@puncsp@02008@rdquor@0201D@rect@025AD@rsquor@02019@rtri@025B9@rtrif@025B8@rx@0211E@sext@02736@sharp@0266F@spades@02660@squ@025A1@squf@025AA@star@02606@starf@02605@target@02316@telrec@02315@thinsp@02009@uhblk@02580@ulcrop@0230F@urcrop@0230E@utri@025B5@utrif@025B4@vellip@022EE@angzarr@0237C@cirmid@02AEF@cudarrl@02938@cudarrr@02935@cularr@021B6@cularrp@0293D@curarr@021B7@curarrm@0293C@Darr@021A1@dArr@021D3@ddarr@021CA@DDotrahd@02911@dfisht@0297F@dHar@02965@dharl@021C3@dharr@021C2@duarr@021F5@duhar@0296F@dzigrarr@027FF@erarr@02971@hArr@021D4@harr@02194@harrcir@02948@harrw@021AD@hoarr@021FF@imof@022B7@lAarr@021DA@Larr@0219E@larrbfs@0291F@larrfs@0291D@larrhk@021A9@larrlp@021AB@larrpl@02939@larrsim@02973@larrtl@021A2@lAtail@0291B@latail@02919@lBarr@0290E@lbarr@0290C@ldca@02936@ldrdhar@02967@ldrushar@0294B@ldsh@021B2@lfisht@0297C@lHar@02962@lhard@021BD@lharu@021BC@lharul@0296A@llarr@021C7@llhard@0296B@loarr@021FD@lrarr@021C6@lrhar@021CB@lrhard@0296D@lsh@021B0@lurdshar@0294A@luruhar@02966@Map@02905@map@021A6@midcir@02AF0@mumap@022B8@nearhk@02924@neArr@021D7@nearr@02197@nesear@02928@nhArr@021CE@nharr@021AE@nlArr@021CD@nlarr@0219A@nrArr@021CF@nrarr@0219B@nvHarr@02904@nvlArr@02902@nvrArr@02903@nwarhk@02923@nwArr@021D6@nwarr@02196@nwnear@02927@olarr@021BA@orarr@021BB@origof@022B6@rAarr@021DB@Rarr@021A0@rarrap@02975@rarrbfs@02920@rarrc@02933@rarrfs@0291E@rarrhk@021AA@rarrlp@021AC@rarrpl@02945@rarrsim@02974@Rarrtl@02916@rarrtl@021A3@rarrw@0219D@rAtail@0291C@ratail@0291A@RBarr@02910@rBarr@0290F@rbarr@0290D@rdca@02937@rdldhar@02969@rdsh@021B3@rfisht@0297D@rHar@02964@rhard@021C1@rharu@021C0@rharul@0296C@rlarr@021C4@rlhar@021CC@roarr@021FE@rrarr@021C9@rsh@021B1@ruluhar@02968@searhk@02925@seArr@021D8@searr@02198@seswar@02929@simrarr@02972@slarr@02190@srarr@02192@swarhk@02926@swArr@021D9@swarr@02199@swnwar@0292A@Uarr@0219F@uArr@021D1@Uarrocir@02949@udarr@021C5@udhar@0296E@ufisht@0297E@uHar@02963@uharl@021BF@uharr@021BE@uuarr@021C8@vArr@021D5@varr@02195@xhArr@027FA@xharr@027F7@xlArr@027F8@xlarr@027F5@xmap@027FC@xrArr@027F9@xrarr@027F6@zigrarr@021DD@ac@0223E@amalg@02A3F@barvee@022BD@Barwed@02306@barwed@02305@bsolb@029C5@Cap@022D2@capand@02A44@capbrcup@02A49@capcap@02A4B@capcup@02A47@capdot@02A40@ccaps@02A4D@ccups@02A4C@ccupssm@02A50@coprod@02210@Cup@022D3@cupbrcap@02A48@cupcap@02A46@cupcup@02A4A@cupdot@0228D@cupor@02A45@cuvee@022CE@cuwed@022CF@Dagger@02021@dagger@02020@diam@022C4@divonx@022C7@eplus@02A71@hercon@022B9@intcal@022BA@iprod@02A3C@loplus@02A2D@lotimes@02A34@lthree@022CB@ltimes@022C9@midast@0002A@minusb@0229F@minusd@02238@minusdu@02A2A@ncap@02A43@ncup@02A42@oast@0229B@ocir@0229A@odash@0229D@odiv@02A38@odot@02299@odsold@029BC@ofcir@029BF@ogt@029C1@ohbar@029B5@olcir@029BE@olt@029C0@omid@029B6@ominus@02296@opar@029B7@operp@029B9@oplus@02295@osol@02298@Otimes@02A37@otimes@02297@otimesas@02A36@ovbar@0233D@plusacir@02A23@plusb@0229E@pluscir@02A22@plusdo@02214@plusdu@02A25@pluse@02A72@plussim@02A26@plustwo@02A27@prod@0220F@race@029DA@roplus@02A2E@rotimes@02A35@rthree@022CC@rtimes@022CA@sdot@022C5@sdotb@022A1@setmn@02216@simplus@02A24@smashp@02A33@solb@029C4@sqcap@02293@sqcup@02294@ssetmn@02216@sstarf@022C6@subdot@02ABD@sum@02211@supdot@02ABE@timesb@022A0@timesbar@02A31@timesd@02A30@tridot@025EC@triminus@02A3A@triplus@02A39@trisb@029CD@tritime@02A3B@uplus@0228E@veebar@022BB@wedbar@02A5F@wreath@02240@xcap@022C2@xcirc@025EF@xcup@022C3@xdtri@025BD@xodot@02A00@xoplus@02A01@xotime@02A02@xsqcup@02A06@xuplus@02A04@xutri@025B3@xvee@022C1@xwedge@022C0@dlcorn@0231E@drcorn@0231F@gtlPar@02995@langd@02991@lbrke@0298B@lbrksld@0298F@lbrkslu@0298D@lceil@02308@lfloor@0230A@lmoust@023B0@lparlt@02993@ltrPar@02996@rangd@02992@rbrke@0298C@rbrksld@0298E@rbrkslu@02990@rceil@02309@rfloor@0230B@rmoust@023B1@rpargt@02994@ulcorn@0231C@urcorn@0231D@gnap@02A8A@gnE@02269@gne@02A88@gnsim@022E7@lnap@02A89@lnE@02268@lne@02A87@lnsim@022E6@nap@02249@ncong@02247@nequiv@02262@nge@02271@ngsim@02275@ngt@0226F@nle@02270@nlsim@02274@nlt@0226E@nltri@022EA@nltrie@022EC@nmid@02224@npar@02226@npr@02280@nprcue@022E0@nrtri@022EB@nrtrie@022ED@nsc@02281@nsccue@022E1@nsim@02241@nsime@02244@nsmid@02224@nspar@02226@nsqsube@022E2@nsqsupe@022E3@nsub@02284@nsube@02288@nsup@02285@nsupe@02289@ntgl@02279@ntlg@02278@nVDash@022AF@nVdash@022AE@nvDash@022AD@nvdash@022AC@parsim@02AF3@prnap@02AB9@prnE@02AB5@prnsim@022E8@rnmid@02AEE@scnap@02ABA@scnE@02AB6@scnsim@022E9@simne@02246@solbar@0233F@subnE@02ACB@subne@0228A@supnE@02ACC@supne@0228B@ang@02220@ange@029A4@angmsd@02221@angmsdaa@029A8@angmsdab@029A9@angmsdac@029AA@angmsdad@029AB@angmsdae@029AC@angmsdaf@029AD@angmsdag@029AE@angmsdah@029AF@angrtvb@022BE@angrtvbd@0299D@bbrk@023B5@bbrktbrk@023B6@bemptyv@029B0@beth@02136@boxbox@029C9@";
com.wiris.util.xml.WEntities.s2 = "bprime@02035@bsemi@0204F@cemptyv@029B2@cirE@029C3@cirscir@029C2@comp@02201@daleth@02138@demptyv@029B1@ell@02113@empty@02205@emptyv@02205@gimel@02137@iiota@02129@image@02111@imath@00131@jmath@0006A@laemptyv@029B4@lltri@025FA@lrtri@022BF@mho@02127@nexist@02204@oS@024C8@planck@0210F@plankv@0210F@raemptyv@029B3@range@029A5@real@0211C@tbrk@023B4@trpezium@0FFFD@ultri@025F8@urtri@025F9@vzigzag@0299A@weierp@02118@apE@02A70@ape@0224A@apid@0224B@asymp@02248@Barv@02AE7@bcong@0224C@bepsi@003F6@bowtie@022C8@bsim@0223D@bsime@022CD@bump@0224E@bumpE@02AAE@bumpe@0224F@cire@02257@Colon@02237@Colone@02A74@colone@02254@congdot@02A6D@csub@02ACF@csube@02AD1@csup@02AD0@csupe@02AD2@cuepr@022DE@cuesc@022DF@Dashv@02AE4@dashv@022A3@easter@02A6E@ecir@02256@ecolon@02255@eDDot@02A77@eDot@02251@efDot@02252@eg@02A9A@egs@02A96@egsdot@02A98@el@02A99@els@02A95@elsdot@02A97@equest@0225F@equivDD@02A78@erDot@02253@esdot@02250@Esim@02A73@esim@02242@fork@022D4@forkv@02AD9@frown@02322@gap@02A86@gE@02267@gEl@02A8C@gel@022DB@ges@02A7E@gescc@02AA9@gesdot@02A80@gesdoto@02A82@gesdotol@02A84@gesles@02A94@Gg@022D9@gl@02277@gla@02AA5@glE@02A92@glj@02AA4@gsim@02273@gsime@02A8E@gsiml@02A90@Gt@0226B@gtcc@02AA7@gtcir@02A7A@gtdot@022D7@gtquest@02A7C@gtrarr@02978@homtht@0223B@lap@02A85@lat@02AAB@late@02AAD@lE@02266@lEg@02A8B@leg@022DA@les@02A7D@lescc@02AA8@lesdot@02A7F@lesdoto@02A81@lesdotor@02A83@lesges@02A93@lg@02276@lgE@02A91@Ll@022D8@lsim@02272@lsime@02A8D@lsimg@02A8F@Lt@0226A@ltcc@02AA6@ltcir@02A79@ltdot@022D6@ltlarr@02976@ltquest@02A7B@ltrie@022B4@mcomma@02A29@mDDot@0223A@mid@02223@mlcp@02ADB@models@022A7@mstpos@0223E@Pr@02ABB@pr@0227A@prap@02AB7@prcue@0227C@prE@02AB3@pre@02AAF@prsim@0227E@prurel@022B0@ratio@02236@rtrie@022B5@rtriltri@029CE@Sc@02ABC@sc@0227B@scap@02AB8@sccue@0227D@scE@02AB4@sce@02AB0@scsim@0227F@sdote@02A66@sfrown@02322@simg@02A9E@simgE@02AA0@siml@02A9D@simlE@02A9F@smid@02223@smile@02323@smt@02AAA@smte@02AAC@spar@02225@sqsub@0228F@sqsube@02291@sqsup@02290@sqsupe@02292@ssmile@02323@Sub@022D0@subE@02AC5@subedot@02AC3@submult@02AC1@subplus@02ABF@subrarr@02979@subsim@02AC7@subsub@02AD5@subsup@02AD3@Sup@022D1@supdsub@02AD8@supE@02AC6@supedot@02AC4@suphsub@02AD7@suplarr@0297B@supmult@02AC2@supplus@02AC0@supsim@02AC8@supsub@02AD4@supsup@02AD6@thkap@02248@thksim@0223C@topfork@02ADA@trie@0225C@twixt@0226C@Vbar@02AEB@vBar@02AE8@vBarv@02AE9@VDash@022AB@Vdash@022A9@vDash@022A8@vdash@022A2@Vdashl@02AE6@vltri@022B2@vprop@0221D@vrtri@022B3@Vvdash@022AA@alpha@003B1@beta@003B2@chi@003C7@Delta@00394@delta@003B4@epsi@003B5@epsiv@003F5@eta@003B7@Gamma@00393@gamma@003B3@Gammad@003DC@gammad@003DD@iota@003B9@kappa@003BA@kappav@003F0@Lambda@0039B@lambda@003BB@mu@003BC@nu@003BD@Omega@003A9@omega@003C9@Phi@003A6@phi@003C6@phiv@003D5@Pi@003A0@pi@003C0@piv@003D6@Psi@003A8@psi@003C8@rho@003C1@rhov@003F1@Sigma@003A3@sigma@003C3@sigmav@003C2@tau@003C4@Theta@00398@theta@003B8@thetav@003D1@Upsi@003D2@upsi@003C5@Xi@0039E@xi@003BE@zeta@003B6@Cfr@0212D@Hfr@0210C@Ifr@02111@Rfr@0211C@Zfr@02128@Copf@02102@Hopf@0210D@Nopf@02115@Popf@02119@Qopf@0211A@Ropf@0211D@Zopf@02124@acd@0223F@aleph@02135@And@02A53@and@02227@andand@02A55@andd@02A5C@andslope@02A58@andv@02A5A@angrt@0221F@angsph@02222@angst@0212B@ap@02248@apacir@02A6F@awconint@02233@awint@02A11@becaus@02235@bernou@0212C@bNot@02AED@bnot@02310@bottom@022A5@cap@02229@Cconint@02230@cirfnint@02A10@compfn@02218@cong@02245@Conint@0222F@conint@0222E@ctdot@022EF@cup@0222A@cwconint@02232@cwint@02231@cylcty@0232D@disin@022F2@Dot@000A8@DotDot@020DC@dsol@029F6@dtdot@022F1@dwangle@029A6@elinters@0FFFD@epar@022D5@eparsl@029E3@equiv@02261@eqvparsl@029E5@exist@02203@fltns@025B1@fnof@00192@forall@02200@fpartint@02A0D@ge@02265@hamilt@0210B@iff@021D4@iinfin@029DC@imped@001B5@infin@0221E@infintie@029DD@Int@0222C@int@0222B@intlarhk@02A17@isin@02208@isindot@022F5@isinE@022F9@isins@022F4@isinsv@022F3@isinv@02208@lagran@02112@Lang@0300A@lang@027e8@lArr@021D0@lbbrk@03014@le@02264@loang@03018@lobrk@0301A@lopar@02985@lowast@02217@minus@02212@mnplus@02213@nabla@02207@ne@02260@nhpar@02AF2@ni@0220B@nis@022FC@nisd@022FA@niv@0220B@Not@02AEC@notin@02209@notinva@02209@notinvb@022F7@notinvc@022F6@notni@0220C@notniva@0220C@notnivb@022FE@notnivc@022FD@npolint@02A14@nvinfin@029DE@olcross@029BB@Or@02A54@or@02228@ord@02A5D@order@02134@oror@02A56@orslope@02A57@orv@02A5B@par@02225@parsl@02AFD@part@02202@permil@02030@perp@022A5@pertenk@02031@phmmat@02133@pointint@02A15@Prime@02033@prime@02032@profalar@0232E@profline@02312@profsurf@02313@prop@0221D@qint@02A0C@qprime@02057@quatint@02A16@radic@0221A@Rang@0300B@rang@027e9@rArr@021D2@rbbrk@03015@roang@03019@robrk@0301B@ropar@02986@rppolint@02A12@scpolint@02A13@sim@0223C@simdot@02A6A@sime@02243@smeparsl@029E4@square@025A1@squarf@025AA@strns@000AF@sub@02282@sube@02286@sup@02283@supe@02287@tdot@020DB@there4@02234@tint@0222D@top@022A4@topbot@02336@topcir@02AF1@tprime@02034@utdot@022F0@uwangle@029A7@vangrt@0299C@veeeq@0225A@Verbar@02016@wedgeq@02259@xnis@022FB@angle@02220@ApplyFunction@02061@approx@02248@approxeq@0224A@Assign@02254@backcong@0224C@backepsilon@003F6@backprime@02035@backsim@0223D@backsimeq@022CD@Backslash@02216@barwedge@02305@Because@02235@because@02235@Bernoullis@0212C@between@0226C@bigcap@022C2@bigcirc@025EF@bigcup@022C3@bigodot@02A00@bigoplus@02A01@bigotimes@02A02@bigsqcup@02A06@bigstar@02605@bigtriangledown@025BD@bigtriangleup@025B3@biguplus@02A04@bigvee@022C1@bigwedge@022C0@bkarow@0290D@blacklozenge@029EB@blacksquare@025AA@blacktriangle@025B4@blacktriangledown@025BE@blacktriangleleft@025C2@blacktriangleright@025B8@bot@022A5@boxminus@0229F@boxplus@0229E@boxtimes@022A0@Breve@002D8@bullet@02022@Bumpeq@0224E@bumpeq@0224F@CapitalDifferentialD@02145@Cayleys@0212D@Cedilla@000B8@CenterDot@000B7@centerdot@000B7@checkmark@02713@circeq@02257@circlearrowleft@021BA@circlearrowright@021BB@circledast@0229B@circledcirc@0229A@circleddash@0229D@CircleDot@02299@circledR@000AE@circledS@024C8@CircleMinus@02296@CirclePlus@02295@CircleTimes@02297@ClockwiseContourIntegral@02232@CloseCurlyDoubleQuote@0201D@CloseCurlyQuote@02019@clubsuit@02663@coloneq@02254@complement@02201@complexes@02102@Congruent@02261@ContourIntegral@0222E@Coproduct@02210@CounterClockwiseContourIntegral@02233@CupCap@0224D@curlyeqprec@022DE@curlyeqsucc@022DF@curlyvee@022CE@curlywedge@022CF@curvearrowleft@021B6@curvearrowright@021B7@dbkarow@0290F@ddagger@02021@ddotseq@02A77@Del@02207@DiacriticalAcute@000B4@DiacriticalDot@002D9@DiacriticalDoubleAcute@002DD@DiacriticalGrave@00060@DiacriticalTilde@002DC@Diamond@022C4@diamond@022C4@diamondsuit@02666@DifferentialD@02146@digamma@003DD@div@000F7@divideontimes@022C7@doteq@02250@doteqdot@02251@DotEqual@02250@dotminus@02238@dotplus@02214@dotsquare@022A1@doublebarwedge@02306@DoubleContourIntegral@0222F@DoubleDot@000A8@DoubleDownArrow@021D3@DoubleLeftArrow@021D0@DoubleLeftRightArrow@021D4@DoubleLeftTee@02AE4@DoubleLongLeftArrow@027F8@DoubleLongLeftRightArrow@027FA@DoubleLongRightArrow@027F9@DoubleRightArrow@021D2@DoubleRightTee@022A8@DoubleUpArrow@021D1@DoubleUpDownArrow@021D5@DoubleVerticalBar@02225@DownArrow@02193@Downarrow@021D3@downarrow@02193@DownArrowUpArrow@021F5@downdownarrows@021CA@downharpoonleft@021C3@downharpoonright@021C2@DownLeftVector@021BD@DownRightVector@021C1@DownTee@022A4@DownTeeArrow@021A7@drbkarow@02910@Element@02208@emptyset@02205@eqcirc@02256@eqcolon@02255@eqsim@02242@eqslantgtr@02A96@eqslantless@02A95@EqualTilde@02242@Equilibrium@021CC@Exists@02203@expectation@02130@ExponentialE@02147@exponentiale@02147@fallingdotseq@02252@ForAll@02200@Fouriertrf@02131@geq@02265@geqq@02267@geqslant@02A7E@gg@0226B@ggg@022D9@gnapprox@02A8A@gneq@02A88@gneqq@02269@GreaterEqual@02265@GreaterEqualLess@022DB@GreaterFullEqual@02267@GreaterLess@02277@GreaterSlantEqual@02A7E@GreaterTilde@02273@gtrapprox@02A86@gtrdot@022D7@gtreqless@022DB@gtreqqless@02A8C@gtrless@02277@gtrsim@02273@Hacek@002C7@hbar@0210F@heartsuit@02665@HilbertSpace@0210B@hksearow@02925@hkswarow@02926@hookleftarrow@021A9@hookrightarrow@021AA@hslash@0210F@HumpDownHump@0224E@HumpEqual@0224F@iiiint@02A0C@iiint@0222D@Im@02111@ImaginaryI@02148@imagline@02110@imagpart@02111@Implies@021D2@in@02208@integers@02124@Integral@0222B@intercal@022BA@Intersection@022C2@intprod@02A3C@InvisibleComma@02063@InvisibleTimes@02062@langle@027e8@Laplacetrf@02112@lbrace@0007B@lbrack@0005B@LeftAngleBracket@027e8@LeftArrow@02190@Leftarrow@021D0@leftarrow@02190@LeftArrowBar@021E4@LeftArrowRightArrow@021C6@leftarrowtail@021A2@LeftCeiling@02308@LeftDoubleBracket@0301A@LeftDownVector@021C3@LeftFloor@0230A@leftharpoondown@021BD@leftharpoonup@021BC@leftleftarrows@021C7@LeftRightArrow@02194@Leftrightarrow@021D4@leftrightarrow@02194@leftrightarrows@021C6@leftrightharpoons@021CB@leftrightsquigarrow@021AD@LeftTee@022A3@LeftTeeArrow@021A4@leftthreetimes@022CB@LeftTriangle@022B2@LeftTriangleEqual@022B4@LeftUpVector@021BF@LeftVector@021BC@leq@02264@leqq@02266@leqslant@02A7D@lessapprox@02A85@lessdot@022D6@lesseqgtr@022DA@lesseqqgtr@02A8B@LessEqualGreater@022DA@LessFullEqual@02266@LessGreater@02276@lessgtr@02276@lesssim@02272@LessSlantEqual@02A7D@LessTilde@02272@ll@0226A@llcorner@0231E@Lleftarrow@021DA@lmoustache@023B0@lnapprox@02A89@lneq@02A87@lneqq@02268@LongLeftArrow@027F5@Longleftarrow@027F8@longleftarrow@027F5@LongLeftRightArrow@027F7@Longleftrightarrow@027FA@longleftrightarrow@027F7@longmapsto@027FC@LongRightArrow@027F6@Longrightarrow@027F9@longrightarrow@027F6@looparrowleft@021AB@looparrowright@021AC@LowerLeftArrow@02199@LowerRightArrow@02198@lozenge@025CA@lrcorner@0231F@Lsh@021B0@maltese@02720@mapsto@021A6@measuredangle@02221@Mellintrf@02133@MinusPlus@02213@mp@02213@multimap@022B8@napprox@02249@natural@0266E@naturals@02115@nearrow@02197@NegativeMediumSpace@0200B@NegativeThickSpace@0200B@NegativeThinSpace@0200B@NegativeVeryThinSpace@0200B@NestedGreaterGreater@0226B@NestedLessLess@0226A@nexists@02204@ngeq@02271@ngtr@0226F@nLeftarrow@021CD@nleftarrow@0219A@nLeftrightarrow@021CE@nleftrightarrow@021AE@nleq@02270@nless@0226E@NonBreakingSpace@000A0@NotCongruent@02262@NotDoubleVerticalBar@02226@NotElement@02209@NotEqual@02260@NotExists@02204@NotGreater@0226F@NotGreaterEqual@02271@NotGreaterLess@02279@NotGreaterTilde@02275@NotLeftTriangle@022EA@NotLeftTriangleEqual@022EC@NotLess@0226E@NotLessEqual@02270@NotLessGreater@02278@NotLessTilde@02274@NotPrecedes@02280@NotPrecedesSlantEqual@022E0@NotReverseElement@0220C@NotRightTriangle@022EB@NotRightTriangleEqual@022ED@NotSquareSubsetEqual@022E2@NotSquareSupersetEqual@022E3@NotSubsetEqual@02288@NotSucceeds@02281@NotSucceedsSlantEqual@022E1@NotSupersetEqual@02289@NotTilde@02241@NotTildeEqual@02244@NotTildeFullEqual@02247@NotTildeTilde@02249@NotVerticalBar@02224@nparallel@02226@nprec@02280@nRightarrow@021CF@nrightarrow@0219B@nshortmid@02224@nshortparallel@02226@nsimeq@02244@nsubseteq@02288@nsucc@02281@nsupseteq@02289@ntriangleleft@022EA@ntrianglelefteq@022EC@ntriangleright@022EB@ntrianglerighteq@022ED@nwarrow@02196@oint@0222E@OpenCurlyDoubleQuote@0201C@OpenCurlyQuote@02018@orderof@02134@parallel@02225@PartialD@02202@pitchfork@022D4@PlusMinus@000B1@pm@000B1@Poincareplane@0210C@prec@0227A@precapprox@02AB7@preccurlyeq@0227C@Precedes@0227A@PrecedesEqual@02AAF@PrecedesSlantEqual@0227C@PrecedesTilde@0227E@preceq@02AAF@precnapprox@02AB9@precneqq@02AB5@precnsim@022E8@precsim@0227E@primes@02119@Proportion@02237@Proportional@0221D@propto@0221D@quaternions@0210D@questeq@0225F@rangle@027e9@rationals@0211A@rbrace@0007D@rbrack@0005D@Re@0211C@realine@0211B@realpart@0211C@reals@0211D@ReverseElement@0220B@ReverseEquilibrium@021CB@ReverseUpEquilibrium@0296F@RightAngleBracket@027e9@RightArrow@02192@Rightarrow@021D2@rightarrow@02192@RightArrowBar@021E5@RightArrowLeftArrow@021C4@rightarrowtail@021A3@RightCeiling@02309@RightDoubleBracket@0301B@RightDownVector@021C2@RightFloor@0230B@rightharpoondown@021C1@rightharpoonup@021C0@rightleftarrows@021C4@rightleftharpoons@021CC@rightrightarrows@021C9@rightsquigarrow@0219D@RightTee@022A2@RightTeeArrow@021A6@rightthreetimes@022CC@RightTriangle@022B3@RightTriangleEqual@022B5@RightUpVector@021BE@RightVector@021C0@risingdotseq@02253@rmoustache@023B1@Rrightarrow@021DB@Rsh@021B1@searrow@02198@setminus@02216@ShortDownArrow@02193@ShortLeftArrow@02190@shortmid@02223@shortparallel@02225@ShortRightArrow@02192@ShortUpArrow@02191@simeq@02243@SmallCircle@02218@smallsetminus@02216@spadesuit@02660@Sqrt@0221A@sqsubset@0228F@sqsubseteq@02291@sqsupset@02290@sqsupseteq@02292@Square@025A1@SquareIntersection@02293@SquareSubset@0228F@SquareSubsetEqual@02291@SquareSuperset@02290@SquareSupersetEqual@02292@SquareUnion@02294@Star@022C6@straightepsilon@003F5@straightphi@003D5@Subset@022D0@subset@02282@subseteq@02286@subseteqq@02AC5@SubsetEqual@02286@subsetneq@0228A@subsetneqq@02ACB@succ@0227B@succapprox@02AB8@succcurlyeq@0227D@Succeeds@0227B@SucceedsEqual@02AB0@SucceedsSlantEqual@0227D@SucceedsTilde@0227F@succeq@02AB0@succnapprox@02ABA@succneqq@02AB6@succnsim@022E9@succsim@0227F@SuchThat@0220B@Sum@02211@Superset@02283@SupersetEqual@02287@Supset@022D1@supset@02283@supseteq@02287@supseteqq@02AC6@supsetneq@0228B@supsetneqq@02ACC@swarrow@02199@Therefore@02234@therefore@02234@thickapprox@02248@thicksim@0223C@ThinSpace@02009@Tilde@0223C@TildeEqual@02243@TildeFullEqual@02245@TildeTilde@02248@toea@02928@tosa@02929@triangle@025B5@triangledown@025BF@triangleleft@025C3@trianglelefteq@022B4@triangleq@0225C@triangleright@025B9@trianglerighteq@022B5@TripleDot@020DB@twoheadleftarrow@0219E@twoheadrightarrow@021A0@ulcorner@0231C@Union@022C3@UnionPlus@0228E@UpArrow@02191@Uparrow@021D1@uparrow@02191@UpArrowDownArrow@021C5@UpDownArrow@02195@Updownarrow@021D5@updownarrow@02195@UpEquilibrium@0296E@upharpoonleft@021BF@upharpoonright@021BE@UpperLeftArrow@02196@UpperRightArrow@02197@upsilon@003C5@UpTee@022A5@UpTeeArrow@021A5@upuparrows@021C8@urcorner@0231D@varepsilon@003F5@varkappa@003F0@varnothing@02205@varphi@003C6@varpi@003D6@varpropto@0221D@varrho@003F1@varsigma@003C2@vartheta@003D1@vartriangleleft@022B2@vartriangleright@022B3@Vee@022C1@vee@02228@Vert@02016@vert@0007C@VerticalBar@02223@VerticalTilde@02240@VeryThinSpace@0200A@Wedge@022C0@wedge@02227@wp@02118@wr@02240@zeetrf@02128@af@02061@asympeq@0224D@Cross@02A2F@DD@02145@dd@02146@DownArrowBar@02913@DownBreve@00311@DownLeftRightVector@02950@DownLeftTeeVector@0295E@DownLeftVectorBar@02956@DownRightTeeVector@0295F@DownRightVectorBar@02957@ee@02147@EmptySmallSquare@025FB@EmptyVerySmallSquare@025AB@Equal@02A75@FilledSmallSquare@025FC@FilledVerySmallSquare@025AA@GreaterGreater@02AA2@Hat@0005E@HorizontalLine@02500@ic@02063@ii@02148@it@02062@larrb@021E4@LeftDownTeeVector@02961@LeftDownVectorBar@02959@LeftRightVector@0294E@LeftTeeVector@0295A@LeftTriangleBar@029CF@LeftUpDownVector@02951@LeftUpTeeVector@02960@LeftUpVectorBar@02958@LeftVectorBar@02952@LessLess@02AA1@mapstodown@021A7@mapstoleft@021A4@mapstoup@021A5@MediumSpace@0205F@NewLine@0000A@NoBreak@02060@NotCupCap@0226D@OverBar@000AF@OverBrace@023DE@OverBracket@023B4@OverParenthesis@023DC@planckh@0210E@Product@0220F@rarrb@021E5@RightDownTeeVector@0295D@RightDownVectorBar@02955@RightTeeVector@0295B@RightTriangleBar@029D0@RightUpDownVector@0294F@RightUpTeeVector@0295C@RightUpVectorBar@02954@RightVectorBar@02953@RoundImplies@02970@RuleDelayed@029F4@Tab@00009@UnderBar@00332@UnderBrace@023DF@UnderBracket@023B5@UnderParenthesis@023DD@UpArrowBar@02912@Upsilon@003A5@VerticalLine@0007C@VerticalSeparator@02758@ZeroWidthSpace@0200B@omicron@003BF@amalg@02210@NegativeThinSpace@0E000@Iopf@1d540@";
com.wiris.util.xml.WEntities.s3 = "Alpha@00391@Beta@00392@Epsilon@00395@Zeta@00396@Eta@00397@Iota@00399@Kappa@0039A@Mu@0039C@Nu@0039D@Omicron@0039F@Rho@003A1@Tau@003A4@Chi@003A7@gamma@003B3@epsilon@003B5@eta@003B7@sigmaf@003C2@thetasym@003D1@upsih@003D2@zwnj@0200C@zwj@0200D@lrm@0200E@rlm@0200F@sbquo@0201A@bdquo@0201E@lsaquo@02039@rsaquo@0203A@oline@0203E@euro@020AC@crarr@021B5@";
com.wiris.util.xml.WEntities.oldWebeq = "infty@221e@partial@2202@iint@222c@neq@2260@nsubset@2284@nsupset@2285@exists@2203@ldots@2026@vdots@22ee@cdots@22ef@ddots@22f1@bar@00af@hat@005e@vec@21c0@ddot@00A8@";
com.wiris.util.xml.WEntities.MATHML_ENTITIES = com.wiris.util.xml.WEntities.s1 + com.wiris.util.xml.WEntities.s2 + com.wiris.util.xml.WEntities.s3 + com.wiris.util.xml.WEntities.oldWebeq;
com.wiris.util.xml.WXmlUtils.WHITESPACE_COLLAPSE_REGEX = new EReg("[ \\t\\n\\r]{2,}","g");
com.wiris.util.xml.WXmlUtils.entities = null;
com.wiris.webwork.MathML2Webwork.MATHML_TO_WEBWORK_GRAMMAR_FILE = "grammar_webwork.txt";
com.wiris.webwork.MathML2Webwork.emptyMmlRe = new EReg("<math(\\s+xmlns\\s*=\\s*\"http://www.w3.org/1998/Math/MathML\")?\\s*((/>)|(></math>))","");
haxe.Serializer.USE_CACHE = false;
haxe.Serializer.USE_ENUM_INDEX = false;
haxe.Serializer.BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789%:";
haxe.Unserializer.DEFAULT_RESOLVER = Type;
haxe.Unserializer.BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789%:";
haxe.Unserializer.CODES = null;
haxe.io.Output.LN2 = Math.log(2);
js.Lib.onerror = null;
