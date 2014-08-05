  var User = new Schema({
  	email: String,
  	first_name: String,
  	last_name: String,
  	hashed_password: String,
  	section: String,
  	recitation: String,
  });

  var Problem = new Schema({
    path: String,
    renderType: String
    });

  var ProblemPool = new Schema({
  	pool: [Problem]
  });

  var ProblemSet = new Schema({  
  	set: [ProblemPool],
  	problemNames: [String],
  	problemIndexes: [Number],
  	dependencies: [Number],	
  	weight: [Number]
  });


  var UserSet = new Schema({
  	pool: ProblemSet,
  	values: [Number],
  	seeds: [Number], 
  	user: User,
  	due_date: Date,
  	open_date: Date,
  	reduced_scoring_date: Date
  });

  var Assignment = new Schema({
  	due_date: Date,
  	open_date: Date,
  	reduced_scoring_date: Date
  	set: [UserSet]
  })

  var Course = new Schema({
  	problemSets: [ProblemSet]
  });


  var HistoryLog = new Schema({
  	user_id: String,
  	problem_id: String,
  	submitted_answer: String,
  	submitted_date: Date
  })
