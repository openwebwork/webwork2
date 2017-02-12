/* This file has the list of functions to be shown on the viewer, seperated into categories.  
   The structure of an element is
   text: latex string to render text on button
   autocomp: whether the string should be included in the autocompletion feature
   tooltip: the tooltip to print when hovering over button
   helpurl: the url of the webpage with function help (nto currently used)
   latex: the latex code corresponding to the function
   PG: the PGML code corresponding to the function
*/

var mathView_translator=["Base","Parenthèses","Trigonometrie","Logarithmes","Intervalles","Autres","Version FR ", "Éditeur d'équations","Insérer","Annuler","Trigonométrie inverse","Exposants"];

var mv_categories =
[
	{
	    text:mathView_translator[0],//"Basic",
	    operators:
	    [
		{
		    text:'\\(a + b\\)',
		    autocomp : false,
		    tooltip:"addition",
		    helpurl:"addition.html",
		    latex:"{}+{}",
		    PG:"+"
		},
		{
		    text:'\\(a-b\\)',
		    autocomp : false,
		    tooltip:"soustraction",
		    helpurl:"subtraction.html",
		    latex:"{}-{}",
		    PG:"-"
		},
		{
		    text:'\\(a\\cdot b\\)',
		    autocomp : false,
		    tooltip:"multiplication",
		    helpurl:"multiplication.html",
		    latex:"{}*{}",
		    PG:"*"
		},
		{
		    text:'\\(a/b\\)',
		    autocomp : false,
		    tooltip:"division",
		    helpurl:"division.html",
		    latex:"{}/{}",
		    PG:"/"
		},
		{
		    text:'\\(\\frac{a}{b}\\)',
		    autocomp : false,
		    tooltip:"fraction",
		    helpurl:"fraction.html",
		    latex:"\\frac{}{}",
		    PG:"()/()"
		},
		{
		    text:'\\(|a|\\)',
		    autocomp : true,
		    tooltip:"valeur absolue",
		    helpurl:"absolute.html",
		    latex:"|{}|",
		    PG:"abs()"
		}
	    ]
	},
    {
	text:mathView_translator[11],//"Exponents",
	operators:
	    [
		
		{
		    text:'\\(a^b\\)',
		    autocomp : false,
		    tooltip:"puissance",
		    helpurl:"exponentiation.html",
		    latex:"{}^{}",
		    PG:"^"
		},
		{
		    text:'\\(\\sqrt{a}\\)',
		    autocomp : true,
		    tooltip:"racine carrée",
		    helpurl:"racine.html",
		    latex:"\\sqrt{}",
		    PG:"sqrt()"
		},
		{
		    text:'\\(\\sqrt[b]{a}\\)',
		    autocomp : false,
		    tooltip:"racine nième",
		    helpurl:"racine.html",
		    latex:"\\sqrt[]{}",
		    PG:"^(1/b)"
		},
		{
		    text:'\\(e^{a}\\)',
		    autocomp : false,
		    tooltip:"exponentielle",
		    helpurl:"eExp.html",
		    latex:"e^{}",
		    PG:"e^()"
		}
		
	    ]
    },
    {
	text:(mathView_translator[2]),//"Trigonometry",
	operators:
	[
	    {
		text:'\\(\\sin(a)\\)',
		autocomp : true,
		tooltip:"sinus",
		helpurl:"sine.html",
		latex:"\\sin{}",
		PG:"sin()"
	    },
	    {
		text:'\\(\\cos(a)\\)',
		autocomp : true,
		tooltip:"cosinus",
		helpurl:"cosine.html",
		latex:"\\cos{}",
		PG:"cos()"
	    },
	    {
		text:'\\(\\tan(a)\\)',
		autocomp : true,
		tooltip:"tangente",
		helpurl:"tangent.html",
		latex:"\\tan{}",
		PG:"tan()"
	    },
	    {
		text:'\\(\\csc(a)\\)',
		autocomp : true,
		tooltip:"cosécante ",
		helpurl:"cosecant .html",
		latex:"\\csc{}",
		PG:"csc()"
	    },
	    {
		text:'\\(\\sec(a)\\)',
		autocomp : true,
		tooltip:"sécante",
		helpurl:"secant.html",
		latex:"\\sec{}",
		PG:"sec()"
	    },
	    {
		text:'\\(\\cot(a)\\)',
		autocomp : true,
		tooltip:"cotangente",
		helpurl:"cotangent.html",
		latex:"\\cot{}",
		PG:"cot()"
	    }
	]
    },
    {
	text:mathView_translator[10],//"Inverse Trig",
	operators:
	[
	    
	    {
		text:'\\(\\arcsin(a)\\)',
		autocomp : false,
		tooltip:"arcsin",
		helpurl:"arcsin.html",
		latex:"\\arcsin{}",
		PG:"arcsin()"
	    },
	    {
		text:'\\(\\arccos(a)\\)',
		autocomp : false,
		tooltip:"arccos",
		helpurl:"arccos.html",
		latex:"\\arccos{}",
		PG:"arccos()"
	    },
	    {
		text:'\\(\\arctan(a)\\)',
		autocomp : false,
		tooltip:"arctan",
		helpurl:"arctan.html",
		latex:"\\arctan{}",
		PG:"arctan()"
	    },
	    {
		text:'\\(\\arccot(a)\\)',
		autocomp : false,
		tooltip:"arccot",
		helpurl:"arccot.html",
		latex:"\\arccot{}",
		PG:"arccot()"
	    },
	    {
		text:'\\(\\arcsec(a)\\)',
		autocomp : false,
		tooltip:"arcsec",
		helpurl:"arcsec.html",
		latex:"\\arcsec{}",
		PG:"arcsec()"
	    },
	    {
		text:'\\(\\arccsc(a)\\)',
		autocomp : false,
		tooltip:"arccsc",
		helpurl:"arccsc.html",
		latex:"\\arccsc{}",
		PG:"arccsc()"
	    }
	]
    },
    {
	text:mathView_translator[3],//"Logarithm",
	operators:
	[
	    {
		text:'\\(\\log(a)\\)',
		tooltip:"log en base 10",
		autocomp : true,
		helpurl:"logarithm.html",
		latex:"\\log{}",
		PG:"log()"
	    },
	    {
		text:'\\(\\log_b(a)\\)',
		tooltip:"log en base b",
		helpurl:"logarithmBase.html",
		latex:"\\log_{}{}",
		PG:"log()/log()"
	    },
	    {
		text:'\\(\\ln(a)\\)',
		autocomp : true,
		tooltip:"logarithme naturel",
		helpurl:"naturalLogarithm.html",
		latex:"\\ln{}",
		PG:"ln()"
	    },
	    {
		text:'\\(\\exp(a)\\)',
		autocomp : true,
		tooltip:"exponentielle",
		helpurl:"eExp.html",
		latex:"\\exp{}",
		PG:"exp()"
	    }
	]
	},
	{
	    text:mathView_translator[4],//"Intervals",
	    operators:
	    [
		{
		    text:'\\([a,b]\\)',
		    tooltip:"intervalle fermé",
		    helpurl:"[].html",
		    latex:"\\left[{},{} \\right]",
		    PG:"[,]"
		},
		{
		    text:'\\((a,b]\\)',
		    tooltip:"half open interval",
		    helpurl:"(].html",
		    latex:"\\left({},{} \\right]",
		    PG:"(,]"
		},
		{
		    text:'\\([a,b)\\)',
		    tooltip:"intervalle semi-ouvert",
		    helpurl:"[).html",
		    latex:"\\left[{},{} \\right[",
		    PG:"[,)"
		},
		{
		    text:'\\((a,b)\\)',
		    tooltip:"intervalle ouvert",
		    helpurl:"().html",
		    latex:"\\left]{},{} \\right[",
		    PG:"(,)"
		},
		{
		    text:'\\(A\\cup B\\)',
		    tooltip:"union",
		    helpurl:"union.html",
		    latex:"\\cup",
		    PG:"U"
		}
	    ]
	},
	{
	    text:mathView_translator[5],//"Other",
	    operators:
	    [
		{
		    text:'\\(\\infty\\)',
		    autocomp : true,
		    tooltip:"infinité",
		    helpurl:"infini.html",
		    latex:"\\infty",
		    PG:"Inf"
		},
		
		{
		    text:'\\(\\pi\\)',
		    tooltip:"Pi",
		    helpurl:"Pi.html",
		    latex:"\\pi",
			PG:"pi"
		},
		{
		    text:'\\(e\\)',
		    tooltip:"nombre e",
		    helpurl:"logarithm.html",
		    latex:"e",
		    PG:"e"
		},
		{
		    text:'\\((a)\\)',
		    tooltip:"parenthèses",
		    helpurl:"parentheses.html",
		    latex:"()",
		    PG:"()"
		},
		{
		    text:'\\([a]\\)',
		    tooltip:"crochets",
		    helpurl:"squarebrackets.html",
		    latex:"[]",
		    PG:"[]"
		},
		{
		    text:'\\(\\{a\\}\\)',
		    tooltip:"accolades",
		    helpurl:"curlybrackets.html",
		    latex:"\\left \\{  \\right \\}",
		    PG:"{}"
		}
		
	    ]
	},
];

