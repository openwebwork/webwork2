
(function(){
  "use strict";

    /**
    * Creates an instance of keys, an extra row of buttons for the iOS virtual keyboard in webapps.
    *
    * @constructor
    * @this {keys}
    * @param {Array} syms An array of characters that you want the new keyboard to containt (this can be added to later).
    * @param {Object} options An object containing options for the new keys, this is optional
    */
    var Keys = function(syms, opt){
        this.symbols = syms;
        this.options = opt;
        //we haven't rendered anything yet
        this.board = false;
        this.input = false; //the currently focused input
    };

    Keys.prototype.hasClass = function(cls) {
        return this.board.className.match(new RegExp('(\\s|^)'+cls+'(\\s|$)'));
    }

    Keys.prototype.addClass = function(cls) {
        if (!this.hasClass(cls)) this.board.className += " "+cls;
    }

    Keys.prototype.removeClass = function(cls) {
        if (this.hasClass(cls)) {
            var reg = new RegExp('(\\s|^)'+cls+'(\\s|$)');
            this.board.className=this.board.className.replace(reg,' ');
        }
    }

    /**
     * Updates the orientation of keys display, we define how it handles the orientation in the css
     *
     * @this {keys}
     * @return {keys} just in case.
     */
    Keys.prototype.setOrientation = function(){
        if(window.orientation == 0 || 180){
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
    Keys.prototype.build = function(){
        var self = this;
        //make sure we're on iOS (just iPad for now)
        if (this.options.debug || (navigator.userAgent.indexOf('iPhone') != -1) || (navigator.userAgent.indexOf('iPod') != -1) || (navigator.userAgent.indexOf('iPad') != -1)) {
            if(!self.board){
                self.board = document.createElement('div');
                self.board.id = "keyboard";
            }
            if(!document.getElementById(self.board.id)){
                document.body.appendChild(self.board);
            }

            self.symbols.forEach(function(key){
                var button = document.createElement('a');
                button.value = key;
                button.innerHTML = key;
                button.className = "key";
                button.hidefocus = "true";

                button.addEventListener('touchstart', function(event){
                    event.preventDefault();
                }, false);
                
                /*button.addEventListener('mouseup', function(event){
                    event.preventDefault();
                }, false);*/
                
                
                button.addEventListener('touchend', function(event){

                    //event.preventDefault();
                    //self.input.focus();
                    //have to check for normal input vs just content editable at some point
                    self.input.value += button.value;

                }, false);
                self.board.appendChild(button);
            });

            //get orientation
            self.setOrientation();
            document.body.addEventListener('orientationchange', function(event){
                self.setOrientation();
            }, false);

            var inputs = document.getElementsByTagName('input');
            for(var i = 0; i < inputs.length; i++){
               inputs[i].addEventListener('focus', function(){
                    self.input = this;
                    self.show();
               }, false);
               inputs[i].addEventListener('blur', function(){self.hide()}, false);
            }
            window.addEventListener('scroll', function(){
                if(self.input){
                    self.board.style.top = window.pageYOffset+"px";
                }
            }, false);
        }

        return this;
    };

    Keys.prototype.hide = function(){
        this.removeClass('visible');
        this.input = false;
        this.board.style.top = "-60px";
    }

    Keys.prototype.show = function(){
        var self = this;
        this.addClass('visible');
        self.board.style.top = (window.pageYOffset)+"px";
    }
    
    window.Keys = Keys;
})();