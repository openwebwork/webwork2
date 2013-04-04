/*  SimpleEditor.js:
   This is the base javascript code for the SimplePGEditor.  This sets up the View and ....
  
*/

require.config({
    paths: {
        "Backbone":             "/webwork2_files/js/vendor/backbone/backbone",
        "backbone-validation":  "/webwork2_files/js/vendor/backbone/modules/backbone-validation",
        "jquery-ui":            "/webwork2_files/js/vendor/jquery/jquery-ui",
        "underscore":           "/webwork2_files/js/vendor/underscore/underscore",
        "jquery":               "/webwork2_files/js/vendor/jquery/jquery",
        "bootstrap":            "/webwork2_files/js/vendor/bootstrap/js/bootstrap",
        "WebPage":              "/webwork2_files/js/lib/views/WebPage",
        "config":               "/webwork2_files/js/apps/config",
        "Closeable":            "/webwork2_files/js/lib/views/Closeable",
        "XDate":                "/webwork2_files/js/vendor/other/xdate"        
    },


urlArgs: "bust=" +  (new Date()).getTime(),
    waitSeconds: 15,
    shim: {
        'jquery-ui': ['jquery'],
        'underscore': { exports: '_' },
        'Backbone': { deps: ['underscore', 'jquery'], exports: 'Backbone'},
        'bootstrap':['jquery'],
        'backbone-validation': ['Backbone'],
        'XDate':{ exports: 'XDate'},
        'config': ['XDate']
        }
});

require(['Backbone', 
    'underscore',
    'WebPage',
    '../../lib/views/LibraryTreeView',
    'bootstrap'
    ], 
function(Backbone, _,WebPage,LibraryTreeView){
    var SimpleEditorView = WebPage.extend({
        initialize: function() {
            this.constructor.__super__.initialize.apply(this, {el: this.el});
            this.render();

        },
        render: function (){
            this.constructor.__super__.render.apply(this);  // Call  WebPage.render(); 
            this.libraryTreeView = new LibraryTreeView({el: this.$("#library-subjects"), parent: this, type: "allLibSubjects"}); 
            this.libraryTreeView.render();
            this.$("#author-info-container").html($("#author-info-template").html());
            this.$("#textbook-info-container").html($("#textbook-info-template").html());
        },
        events: {"click #build-script": "buildScript",
            "change #answerType-select": "changeAnswerType"},
            
        changeAnswerType: function(evt){

            var type = $(evt.target).find("option:selected").data("type");
            console.log(type);
            this.answerType = new AnswerChoiceView({template: $(type+"-template"), el: $("#answerArea")});
            this.answerType.render(); 
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
            
          
        }
    });

    var AnswerChoiceView = Backbone.View.extend({
        initialize: function(){
            _.bindAll(this,'render');
            this.theTemplate = this.options.template.html()
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