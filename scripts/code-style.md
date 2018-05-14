# kOS script code style conventions

**Why?**
I have one main goal for this code style: readability. I have found that these conventions greatly improve the speed at which I can understand old code and write new code, assuming you have some sort of naive auto-completion.

## Variables
- All user-defined variables use **_underscoredCamelCase**.
- All user-defined variable suffixes use **_underscoredCamelCase:ALLCAPS**.
- All system variables use **ALLCAPS**.
- Use local definitions wherever possible.

## Functions
- All user-defined functions should start with "fn_" and **fn_areThenCamelCased()**.
- All system defined functions use **ALLCAPS()**.

## Comments/docs
- Inline comments  
**// are all lower case to imply their small scale/scope**
- Variable documentation  
**//\*\*  
// Uses sentence case and a more noticeable opening line to denote importance.**
- Function documentation  
**//\*\*  
// Is similar to variable documentation but has additional PARAMETER tags  
//  
// PARAMETER _kindOfLikeThis:  
// And then the actual docs go here.**
