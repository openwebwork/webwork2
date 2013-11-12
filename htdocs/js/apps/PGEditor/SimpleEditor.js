/*  SimpleEditor.js:
   This is the base javascript code for the SimplePGEditor.  This sets up the View and ....
  
*/


require(['Backbone', 
    'underscore',
    'WebPage',
    '../../lib/views/LibraryTreeView',
    '../../lib/models/PGProblem',
    '../../lib/models/Problem',
    '../../lib/models/ProblemList',
    '../../lib/views/ProblemView',
    '../../lib/views/WWSettingsView',
    '../../lib/models/Settings',
    'bootstrap'
    ], 
function(Backbone, _,WebPage,LibraryTreeView,PGProblem,Problem,ProblemList,ProblemView,WWSettingsView,Settings){
    var SimpleEditorView = WebPage.extend({
        initialize: function() {
            this.constructor.__super__.initialize.apply(this, {el: this.el});
            _.bindAll(this,"render","renderProblem","postSettingsFetched");
            this.problem = new PGProblem();
            this.model = new Problem();
            var urlSplit = location.href.split("/");
            var index = _(urlSplit).indexOf("SimplePGEditor");
            this.setInfo = {name: urlSplit[index+1], number: urlSplit[index+2] };
            this.problem.on("saveSuccess",this.renderProblem);
            this.settings = new Settings();  // need to get other settings from the server.  
            this.settings.fetch();
            this.settings.on("fetchSuccess",this.postSettingsFetched);

        },
        render: function (){
            this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 
            this.libraryTreeView = new LibraryTreeView({el: this.$("#library-subjects"), parent: this, type: "allLibSubjects"}); 
            this.libraryTreeView.render();
            this.$("#author-info-container").html($("#author-info-template").html());
            this.$("#textbook-info-container").html($("#textbook-info-template").html());
            this.editorSettingsView.render();
        },
        events: {"click #build-script": "buildScript",
            "change #answerType-select": "changeAnswerType",
            "click #testSave": "saveFile"},
        renderProblem: function(){
          console.log("rendering the problem");
          this.model.set("path",this.problem.get("path"));
          this.showProblemView = new ShowProblemView({model: this.model, el: $("#viewer-tab")});
          this.showProblemView.render();
          this.$("a[href='#viewer-tab']").tab("show");

        },
        postSettingsFetched: function(){
            this.editorSettingsView = new EditorSettingsView({el: $("#settings-tab"), settings: this.settings});
            console.log(this.settings);
            this.render();
        },
        changeAnswerType: function(evt){

            var type = $(evt.target).find("option:selected").data("type");
            console.log(type);
            this.answerType = new AnswerChoiceView({template: $(type+"-template"), el: $("#answerArea")});
            this.answerType.render(); 
        },        
        saveFile: function(){
            console.log("Saving the file");
            this.problem.set("path","set"+this.setInfo.name+"/Problem" + this.setInfo.number + ".pg");
            this.problem.save(this.buildScript());

        },
        buildScript: function (){           
            var pgTemplate = _.template($("#pg-template").text())
              , inputProblemDescription = $("#ProblemDescription-input").val()
              , inputProblemStatement = $("#ProblemStatement-input").val()
              , inputAuthor = $("#Author-input").val()
              , inputInstitution = $("#Institution-input").val()
              , inputTitleText1 = $("#TitleText1-input").val()
              , inputEditionText1 = $("#EditionText1-input").val()
              , inputAuthorText1 = $("#AuthorText1-input").val()
              , inputSection1 = $("#Section1-input").val()
              , inputProblem1 = $("#Problem1-input").val()
              , inputAnswer = $("#Answer-input").val()
              , inputProblemSolution = $("#ProblemSolution-input").val()
            
              , answer_type = $("#answerType-select option:selected").text()

              , _type = $("#answerType-select option:selected").data("type")
              , _withUnits = $("#requireUnitsCheckBox").prop("checked")
              , _allowInterval = $("#allowIntervalCheckBox").prop("checked")
              , _allowInequality = $("#allowInequalityCheckBox").prop("checked")
              , _variableList = $("#VariableList-input").val()
              , _inputExtraMultipleChoice = $("#ExtraMultipleChoice-input").val()
              , _lastChoice = $("#LastChoice-input").val()
              , _lastChoiceOption = $("#LastChoiceCheckBox").prop("checked")
              , _extraChoiceString;
            if(_inputExtraMultipleChoice){
              var _extraChoiceString = _inputExtraMultipleChoice.split(",").join('","');
            };
            if(_variableList){
               var _variables = _variableList.split(",").join("=>Real,")+"=>Real"; 
            };


            var _setupSection = _.template($(_type + "-pg-setup").text(),{
                        answer: inputAnswer
                        , withUnits: _withUnits
                        , problemStatement: inputProblemStatement
                        , allowInterval: _allowInterval
                        , allowInequality: _allowInequality
                        , variables: _variables
                        , extraChoiceString: _extraChoiceString
                        , lastChoice: _lastChoice
                        , lastChoiceOption: _lastChoiceOption})
              , _textSection = _.template($(_type + "-pg-text").text(),{
                        problemStatement: inputProblemStatement
                        , allowInterval: _allowInterval
                        , allowInequality: _allowInequality})
              , _answerSection = _.template($(_type + "-pg-answer").text(),{});            


            var fields = {ProblemDescription:inputProblemDescription,
                                  DBsubject:$("#DBsubject-select option:selected").val(),
                                  DBchapter:$("#DBchapter-select option:selected").val(),
                                  Author:inputAuthor,
                                  Institution:inputInstitution,
                                  TitleText1:inputTitleText1,
                                  EditionText1:inputEditionText1,
                                  AuthorText1:inputAuthorText1,
                                  Section1:inputSection1,
                                  Problem1:inputProblem1,
                                  ProblemStatement:inputProblemStatement,
                                  SetupSection:_setupSection,
                                  TextSection:_textSection,
                                  AnswerSection:_answerSection,
                                  ProblemSolution:inputProblemSolution
                                  }
                
            console.log(fields);
               
            $("#problem-code").text(pgTemplate(fields));
            
            return pgTemplate(fields);
          
        }
    });

    var ShowProblemView = Backbone.View.extend({
        initialize: function() {
          _.bindAll(this,'render');
          this.model.set("data","");
          this.collection = new ProblemList();  // this is done as a hack b/c Problem View assumes that all problems 
                                                // are in a ProblemList. 
          this.collection.add(this.model);
          problemViewAttrs = {reorderable: false, showPoints: false, showAddTool: false, showEditTool: false,
                    showRefreshTool: false, showViewTool: false, showHideTool: false, deletable: false, draggable: false};
          this.problemView = new ProblemView({model: this.model, viewAttrs: problemViewAttrs});
        },
        render: function (){
            this.$(".problemList").html("").append(this.problemView.render().el);
        }
    });

    var EditorSettingsView = WWSettingsView.extend({
        initialize: function () {
            _.bindAll(this,'render');
            this.settings = options.settings.filter(function (setting) {return setting.get("category")==='Editor'});
            this.constructor.__super__.initialize.apply(this,{settings: this.settings});
         }, 
         render: function () {
            //$("#settings").html(_.template($("#settings-template").html()));
            this.constructor.__super__.render.apply(this);
         }
    });

    var AnswerChoiceView = Backbone.View.extend({
        initialize: function(){
            _.bindAll(this,'render');
            this.theTemplate = options.template.html()
        },
        render: function(){
            this.$el.html(_.template(this.theTemplate));
            
        },
        getAnswer: function(){
            return this.$("#answer").val()
        },
        getOptions: function () {
            return $(".answer-option").map(function(i,elem) { return {id: $(elem).attr("id"), value: $(elem).val()};}); 
        }

    })
    new SimpleEditorView({el: $("div#mainDiv")});
});