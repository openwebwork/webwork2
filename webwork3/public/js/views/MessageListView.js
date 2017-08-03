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
      if(this.messageQueue.length>0){
        $("#short-message").show("slide",500);
          this.changeQueue();
          this.isOpen = true;
      }

    },
    close: function(){
      $("#short-message").hide("slide",1000).text("");
      this.messageQueue.shift();
      this.isOpen = false;
    },
    toggle: function (){
      if(this.isOpen){
        this.close();
      } else {
        this.open();
      }
    },
    /* the following two functions run the message queue to
     * display the alert on the navigation bar.
     *
     * The first message opens the message popup and then successive messages
     * 1. add to the this.messageQueue array
     * 2. start a timeout that takes the first item off the messageQueue
          displays it and waits 2000 ms.
       3. Repeat

     */
    changeQueue: function(){
      var self = this;
      var msgPane = $("#short-message");
      var msg = this.messageQueue.shift();
      if(msg){
        msgPane.fadeOut(500,function(){
          msgPane
            .removeClass("alert-success alert-danger")
            .addClass("alert-" + msg.type)
            .text(msg.short)
            .fadeIn(500,function(){
              this.queueTimer = setTimeout(self.changeQueue,2000);
          });
        });
      } else {
        this.close();
      }
    },
    addToQueue: function(msg){
      this.messageQueue.push(msg);
      if(!this.isOpen){
        this.open();
      }
    },
    addMessage: function(msg){
      this.messages.add(new Message(msg));
      this.addToQueue(msg);
    }
  });

  return MessageListView;
});
