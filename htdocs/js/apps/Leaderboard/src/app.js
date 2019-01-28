// Development file only.
let user = null;
let key = null;

// get static values from webwork
const courseName = document.getElementById("courseName").value;
const leaderboardURL =
  document.getElementById("site_url").value +
  "/js/apps/Leaderboard/leaderboard.php";
const pointsPerProblem = document.getElementById('achievementPPP').value;
let maxScore = 0;

// we must pull the user + key to authenticate for php
// php script is set to require a valid user/key pair
function checkCookies() {
  const value = getCookie(`WeBWorKCourseAuthen.${courseName}`); // getCookie defined at the bottom
  user = value.split("\t")[0];
  key = value.split("\t")[1];
}
if (!user & !key) {
  checkCookies();
}

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

  componentDidMount() {

    const requestObject = {
      user,
      key,
      courseName: courseName
    };

    $.post(
      leaderboardURL,
      requestObject,
      data => {
        data.forEach(item => {
          if (item.achievementPoints == null) item.achievementPoints = 0;
        });
        maxScore =
          parseInt(data[0].numOfProblems)*parseInt(pointsPerProblem)+parseInt(data[0].achievementPtsSum);
	data.sort((a, b) => b.achievementPoints - a.achievementPoints);
        this.setState({ data: data, current: "progress" });
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
    } else if (option.target.id == "Point" || option.target.id == "progress") {
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
    let tableInfo = [];
    if (this.state.data.length > 0) {
      for (var i = 0; i < this.state.data.length; i++) {
        var current = this.state.data[i];
        tableInfo.push(
          <LeaderTableItem rID={current.id}>
            <td className="tdStyleLB">
              {current.username ? current.username : "Anonymous"}
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
              />
            </td>
          </LeaderTableItem>
        );
      }
    }

    return tableInfo;
  }
  render() {

    let tableInfo = this.renderTable();

    return (
      <div className="lbContainer">
        <table className="lbTable">
	<caption>Sponsored by Santander Bank</caption>
          <thead>
            <tr>
              <th id="username">
                Username
              </th>
              <th
                className="sortButtons"
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
                className="sortButtons"
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
              <th
		className="sortButtons" 
		id="progress"
                onClick={this.checkOption}
              >
                Achievement Points Collected
                {this.state.current == "progress" ? (
                  this.state.currentSort == "Asc" ? (
                    <i className="ion-android-arrow-dropup" />
                  ) : (
                    <i className="ion-android-arrow-dropdown" />
                  )
                ) : null}
              </th>
            </tr>
          </thead>
          <tbody>{tableInfo}</tbody>
        </table>
      </div>
    );
  }
}

class LeaderTableItem extends React.Component {
  render() {
    if (this.props.rID == user) { return <tr className="myRow">{this.props.children}</tr>; }
    return <tr className="LeaderItemTr">{this.props.children}</tr>;
  }
}
class Leaderboard extends React.Component {
  render() {

    return (
      <div>
        <LeaderTable />
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
    const perc = parseInt(this.props.percentage);
	var r, g, b = 0;
	if(perc < 50) {
		r = 255;
		g = Math.round(5.1 * perc);
	}
	else {
		g = 255;
		r = Math.round(510 - 5.10 * perc);
	}
	var h = r * 0x10000 + g * 0x100 + b * 0x1;
	return '#' + ('000000' + h.toString(16)).slice(-6);
  }
  render() {
    return (
      <div className="fillerContainer">
	<span className="fillerBar"
        style={{
          width: `${this.props.percentage}%`,
          background: this.changeColor()
        }}
        ></span>
        <div className="fillerLabel"
	style={{
	  left: `${this.props.percentage}%`
	}}>
          {this.props.percentage}%
        </div>	
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

ReactDOM.render(<Leaderboard />, document.getElementById("LeaderboardPage"));
