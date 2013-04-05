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

 //paths: {
 //       "Backbone":             "../../../js/lib/vendor/backbone",
 //       "backbone-validation":  "../../../js/lib/vendor/backbone-validation",
 //       "jquery-ui":            "../../../js/lib/vendor/jquery-ui",
 //       "underscore":           "../../../js/lib/vendor/underscore/underscore",
 //       "jquery":               "../../../js/lib/vendor/jquery/jquery",
 //       "bootstrap":            "../../../js/lib/vendor/bootstrap/js/bootstrap",
 //       "util":                 "../../../js/lib/webwork/util",
 //       "XDate":                "../../../js/lib/vendor/xdate",
 //       "WebPage":              "../../../js/lib/webwork/views/WebPage",
 //       "config":               "../../../js/apps/config",
 //       "Closeable":            "../../../js/lib/webwork/views/Closeable"
 //   },

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
              , _variableList = $("#VariableList-input").val();

            if(_variableList){
               var _variables = _variableList.split(",").join("=>Real,")+"=>Real"; 
            }


            var _setupSection = _.template($(_type + "-pg-setup").text(),{answer: inputAnswer, withUnits: _withUnits, 
                        variables: _variables})
              , _textSection = _.template($(_type + "-pg-text").text(),{problemStatement: inputProblemStatement})
              , _answerSection = _.template($(_type + "-pg-answer").text(),{});            


            /* if (answer_type == "Number") {
                if ($("#requireUnitsCheckBox").prop("checked")){
                    _setupSection = "Context(\"Numeric\");\n \n$answer = NumberWithUnits(\" ".concat(inputAnswer).concat("\");");
                    _textSection = "Context()->texStrings;\nBEGIN_TEXT \n ".concat(inputProblemStatement).concat("$BR $BR\nAnswer:\\{ans_rule(55)\\} \\{AnswerFormatHelp(\"numbers\")\\}\n\nEND_TEXT\nContext()->normalStrings;");
                    _answerSection = "ANS($answer->cmp);";
     
                } else {
                    _setupSection = "Context(\"Numeric\");\n \n$answer = Compute(\" ".concat(inputAnswer).concat("\");");
                    _textSection = "Context()->texStrings;\nBEGIN_TEXT \n ".concat(inputProblemStatement).concat("$BR $BR\nAnswer:\\{ans_rule(55)\\} \\{AnswerFormatHelp(\"numbers\")\\}\n\nEND_TEXT\nContext()->normalStrings;");
                    _answerSection = "ANS($answer->cmp);";
                }
            } else if (answer_type == "String") {
                _setupSection = "Context(\"Numeric\");\nContext()->strings->add(\""+inputAnswer+"\"=>{});\n \n$answer = Compute(\" ".concat(inputAnswer).concat("\");");
                _textSection = "Context()->texStrings;\nBEGIN_TEXT \n ".concat(inputProblemStatement).concat("$BR $BR\nAnswer:\\{ans_rule(55)\\} \\{AnswerFormatHelp(\"numbers\")\\}\n\nEND_TEXT\nContext()->normalStrings;");
                _answerSection = "ANS($answer->cmp);";
            } else if (answer_type == "Formula") {
                if ($("#requireUnitsCheckBox").prop("checked")){
                    var inputVariableList = $("#VariableList-input").val();
                    var VariableListArray = inputVariableList.split(",");
                    var VariableListString = "Context()->variables->are(";
                    VariableListString = VariableListArray.join('=>\"Real\",\n');
                    _setupSection = "Context(\"Numeric\");\nContext()->variables->are("+VariableListString+"=>\"Real\");"+" \n$answer = FormulaWithUnits(\" ".concat(inputAnswer).concat("\");");
                    _textSection = "Context()->texStrings;\nBEGIN_TEXT \n ".concat(inputProblemStatement).concat("$BR $BR\nAnswer:\\{ans_rule(55)\\} \\{AnswerFormatHelp(\"formulas\")\\}\n\nEND_TEXT\nContext()->normalStrings;");
                    _answerSection = "ANS($answer->cmp);";
                } else {
                    var inputVariableList = $("#VariableList-input").val();
                    var VariableListArray = inputVariableList.split(",");
                    var VariableListString = "Context()->variables->are(";
                    VariableListString = VariableListArray.join('=>\"Real\",\n');
                    _setupSection = "Context(\"Numeric\");\nContext()->variables->are("+VariableListString+"=>\"Real\");"+" \n$answer = Compute(\" ".concat(inputAnswer).concat("\");");
                    _textSection = "Context()->texStrings;\nBEGIN_TEXT \n ".concat(inputProblemStatement).concat("$BR $BR\nAnswer:\\{ans_rule(55)\\} \\{AnswerFormatHelp(\"formulas\")\\}\n\nEND_TEXT\nContext()->normalStrings;");
                    _answerSection = "ANS($answer->cmp);";
                }
            } else if (answer_type == "Interval or Inequality") {
                if ($("#allowIntervalCheckBox").prop("checked") && !$("#allowInequalityCheckBox").prop("checked")){
                    _setupSection = "Context(\"Interval\");\n \n$answer = Compute(\" ".concat(inputAnswer).concat("\");");
                    _textSection = "Context()->texStrings;\nBEGIN_TEXT \n ".concat(inputProblemStatement).concat("$BR $BR\nAnswer:\\{ans_rule(55)\\} \\{AnswerFormatHelp(\"interval\")\\}\n\nEND_TEXT\nContext()->normalStrings;");
                    _answerSection = "ANS($answer->cmp);";                    
                } else if (!$("#allowIntervalCheckBox").prop("checked") && $("#allowInequalityCheckBox").prop("checked")){
                    _setupSection = "Context(\"Inequalities-Only\");\n \n$answer = Compute(\" ".concat(inputAnswer).concat("\");");
                    _textSection = "Context()->texStrings;\nBEGIN_TEXT \n ".concat(inputProblemStatement).concat("$BR $BR\nAnswer:\\{ans_rule(55)\\} \\{AnswerFormatHelp(\"inequalities\")\\}$BR\n\nNote:  Use NONE for the empty set.\nEND_TEXT\nContext()->normalStrings;");
                    _answerSection = "ANS($answer->cmp);";
                } else {
                    _setupSection = "Context(\"Inequalities\");\n \n$answer = Compute(\" ".concat(inputAnswer).concat("\");");
                    _textSection = "Context()->texStrings;\nBEGIN_TEXT \n ".concat(inputProblemStatement).concat("$BR $BR\nAnswer:\\{ans_rule(55)\\} \\{AnswerFormatHelp(\"inequalities\")\\}$BR\n\nNote:  Use NONE or {} for the empty set.\nEND_TEXT\nContext()->normalStrings;");
                    _answerSection = "ANS($answer->cmp);";

                }
            } else if (answer_type == "Comma Separated List of Values") {
                _setupSection = "Context(\"Numeric\");\n \n$answer = List(\" ".concat(inputAnswer).concat("\");");
                _textSection = "Context()->texStrings;\nBEGIN_TEXT \n ".concat(inputProblemStatement).concat("$BR $BR\nAnswer:\\{ans_rule(55)\\} \\{AnswerFormatHelp(\"numbers\")\\}\n$BR\nEnter answers as a comma separated list.\nEND_TEXT\nContext()->normalStrings;");
                _answerSection = "ANS($answer->cmp);";
            } else if (answer_type == "Multiple Choice") {
                var inputExtraMultipleChoice = $("#ExtraMultipleChoice-input").val();
                var ExtraChoiceArray = inputExtraMultipleChoice.split(",");
                var inputLastChoice = $("#LastChoice-input").val();
                var LastChoiceString = "";
                if ($("#LastChoiceCheckBox").prop("checked")){
                LastChoiceString = "$mc->makeLast(\""+inputLastChoice+"\");"
                };
                ExtraChoiceString = ExtraChoiceArray.join('","');         
                _setupSection = "$mc = new_multiple_choice();\n$mc->qa(\"".concat(inputProblemStatement).concat("\",\"").concat(inputAnswer).concat("\");\n$mc->extra(\"").concat(ExtraChoiceString).concat("\");\n").concat(LastChoiceString);
                _textSection = "Context()->texStrings;\nBEGIN_TEXT \n\\{$mc->print_q()\\}\n$BR\n\\{$mc->print_a()\\}\nEND_TEXT\nContext()->normalStrings;";
                _answerSection = "ANS(radio_cmp($mc->correct_ans()));";
            } */

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