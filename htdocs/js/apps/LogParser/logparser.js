var fields = ['answer', 'score', 'time'];
var prettyProblemNumbers = [];
var pNumRegex = /(.*?)-(\d+)-(\d+)/;

function outputTableBody(entriesJSON, attempts) {
    var $tbody = $("<tbody></tbody>");
    var prevUser = '';
    var count = 0;

    var auxTable = [];
    var pSetNum;
    var entry;
    var currentUser;
    for (var entryIndex = 0; entryIndex < entriesJSON.length; entryIndex++) {
        entry = entriesJSON[entryIndex];
        currentUser = entry['studentUser'];
        if (currentUser != prevUser) {
            count = 0;
            prevUser = currentUser;
        }

        var row = {
            studentUser: currentUser,
            answers: {}
        };
        
        pSetNum = entry['pSetNum'];
        var newEntry = true;
        for (var i = 0; i < auxTable.length; i++) {
            if (auxTable[i]['studentUser'] != currentUser) {
                continue;
            }
            if (auxTable[i]['answers'][pSetNum] == null || typeof auxTable[i]['answers'][pSetNum] == 'undefined') {
                auxTable[i]['answers'][pSetNum] = {
                    answer: entry['answer'],
                    score: entry['score'],
                    time: entry['time']
                };
                newEntry = false;
                break;
            }
        }
        if (newEntry && count < attempts) {
            row['answers'][pSetNum] = {
                answer: entry['answer'],
                score: entry['score'],
                time: entry['time']
            };
            row['attempt'] = count + 1;
            auxTable.push(row);
            count++;
        }
        
    }
    var row;
    var $tr;
    for (var i = 0; i < auxTable.length; i++) {
        row = auxTable[i];
        $tr = $('<tr></tr>');
        $tr.append('<td><span>' + row['studentUser'] + '</span></td>');
        $tr.append('<td><span>' + row['attempt'] + '</span></td>');        
        for (var j = 0; j < prettyProblemNumbers.length; j++) {
            pSetNum = prettyProblemNumbers[j];
            try {
                $tr.append('<td><div class="field answer">' + row['answers'][pSetNum]['answer'] + '</div>' 
                + '<div class="field score" style="border-top:solid #ddd 1px">' + row['answers'][pSetNum]['score'] + '</div>'
                + '<div class="field time" style="border-top:solid #ddd 1px">' + row['answers'][pSetNum]['time'] + '</div></td>');
            } catch(e) {
                $tr.append('<td></td>');
            }
        };
        $tbody.append($tr);
    };
    return $tbody;
}

$(function() {
    entriesJSON.sort(function(a, b) {
        return a['studentUser'].localeCompare(b['studentUser']) || b['answerID'] - a['answerID'];
    });

    var hwsets = [];
    var hwset;
    var entry;
    for (var i = 0; i < entriesJSON.length; i++) {
        entry = entriesJSON[i];
        hwset = entry['setName'] || 'undefined';
        if (hwsets.indexOf(hwset) == -1) {
            hwsets.push(hwset);
        }
        if (prettyProblemNumbers.indexOf(entry['pSetNum']) == -1) {
            prettyProblemNumbers.push(entry['pSetNum']);
        }
    };
    prettyProblemNumbers.sort(function(a, b) {
        return a.match(pNumRegex)[1].localeCompare(b.match(pNumRegex)[1]) ||
        a.match(pNumRegex)[2] - b.match(pNumRegex)[2] ||
        a.match(pNumRegex)[3] - b.match(pNumRegex)[3];
    });

    var $history = $('<select class="form-control-sm" id="history" name="history"><option value="0">Number of Recent Attempts</option></select>');
    var option;
    for (var i = 1; i < 11 ; i++) {
        option = new Option(i, i);
        $history.append(option);
    }

    var checkboxHtml = '';
    for(var i = 0; i < fields.length; i++) {
        checkboxHtml += '<div class="checkbox" style="margin-left:5px;display:none"><input class="checkbox" checked type="checkbox" name="' + fields[i] +'">'
        + '<label class="form-check-label" for="answer">' + fields[i] + '</label></div>';
    }
    $checkboxes = $(checkboxHtml);
    
    $('#answer-log-modal .modal-header').append($history).append($checkboxes);
    $history.on('change', function() {
        $('#log-body table').remove();
        var attempts = $(this).val();
        var $table = $("<table class='table table-bordered answer-log'></table>");
        var theads = '';
        var pNum;
        for(var i = 0; i < prettyProblemNumbers.length; i++) {
            pNum = prettyProblemNumbers[i];
            theads += '<th><span>' + pNum + '</span></th>';
        };
        $table.append('<thead><tr><th><span>User</span></th><th><span>Attempt</span></th>' + theads + '</tr></thead>'); // <th>answerID</th><th>time</th>
        $table.append(outputTableBody(entriesJSON, attempts));
        
        $('#log-body').append($table);
        $('.checkbox').each(function() {
            var field = $(this).attr('name');
            if ($(this).is(':checked')) {
                $('.field.' + field).show();
            } else {
                $('.field.' + field).hide();
            }
        });
        
        $("div.checkbox").css('display', 'inline-block');
        $('.checkbox').off();
        $('.checkbox').on('change', function() {
            var field = $(this).attr('name');
            if ($(this).is(':checked')) {
                $('.field.' + field).show();
            } else {
                $('.field.' + field).hide();
            }
        });
        
        $('#answer-log-modal button.csv').off();
        $('#answer-log-modal button.csv').click(function() {
            var csv = $table.table2csv('return', {
                "separator": ",",
                "newline": "\n",
                "quoteFields": true,
                "excludeColumns": "",
                "excludeRows": "",
                "trimContent": true,
            });
            var a = document.createElement('a');
            a.setAttribute('href', 'data:text/csv;charset=UTF-8,' + encodeURIComponent(csv));
            a.setAttribute('download', 'answer_log.csv');
            a.click();
        });
        
    });
    $('.show_answer_log_modal').click(function() {$('#answer-log-modal').modal('show');});
    $('#past-answer-form table.FormLayout select').change(function() {$('button.show_answer_log_modal').hide();});

})
