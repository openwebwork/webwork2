/*
*  This is a Message View for delivering messages to the user
*
*/

define(['backbone','underscore','models/MessageList','models/Message'], function(Backbone, _,MessageList,Message){
  var MessageListView = Backbone.View.extend({
    id: "message-pane",
    isOpen: false,
    template: $("#message-pane-template").html(),
    initialize: function () {
      _.bindAll(this,"open","close","addMessage","changeQueue");
      this.messages = new MessageList();  // for storing all messages
      this.messageQueue = [];
    },
    render: function() {
      this.$el.html(this.template);
      return this;
    },
    open: function(){
      var self = this;
      var msg = this.messageQueue[0];
      if(msg){
        $("#short-message").removeClass("alert-success alert-danger")
          .addClass("alert-" + msg.type)
          .text(msg.short).show("slide", 1000);
      }
      this.isOpen = true;
    },
    close: function(){
      $("#short-message").hide("slide",1000).text("");
      this.messageQueue.shift();
      this.isOpen = false;
      delete this.timer;
    },
    toggle: function (){
      if(this.isOpen){
        this.close();
      } else {
        this.open();
      }
    },
    changeQueue: function(){
      var msg = this.messageQueue.shift();
      if(msg){
        this.timer.extend(2500);
        $("#short-message").fadeOut(500);
        setTimeout(function(){
          $("#short-message").text(msg.short).fadeIn(500);
        });

      }
    },
    addToQueue: function(msg){
      this.messageQueue.push(msg);
      this.open();
      if(_.isUndefined(this.timer)){
        this.timer = setAdvancedTimer(this.close, 2500);
      }
      if(this.messageQueue.length>1){
        setTimeout(this.changeQueue,2000);
      }

    },
    addMessage: function(msg){
      this.messages.add(new Message(msg));
      this.addToQueue(msg);
    }
  });

  function setAdvancedTimer(f, delay) {
    var obj = {
      firetime: delay + (+new Date()), // the extra + turns the date into an int
      called: false,
      canceled: false,
      callback: f
    };
    // this function will set obj.called, and then call the function whenever
    // the timeout eventually fires.
    var callfunc = function() { obj.called = true; f(); };
    // calling .extend(1000) will add 1000ms to the time and reset the timeout.
    // also, calling .extend(-1000) will remove 1000ms, setting timer to 0ms if needed
    obj.extend = function(ms) {
      // break early if it already fired
      if (obj.called || obj.canceled) return false;
      // clear old timer, calculate new timer
      clearTimeout(obj.timeout);
      obj.firetime += ms;
      var newDelay = obj.firetime - new Date(); // figure out new ms
      if (newDelay < 0) newDelay = 0;
      obj.timeout = setTimeout(callfunc, newDelay);
      return obj;
    };
    // Cancel the timer...
    obj.cancel = function() {
      obj.canceled = true;
      clearTimeout(obj.timeout);
    };
    // call the initial timer...
    obj.timeout = setTimeout(callfunc, delay);
    // return our object with the helper functions....
    return obj;
  }

  return MessageListView;
});
