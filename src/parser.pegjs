start
= token*

token
= nonSourceCharExp
/ chars:sourceChar+ { return chars.join(''); }

nonSourceCharExp
= requireExp
/ globalExp

// = string
// / comment
// / requireExp
// / globalExp

sourceChar
= !nonSourceCharExp c:. { return c; }

lineTerm
= "\r\n"
/ "\r"
/ "\n"
/ "\u2028" // line separator
/ "\u2029" // paragraph separator

comment
= singleLineComment
/ multiLineComment

singleLineComment
= "//" chars:singleLineCommentChar* t:lineTerm { return {comment: "//" + chars.join('') + t }; }
/ "#" chars:singleLineCommentChar* t:lineTerm { return {comment: "#" + chars.join('') + t }; }

singleLineCommentChar
= !lineTerm c:. { return c; }

multiLineComment
= "/*" chars:multiLineCommentChar* "*/" { return { comment: "/*" + chars.join('') + "*/" }; }

multiLineCommentChar
= !"*/" c:. { return c; }

string
= sqString
/ dqString
/ regExpLiteral

sqString
= "'" chars:sqChar* "'" { return "'" + chars.join('') + "'"; }

sqChar
= "\\'"
/ !"'" c:. { return c; }

dqString
= '"' chars:dqChar* '"' { return '"' + chars.join('') + '"'; }

dqChar
= '\\"'
/ !'"' c:. { return c; }

regExpLiteral "regular expression"
  = "/" pattern:$regExpBody "/" flags:$regExpFlags {
      console.log('--- parse.regexp.literal', pattern, flags);
      var value = new RegExp(pattern, flags);
      return "/" + pattern + "/" + flags;
    }

regExpBody
  = regExpFirstChar regExpChar*

regExpFirstChar
  = ![*\\/[] regExpNonTerminator
  / regExpBackslashSequence
  / regExpClass

regExpChar
  = ![\\/[] regExpNonTerminator
  / regExpBackslashSequence
  / regExpClass

regExpBackslashSequence
  = "\\" regExpNonTerminator

regExpNonTerminator
  = !lineTerm .

regExpClass
  = "[" regExpClassChar* "]"

regExpClassChar
  = ![\]\\] regExpNonTerminator
  / regExpBackslashSequence

regExpFlags
  = [a-z]*

requireExpSpec
= s:string { return s.substring(1, s.length - 1); }

requireExp
= "require" _ "(" _ spec:requireExpSpec _ ")"  { return { require: spec } }

whitespace
= [ \r\n\t]

_ 
= (whitespace / comment)*

globalExp
= 'process' { return {global: 'process', require: 'process'}; }
// / 'console' { return {global: 'console', require: 'console'}; }
/ 'Buffer' { return {global: 'Buffer', require: 'buffer'}; }

