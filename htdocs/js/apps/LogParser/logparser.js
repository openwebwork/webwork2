var $container = $('<div class="container"></div>');
// var $setNames = $('<select class="form-control-sm" id="set_names" name="set_names"><option value="">Select Assignment Set</option></select>');

var prettyProblemNumbers = [];
var auxTable = [];
var pNumRegex = /(.*?)-(\d+)-(\d+)/;

function outputTableBody(entriesJSON, attempts) {
    var $tbody = $("<tbody></tbody>");
    var prevUser = '';
    var count = 0;
    var $tr;

    auxTable = [];
    // console.log(prettyProblemNumbers);
    for (var entryIndex = 0; entryIndex < entriesJSON.length; entryIndex++) {
        var item = entriesJSON[entryIndex];
        // console.log(item);
        var currentUser = item['studentUser'];
        if (currentUser != prevUser) {
            count = 0;
            prevUser = currentUser;
        }

        var row = {};
        row['studentUser'] = currentUser;
        row['answers'] = {};
        var addRow = false;
        for (var pNumIndex = 0; pNumIndex < prettyProblemNumbers.length; pNumIndex++) {
            var pSetNum = prettyProblemNumbers[pNumIndex];
            var pSet = pSetNum.match(pNumRegex)[1];
            var pNum = pSetNum.match(pNumRegex)[2] + '-' + pSetNum.match(pNumRegex)[3];
            var newEntry = true;
            if (pSet != item['setName']) {
                continue;
            }
            for (var i = 0; i < auxTable.length; i++) {
                if (auxTable[i]['studentUser'] != currentUser) {
                    continue;
                }
                if (auxTable[i]['answers'][pSetNum] == null || typeof auxTable[i]['answers'][pSetNum] == 'undefined') {
                    auxTable[i]['answers'][pSetNum] = item['prettyProblemNumber-' + pSetNum];
                    // addRow = false;
                    newEntry = false;
                    break;
                }
            }
            if (newEntry) {
                row['answers'][pSetNum] = item['prettyProblemNumber-' + pSetNum];
                addRow = true;
            }
        }
        if (addRow && count < attempts) {
            row['attempt'] = count + 1;
            auxTable.push(row);
            count++;
        }
    }

    // console.log(auxTable);
    // auxTable.forEach(function (row, index) {
    var row;
    for (var i = 0; i < auxTable.length; i++) {
        row = auxTable[i];
        $tr = $('<tr></tr>');
        $tr.append('<td>' + row['studentUser'] + '</td>');
        $tr.append('<td>' + row['attempt'] + '</td>');
        // $tr.append('<td>' + item['setName'] + '</td>');
        // $tr.append('<td>' + item['answerID'] + '</td>');
        // $tr.append('<td>' + item['time'] + '</td>');
        var pSetNum;
        for (var j = 0; j < prettyProblemNumbers.length; j++) {
            // prettyProblemNumbers.forEach(function (pSetNum) {
            pSetNum = prettyProblemNumbers[j];
            $tr.append('<td>' + row['answers'][pSetNum] + '</td>');
        };
        $tbody.append($tr);
    };

    return $tbody;
}

$(function() {
    entriesJSON.sort(function(a, b) {
        return a['studentUser'].localeCompare(b['studentUser']) || b['answerID'] - a['answerID'];
    });

    // console.log(entriesJSON);
    // build problem numbers list
    var hwsets = [];
    var hwset;
    var item;
    for (var i = 0; i < entriesJSON.length; i++) {
        // entriesJSON.forEach(function (item, index) {
        item = entriesJSON[i];
        hwset = item['setName'] || 'undefined';
        // if (!(hwsets.includes(hwset))) {
        if (hwsets.indexOf(hwset) == -1) {
            hwsets.push(hwset);
            // var option = new Option(hwset, hwset);
            // $setNames.append(option);
        }
        for(var key in item) {
            if (item.hasOwnProperty(key)) {
                var match = key.match(/^prettyProblemNumber-(.*)/);
                if (match) {
                    var setProblemName = match[1];
                    // if (!(prettyProblemNumbers.includes(setProblemName))) {
                    if (prettyProblemNumbers.indexOf(setProblemName) == -1) {
                        prettyProblemNumbers.push(setProblemName);
                    }
                }
            }
        }
    };
    // console.log(prettyProblemNumbers);
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

    // $container.append($setNames);
    $container.append($history);
    $('#log-body').append($container);

    $history.on('change', function() {
        $('#log-body .container table').remove();
        var attempts = $(this).val();
        var $table = $("<table class='table table-bordered answer-log'></table>");
        var theads = '';
        var pNum;
        for(var i = 0; i < prettyProblemNumbers.length; i++) {
            // prettyProblemNumbers.forEach(function (pNum) {
            pNum = prettyProblemNumbers[i];
            theads += '<th>' + pNum + '</th>';
        };
        $table.append('<thead><tr><th>User</th><th>Attempt</th>' + theads + '</tr></thead>'); // <th>answerID</th><th>time</th>
        $table.append(outputTableBody(entriesJSON, attempts));
        $('#answer-log-modal button.csv').off();
        $('#answer-log-modal button.csv').click(function() {
            var csv = $table.table2csv('return', {
                "separator": ",",
                "newline": "\n",
                "quoteFields": true,
                "excludeColumns": ".col_chkbox, .col_count",
                "excludeRows": "",
                "trimContent": true,
            });
            var a = document.createElement('a');
            a.setAttribute('href', 'data:text/csv;charset=UTF-8,' + encodeURIComponent(csv));
            a.setAttribute('download', 'answer_log.csv');
            a.click();
        });
        $('#log-body .container').append($table);
    });
    $('.show_answer_log_modal').click(function() {$('#answer-log-modal').modal('show');});
    $('#past-answer-form table.FormLayout select').change(function() {$('button.show_answer_log_modal').hide();});

})
