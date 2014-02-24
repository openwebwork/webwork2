/*  SimpleEditor.js:
   This is the base javascript code for the SimplePGEditor.  This sets up the View and ....
  
*/


define(['module','backbone','underscore','views/WebPage','views/LibraryTreeView','models/PGProblem',
    'models/Problem','models/ProblemList','views/ProblemView','views/WWSettingsView','models/Settings',
    'config','moment', 'bootstrap'], 
function(module,Backbone, _,WebPage,LibraryTreeView,PGProblem,Problem,ProblemList,ProblemView,WWSettingsView,Settings,
            config,moment){
var SimpleEditorView = WebPage.extend({
    initialize: function(options) {
        var self = this;
        this.constructor.__super__.initialize.apply(this, [{el: this.el}]);
        _.bindAll(this,"changeAnswerType","checkLogin");
        this.problem = new Problem();
        this.model = new PGProblem();
        this.model.on({"change": this.problemChanged});
        config.settings = new Settings();
        if (module.config().settings){
            config.settings.parseSettings(module.config().settings);
        }
        config.courseSettings.course_id = module.config().course_id;
        this.editorSettingsView = new EditorSettingsView({settings: config.settings});
        //this.model.bind('validated:invalid', this.handleErrors);

        var answerTypes = ['Number','String','Formula','Interval or Inequality',
                'Comma Separated List of Values','Multiple Choice'];
        this.answerTypeCollection = _(answerTypes).map(function(type){return {label: type, value: type};});
        this.updateFields();
        this.render();

        if(module.config().session){
            _.extend(config.courseSettings,module.config().session);
        }
        if(! config.courseSettings.logged_in){
            this.constructor.__super__.requestLogin.call(this, {success: this.checkLogin});
        }
        
    },
    render: function (){
        this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 
        this.libraryTreeView = new LibraryTreeView({el: this.$("#library-subjects"), parent: this, 
                type: "subjects", orientation: "vertical"}); 
        this.libraryTreeView.render();
        this.editorSettingsView.setElement($("#settings-tab")).render();
        this.stickit();
    },
    events: {"click #build-script": "buildScript",
        "change .answer-type": "changeAnswerType",
        "click #testSave": "saveFile"},
    bindings: { ".problem-statement": {observe: "statement", events: ['blur']},
        ".problem-description": {observe: "description", events: ['blur']},
        ".problem-solution": {observe: "solution", events: ['blur']},
        ".problem-author": {observe: "problem_author", events: ['blur']},
        ".institution": {observe: "institution", events: ['blur']},
        ".text-title": {observe: "textbook_title", events: ['blur']},
        ".text-edition": {observe: "textbook_edition", events: ['blur']},
        ".text-author": {observe: "textbook_author", events: ['blur']},
        ".keywords": {observe: "keywords", events: ['blur'], onSet: function(val, options){
            return _(val.split(",")).map(function(kw) { return kw.trim()});
        }},
        ".answer-type": {observe: "answer_type", selectOptions: {collection: "this.answerTypeCollection",
            defaultOption: {label: "Select an Answer Type...", value: null}}}
    },
    checkLogin: function(data){
        if(data.logged_in==1){
            this.closeLogin();
            _.extend(config.courseSettings,data);
        } else {
            this.loginPane.$(".message").html(config.msgTemplate({type: "bad_password"}));
        }
    },
    problemChanged: function(model) {
        console.log(model);
    },
    renderProblem: function(){
      console.log("rendering the problem");
      this.showProblemView = new ShowProblemView({model: this.problem, el: $("#viewer-tab")});
      this.showProblemView.render();
      this.$("a[href='#viewer-tab']").tab("show");

    },
    updateFields: function () {
        this.model.set({problem_author: config.settings.findWhere({"var": "editor{author}"}).get("value"),
            institution: config.settings.findWhere({"var": "editor{authorInstitute}"}).get("value"),
            textbook_title: config.settings.findWhere({"var": "editor{textTitle}"}).get("value"),
            textbook_edition: config.settings.findWhere({"var": "editor{textEdition}"}).get("value"),
            textbook_author: config.settings.findWhere({"var": "editor{textAuthor}"}).get("value"),
            date: moment().format("MM/DD/YYYY")});
    },
    changeAnswerType: function(evt){
        switch($(evt.target).val()){
            case "Number":
                this.answerView = (new NumberAnswerView({el: $("#answerArea")})).render();
                break;
            case "String":
                this.answerView = (new StringAnswerView({el: $("#answerArea")})).render();
                break;
            case "Formula":
                this.answerView = (new FormulaAnswerView({el: $("#answerArea")})).render();
                break;
            case "Interval or Inequality":
                this.answerView = (new IntervalAnswerView({el: $("#answerArea")})).render();
                break;
            case "Comma Separated List of Values":
                this.answerView = (new ListAnswerView({el: $("#answerArea")})).render();
                break;
            case "Multiple Choice":
                this.answerView = (new MultipleChoiceAnswerView({el: $("#answerArea")})).render();
                break;
            
            
        }
    },        
    saveFile: function(){
        var self = this;
        if(!this.buildScript()){
            return;
        }

        var params = _.pick(this.model.attributes,"pgSource");

        $.ajax({url: config.urlPrefix+"renderer/courses/" + config.courseSettings.course_id+"/problems/0",
            data: params,
            type: "POST",
            success: function(response){
               self.problem.set({data: response.text});
               self.renderProblem();
            }
        })

    },
    buildScript: function (){       
        // check that everything should be filled in
        var self = this;
        var errors = this.model.validate();
        var answerErrors;
        if(this.answerView && this.answerView.model){
            answerErrors = this.answerView.model.validate();
        } 
        if(errors || answerErrors){
            var bindings = _.chain(this.bindings).keys()
                .map(function(key) { return [self.bindings[key].observe,key];}).object().value();

            _(_(errors||{}).keys()).each(function(key){
                self.$(bindings[key]).closest("div").addClass("has-error");
            });

            var answerBindings = typeof(this.answerView)==="undefined" ? {} :  _.chain(this.answerView.bindings).keys()
                .map(function(key) { return [self.answerView.bindings[key],key];}).object().value();

            _(_(answerErrors || {}).keys()).each(function(key){
                self.answerView.$(answerBindings[key]).closest("div").addClass("has-error");
            })


            this.messagePane.addMessage({type: "danger", short: "The following are required."});
            
            return false;
        }

        var pgTemplate = _.template($("#pg-template").text());
        var fields = this.libraryTreeView.fields.attributes;
        _.extend(fields,{setup_section: this.answerView.getSetupText(this.model.attributes),
            statement_section: this.answerView.getStatementText(this.model.attributes),
            answer_section: this.answerView.getAnswerText()});

        _.extend(fields,this.model.attributes);
        this.model.set("pgSource",pgTemplate(fields));
        $("#problem-code").text(this.model.get("pgSource"));
      
        return true;
    },
    handleErrors: function(model,errors){
        console.log(errors);
    }
});

var ShowProblemView = Backbone.View.extend({
    initialize: function(options) {
      _.bindAll(this,'render');
      this.collection = new ProblemList();  // this is done as a hack b/c Problem View assumes that all problems 
                                            // are in a ProblemList. 
      this.collection.add(this.model);
      problemViewAttrs = {reorderable: false, showPoints: false, showAddTool: false, showEditTool: false,
                showRefreshTool: false, showViewTool: false, showHideTool: false, deletable: false, draggable: false,
                displayMode: "MathJax"};
      this.problemView = new ProblemView({model: this.model, viewAttrs: problemViewAttrs});
    },
    render: function (){
        this.$(".problemList").html("").append(this.problemView.render().el);
    },
    setProblem: function(problem){
        this.model = problem;
    }
});

var EditorSettingsView = WWSettingsView.extend({
    initialize: function (options) {
        _.bindAll(this,'render');
        this.settings = options.settings.filter(function (setting) {return setting.get("category")==='Editor'});
        this.constructor.__super__.initialize.apply(this,[{settings: this.settings}]);
     }, 
     render: function () {
        //$("#settings").html(_.template($("#settings-template").html()));
        this.constructor.__super__.render.apply(this,[{settings: this.settings}]);
     }
});

var AnswerChoiceView = Backbone.View.extend({
    render: function(){
        this.$el.html(this.viewTemplate);
        this.stickit();
        return this;
    },
    getSetupText: function (opts) {
        return this.pgSetupTemplate(opts? _.extend(opts,this.model.attributes): this.model.attributes);
    },
    getStatementText: function(opts){
        return this.pgTextTemplate(_.extend(opts,this.model.attributes));  
    },
    getAnswerText: function (){
        return this.pgAnswerTemplate(this.model.attributes);
    }
});

var NumberAnswerView = AnswerChoiceView.extend({
    initialize: function () {
        this.viewTemplate = _.template($("#number-option-template").html());    
        this.pgSetupTemplate = _.template($("#number-option-pg-setup").html());
        this.pgTextTemplate =_.template($("#number-option-pg-text").html());
        this.pgAnswerTemplate = _.template($("#number-option-pg-answer").html());
        var ThisModel = Backbone.Model.extend({
            defaults: {
                answer: "", require_units: false
            },
            validation: {answer: {required: true}}});
        this.model = new ThisModel();
    },
    bindings: { ".answer": "answer", ".require-units": "require_units"},
});

var StringAnswerView = AnswerChoiceView.extend({
    initialize: function () {
        this.viewTemplate = _.template($("#string-option-template").html());    
        this.pgSetupTemplate = _.template($("#string-option-pg-setup").html());
        this.pgTextTemplate =_.template($("#string-option-pg-text").html());
        this.pgAnswerTemplate = _.template($("#string-option-pg-answer").html());
        var ThisModel = Backbone.Model.extend({defaults: {answer: ""}});
        this.model = new ThisModel();
    },
    bindings: { ".answer": "answer"},
});

var FormulaAnswerView = AnswerChoiceView.extend({
    initialize: function () {
        this.viewTemplate = _.template($("#formula-option-template").html());    
        this.pgSetupTemplate = _.template($("#formula-option-pg-setup").html());
        this.pgTextTemplate =_.template($("#formula-option-pg-text").html());
        this.pgAnswerTemplate = _.template($("#formula-option-pg-answer").html());
        var ThisModel = Backbone.Model.extend({defaults: {answer: "", require_units: false, variables: ""}});
        this.model = new ThisModel();
    },
    bindings: { ".answer": "answer", ".require-units": "require_units", ".variables" : "variables"},
});


var IntervalAnswerView = AnswerChoiceView.extend({
    initialize: function () {
        this.viewTemplate = _.template($("#interval-option-template").html());    
        this.pgSetupTemplate = _.template($("#interval-option-pg-setup").html());
        this.pgTextTemplate =_.template($("#interval-option-pg-text").html());
        this.pgAnswerTemplate = _.template($("#interval-option-pg-answer").html());
        var ThisModel = Backbone.Model.extend({defaults: {answer: "", allow_interval: false, allow_inequality: false}});
        this.model = new ThisModel();
    },
    bindings: { ".answer": "answer", ".allow-interval-notation": "allow_interval",
         ".allow-inequality-notation" : "allow_inequality"},
});

var ListAnswerView = AnswerChoiceView.extend({
    initialize: function () {
        this.viewTemplate = _.template($("#list-option-template").html());    
        this.pgSetupTemplate = _.template($("#list-option-pg-setup").html());
        this.pgTextTemplate =_.template($("#list-option-pg-text").html());
        this.pgAnswerTemplate = _.template($("#list-option-pg-answer").html());
        var ThisModel = Backbone.Model.extend({defaults: {answer: ""}});
        this.model = new ThisModel();
    },
    bindings: { ".answer": "answer"},
});

var MultipleChoiceAnswerView = AnswerChoiceView.extend({
    initialize: function () {
        this.viewTemplate = _.template($("#multiple-choice-option-template").html());    
        this.pgSetupTemplate = _.template($("#multiple-choice-option-pg-setup").html());
        this.pgTextTemplate =_.template($("#multiple-choice-option-pg-text").html());
        this.pgAnswerTemplate = _.template($("#multiple-choice-option-pg-answer").html());
        var ThisModel = Backbone.Model.extend({defaults: {answer: "", extra_choice: "", last_choice: "", use_last_choice: false}});
        this.model = new ThisModel();
    },
    bindings: { ".answer": "answer", ".extra-choice": "extra_choice", ".last-choice": "last_choice",
        ".use-last-choice": "use_last_choice"},
});


new SimpleEditorView({el: $("div#mainDiv")});
});