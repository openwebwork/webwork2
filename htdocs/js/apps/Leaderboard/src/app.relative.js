// Development file only.
let user = null;
let key = null;

// uncomment the following two lines,
// replace courseinfo.name with courseName
// replace hard-coded leaderboard URL,
// and place leaderboard.php in /opt/webwork/webwork2/htdocs/js/apps/Leaderboard/
// along with "compiled" version of this app.js

const courseNameStr = document.getElementById("courseName").value;
const leaderboardURL =
  getRootUrl(document.location) +
  document.getElementById("site_url").value +
  "/js/apps/Leaderboard/leaderboard.php";

// to do: construct maxExperience in Leaderboards.pm and stash it in id='maxExperience'
// then uncomment this bad boy
// const maxExperience = document.getElementByID('maxExperience').value;

// instead: keep track of highest experience for the class
var maxScore = 0;

function checkCookies() {
  const value = getCookie(`WeBWorKCourseAuthen.${courseNameStr}`); // getCookie defined at the bottom
  user = value.split("\t")[0];
  key = value.split("\t")[1];
}
if (!user & !key) {
  checkCookies();
}

// is it possible to move this css to a leaderboard.css file?
// along with the css styles from the Leaderboards.tmpl file?
// place combined leaderboard.css file in /opt/webwork/webwork2/htdocs/js/apps/Leaderboard

const styles = {
  tableStyle: {
    width: "100%",
    tableLayout: "fixed",
    borderSpacing: "0px",
    border: "1px solid #e6e6e6",
    boxShadow:
      "0 6px 10px 0 rgba(0, 0, 0, .14), 0 1px 18px 0 rgba(0, 0, 0, .12), 0 3px 5px -1px rgba(0, 0, 0, .2)"
  },
  pStyle: {
    fontFamily: "Helvetica Neue, Helvetica, Arial, sans-serif",
    fontWeight: "300",
    fontSize: "13px",
    textAlign: "center",
    paddingRight: "10%"
  },
  buttonStyle: {
    background: "none",
    color: "inherit",
    border: "none",
    padding: 0,
    font: "inherit",
    cursor: "pointer",
    outline: "inherit"
  },
  divStyle: {
    overflowY: "auto",
    height: "80%",
    width: "70%",
    minWidth: "550px"
  },
  thStyle: {
    backgroundColor: "#003388",
    color: "white",
    fontFamily: "Helvetica Neue, Helvetica, Arial, sans-serif",
    padding: "15px",
    cursor: "pointer"
  },
  tdStyle: {
    textAlign: "center",
    padding: "15px"
  },
  trStyle: {
    height: "2%"
  },
  LeaderItemTrStyle: {
    backgroundColor: "#f6f6f6",
    color: "black",
    fontFamily: "Helvetica Neue, Helvetica, Arial, sans-serif",
    fontWeight: "300",
    padding: "15px",
    borderSpacing: "2px"
  }
};
class LeaderTable extends React.Component {
  constructor() {
    super();
    this.state = {
      data: [],
      option: null,
      clicks: 0,
      current: null,
      currentSort: null
    };
    this.checkOption = this.checkOption.bind(this);
  }

