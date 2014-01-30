# jQuery Truncate Text Plugin #

Simple plugin that truncates a text either at its end or middle based on a given width or it's elements width. The width calculation takes into account all the original elements css styles like font-size, font-family, font-weight, text-transform, letter-spacing etc.
Additionally if the text has been shortened you can set a class to be appended to the element and/or set the "title" attribute to the original text.

## Usage ##


    $('.class').truncate();

    $('.class').truncate({
    	width: 'auto',
    	token: '&hellip;',
    	side: 'right',
    	multiline: false
    });

## Options ##

- **width** (int) Width to which the text will be shortened *[default: auto]*
- **token** (string) Replacement string for the stripped part *[default: '&amp;hellip;']*
- **side** (string) Side from which shorten. Can either be 'left', 'center', 'right' *[default: right]*
- **addclass** (string) Add a class to the truncated strings element *[default: false]*
- **addtitle** (bool) Add/Set "title" attribute with original text to the truncated strings element *[default: false]*
- **multiline** (bool) Applies truncation to multi-line, wrapped text *[default: false]*

## License ##

Copyright (c) 2012-2013 Thorsten Basse and contributors

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
