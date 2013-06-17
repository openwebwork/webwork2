var jqmv_language = window.navigator.userLanguage || window.navigator.language;

// BasePath for images

	// Local Uncomment for local use
	//var jqmv_basepath_images = "mathview/";// jqmv_basepath_images for images

	// Uncomment for Webwork Use
	var jqmv_basepath_images =  "/webwork2_files/images/mathview/"

// EVENTUALLY IT WOULD BE BETTER TO MAKE TRANSLATOR OBJECT TO GET REPRESENTIVE NAME FOR CODE READING TODO
var jqmv_translator=["Base","Groupings","Trigonometry","Logarithms","Intervals","Others","Version EN ", "Equation Editor","Insert","Cancel"];
	if (jqmv_language.split("-")[0]=="fr")
		jqmv_translator=["Base","Regroupements","Trigonom&eacute;trie","Logarithmes","Intervalles","Autres","Version FR ", "&Eacute;diteur d'&eacute;quation","Inserer","Annuler"];
var categories =
[
	{
		image: jqmv_basepath_images + "Base4.gif",
			tooltip:jqmv_translator[0],//"Base",
		operators:
		[
			{
				image:jqmv_basepath_images + "addition.jpg",
				tooltip:"addition",
				helpurl:"addition.html",
				latex:"{}+{}",
				PG:"+"
			},
			{
				image:jqmv_basepath_images + "subtraction.jpg",
				tooltip:"subtraction",
				helpurl:"subtraction.html",
				latex:"{}-{}",
				PG:"-"
			},
			{
				image:jqmv_basepath_images + "multiplication.jpg",
				tooltip:"multiplication",
				helpurl:"multiplication.html",
				latex:"{}*{}",
				PG:"*"
			},
			{
				image:jqmv_basepath_images + "division.jpg",
				tooltip:"division",
				helpurl:"division.html",
				latex:"{}/{}",
				PG:"/"
			},
			{
				image:jqmv_basepath_images + "fraction.jpg",
				tooltip:"fraction",
				helpurl:"fraction.html",
				latex:"\\frac{}{}",
				PG:"/"
			},
			{
				image:jqmv_basepath_images + "exponentiation.jpg",
				tooltip:"exponentiation",
				helpurl:"exponentiation.html",
				latex:"{}^{}",
				PG:"^"
			},
			{
				image:jqmv_basepath_images + "racine.jpg",
				tooltip:"racine",
				helpurl:"racine.html",
				latex:"\\sqrt{}",
				PG:"sqrt()"
			},
			{
				image:jqmv_basepath_images + "racine.jpg",
				tooltip:"racine",
				helpurl:"racine.html",
				latex:"\\sqrt[]{}",
				PG:""
			},
			{
				image:jqmv_basepath_images + "carre.jpg",
				tooltip:"carre",
				helpurl:"carre.html",
				latex:"{}^{1/2}",
				PG:"^(1/2)"
			},
			{
				image:jqmv_basepath_images + "absolute.jpg",
				tooltip:"absolute",
				helpurl:"absolute.html",
				latex:"|{}|",
				PG:"abs()"
			}
		]
	},
	{
		image:jqmv_basepath_images + "Parentheses.gif",
		tooltip:jqmv_translator[1],//"Parentheses",
		operators:
		[
			{
				image:jqmv_basepath_images + "parentheses.jpg",
				tooltip:"parentheses",
				helpurl:"parentheses.html",
				latex:"()",
				PG:"()"
			},
			{
				image:jqmv_basepath_images + "squarebrackets.jpg",
				tooltip:"squarebrackets",
				helpurl:"squarebrackets.html",
				latex:"[]",
				PG:"[]"
			},
			{
				image:jqmv_basepath_images + "curlybrackets.jpg",
				tooltip:"curlybrackets",
				helpurl:"curlybrackets.html",
				latex:"\\left \\{  \\right \\}",
				PG:"{}"
			}
		]
	},
	{
		image:jqmv_basepath_images + "Trigonometry.gif",
		tooltip:jqmv_translator[2],//"Trigonometry",
		operators:
		[
			{
				image:jqmv_basepath_images + "pi.jpg",
				tooltip:"Pi",
				helpurl:"Pi.html",
				latex:"\\pi",
				PG:"pi"
			},
			{
				image:jqmv_basepath_images + "sine.jpg",
				tooltip:"sine",
				helpurl:"sine.html",
				latex:"\\sin{}",
				PG:"sin( )"
			},
			{
				image:jqmv_basepath_images + "cosine.jpg",
				tooltip:"cosine",
				helpurl:"cosine.html",
				latex:"\\cos{}",
				PG:"cos( )"
			},
			{
				image:jqmv_basepath_images + "tangent.jpg",
				tooltip:"tangent",
				helpurl:"tangent.html",
				latex:"\\tan{}",
				PG:"tan( )"
			},
			{
				image:jqmv_basepath_images + "cosecant .jpg",
				tooltip:"cosecant ",
				helpurl:"cosecant .html",
				latex:"\\csc{}",
				PG:"csc( )"
			},
			{
				image:jqmv_basepath_images + "secant.jpg",
				tooltip:"secant",
				helpurl:"secant.html",
				latex:"\\sec{}",
				PG:"sec( )"
			},
			{
				image:jqmv_basepath_images + "cotangent.jpg",
				tooltip:"cotangent",
				helpurl:"cotangent.html",
				latex:"\\cot{}",
				PG:"cot( )"
			},
			{
				image:jqmv_basepath_images + "arcsin.jpg",
				tooltip:"arcsin",
				helpurl:"arcsin.html",
				latex:"\\sin^{-1}{}",
				PG:"arcsin( )"
			},
			{
				image:jqmv_basepath_images + "arccos.jpg",
				tooltip:"arccos",
				helpurl:"arccos.html",
				latex:"\\cos^{-1}{}",
				PG:"arccos( )"
			},
			{
				image:jqmv_basepath_images + "arctan.jpg",
				tooltip:"arctan",
				helpurl:"arctan.html",
				latex:"\\tan^{-1}{}",
				PG:"arctan( )"
			},
			{
				image:jqmv_basepath_images + "arccot.jpg",
				tooltip:"arccot",
				helpurl:"arccot.html",
				latex:"\\cot^{-1}{}",
				PG:"arccot( )"
			},
			{
				image:jqmv_basepath_images + "arcsec.jpg",
				tooltip:"arcsec",
				helpurl:"arcsec.html",
				latex:"\\sec^{-1}{}",
				PG:"arcsec( )"
			},
			{
				image:jqmv_basepath_images + "arccsc.jpg",
				tooltip:"arccsc",
				helpurl:"arccsc.html",
				latex:"\\csc^{-1}{}",
				PG:"arccsc( )"
			}
		]
	},
	{
		image:jqmv_basepath_images + "Logarithm1.gif",
		tooltip:jqmv_translator[3],//"Logarithm",
		operators:
		[
			{
				image:jqmv_basepath_images + "e.jpg",
				tooltip:"e",
				helpurl:"logarithm.html",
				latex:"e",
				PG:"e"
			},
			{
				image:jqmv_basepath_images + "logarithm.jpg",
				tooltip:"logarithm",
				helpurl:"logarithm.html",
				latex:"\\log{}",
				PG:"log( )"
			},
			{
				image:jqmv_basepath_images + "logarithmBase.jpg",
				tooltip:"logarithmBase",
				helpurl:"logarithmBase.html",
				latex:"\\log_{}{}",
				PG:"log( )"
			},
			{
				image:jqmv_basepath_images + "naturalLogarithm.jpg",
				tooltip:"naturalLogarithm",
				helpurl:"naturalLogarithm.html",
				latex:"\\ln{}",
				PG:"ln( )"
			},
			{
				image:jqmv_basepath_images + "eExp.jpg",
				tooltip:"eExp",
				helpurl:"eExp.html",
				latex:"e^{}",
				PG:"exp( )"
			}
		]
	},
	{
		image:jqmv_basepath_images + "Intervals.gif",
		tooltip:jqmv_translator[4],//"Intervals",
		operators:
		[
			{
				image:jqmv_basepath_images + "[].jpg",
				tooltip:"[]",
				helpurl:"[].html",
				latex:"\\left[{},{} \\right]",
				PG:"[,]"
			},
			{
				image:jqmv_basepath_images + "(].jpg",
				tooltip:"(]",
				helpurl:"(].html",
				latex:"\\left]{},{} \\right]",
				PG:"(,]"
			},
			{
				image:jqmv_basepath_images + "[).jpg",
				tooltip:"[)",
				helpurl:"[).html",
				latex:"\\left[{},{} \\right[",
				PG:"[,)"
			},
			{
				image:jqmv_basepath_images + "().jpg",
				tooltip:"()",
				helpurl:"().html",
				latex:"\\left]{},{} \\right[",
				PG:"(,)"
			},
			{
				image:jqmv_basepath_images + "union.jpg",
				tooltip:"union",
				helpurl:"union.html",
				latex:"\\cup",
				PG:"U"
			}
		]
	},
	{
		image:jqmv_basepath_images + "Others.gif",
		tooltip:jqmv_translator[5],//"Other",
		operators:
		[
			{
				image:jqmv_basepath_images + "infini.jpg",
				tooltip:"infini",
				helpurl:"infini.html",
				latex:"\\infty",
				PG:"Inf"
			},
			{
				image:jqmv_basepath_images + "vector.jpg",
				tooltip:"vector",
				helpurl:"vector.html",
				latex:"\\vec{}",
				PG:"\mathit{\vec ()}"
			},
			{
				image:jqmv_basepath_images + "sigma.jpg",
				tooltip:"sigma",
				helpurl:"sigma.html",
				latex:"\\sigma",
				PG:"sigma()"
			},
			{
				image:jqmv_basepath_images + "theta.jpg",
				tooltip:"theta",
				helpurl:"theta.html",
				latex:"\\theta",
				PG:"theta()"
			}
		]
	},
];