  componentWillMount() {
    const requestObject = {
      user,
      key,
      courseName: courseNameStr // replace this with courseName
    };
    // The url  needs to be taken from a global environment variable
    // This would idealy be a variable in the leaderboards.tmpl file
    // leaderboard.php should be placed in /var/www/html/
    // fetch("http://mathww.citytech.cuny.edu/leaderboard.php", {
    //   method: "POST",
    //   headers: { "Content-type": "application/x-www-form-urlencoded" },
    //   body: formEncode(requestObject) // formEncode defined at the bottom
    // })
    //   .then(response => {
    //     if (!response.ok) {
    //       throw Error(response.statusText);
    //     }
    //     return response.json();
    //   })
    //   .then(data => {
    //     data.forEach(item => {
    //       if (item.achievementPoints == null) item.achievementPoints = 0;
    //     });
    //     this.setState({ data });
    //   })
    //   .catch(err => {
    //     console.log("An error has occurred: " + err);
    //   });

    $.post(
      leaderboardURL,
      //      "http://mathww.citytech.cuny.edu/leaderboard.php", // replace this with leaderboardURL
      requestObject,
      data => {
        data.forEach(item => {
          if (item.achievementPoints == null) item.achievementPoints = 0;

          if (parseInt(item.achievementPoints) > maxScore)
            maxScore = item.achievementPoints;
        });
        this.setState({ data: data });
      },
      "json"
    );
  }
  checkOption(option) {
    this.setState({ clicks: this.state.clicks + 1 });
    let newData = this.state.data;
    if (option.target.id == "Earned") {
      newData.sort(function(a, b) {
        return (
          parseFloat(a.achievementsEarned) - parseFloat(b.achievementsEarned)
        );
      });
      if (this.state.current == "Point") this.setState({ clicks: 0 });
    } else if (option.target.id == "Point") {
      newData.sort(function(a, b) {
        return (
          parseFloat(a.achievementPoints) - parseFloat(b.achievementPoints)
        );
      });
      if (this.state.current == "Earned") this.setState({ clicks: 0 });
    }
    if (this.state.clicks % 2 == 0) {
      this.setState({
        data: newData.reverse(),
        current: option.target.id,
        currentSort: "Desc"
      });
    } else {
      this.setState({
        data: newData,
        current: option.target.id,
        currentSort: "Asc"
      });
    }
  }
  renderTable() {
    let { tdStyle } = styles;
    let tableInfo = [];
    if (this.state.data.length > 0) {
      for (var i = 0; i < this.state.data.length; i++) {
        var current = this.state.data[i];
        tableInfo.push(
          <LeaderTableItem>
            <td className="tdStyleLB">
              {current.username ? current.username : current.id}
            </td>
            <td className="tdStyleLB">{current.achievementsEarned}</td>
            <td className="tdStyleLB">
              {current.achievementPoints ? current.achievementPoints : 0}
            </td>
            <td className="tdStyleLB">
              <Filler
                percentage={
                  Math.floor((current.achievementPoints / maxScore) * 1000) / 10
                }
                score={current.achievementPoints}
              />
            </td>
          </LeaderTableItem>
        );
      }
    }

    return tableInfo;
  }
  render() {
    let { tableStyle, thStyle, tdStyle, trStyle, divStyle, pStyle } = styles;
    let tableInfo = this.renderTable();

    return (
      <div className="divStyleLB">
        <table className="tableStyleLB">
          <tbody>
            <tr className="trStyleLB">
              <th id="username" className="thStyleLB">
                Username
              </th>
              <th
                className="sortButtons thStyleLB"
                style={thStyle}
                id="Earned"
                onClick={this.checkOption}
              >
                Achievements Earned
                {this.state.current == "Earned" ? (
                  this.state.currentSort == "Asc" ? (
                    <i className="ion-android-arrow-dropup" />
                  ) : (
                    <i className="ion-android-arrow-dropdown" />
                  )
                ) : null}
              </th>
              <th
                className="sortButtons thStyleLB"
                style={thStyle}
                id="Point"
                onClick={this.checkOption}
              >
                Achievement Points
                {this.state.current == "Point" ? (
                  this.state.currentSort == "Asc" ? (
                    <i className="ion-android-arrow-dropup" />
                  ) : (
                    <i className="ion-android-arrow-dropdown" />
                  )
                ) : null}
              </th>
              <th className="thStyleLB">Progress</th>
            </tr>
          </tbody>
          <tbody>{tableInfo}</tbody>
        </table>
      </div>
    );
  }
}

class LeaderTableItem extends React.Component {
  render() {
    let { LeaderItemTrStyle } = styles;
    return <tr className="LeaderItemTr">{this.props.children}</tr>;
  }
}
class Leaderboard extends React.Component {
  render() {
    let {
      tableStyle,
      thStyle,
      tdStyle,
      trStyle,
      divStyle,
      pStyle,
      LeaderItemTrStyle
    } = styles;
    return (
      <div>
        <LeaderTable />
        <p className="pStyleLB">
          <i>Sponsored by Santander Bank</i>
        </p>
      </div>
    );
  }
}

class Filler extends React.Component {
  constructor() {
    super();
    this.state = { color: null };
    this.changeColor = this.changeColor.bind(this);
  }
  changeColor() {
    const percentage = parseInt(this.props.percentage);
    let colorValue = "";

    switch (true) {
      case percentage < 20:
        colorValue = "#ff6961";
        break;
      case percentage >= 20 && percentage < 40:
        colorValue = "#FF7F50";
        break;
      case percentage >= 40 && percentage < 60:
        colorValue = "#fada5e";
        break;
      case percentage >= 60 && percentage < 80:
        colorValue = "#aedb30";
        break;
      case percentage >= 80:
        colorValue = "#4dff88";
        break;
    }
    return colorValue;
  }

  render() {
    return (
      <div
        className="filler"
        style={{
          width: `${this.props.percentage}%`,
          background: this.changeColor()
        }}
      >
        <p style={{ fontWeight: "100" }}>{this.props.score}</p>
      </div>
    );
  }
}

//Utility functions
function formEncode(obj) {
  var str = [];
  for (var p in obj)
    str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
  return str.join("&");
}

function getCookie(cname) {
  const name = cname + "=";
  const decodedCookie = decodeURIComponent(document.cookie);
  const ca = decodedCookie.split(";");
  for (let i = 0; i < ca.length; i++) {
    let c = ca[i];
    while (c.charAt(0) == " ") {
      c = c.substring(1);
    }
    if (c.indexOf(name) == 0) {
      return c.substring(name.length, c.length);
    }
  }
  return "";
}

function getRootUrl(url) {
  return url.toString().replace(/^(.*\/\/[^\/?#]*).*$/, "$1");
}

ReactDOM.render(<Leaderboard />, document.getElementById("LeaderboardPage"));
