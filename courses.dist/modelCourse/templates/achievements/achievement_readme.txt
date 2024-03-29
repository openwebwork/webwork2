 This folder contains achievement evaluators.  Their job is to test
 whether or not an achievement has been earned.  The code is run every time a
 student submits an answer to a homework question as long as the achievement 
 is unearned.  

 -The code should be written in perl and should return 1 if the achievement 
  was earned and 0 if it was not earned. 

 -Any perl code in preamble.at will be run before the content of any
  achievement evaluator.  

 You have access to a variety of variables:
  - $problem : the problem data (changes to this variable will not be saved!)
      This variable contains the problem data.  It is a hash pointer with the
      following values (not all values shown)
      - $problem->status : the score of the current problem
      - $problem->problem_id : the id of the current problem
      - $problem->set_id : the id of the set containing the problem
      - $problem->num_correct : the number of correct attempts
      - $problem->num_incorrect : the number of incorrect attempts
      - $problem->max_attempts : the maximum number of allowed attempts
   
  - $set : the set data (changes to this variable will not be saved!)
      This variable contains the set data.  it is a hash pointer with the
      following values. (not all values shown)
      - $set->open_date : when the set was open
      - $set->due_date : when the set is due
    
  - @setProblems : the problem data for all the problems from this set.  
      (changes to this variable will not be saved!)
      This is an array of problem hashes.  Each element of the array has the
      save hash keys as the $problem variable above

  - $counter : the users counter associated to this achievement
      (changes to this variable *will* be saved!)
      If this achievement has a counter associated to it 
      (i.e. solve 20 problems) then this is where you store 
      the students counter for this achievement. 
      This variable will initally start as ''

  - $maxCounter : the goal for the $counter variable for this achievement
      (changes to this variable will not be saved!)
      If this achievement has a counter associated to it then this variable 
      contains the goal for the counter.  Your achievement should return 1 
      when $counter >= $maxCounter.  These two variables are used to show a 
      progress bar for the achievement.  

  - $tags : this contains the metadata for the problem stored in a hash.  This includes DBsubject
       DBchapter and DBsection Note:  These values are not super stable and are likely to change
       from problem to problem and year to year

  - $userAchievements: this hash stores all assigned achievements for
      the current user. The keys are the achievement_id and the values
      are 0 or 1 for if the achievement has been earned. Changes to this
      variable will be accessible by achievements down the line in the
      current evaluation loop, but will not be saved across evaluations.
      Note: This variable is updated if an achievement is earned,
      but only achievements further down the evaluation chain will
      see the update. So when depending on other achievements place
      make sure they are run first.

  - $localData : this is a hash which stores data for this user and 
      achievement (changes to this variable *will* be saved!)
      This hash will persist from evaluation to evaluation.  You can 
      store whatever you like in here and it can be accessed next time 
      this evaluator is run. Two things to keep in mind. First, The data 
      in this hash will *not* be accessible by other achievements.  Second, 
      the first time a variable is accessed it will have the value ''.   

   - $globalData : this is a hash which stores data for all achievements
       (changes to this variable *will* be saved!)
       This hash will persist from evaluation to evaluation and, like
       $localData, you can store whatever you like in here.  This data 
       will be accessable from *every* achievement and is unique to the 
       user.  There are three variables stored in this hash that are
       maintained by the system. 
       - $globalData->completeSets : This is the number of sets which 
         the student has earned 100% on
       - $globalData->complete Problems : This is the number of problems 
         which the student has earned 100% on
       - $globalData->prev_level_points : This is the number of points
         to reach current level which is used with level progress bar.
       Warning: The achievements are always evaluated in the order they 
       are listed the Instructors achievement editor page.  To make matters
       more complicated, achievements which have already been earned are 
       not evaluated at all.  The up-shot of this is that when modifying 
       variables in $globalData you need to either write your code so it 
       doesnt matter which order the evaluators are run, or you need to 
       pay very close attention to which evaluators are run and when. 
