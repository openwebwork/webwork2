<?php
  define('DB_HOST', 'localhost');
  define('DB_NAME', 'webwork');
  define('DB_USER', 'webworkWrite');
  define('DB_PASS', 'passwordRW');

  global $conn;

  $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);

    if($conn->errno){
        echo "Failed to connect to MySQL database ".$conn->error;
    }

  $user = mysqli_real_escape_string($conn, $_POST['user']);  
  $key = mysqli_real_escape_string($conn, $_POST['key']);
  $courseName = mysqli_real_escape_string($conn, $_POST['courseName']);

  //  MAT1275EN-S18-Parker_achievement_user        
  //  MAT1275EN-S18-Parker_global_user_achievement 
  //  MAT1275EN-S18-Parker_user

  if(validateUser($conn, $user, $key, $courseName) != False){
    http_response_code(200);
    echo leaderboard($conn, $courseName);
  }else{
    http_response_code(401);
  }
  
  
  function validateUser($conn, $user, $key, $courseName){
      $query = "SELECT user_id from `".$courseName."_key` WHERE user_id = '".$user."' AND key_not_a_keyword = '".$key."';";
      $result = $conn->query($query);
  
      if(mysqli_num_rows($result) == 0) return null;
  
      return $result;
  }
  
  
  
  function leaderboard($conn, $courseName){
  
    $query = "SELECT user_id, comment from `".$courseName."_user` WHERE user_id NOT IN (SELECT user_id from `".$courseName."_permission` WHERE permission > 0);";
  
    // 2D array with only one collumn
    $users = extractRows($conn->query($query), 0);

    $query = "select count(*) from `".$courseName."_problem`;";

    $numOfProblems = extractRows($conn->query($query), 0);

    $query = "select SUM(points) from `".$courseName."_achievement`;";

    $achievementPtsSum = extractRows($conn->query($query), 0);
  
    $achievementsEarned = [];
    $achievementPoints = [];
    $data = [];
  
    foreach($users as $user){
      $getEarned = "SELECT COUNT(*) FROM `".$courseName."_achievement_user` WHERE user_id = '$user[0]' AND earned > 0;";
      $getPoints = "SELECT achievement_points FROM `".$courseName."_global_user_achievement` WHERE user_id = '$user[0]';";
  
      array_push($achievementsEarned, extractRows($conn->query($getEarned), 0)[0][0]);
      array_push($achievementPoints, extractRows($conn->query($getPoints), 0)[0][0]);
  
    }
    
    

  
    for($i=0; $i < sizeof($achievementPoints); $i++){
      $data[$i] = ["id" => $users[$i][0], "username" => $users[$i][1], "achievementsEarned" => $achievementsEarned[$i], "achievementPoints" => $achievementPoints[$i], "achievementPtsSum" => $achievementPtsSum[0][0], "numOfProblems" => $numOfProblems[0][0]];
    }
  
  
  
    return json_encode($data);
  }






  function extractRows($results, $num_or_assoc){
      $rows = array();
      if($num_or_assoc == 0){
          while($row = $results->fetch_array(MYSQLI_NUM) ){
              array_push($rows, $row);
          }

      }else{
          while($row = $results->fetch_array(MYSQLI_ASSOC) ){
              array_push($rows, $row);
          }
      }

      return $rows;

    }

    $conn->close();
