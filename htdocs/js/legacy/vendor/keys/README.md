##Usage Guide

You should really just be able to drop in ``keys.js`` and ``keys.css``

To create a keyboard just add 

```javascript
var testKeyboard = new Keys(['a','b','c']);
testKeyboard.build();
```

and everything else should be taken care of

At the moment multiple keyboards will overlap…I'll work on a solution to that o_0