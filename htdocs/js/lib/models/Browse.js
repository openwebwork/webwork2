define(['Backbone', 'underscore','config', './ProblemList', './Problem'], function(Backbone, _, config, ProblemList, Problem){
    /**
     *
     * @constructor
     */
    var Browse = Backbone.Model.extend({
    
        defaults:{
            library_subject:null,
            library_chapter:null,
            library_section:null
        },
    
        initialize: function(){
            var self = this;
            this.defaultRequestObject = {
            };
            _.defaults(this.defaultRequestObject, config.requestObject);
            
            this.set('problems', new ProblemList());
            this.set('library_subjects', new Array());
            this.set('library_chapters', new Array());
            this.set('library_sections', new Array());
            
            this.on('change:library_subject', function(){
               self.set('library_chapter', null);
               self.set('library_section', null);
               self.getAllDBchapters();
               self.getSectionListings();
            });
            
            this.on('change:library_chapter', function(){
                self.set('library_section', null);
               self.getSectionListings();
            });
            
            this.getAllDBsubjects();
            this.getAllDBchapters();
            this.getSectionListings();
        },
    
        go: function (callback) {
            var requestObject = {
                xml_command: "searchLib",
                subcommand: "getDBListings",
                library_subjects: this.get('library_subject'),
                library_chapters: this.get('library_chapter'),
                library_sections: this.get('library_section')
            };
            _.defaults(requestObject, config.requestObject);
            var self = this;
            $.post(config.webserviceURL, requestObject, function (data) {
                var response = $.parseJSON(data);
                var results = response.result_data;//.split(",");
                
                var newSearchResult = new Array();
                for (var i = 0; i < results.length; i++) {
                    newSearchResult.push(new Problem({path: results[i]}));
                }
                //self.get('problems').reset(newSearchResult);
                callback(newSearchResult);
            });
        },
    
        updateSubcategory: function (subcommand, category) {
            var self = this;
            var requestObject = {
                xml_command: "searchLib",
                subcommand: subcommand,
                library_subjects: this.get('library_subject'),
                library_chapters: this.get('library_chapter'),
                library_sections: this.get('library_section')
            };
            _.defaults(requestObject, config.requestObject);
            $.post(config.webserviceURL, requestObject, function (data) {
                var response = $.parseJSON(data);
                console.log(response);
                self.set(category, response.result_data);
            });
        },
        
        getAllDBsubjects: function(){
            this.updateSubcategory('getAllDBsubjects', 'library_subjects');
        },
        
        getAllDBchapters: function(){
            this.updateSubcategory('getAllDBchapters', 'library_chapters');
        },
        
        getSectionListings: function(){
            this.updateSubcategory('getSectionListings', 'library_sections');
        }
    });
    
    
    
    
    /*
    function Search() {
        this.problems = new Array();
        this.subjectBox = document.getElementById("subjectBox");
        this.chaptersBox = document.getElementById("chaptersBox");
        this.sectionsBox = document.getElementById("sectionsBox");
        this.textbooksBox = document.getElementById("textbooksBox");
        this.textChaptersBox = document.getElementById("textChaptersBox");
        this.textSectionsBox = document.getElementById("textSectionsBox");
        this.keywordsBox = document.getElementById("keywordsBox");
    
    
        var workAroundTheClosure = this;
        subjectBox.addEventListener("change", function () {
            //update inputs
            workAroundTheClosure.updateInputs();
            //update lists
            workAroundTheClosure.updateChaptersBox();
            workAroundTheClosure.updateSectionsBox();
        }, false);
        chaptersBox.addEventListener("change", function () {
            //update inputs
            workAroundTheClosure.updateInputs();
            //update lists
            workAroundTheClosure.updateSectionsBox();
        }, false);
        sectionsBox.addEventListener("change", function () {
            //update inputs
            workAroundTheClosure.updateInputs();
        }, false);
    
        this.updateSubjectBox();
        this.updateChaptersBox();
        this.updateSectionsBox();
    
    }
    */
    
    function SearchResult() {
        this.searchName = "search" + generateUniqueID();
        this.displayBox;
        this.problems;
    }
    
    SearchResult.prototype.createPageControls = function () {
    
        this.nextButton = document.createElement("button");
        //<button type="button" disabled=true id="nextList">Next</button>
        this.nextButton.id = this.searchName + "nextList";
        this.nextButton.type = "button";
        this.nextButton.innerHTML = "Next";
        this.nextButton.setAttribute("disabled", true);
    
        this.prevButton = document.createElement("button");
        //<button type="button" disabled=true id="prevList">Previous</button>
        this.prevButton.id = this.searchName + "prevList";
        this.prevButton.type = "button";
        this.prevButton.innerHTML = "Previous";
        this.prevButton.setAttribute("disabled", true);
    
        var thisContainer = document.getElementById(this.searchName);
        thisContainer.appendChild(this.prevButton);
        thisContainer.appendChild(this.nextButton);
    
    
        //hard coded for now
        this.probsPerPage = 10;//document.getElementById("prob_per_page");
        this.topProbIndex = 0;
    
        //attach event listeners:
        var workAroundTheClosure = this;
        this.nextButton.addEventListener('click', function () {
            console.log("Next Button was clicked");
            // then load new problems? yes because we shouldn't
            // even be able to click on it if we can't
            workAroundTheClosure.topProbIndex += workAroundTheClosure.probsPerPage;
            workAroundTheClosure.renderProblems(workAroundTheClosure.topProbIndex, workAroundTheClosure.probsPerPage);
        }, false);
        this.prevButton.addEventListener('click', function () {
            workAroundTheClosure.topProbIndex -= workAroundTheClosure.probsPerPage;
            if (workAroundTheClosure.topProbIndex < 0)
                workAroundTheClosure.topProbIndex = 0;
            workAroundTheClosure.renderProblems(workAroundTheClosure.topProbIndex, workAroundTheClosure.probsPerPage);
        }, false);
    
    
    }
    
    /*
    Search.prototype.go = function () {
        this.updateInputs();
        listLibRequest.xml_command = "searchLib";
        listLibRequest.subcommand = "getDBListings";
        var workAroundTheClosure = this;
        $.post(webserviceURL, listLibRequest, function (data) {
            console.log(data);
            //try {
            var response = $.parseJSON(data);
            console.log("result: " + response.server_response);
            updateMessage(response.server_response);
            var results = response.result_data.split(",");
    
            var newSearchResult = new SearchResult();
    
            $('#problems_container').tabs("add", "#" + newSearchResult.searchName, "Search (" + results.length + ")");
            var thisContainer = document.getElementById(newSearchResult.searchName);
            var displayList = document.createElement("ul");
            thisContainer.appendChild(displayList);
    
    
            newSearchResult.createPageControls();
    
            newSearchResult.displayBox = displayList;
            newSearchResult.problems = new Array();
            for (var i = 0; i < results.length; i++) {
                newSearchResult.problems.push(new Problem(results[i]));
            }
            newSearchResult.renderProblems(newSearchResult.topProbIndex, newSearchResult.probsPerPage);
    
        });
    };
    */
    
    SearchResult.prototype.renderProblems = function (start, limit) {
        //$('#'+this.searchName+' a').text("Other text");
        $('a[href="#' + this.searchName + '"] span').text("Search (" + start + " - " + (start + limit) + " of " + this.problems.length + ") ");
        console.log($('#' + this.searchName + ' a'));
        while (this.displayBox.hasChildNodes()) {
            this.displayBox.removeChild(this.displayBox.lastChild);
        }
        for (var i = start; i < start + limit && i < this.problems.length; i++) {
            this.problems[i].render(this.displayBox);
        }
        this.updateMoveButtons();
    };
    
    SearchResult.prototype.updateMoveButtons = function () {
        if ((this.topProbIndex + this.probsPerPage) < this.problems.length) {
            this.nextButton.removeAttribute("disabled");
        } else {
            this.nextButton.setAttribute("disabled", true);
        }
        if (this.topProbIndex > 0) {
            this.prevButton.removeAttribute("disabled");
        } else {
            this.prevButton.setAttribute("disabled", true);
        }
    };
    
    /*
    Search.prototype.updateInputs = function () {
        listLibRequest.library_subjects = this.subjectBox.options[this.subjectBox.selectedIndex].value;
        listLibRequest.library_chapters = this.chaptersBox.options[this.chaptersBox.selectedIndex].value;
        listLibRequest.library_sections = this.sectionsBox.options[this.sectionsBox.selectedIndex].value;
    //	listLibRequest.library_textbook = this.textbooksBox.options[this.textbooksBox.selectedIndex].value;
    //	listLibRequest.library_textchapter = this.textChaptersBox.options[this.textChaptersBox.selectedIndex].value;
    //	listLibRequest.library_textsection = this.textSectionsBox.options[this.textSectionsBox.selectedIndex].value;
    //	listLibRequest.library_keywords = this.keywordsBox.value;
    };
    */
    
    /*
    Search.prototype.updateSubjectBox = function () {
        listLibRequest.xml_command = "searchLib";
        listLibRequest.subcommand = "getAllDBsubjects";
        this.update(this.subjectBox, "All Subjects");
    };
    
    Search.prototype.updateChaptersBox = function () {
        listLibRequest.xml_command = "searchLib";
        listLibRequest.subcommand = "getAllDBchapters";
        this.update(this.chaptersBox, "All Chapters");
    };
    
    Search.prototype.updateSectionsBox = function () {
        listLibRequest.xml_command = "searchLib";
        listLibRequest.subcommand = "getSectionListings";
        this.update(this.sectionsBox, "All Sections");
    };
    
    Search.prototype.updateTextbookBox = function () {
        listLibRequest.xml_command = "searchLib";
        listLibRequest.subcommand = "getDBTextbooks";
        this.update(this.textbooksBox, "All Textbooks");
    };
    
    Search.prototype.update = function (box, blankName) {
        $.post(webserviceURL, listLibRequest, function (data) {
            console.log(data);
            try {
                var response = $.parseJSON(data);
                console.log("result: " + response.server_response);
                updateMessage(response.server_response);
    
                box.options.length = 0;
                var options = response.result_data.split(",");
                for (var i = 0; i < options.length; i++) {
                    if (!name.match(/\./)) {
                        var option = document.createElement("option")
                        option.value = options[i];
                        option.innerHTML = options[i];
                        box.add(option, null);
                    }
                }
                if (box.childNodes.length > 0) {
                    var emptyOption = document.createElement("option");
                    emptyOption.innerHTML = blankName;
                    emptyOption.value = "";
                    box.add(emptyOption, box.firstChild);
                }
                //callback();
            } catch (err) {
                console.log(err);
                var myWindow = window.open('', '', 'width=500,height=800');
                myWindow.document.write(data);
                myWindow.focus();
            }
        });
    };
        */
    
    return Browse;
});