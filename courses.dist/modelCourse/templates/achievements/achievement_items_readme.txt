To use achievement items you should import the default_achievement_items.axp
achievements using the editor.  

If you want to change which items are given at which levels you need to do two 
things.  
1) You should change the line 
$globalData->{SuperExtendDueDate} = 1;
to have a different achievement item id. 
2) Using the editor, you should change the name of the achievement in the 
description of the level. 

The available items are: 
    	id : RessurectHW
	name : Scroll of Ressurection
	description : Opens any homework set for 24 hours.

	id : ExtendDueDate
	name : Tunic of Extension
	description : Adds 24 hours to the due date of a homework.

	id : SuperExtendDueDate
	name : Robe of Longevity
	description : Adds 48 hours to the due date of a homework.

	id : ReducedCred
	name : Ring of Reduction
	description : Enable reduced credit for a homework set.  This will allow you to submit answers for partial credit for limited time after the due date.
	Reduced credit needs to be set up in course configuration for this
	item to work,

	id : DoubleSet
	name : Cake of Enlargment
	description : Cause the selected homework set to count for twice as many points as it normally would.

	id : ResetIncorrectAttempts
	name : Potion of Forgetfullness
	description : Resets the number of incorrect attempts on a single homework problem.

	id : DoubleProb
	name : Cupcake of Enlargement
	description : Causes a single homework problem to be worth twice as much..
	id : HalfCreditProb
	name : Lesser Rod of Revelation
	description : Gives half credit on a single homework problem.

	id : HalfCreditSet
	name : Lesser Tome of Enlightenment
	description : Gives half credit on every problem in a set.

	id : FullCreditProb
	name : Greater Rod of Revelation
	description : Gives full credit on a single homework problem.

	id : FullCreditSet
	name : Greater Tome of Enlightenment
	description : Gives full credit on every problem in a set.

	id : DuplicateProb
	name : Box of Transmogrification
	description : Causes a homework problem to become a clone of another problem from the same set.

	id : Surprise
	name : Mysterious Package (with Ribbons)
	description : What could be inside?
        this opens the file suprise_message.txt in the achievements 
        folder and then prints the contetnts of the file.  

