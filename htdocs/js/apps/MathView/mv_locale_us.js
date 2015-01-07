/* This file has the list of functions to be shown on the viewer, seperated into categories.  
   The structure of an element is
   text: latex string to render text on button
   autocomp: whether the string should be included in the autocompletion feature
   tooltip: the tooltip to print when hovering over button
   helpurl: the url of the webpage with function help (nto currently used)
   latex: the latex code corresponding to the function
   PG: the PGML code corresponding to the function
*/

var mathView_translator=["Basic","Parenthesis","Trigonometry","Logarithms","Intervals","Others","Version EN ", "Equation Editor","Insert","Cancel","Inverse Trig","Exponents"];

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
		    tooltip:"subtraction",
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
		    tooltip:"absolute value",
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
		    tooltip:"exponentiation",
		    helpurl:"exponentiation.html",
		    latex:"{}^{}",
		    PG:"^"
		},
		{
		    text:'\\(\\sqrt{a}\\)',
		    autocomp : true,
		    tooltip:"square root",
		    helpurl:"racine.html",
		    latex:"\\sqrt{}",
		    PG:"sqrt()"
		},
		{
		    text:'\\(\\sqrt[b]{a}\\)',
		    autocomp : false,
		    tooltip:"bth root",
		    helpurl:"racine.html",
		    latex:"\\sqrt[]{}",
		    PG:"^(1/b)"
		},
		{
		    text:'\\(e^{a}\\)',
		    autocomp : false,
		    tooltip:"exponential",
		    helpurl:"eExp.html",
		    latex:"e^{}",
		    PG:"e^()"
		}
		
	    ]
    },
    {
	text:mathView_translator[2],//"Trigonometry",
	operators:
	[
	    {
		text:'\\(\\sin(a)\\)',
		autocomp : true,
		tooltip:"sine",
		helpurl:"sine.html",
		latex:"\\sin{}",
		PG:"sin()"
	    },
	    {
		text:'\\(\\cos(a)\\)',
		autocomp : true,
		tooltip:"cosine",
		helpurl:"cosine.html",
		latex:"\\cos{}",
		PG:"cos()"
	    },
	    {
		text:'\\(\\tan(a)\\)',
		autocomp : true,
		tooltip:"tangent",
		helpurl:"tangent.html",
		latex:"\\tan{}",
		PG:"tan()"
	    },
	    {
		text:'\\(\\csc(a)\\)',
		autocomp : true,
		tooltip:"cosecant ",
		helpurl:"cosecant .html",
		latex:"\\csc{}",
		PG:"csc()"
	    },
	    {
		text:'\\(\\sec(a)\\)',
		autocomp : true,
		tooltip:"secant",
		helpurl:"secant.html",
		latex:"\\sec{}",
		PG:"sec()"
	    },
	    {
		text:'\\(\\cot(a)\\)',
		autocomp : true,
		tooltip:"cotangent",
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
		text:'\\(\\sin^{-1}(a)\\)',
		autocomp : false,
		tooltip:"inverse sin",
		helpurl:"arcsin.html",
		latex:"\\sin^{-1}{}",
		PG:"sin^(-1)()"
	    },
	    {
		text:'\\(\\cos^{-1}(a)\\)',
		autocomp : false,
		tooltip:"inverse cos",
		helpurl:"arccos.html",
		latex:"\\cos^{-1}{}",
		PG:"cos^(-1)()"
	    },
	    {
		text:'\\(\\tan^{-1}(a)\\)',
		autocomp : false,
		tooltip:"inverse tan",
		helpurl:"arctan.html",
		latex:"\\tan^{-1}{}",
		PG:"tan^(-1)()"
	    },
	    {
		text:'\\(\\cot^{-1}(a)\\)',
		autocomp : false,
		tooltip:"inverse cot",
		helpurl:"arccot.html",
		latex:"\\cot^{-1}{}",
		PG:"cot^{-1}()"
	    },
	    {
		text:'\\(\\sec^{-1}(a)\\)',
		autocomp : false,
		tooltip:"inverse sec",
		helpurl:"arcsec.html",
		latex:"\\sec^{-1}{}",
		PG:"sec^(-1)()"
	    },
	    {
		text:'\\(\\csc^{-1}(a)\\)',
		autocomp : false,
		tooltip:"inverse csc",
		helpurl:"arccsc.html",
		latex:"\\csc^{-1}{}",
		PG:"csc^(-1)()"
	    }
	]
    },
    {
	text:mathView_translator[3],//"Logarithm",
	operators:
	[
	    {
		text:'\\(\\log(a)\\)',
		tooltip:"logarithm base 10",
		autocomp : true,
		helpurl:"logarithm.html",
		latex:"\\log{}",
		PG:"log()"
	    },
	    {
		text:'\\(\\log_b(a)\\)',
		tooltip:"logarithm base b",
		helpurl:"logarithmBase.html",
		latex:"\\log_{}{}",
		PG:"log()/log()"
	    },
	    {
		text:'\\(\\ln(a)\\)',
		autocomp : true,
		tooltip:"natural logarithm",
		helpurl:"naturalLogarithm.html",
		latex:"\\ln{}",
		PG:"ln()"
	    },
	    {
		text:'\\(\\exp(a)\\)',
		autocomp : true,
		tooltip:"exponential",
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
		    tooltip:"closed interval",
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
		    tooltip:"half open interval",
		    helpurl:"[).html",
		    latex:"\\left[{},{} \\right[",
		    PG:"[,)"
		},
		{
		    text:'\\((a,b)\\)',
		    tooltip:"open interval",
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
		    tooltip:"infinity",
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
		    tooltip:"natural number",
		    helpurl:"logarithm.html",
		    latex:"e",
		    PG:"e"
		},
		{
		    text:'\\((a)\\)',
		    tooltip:"parentheses",
		    helpurl:"parentheses.html",
		    latex:"()",
		    PG:"()"
		},
		{
		    text:'\\([a]\\)',
		    tooltip:"square brackets",
		    helpurl:"squarebrackets.html",
		    latex:"[]",
		    PG:"[]"
		},
		{
		    text:'\\(\\{a\\}\\)',
		    tooltip:"curly brackets",
		    helpurl:"curlybrackets.html",
		    latex:"\\left \\{  \\right \\}",
		    PG:"{}"
		}
		
	    ]
	},
];

