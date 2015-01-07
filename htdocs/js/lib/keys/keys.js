(function () {
    "use strict";

    /**
     * Creates an instance of keys, an extra row of buttons for the iOS virtual keyboard in webapps.
     *
     * @constructor
     * @this {keys}
     * @param {Array} syms An array of characters that you want the new keyboard to contain (this can be added to later).
     * @param {Object} options An object containing options for the new keys, this is optional
     */
    var Keys = function (syms, opt) {
        this.symbols = syms;
        this.options = opt ? opt : {};
        //we haven't rendered anything yet
        this.board = false;
        this.input = false; //the currently focused input
    };

    Keys.prototype.hasClass = function (cls) {
        return this.board.className.match(new RegExp('(\\s|^)' + cls + '(\\s|$)'));
    }

    Keys.prototype.addClass = function (cls) {
        if (!this.hasClass(cls)) this.board.className += " " + cls;
    }

    Keys.prototype.removeClass = function (cls) {
        if (this.hasClass(cls)) {
            var reg = new RegExp('(\\s|^)' + cls + '(\\s|$)');
            this.board.className = this.board.className.replace(reg, ' ');
        }
    }

    /**
     * Updates the orientation of keys display, we define how it handles the orientation in the css
     *
     * @this {keys}
     * @return {keys} just in case.
     */
    Keys.prototype.setOrientation = function () {
        if (window.orientation == 0 || 180) {
            this.removeClass("landscape");
            this.addClass("portrait");
        } else {
            this.removeClass("portrait");
            this.addClass("landscape");
        }
        return this;
    }

    /**
     * Creates and or renders the board and respective keys,
     * including listeners, orientation etc.
     *
     * @self {keys}
     * @return {keys} just in case.
     */
    Keys.prototype.build = function () {
        var self = this;
        //make sure we're on iOS (just iPad for now)
        if (this.options.debug || (navigator.userAgent.indexOf('iPhone') != -1) || (navigator.userAgent.indexOf('iPod') != -1) || (navigator.userAgent.indexOf('iPad') != -1)) {
            if (!self.board) {
                self.board = document.createElement('div');
                self.board.id = "keyboard";
            }
            if (!document.getElementById(self.board.id)) {
                document.body.appendChild(self.board);
                self.board.addEventListener('selectstart', function(event){event.preventDefault(); return false;}, false);
                self.board.addEventListener('select', function(event){event.preventDefault(); return false;}, false);
            }

            self.symbols.forEach(function (key) {
                var button = document.createElement('a');

                if(!key.value && !key.display){
                    button.value = key;
                    button.innerHTML = key;
                } else {
                    button.value = key.value;
                    button.innerHTML = key.display;
                }

                button.className = "key";
                
                var insertAtCaret = function(el,text) {
                    var txtarea = el;
                    var scrollPos = txtarea.scrollTop;
                    var strPos = 0;
                    strPos = txtarea.selectionStart;
                
                    var front = (txtarea.value).substring(0,strPos);  
                    var back = (txtarea.value).substring(strPos,txtarea.value.length); 
                    txtarea.value=front+text+back;
                    strPos = strPos + text.length;
                    txtarea.selectionStart = strPos;
                    txtarea.selectionEnd = strPos;
                    txtarea.focus();
                    txtarea.scrollTop = scrollPos;
                }

                button.hitButton = function (event) {
                    button.removeEventListener('touchend', button.hitButton, false);
                    event.preventDefault();

                    if (self.input.replaceRange) {
                        var cursor_temp = self.input.getCursor();
                        self.input.replaceRange(button.value, cursor_temp);
                        /*var cursor_temp = self.input.getCursor();
                        self.input.setValue(self.input.getValue() + button.value);
                        cursor_temp.ch += 1;
                        self.input.setCursor(cursor_temp);*/
                    } else {
                        insertAtCaret(self.input, button.value);
                    }

                    if(key.behavior){
                        key.behavior(self.input)
                    };

                };
                var onTouchStart = function(){
                    button.addEventListener('touchend', button.hitButton, false);
                };
                
                button.addEventListener('touchstart', onTouchStart, false);
                button.addEventListener('touchmove', function(){
                    button.removeEventListener('touchend', button.hitButton, false);
                }, false);
                
                button.addEventListener('mousedown', function (event) {
                  event.preventDefault();
                }, false);
                button.addEventListener('mouseup', function (event) {
                  event.preventDefault();
                }, false);
                if (self.options.debug && !((navigator.userAgent.indexOf('iPhone') != -1) || (navigator.userAgent.indexOf('iPod') != -1) || (navigator.userAgent.indexOf('iPad') != -1))) {
                  button.addEventListener('click', button.hitButton, false);
                }

                self.board.appendChild(button);
            });


            //get orientation
            self.setOrientation();
            document.body.addEventListener('orientationchange', function (event) {
                self.setOrientation();
            }, false);

            var inputs = document.getElementsByTagName('input');
            for (var i = 0; i < inputs.length; i++) {
                inputs[i].addEventListener('focus', function () {
                    self.input = this;
                    self.show();
                }, false);
                inputs[i].addEventListener('blur', function () {
                    self.hide()
                }, false);
            }
            if (this.options.codemirrors) {
                for (var i = 0; i < this.options.codemirrors.length; i++) {
                    var currentMirror = this.options.codemirrors[i];
                    currentMirror.setOption('onFocus', function () {
                        self.input = currentMirror;
                        self.show();
                    });
                    currentMirror.setOption('onBlur', function () {
                        self.hide();
                    });
                }
            }

            window.addEventListener('scroll', function () {
                if (self.input) {
                    self.board.style.top = window.pageYOffset + "px";
                    self.board.style.left = window.pageXOffset + "px";
                }
            }, false);
            window.addEventListener('resize', function () {
                if (self.input) {
                    self.board.style.top = window.pageYOffset + "px";
                    self.board.style.left = window.pageXOffset + "px";
                    self.board.style.width = window.innerWidth + "px";
                }
            }, false);
        }

        return this;
    };

    Keys.prototype.hide = function () {
        this.removeClass('visible');
        this.input = false;
        this.board.style.top = "-60px";
        if(this.options.onHide){
            this.options.onHide();
        }
    }

    Keys.prototype.show = function () {
        var self = this;
        this.addClass('visible');
        self.board.style.top = (window.pageYOffset) + "px";
        self.board.style.left = window.pageXOffset + "px";
        self.board.style.width = window.innerWidth + "px";
        if(self.options.onShow){
            self.options.onShow();
        }
    }

    window.Keys = Keys;
})();