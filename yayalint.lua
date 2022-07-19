local dirname = string.match(arg[0], [[(.*[\/])(.*)]])
if dirname then
  package.path  = package.path .. ";" .. dirname .. "?.lua"
  package.path  = package.path .. ";" .. dirname .. "?/init.lua"
  if string.sub(package.config, 1, 1) == "/" then
    package.cpath  = package.cpath .. ";" .. dirname .. "?.so"
    package.cpath  = package.cpath .. ";" .. dirname .. "?/init.so"
  else
    package.cpath  = package.cpath .. ";" .. dirname .. "?.dll"
    package.cpath  = package.cpath .. ";" .. dirname .. "?/init.dll"
  end
end

--local Lpeg    = require("lpeg")
local Lfs     = require("lfs")
local Path    = require("path.path")

local Lpeg    = require("lpeglabel")
local Re      = require("lpeglabel.relabel")
local Conv    = require("conv")
local StringBuffer  = require("string_buffer")
local ArgParse  = require("argparse.src.argparse")

local AycDecoder  = require("ayc_decoder")

local UserDefined = require("user_defined")
local Levenshtein = require("levenshtein")

local OutputSep = "\t"
local DirSep  = string.sub(package.config, 1, 1)
local NewLine = "\x0a"
if DirSep == "\\" then
  NewLine = "\x0d\x0a"
end

local Ascii   = Lpeg.R("\x00\x7f")
local NumberZ = Lpeg.S("+-") ^ -1 * (Lpeg.P("0") + (Lpeg.R("19") * Lpeg.R("09") ^ 0))
local NumberX = Lpeg.S("+-") ^ -1 * Lpeg.P("0x") * (Lpeg.R("09") + Lpeg.R("af"))  ^ 1
local NumberR = Lpeg.Cg(NumberX + (NumberZ * (Lpeg.P(".") * Lpeg.R("09") ^ 1) ^ -1), "num")
local MBHead  = Lpeg.R("\xc2\xf4")
local MBData  = Lpeg.R("\x80\xbf")
local NL      = Lpeg.S("\x0a")
local Char    = Ascii + (MBHead * (MBData ^ 1)) - NL
local Comment2  = (Lpeg.P("/*") * ((Lpeg.B( - Lpeg.P("*/")) * (Char + NL)) ^ 0) * Lpeg.P("*/"))
local Space   = Lpeg.S(" \t") + Lpeg.P("/\x0a") + Comment2
local Comment1  = (Lpeg.P("//") * Char ^ 1 * NL)
local Sep     = Lpeg.P("\x0a") + Comment1
local Sep2    = Lpeg.P(";")
local Empty   = (Space + (Lpeg.P("//") * Char ^ 0)) ^ 0 * NL
local SepEx   = (Sep + Empty + Space)

local Reserve = Lpeg.P("if") + Lpeg.P("elseif") + Lpeg.P("else") + Lpeg.P("case") + Lpeg.P("when") + Lpeg.P("others") + Lpeg.P("switch") + Lpeg.P("while") + Lpeg.P("for") + Lpeg.P("break") + Lpeg.P("continue") + Lpeg.P("return") + Lpeg.P("foreach")
local ArithmeticOperator  = Lpeg.S("+-*/%")
local LogicalOperator = Lpeg.P("!") + Lpeg.P("&&") + Lpeg.P("||")
local ComparisonOperator = Lpeg.P("==") + Lpeg.P("!=") + Lpeg.P("<=") + Lpeg.P(">=") + Lpeg.S("<>")
local AssignmentOperator  = Lpeg.P("=") + Lpeg.P(":=") + Lpeg.P("+=") + Lpeg.P("-=") + Lpeg.P("*=") + Lpeg.P("/=") + Lpeg.P("%=") + Lpeg.P("+:=") + Lpeg.P("-:=") + Lpeg.P("*:=") + Lpeg.P("/:=") + Lpeg.P("%:=") + Lpeg.P(",=")
local Operator  = Lpeg.S("()[]&") + Lpeg.P("++") + Lpeg.P("--") + ComparisonOperator + Lpeg.P("_in_") + Lpeg.P("!_in_") + LogicalOperator + AssignmentOperator
local InvalidName = Lpeg.S(" !\"#$%&()+,-*/:;<=>?@[]'{|}\t")
local Number  = NumberR * Lpeg.B( - (Char - InvalidName))
local InvalidNameHead = Lpeg.R("09") + InvalidName
local Name  = (((Lpeg.B( - (InvalidNameHead + (Reserve * (-1 + InvalidName + Sep)))) + Lpeg.R("09") ^ 1) * (Lpeg.B(- InvalidName) * Char) ^ 1))

local ScopeBegin  = Lpeg.P("{")
local ScopeEnd    = Lpeg.P("}")

-- 予約語にはひっかからんし- Reserveはいらんやろ
local LocalVariable = Lpeg.P("_") * (Lpeg.B(- InvalidName) * Char) ^ 0
local GlobalVariable  = Lpeg.B(- Lpeg.P("_")) * Name
local Variable  = Lpeg.Cg(Lpeg.Cp(), "pos") * (Lpeg.Cg(LocalVariable, "l") + Lpeg.Cg(GlobalVariable, "g"))

local Return    = Lpeg.Ct(Space ^ 0 * Lpeg.Cg(Lpeg.P("return"), "special"))
local Break     = Lpeg.Ct(Space ^ 0 * Lpeg.Cg(Lpeg.P("break"), "special"))
local Continue  = Lpeg.Ct(Space ^ 0 * Lpeg.Cg(Lpeg.P("continue"), "special"))

local StringSep1 = Lpeg.P("\"")
local StringSep2 = Lpeg.P("'")
local String1_2 = (StringSep2 * Lpeg.Cg(((Lpeg.P("/") * Space ^ 0 * NL * (Empty ^ 0) * (Space ^ 0 * Lpeg.P("//") * Char ^ 0 * NL) ^ 0) + (Lpeg.B( - StringSep2) * Char)) ^ 0, "string") * StringSep2)
local String2_2 = (Lpeg.P("<<") * StringSep2 * Lpeg.Cg(((NL) + (Lpeg.B( - (StringSep2 * Lpeg.P(">>"))) * Char)) ^ 0, "string") * StringSep2 * Lpeg.P(">>"))

local ExpSep  = (Space) ^ 0
local ExpOp1  = Lpeg.P(",")
local ExpOp2  = Lpeg.P("+=") + Lpeg.P("-=") + Lpeg.P("*=") + Lpeg.P("/=") + Lpeg.P("%=") + Lpeg.P("+:=") + Lpeg.P("-:=") + Lpeg.P("*:=") + Lpeg.P("/:=") + Lpeg.P("%:=") + Lpeg.P(",=")
local ExpOp3  = Lpeg.P("=") + Lpeg.P(":=")
local ExpOp4  = Lpeg.P("||")
local ExpOp5  = Lpeg.P("&&")
local ExpOp6  = Lpeg.P("==") + Lpeg.P("!=") + Lpeg.P("<=") + Lpeg.P(">=") + Lpeg.S("<>") + Lpeg.P("_in_") + Lpeg.P("!_in_")
local ExpOp7  = Lpeg.P("&")
local ExpOp8  = Lpeg.S("+-")
local ExpOp9  = Lpeg.S("*/%")
local ExpOp10 = Lpeg.P("++") + Lpeg.P("--")
local ExpOp11 = Lpeg.P("!")
local ExpS1   = Lpeg.V("exp1")
local ExpS2   = Lpeg.V("exp2")
local ExpS3   = Lpeg.V("exp3")
local ExpS4   = Lpeg.V("exp4")
local ExpS5   = Lpeg.V("exp5")
local ExpS6   = Lpeg.V("exp6")
local ExpS7   = Lpeg.V("exp7")
local ExpS8   = Lpeg.V("exp8")
local ExpS9   = Lpeg.V("exp9")
local ExpS10  = Lpeg.V("exp10")
local ExpS11  = Lpeg.V("exp11")
local ExpS12  = Lpeg.V("exp12")
--[=[
  + ((Lpeg.Cg(Lpeg.Cp(), "pos") * Lpeg.Cg(GlobalVariable, "g"))
  ---[[
  * ( ExpSep *
    (
    Lpeg.Cg((Lpeg.P("[") * ExpSep * Lpeg.Ct(ExpS1) * ExpSep * Lpeg.P("]")), "index")
    + Lpeg.Cg(Lpeg.Ct(Lpeg.P("(") * (ExpSep * Lpeg.Ct(ExpS1) * (ExpSep * Lpeg.P(",") * ExpSep * Lpeg.Ct(ExpS1)) ^ 0) ^ -1 * ExpSep * Lpeg.P(")")), "func")
    )
  ) ^ 0
  --]]
  )
--]=]
local ExpressionInString  = Lpeg.P({
  ExpS1,
  exp1  = ((ExpS2) * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp1, "enum")) * (ExpSep * ExpS2) ^ -1) ^ 0 + (Lpeg.Ct(Lpeg.Cg(ExpOp1, "enum")) * (ExpS2) ^ -1) ^ 1),
  exp2  = (ExpS3 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp2, "op_assign")) * ExpSep * ExpS3) ^ 0),
  exp3  = (ExpS4 * (ExpSep * Lpeg.Ct(Lpeg.Cg(Lpeg.Cp(), "pos") * Lpeg.Cg(ExpOp3, "assign")) * ExpSep * ExpS4) ^ 0),
  exp4  = (ExpS5 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp4, "or")) * ExpSep * ExpS5) ^ 0),
  exp5  = (ExpS6 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp5, "and")) * ExpSep * ExpS6) ^ 0),
  exp6  = (ExpS7 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp6, "comparison")) * ExpSep * ExpS7) ^ 0),
  exp7  = ((Lpeg.Ct(Lpeg.Cg(ExpOp7, "feedback")) * ExpSep) ^ -1 * ExpS8),
  exp8  = (ExpS9 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp8, "add")) * ExpSep * ExpS9) ^ 0 + Lpeg.Ct(Lpeg.Cg(ExpOp8, "add")) * ExpSep * ExpS9),
  exp9  = (ExpS10 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp9, "multi")) * ExpSep * ExpS10) ^ 0),
  exp10 = (ExpS11 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp10, "inc"))) ^ -1),
  exp11 = ((Lpeg.Ct(Lpeg.Cg(ExpOp11, "not")) * ExpSep) ^ -1 * ExpS12),
  exp12 = Lpeg.Ct(Number 
  + (String1_2 + String2_2) * Lpeg.Cg((ExpSep * Lpeg.P("[") * ExpSep * Lpeg.Ct(ExpS1) * ExpSep * Lpeg.P("]")), "index") ^ 0
  + (Lpeg.Cg(Lpeg.Cp(), "pos") * Lpeg.Cg(LocalVariable, "l")) * Lpeg.Cg((ExpSep * Lpeg.P("[") * ExpSep * Lpeg.Ct(ExpS1) * ExpSep * Lpeg.P("]")), "index") ^ 0
  + (Lpeg.P("(") * ExpSep * ExpS1 * ExpSep * Lpeg.P(")")) * Lpeg.Cg((ExpSep * Lpeg.P("[") * ExpSep * Lpeg.Ct(ExpS1) * ExpSep * Lpeg.P("]")), "index") ^ 0
  + ((Lpeg.Cg(Lpeg.Cp(), "pos") * Lpeg.Cg(GlobalVariable, "g"))
    * Lpeg.Cg(Lpeg.Ct(Lpeg.Ct( ExpSep * (Lpeg.Cg((Lpeg.P("[") * ExpSep * Lpeg.Ct(ExpS1) * ExpSep * Lpeg.P("]")), "index")
      + (Lpeg.Cg(Lpeg.Ct(Lpeg.P("(") * (ExpSep * Lpeg.Ct(ExpS1) * (ExpSep * Lpeg.P(",") * ExpSep * Lpeg.Ct(ExpS1)) ^ 0) ^ -1 * ExpSep * Lpeg.P(")")), "func")))) ^ 0), "append"))
  + (Lpeg.P("(") * ExpSep * ExpS1 * ExpSep * Lpeg.P(")"))),
})
local String1_1 = (StringSep1 * Lpeg.Cg(Lpeg.Ct(((Lpeg.P("%(") * ExpSep * (ExpressionInString) * ExpSep * Lpeg.P(")")) + Lpeg.Ct(Lpeg.Cg((((Lpeg.P("/") * Space ^ 0 * NL * (Empty ^ 0) * (Space ^ 0 * Lpeg.P("//") * Char ^ 0 * NL) ^ 0)) + Lpeg.B( - (StringSep1 + Lpeg.P("%("))) * Char) ^ 1, "text"))) ^ 0), "string") * StringSep1)
local String1 = String1_1 + String1_2

local String2_1 = Lpeg.V("string2_1")
local String2 = Lpeg.V("string2")
local StringV = Lpeg.V("stringv")

local Exp1  = Lpeg.V("exp1")
local Exp2  = Lpeg.V("exp2")
local Exp3  = Lpeg.V("exp3")
local Exp4  = Lpeg.V("exp4")
local Exp5  = Lpeg.V("exp5")
local Exp6  = Lpeg.V("exp6")
local Exp7  = Lpeg.V("exp7")
local Exp8  = Lpeg.V("exp8")
local Exp9  = Lpeg.V("exp9")
local Exp10 = Lpeg.V("exp10")
local Exp11 = Lpeg.V("exp11")
local Exp12 = Lpeg.V("exp12")
local ExpTbl  = 
{
  exp1  = (Exp2 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp1, "enum")) * (ExpSep * Exp2) ^ -1) ^ 0 + (Lpeg.Ct(Lpeg.Cg(ExpOp1, "enum")) * ExpSep * (Exp2) ^ -1) ^ 1),
  exp2  = (Exp3 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp2, "op_assign")) * ExpSep * Exp3) ^ 0),
  exp3  = (Exp4 * (ExpSep * Lpeg.Ct(Lpeg.Cg(Lpeg.Cp(), "pos") * Lpeg.Cg(ExpOp3, "assign")) * ExpSep * Exp4) ^ 0),
  exp4  = (Exp5 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp4, "or")) * ExpSep * Exp5) ^ 0),
  exp5  = (Exp6 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp5, "and")) * ExpSep * Exp6) ^ 0),
  exp6  = (Exp7 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp6, "comparison")) * ExpSep * Exp7) ^ 0),
  exp7  = ((Lpeg.Ct(Lpeg.Cg(ExpOp7, "feedback")) * ExpSep) ^ -1 * Exp8),
  exp8  = (Exp9 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp8, "add")) * ExpSep * Exp9) ^ 0 + Lpeg.Ct(Lpeg.Cg(ExpOp8, "add") * ExpSep * Exp9)),
  exp9  = (Exp10 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp9, "multi")) * ExpSep * Exp10) ^ 0),
  exp10 = (Exp11 * (ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp10, "inc"))) ^ -1),
  exp11 = ((ExpSep * Lpeg.Ct(Lpeg.Cg(ExpOp11, "not")) * ExpSep) ^ -1 * Exp12),
  exp12 = Lpeg.Ct(Number 
  + StringV * Lpeg.Cg((ExpSep * Lpeg.P("[") * ExpSep * Lpeg.Ct(Exp1) * ExpSep * Lpeg.P("]")), "index") ^ 0
  + Return + Break + Continue
  + (Lpeg.Cg(Lpeg.Cp(), "pos") * Lpeg.Cg(LocalVariable, "l")) * Lpeg.Cg((ExpSep * Lpeg.P("[") * ExpSep * Lpeg.Ct(Exp1) * ExpSep * Lpeg.P("]")), "index") ^ 0
  + (Lpeg.P("(") * ExpSep * Exp1 * ExpSep * Lpeg.P(")")) * Lpeg.Cg((ExpSep * Lpeg.P("[") * ExpSep * Lpeg.Ct(Exp1) * ExpSep * Lpeg.P("]")), "index") ^ 0
  + (Lpeg.Cg(Lpeg.Cp(), "pos") * Lpeg.Cg(GlobalVariable, "g"))
    * Lpeg.Cg(Lpeg.Ct(Lpeg.Ct( ExpSep * (Lpeg.Cg((Lpeg.P("[") * ExpSep * Lpeg.Ct(Exp1) * ExpSep * Lpeg.P("]")), "index")
      + (Lpeg.Cg(Lpeg.Ct(Lpeg.P("(") * (ExpSep * Lpeg.Ct(Exp1) * (ExpSep * Lpeg.P(",") * ExpSep * Lpeg.Ct(Exp1)) ^ 0) ^ -1 * ExpSep * Lpeg.P(")")), "func")))) ^ 0), "append")
      + (Lpeg.P("(") * ExpSep * Exp1 * ExpSep * Lpeg.P(")"))),
  stringv = String1 + String2,
  string2 = String2_1 + String2_2,
  string2_1 = (Lpeg.P("<<") * StringSep1 * Lpeg.Cg(Lpeg.Ct(((Lpeg.P("%(") * ExpSep * (Exp1) * ExpSep * Lpeg.P(")")) + Lpeg.Ct(Lpeg.Cg((((NL)) + Lpeg.B( - (Lpeg.P("%(") + (StringSep1 * Lpeg.P(">>")))) * Char) ^ 1, "text"))) ^ 0), "string") * StringSep1 * Lpeg.P(">>")),
}
local Expression  = Lpeg.P(
{
  Exp1,
  exp1  = ExpTbl.exp1,
  exp2  = ExpTbl.exp2,
  exp3  = ExpTbl.exp3,
  exp4  = ExpTbl.exp4,
  exp5  = ExpTbl.exp5,
  exp6  = ExpTbl.exp6,
  exp7  = ExpTbl.exp7,
  exp8  = ExpTbl.exp8,
  exp9  = ExpTbl.exp9,
  exp10  = ExpTbl.exp10,
  exp11  = ExpTbl.exp11,
  exp12  = ExpTbl.exp12,
  stringv = ExpTbl.stringv,
  string2 = ExpTbl.string2,
  string2_1 = ExpTbl.string2_1,
}
)
local String  = Lpeg.P(
{
  StringV,
  exp1  = ExpTbl.exp1,
  exp2  = ExpTbl.exp2,
  exp3  = ExpTbl.exp3,
  exp4  = ExpTbl.exp4,
  exp5  = ExpTbl.exp5,
  exp6  = ExpTbl.exp6,
  exp7  = ExpTbl.exp7,
  exp8  = ExpTbl.exp8,
  exp9  = ExpTbl.exp9,
  exp10  = ExpTbl.exp10,
  exp11  = ExpTbl.exp11,
  exp12  = ExpTbl.exp12,
  stringv = ExpTbl.stringv,
  string2 = ExpTbl.string2,
  string2_1 = ExpTbl.string2_1,
}
)

local Alternative = Lpeg.P("void") + Lpeg.P("pool") + Lpeg.P("all") + Lpeg.P("last") + (Lpeg.P("melt_") ^ -1) * (Lpeg.P("random") + Lpeg.P("nonoverlap") + Lpeg.P("sequential") + Lpeg.P("array")) * (Lpeg.P("_pool") ^ -1)
local AlternativeSep  = Lpeg.Ct(Space ^ 0 * Lpeg.Cg(Lpeg.P("--"), "altersep") * Space ^ 0 * (Comment1 + NL))
local ForCondSep  = Lpeg.P(";")
local ForCondition  = Lpeg.Ct(Lpeg.Cg(Lpeg.Ct(Expression), "init") * Space ^ 0 * ForCondSep * (Space ^ 0 * ForCondSep) ^ 0 * Space ^ 0 * Lpeg.Cg(Lpeg.Ct(Expression), "condition") * Space ^ 0 * ForCondSep * (Space ^ 0 * ForCondSep) ^ 0 * Space ^ 0 * Lpeg.Cg(Lpeg.Ct(Expression), "next"))
local ForeachCondition  = Lpeg.Ct(Lpeg.Cg(Lpeg.Ct(Expression), "array") * Space ^ 0 * ForCondSep * Space ^ 0 * Lpeg.Cg(Lpeg.Ct(Variable), "var"))
local Label = String + Number
local WhenCondition = Lpeg.Ct(Lpeg.Ct(Lpeg.Cg(Label, "name")) * ((Space ^ 0 * Lpeg.P(",") * Space ^ 0 * Lpeg.Ct(Lpeg.Cg(Label, "name"))) + (Space ^ 0 * Lpeg.P("-") * Space ^ 0 * Lpeg.Ct(Lpeg.Cg(Label, "name")))) ^ 0)

local Scope1          = Lpeg.V("scope1")
local Scope2          = Lpeg.V("scope2")
local ScopeInner      = Lpeg.V("scopeinner")
local ScopeParallel   = Lpeg.V("scopeparallel")
local ScopeIf         = Lpeg.V("scopeif")
local ScopeIfIf       = Lpeg.V("scopeifif")
local ScopeIfElseIf   = Lpeg.V("scopeifelseif")
local ScopeIfElse     = Lpeg.V("scopeifelse")
local ScopeWhile      = Lpeg.V("scopewhile")
local ScopeFor        = Lpeg.V("scopefor")
local ScopeForeach    = Lpeg.V("scopeforeach")
local ScopeCase       = Lpeg.V("scopecase")
local ScopeCaseCase   = Lpeg.V("scopecasecase")
local ScopeCaseWhen   = Lpeg.V("scopecasewhen")
local ScopeCaseOthers = Lpeg.V("scopecaseothers")
local ScopeSwitch     = Lpeg.V("scopeswitch")
--local OneLineExpression = Expression * (Space ^ 0 * Lpeg.P(";") * Space ^ 0 * Expression) ^ 0
local OneLineExpression = ScopeInner
local ScopeTbl  = {
  scope1    = Lpeg.Ct((Lpeg.Cg(Alternative, "alter") * SepEx ^ 0 * Lpeg.P(":") * SepEx ^ 0) ^ -1 * Scope2),
  scope2    = ScopeBegin * Lpeg.Ct(ScopeInner ^ 0) * (SepEx + Sep2) ^ 0 * ScopeEnd,
  scopeinner  = ((SepEx + Sep2) ^ 0 * (Lpeg.Ct(ScopeParallel)
  + Lpeg.Ct(Space ^ 0 * Lpeg.Ct(Lpeg.Cg((Scope1), "scope")) * Space ^ 0) + Lpeg.Ct(ScopeIf) + Lpeg.Ct(ScopeWhile) + Lpeg.Ct(ScopeFor) + Lpeg.Ct(ScopeForeach) + Lpeg.Ct(ScopeCase) + Lpeg.Ct(ScopeSwitch) + AlternativeSep
  + (Space ^ 0 * Lpeg.Ct(Expression) * Space ^ 0)
  + Empty) * (SepEx + Sep2) ^ 0),
  scopeparallel = Lpeg.Ct((Lpeg.P("parallel") + Lpeg.P("void")) * SepEx ^ 1 * Lpeg.Cg(Lpeg.Ct(Expression), "parallel")),
  scopeif   = ScopeIfIf * ((SepEx + Sep2) ^ 0 * ScopeIfElseIf) ^ 0 * ((SepEx + Sep2) ^ 0 * ScopeIfElse) ^ -1,
  scopeifif = Lpeg.Ct(Space ^ 0 * Lpeg.P("if") * Space ^ 0 * Lpeg.Cg(Lpeg.Ct(Expression + (Lpeg.P("(") * Expression * Lpeg.P(")"))), "condition") * Lpeg.Cg((SepEx + Sep2) ^ 0 * Scope1 + Lpeg.Ct(Lpeg.Ct(Space ^ 0 * ((Space ^ 0 * Comment1) + Sep + Sep2) ^ 1 * Space ^ 0 * OneLineExpression * (Sep + Sep2) ^ 0)), "scope_if")),
  scopeifelseif = Lpeg.Ct(Space ^ 0 * Lpeg.P("elseif") * Space ^ 0 * Lpeg.Cg(Lpeg.Ct(Expression + (Lpeg.P("(") * Expression * Lpeg.P(")"))), "condition") * Lpeg.Cg(SepEx ^ 0 * Scope1 + Lpeg.Ct(Lpeg.Ct(Space ^ 0 * ((Space ^ 0 * Comment1) + Sep + Sep2) ^ 1 * Space ^ 0 * OneLineExpression)), "scope_elseif")),
  scopeifelse = Lpeg.Ct(Space ^ 0 * Lpeg.P("else") * Lpeg.Cg(Lpeg.Ct(Lpeg.Ct(Space ^ 0 * ((Space ^ 0 * Comment1) + Sep + Sep2) ^ 1 * Space ^ 0 * OneLineExpression)) + (SepEx + Sep2) ^ 0 * Scope1, "scope_else")),
  scopewhile  = Lpeg.Ct(Space ^ 0 * Lpeg.P("while") * Lpeg.Cg(Lpeg.Ct((Space ^ 1 * Expression) + (Space ^ 0 * Lpeg.P("(") * Expression * Lpeg.P(")"))), "condition") * (SepEx + Sep2) ^ 0 * Lpeg.Cg(Scope1 + Lpeg.Ct(Lpeg.Ct(OneLineExpression)), "scope_while")),
  scopefor  = Lpeg.Ct(Space ^ 0 * Lpeg.P("for") * Lpeg.Cg(Lpeg.Ct((Space ^ 1 * ForCondition) + (Space ^ 0 * Lpeg.P("(") * ForCondition * Lpeg.P(")"))), "condition") * (SepEx + Sep2) ^ 0 * Lpeg.Cg(Scope1 + Lpeg.Ct(Lpeg.Ct(OneLineExpression)), "scope_for")),
  scopeforeach  = Lpeg.Ct(Space ^ 0 * Lpeg.P("foreach") * Lpeg.Cg(Lpeg.Ct((Space ^ 1 * ForeachCondition) + (Space ^ 0 * Lpeg.P("(") * ForeachCondition * Lpeg.P(")"))), "condition") * SepEx ^ 0 * Lpeg.Cg(Scope1 + Lpeg.Ct(Lpeg.Ct(OneLineExpression)), "scope_foreach")),
  scopecase   = ScopeCaseCase,
  scopecasecase = Lpeg.Ct(Space ^ 0 * Lpeg.P("case") * Space ^ 0 * Lpeg.Cg(Lpeg.Ct(Expression + (Lpeg.P("(") * Expression * Lpeg.P(")"))), "condition") * SepEx ^ 0 * Lpeg.Cg(SepEx ^ 0 * Lpeg.P("{" ) * Lpeg.Ct((SepEx ^ 0 * ScopeCaseWhen + (ScopeInner)) ^ 0 * (SepEx ^ 0 * ScopeCaseOthers) ^ -1 * Lpeg.Ct(ScopeInner ^ 0)) * SepEx ^ 0 * Lpeg.P("}"), "scope_case")),
  scopecasewhen = Lpeg.Ct(Space ^ 0 * Lpeg.P("when") * Space ^ 0 * Lpeg.Cg(Lpeg.Ct(WhenCondition + (Lpeg.P("(") * WhenCondition * Lpeg.P(")"))), "condition") * Lpeg.Cg(SepEx ^ 0 * Scope1 + Lpeg.Ct(Lpeg.Ct(Space ^ 0 * ((Space ^ 0 * Comment1) + Sep + Sep2) ^ 1 * Space ^ 0 * OneLineExpression * (Sep + Sep2) ^ 0)), "scope_when")),
  scopecaseothers = Lpeg.Ct(Space ^ 0 * Lpeg.P("others") * Lpeg.Cg(Lpeg.Ct(Lpeg.Ct(Space ^ 0 * ((Space ^ 0 * Comment1) + Sep + Sep2) ^ 1 * Space ^ 0 * OneLineExpression)) + SepEx ^ 0 * Scope1, "scope_others")),
  scopeswitch = Lpeg.Ct(Space ^ 0 * Lpeg.P("switch") * Space ^ 0 * Lpeg.Cg(Lpeg.Ct(Expression + (Lpeg.P("(") * Expression * Lpeg.P(")"))), "condition") * SepEx ^ 0 * Lpeg.Cg(Scope1 + Lpeg.Ct(Lpeg.Ct(OneLineExpression)), "scope_switch")),
}
local Scope = Lpeg.P({
  Scope1,
  scope1          = ScopeTbl.scope1,
  scope2          = ScopeTbl.scope2,
  scopeinner      = ScopeTbl.scopeinner,
  scopeparallel   = ScopeTbl.scopeparallel,
  scopeif         = ScopeTbl.scopeif,
  scopeifif       = ScopeTbl.scopeifif,
  scopeifelseif   = ScopeTbl.scopeifelseif,
  scopeifelse     = ScopeTbl.scopeifelse,
  scopewhile      = ScopeTbl.scopewhile,
  scopefor        = ScopeTbl.scopefor,
  scopeforeach    = ScopeTbl.scopeforeach,
  scopecase       = ScopeTbl.scopecase,
  scopecasecase   = ScopeTbl.scopecasecase,
  scopecasewhen   = ScopeTbl.scopecasewhen,
  scopecaseothers = ScopeTbl.scopecaseothers,
  scopeswitch     = ScopeTbl.scopeswitch,
})
local ScopeOuter = Lpeg.P({
  Scope2,
  scope1  = ScopeTbl.scope1,
  scope2  = ScopeTbl.scope2,
  scopeinner      = ScopeTbl.scopeinner,
  scopeparallel   = ScopeTbl.scopeparallel,
  scopeif       = ScopeTbl.scopeif,
  scopeifif     = ScopeTbl.scopeifif,
  scopeifelseif = ScopeTbl.scopeifelseif,
  scopeifelse   = ScopeTbl.scopeifelse,
  scopewhile    = ScopeTbl.scopewhile,
  scopefor      = ScopeTbl.scopefor,
  scopeforeach  = ScopeTbl.scopeforeach,
  scopecase       = ScopeTbl.scopecase,
  scopecasecase   = ScopeTbl.scopecasecase,
  scopecasewhen   = ScopeTbl.scopecasewhen,
  scopecaseothers = ScopeTbl.scopecaseothers,
  scopeswitch     = ScopeTbl.scopeswitch,
})
local Function  = Lpeg.Ct(Space ^ 0 * Lpeg.Cg(Lpeg.Cp(), "pos") * Lpeg.Cg(Name, "name") * (SepEx ^ 0 * Lpeg.P(":") * SepEx ^ 0 * Lpeg.Cg(Alternative, "alter")) ^ -1 * SepEx ^ 0 * Lpeg.Cg(ScopeOuter, "body"))

local Grammar = Lpeg.Ct((Function + Empty) ^ 0) * -1

local Error = {
  fail  = "syntax error:",
}


local parser  = ArgParse("yayalint", "YAYA linter")
parser:argument("path", "Path of the folder containing yaya.dll")
parser:flag("-F --nofile")
parser:flag("-s --nosyntaxerror")
parser:flag("-w --nowarning")
parser:flag("-f --nofunction")
parser:flag("-u --nounused")
parser:flag("-d --noundefined")
parser:flag("-l --nolocal")
parser:flag("-g --noglobal")

local args  = parser:parse()

local output  = StringBuffer()

local function dump(t, indent)
  indent  = indent or ""
  for k, v in pairs(t) do
    if type(v) == "table" then
      print(indent, k, "= {")
      dump(v, indent .. "\t")
      print(indent, "}")
    else
      print(indent, k, "=", v)
    end
  end
end

local function pos2linecol(t, data)
  if type(t) == "table" then
    for k, v in pairs(t) do
      if type(v) == "table" then
        pos2linecol(v, data)
      end
    end
    if t.pos then
      local pos   = t.pos
      local line  = 1
      -- + 1 は改行の分
      while pos > (#data[line] + 1) do
        pos   = pos - (#data[line] + 1)
        line  = line + 1
      end
      t.line  = line
      -- 直前の文字まで+1がcaptureした文字の開始位置
      t.col   = utf8.len(string.sub(data[line], 1, pos - 1)) + 1
      t.pos   = nil
    end
  end
end

local function parse(path, filename, global_define)
  filename  = Path.normalize(filename, "win", {sep = "/"})
  local fh  = io.open(path .. filename, "rb")
  if not(fh) then
    if args.nofile then
      return nil, nil
    else
      return nil, string.format("not found:%s%s%s", OutputSep, path, filename)
    end
  end
  local data  = fh:read("*a")
  fh:close()
  if not(data) then
    if args.nofile then
      return nil, nil
    else
      return nil, string.format("not found:%s%s%s", OutputSep, path, filename)
    end
  end
  if string.sub(filename, -4) == ".ayc" then
    data  = AycDecoder.decode(data)
  end
  data  = string.gsub(data, "\x0d\x0a", "\x0a")
  data  = string.gsub(data, "\x0d", "\x0a")
  data  = data .. "\n" -- noeolに対応
  -- UTF-8(with BOM) => UTF-8
  if string.sub(data, 1, 3) == string.char(0xef, 0xbb, 0xbf) then
    data  = string.sub(data, 4)
  end
  -- Shift_JIS => UTF-8
  local tmp = Conv.conv(data, "UTF-8", "CP932")
  if tmp then
    data  = tmp
  end

  -- preprocess
  local function escape(s)
    --[[
    local t = {
      "%%",
      "%.", "%*", "%+", "%-", "%^",
      "%(", "%)", "%[", "%]", "%$",
    }
    --]]
    local t = {
      "%",
      ".", "*", "+", "-", "^",
      "(", ")", "[", "]", "$",
    }
    for _, v in ipairs(t) do
      --s = string.gsub(s, v, "%" .. v)
      if v == "%" then
        s = string.gsub(s, "%" .. v, "%%%" .. v)
      else
        s = string.gsub(s, "%" .. v, "%%" .. v)
      end
    end
    return s
  end
  local define  = {}
  local i = 1
  local str = StringBuffer()
  for line in string.gmatch(data, "[^\x0a]*") do
    if string.sub(line, 1, 1) == "#" then
      local before, after = string.match(line, "#define[ \t]*([^ \t]+)[ \t]+(.+)")
      if before and after then
        --print("DEFINE:", before, after)
        --print("DEFINE", escape(before), string.gsub(after, "%%", "%%%%"))
        table.insert(define, {
          before  = escape(before),
          after   = string.gsub(after, "%%", "%%%%"),
        })
      end
      local before, after = string.match(line, "#globaldefine[ \t]*([^ \t]+)[ \t]+(.+)")
      if before and after then
        --print("GLOBALDEFINE:", before, after)
        --print("GLOBAL DEFINE", escape(before), string.gsub(after, "%%", "%%%%"))
        table.insert(global_define, {
          before  = escape(before),
          after   = string.gsub(after, "%%", "%%%%"),
        })
      end
      str:append("\x0a")
    else
      local s = line
      s = string.gsub(s, "__AYA_SYSTEM_FILE__", filename)
      s = string.gsub(s, "__AYA_SYSTEM_LINE__", i)
      for _, v in ipairs(define) do
        --print(string.format("%s", v.before), string.format("%s", v.after))
        s = string.gsub(s, v.before, v.after)
      end
      for _, v in ipairs(global_define) do
        s = string.gsub(s, v.before, v.after)
      end
      str:append(s):append("\x0a")
    end
    i = i + 1
  end

  data  = str:tostring()

  local t, label, pos = Lpeg.match(Grammar, data)
  local line, col = Re.calcline(data, pos)
  local err_line  = ""
  local index = 1
  local index_sub = (col == 1) and 1 or 0
  for l in string.gmatch(data, "[^\x0a]*") do
    if index + index_sub == line then
      err_line  = l
    end
    index = index + 1
  end
  local c = ""
  local p = 0
  local err_pos = col == 1 and (#err_line + 1) or col
  for pos, code in utf8.codes(err_line) do
    if pos < err_pos then
      p = pos
      c = utf8.char(code)
    end
  end
  col = utf8.len(string.sub(err_line, 1, p - 1)) + 1
  -- \tをそのまま出力するとバグるので変換。
  -- 他の見えない文字も変換するべき？
  if c == "\t" then
    c = "\\t"
  end
  if not(t) then
    if args.nosyntaxerror then
      return nil, nil
    else
      return nil, table.concat({Error[label], c, "at", filename, "pos:", line .. ":" .. col}, OutputSep)
    end
  end
  t.filename  = filename
  local linecol = {}
  for s in string.gmatch(data, "[^\x0a]*") do
    table.insert(linecol, s)
  end
  pos2linecol(t, linecol)
  return t
end

local function isFunc(e)
  if e.append then
    for i, v in ipairs(e.append) do
      if i == 1 and v.func then
        return true
      end
    end
  end
  return false
end

local function recursive(scope, gv, upper, filename, funcname, global, opt)
  opt = opt or {
    var_foreach = false,
    overwrite   = false,
    force_read  = false,
  }
  --[[
  if type(scope) ~= "table" then
    -- TODO warning
    return
  end
  --]]
  local lv  = {}
  if opt.overwrite then
    lv  = upper
  else
    for k, v in pairs(upper) do
      lv[k] = v
    end
  end

  local function assignmentInCondition(t, filename)
    for _, v in ipairs(t) do
      if type(v) == "table" then
        if v.assign then
          output:append(table.concat({"assignment operator exists in conditional statement:", v.assign, "at", filename, "pos:", v.line .. ":" .. v.col}, OutputSep)):append(NewLine)
        end
        if #v > 0 then
          assignmentInCondition(v, filename)
        end
      end
    end
  end

  for _, line in ipairs(scope) do
    if type(line) ~= "table" then
      print("line:", line)
    end
    for i, col in ipairs(line) do
      if #col > 0 then
        recursive({col}, gv, lv, filename, funcname, global, {
          overwrite = true,
        })
      end
      if col.append then
        recursive({col.append}, gv, lv, filename, funcname, global, {
          overwrite   = true,
          force_read  = true,
        })
      end
      if col.scope then
        recursive(col.scope[1], gv, lv, filename, funcname, global)
      end
      if col.parallel then
        recursive({col.parallel}, gv, lv, filename, funcname, global, {
          overwrite = true,
        })
      end
      if col.scope_if then
        if global then
          assignmentInCondition(col.condition, filename)
        end
        recursive({col.condition}, gv, lv, filename, funcname, global, {
          overwrite   = true,
          force_read  = true,
        })
        recursive(col.scope_if, gv, lv, filename, funcname, global)
      end
      if col.scope_elseif then
        if global then
          assignmentInCondition(col.condition, filename)
        end
        recursive({col.condition}, gv, lv, filename, funcname, global, {
          overwrite   = true,
          force_read  = true,
        })
        recursive(col.scope_elseif[1], gv, lv, filename, funcname, global)
      end
      if col.scope_else then
        recursive(col.scope_else[1], gv, lv, filename, funcname, global)
      end
      if col.scope_while then
        if global then
          assignmentInCondition(col.condition, filename)
        end
        recursive({col.condition}, gv, lv, filename, funcname, global, {
          overwrite   = true,
          force_read  = true,
        })
        recursive(col.scope_while[1], gv, lv, filename, funcname, global)
      end
      if col.scope_for then
        --[[
        local var = {}
        for k, v in pairs(lv) do
          var[k]  = v
        end
        --]]
        recursive({col.condition[1].init}, gv, lv, filename, funcname, global, {
          overwrite = true,
        })
        if global then
          assignmentInCondition(col.condition[1].condition or {}, filename)
        end
        recursive({col.condition[1].condition}, gv, lv, filename, funcname, global, {
          overwrite   = true,
          force_read  = true,
        })
        recursive({col.condition[1].next}, gv, lv, filename, funcname, global, {
          overwrite = true,
        })
        recursive(col.scope_for[1], gv, lv, filename, funcname, global)
      end
      if col.scope_foreach then
        recursive({{col.condition[1].array}}, gv, lv, filename, funcname, global, {
          overwrite   = true,
          force_read  = true,
        })
        --[[
        local var = {}
        for k, v in pairs(lv) do
          var[k]  = v
        end
        --]]
        recursive({{col.condition[1].var}}, gv, lv, filename, funcname, global, {
          var_foreach = true,
          overwrite   = true,
        })
        recursive(col.scope_foreach[1], gv, lv, filename, funcname, global)
      end
      if col.scope_case then
        recursive({col.condition}, gv, lv, filename, funcname, global, {
          overwrite   = true,
          force_read  = true,
        })
        local doubt = false
        for _, v in ipairs(col.scope_case) do
          -- when節とothers節以外はネストが1つ深い
          if #v > 0 then
            doubt = true
            break
          end
        end
        if doubt then
          if global then
            if not(args.nowarning) then
              output:append(table.concat({"case statement contains a clause that is neither a when clause nor others clause:", "", "at", filename, funcname}, OutputSep)):append(NewLine)
            end
          end
        end
        recursive({col.scope_case}, gv, lv, filename, funcname, global)
      end

      if col.scope_when then
        recursive(col.scope_when[1], gv, lv, filename, funcname, global)
      end
      if col.scope_others then
        recursive(col.scope_others[1], gv, lv, filename, funcname, global)
      end
      if col.scope_switch then
        recursive({col.condition}, gv, lv, filename, funcname, global, {
          overwrite   = true,
          force_read  = true,
        })
        recursive(col.scope_switch[1], gv, lv, filename, funcname, global)
      end
      if col.string then
        if type(col.string) == "table" then
          recursive({col.string}, gv, lv, filename, funcname, global, {
            overwrite   = true,
            force_read  = true,
          })
        end
      end
      if col.l then
        local v = col.l
        if lv[v] == nil then
          lv[v] = {
            read  = false,
            write = false,
            line  = col.line,
            col   = col.col,
          }
        end
        if opt.var_foreach then
          lv[v].write = true
        end
        if opt.force_read then
          lv[v].read  = true
        end
        if line[i - 1] and (not(line[i - 1].enum) or not(line[i + 1]) or line[i + 1].enum) then
          lv[v].read  = true
          if not(lv[v].write) then
            if global then
              if not(args.noundefined) and not(args.nolocal) then
                if not(UserDefined.isUserDefinedVariable(v)) then
                  local maybe = Levenshtein(v, lv, gv) or ""
                  output:append(table.concat({"read undefined variable:", v, "at", filename, "pos:", col.line .. ":" .. col.col, "maybe:", maybe}, OutputSep)):append(NewLine)
                end
              end
            end
          end
        elseif line[i + 1] then
          if (line[i + 1].assign or line[i + 1].op_assign) then
            lv[v].write = true
          else
            lv[v].read  = true
            if not(lv[v].write) then
              if global then
                if not(args.noundefined) and not(args.nolocal) then
                  if not(UserDefined.isUserDefinedVariable(v)) then
                    local maybe = Levenshtein(v, lv, gv) or ""
                    output:append(table.concat({"read undefined variable:", v, "at", filename, "pos:", col.line .. ":" .. col.col, "maybe:", maybe}, OutputSep)):append(NewLine)
                  end
                end
              end
            end
          end
        elseif #line == 1 and not(opt.var_foreach)then
          lv[v].read = true
          if not(lv[v].write) then
            if global then
              if not(args.noundefined) and not(args.nolocal) then
                if not(UserDefined.isUserDefinedVariable(v)) then
                  local maybe = Levenshtein(v, lv, gv) or ""
                  output:append(table.concat({"read undefined variable:", v, "at", filename, "pos:", col.line .. ":" .. col.col, "maybe:", maybe}, OutputSep)):append(NewLine)
                end
              end
            end
          end
        end
      end
      if col.g then
        local v = col.g
        if gv[v] == nil then
          gv[v] = {
            read  = false,
            write = false,
          }
        end
        if opt.force_read then
          gv[v].read  = true
        end
        if opt.var_foreach then
          lv[v].write = true
        end
        if line[i - 1] and (not(line[i - 1].enum) or not(line[i + 1]) or line[i + 1].enum) then
          gv[v].read  = true
          if global and not(global[v].write) then
            if isFunc(col) then
              if not(args.noundefined) and not(args.noglobal) then
                if not(UserDefined.isUserDefinedFunction(v)) then
                  local maybe = Levenshtein(v, gv, lv) or ""
                  output:append(table.concat({"read undefined function:", v, "at", filename, "pos:", col.line .. ":" .. col.col, "maybe:", maybe}, OutputSep)):append(NewLine)
                end
              end
            else
              if not(args.noundefined) and not(args.noglobal) then
                if not(UserDefined.isUserDefinedVariable(v)) then
                  local maybe = Levenshtein(v, gv, lv) or ""
                  output:append(table.concat({"read undefined variable:", v, "at", filename, "pos:", col.line .. ":" .. col.col, "maybe:", maybe}, OutputSep)):append(NewLine)
                end
              end
            end
          end
        elseif line[i + 1] then
          if (line[i + 1].assign or line[i + 1].op_assign) then
            gv[v].write = true
            if global then
              if isFunc(col) then
                if not(args.nounused) and not(args.noglobal) and not(args.no_unused_global) then
                  if not(UserDefined.isUserUsedFunction(v)) then
                    output:append(table.concat({"unused function:", v, "at", filename, "pos:", col.line .. ":" .. col.col}, OutputSep)):append(NewLine)
                  end
                end
              else
                if global[v].write and not(global[v].read) then
                  if not(args.nounused) and not(args.noglobal) and not(args.no_unused_global) then
                    if not(UserDefined.isUserUsedVariable(v)) then
                      output:append(table.concat({"unused variable:", v, "at", filename, "pos:", col.line .. ":" .. col.col}, OutputSep)):append(NewLine)
                    end
                  end
                end
              end
            end
          else
            gv[v].read  = true
            if global and not(global[v].write) then
              if isFunc(col) then
                if not(args.noundefined) and not(args.noglobal) then
                  if not(UserDefined.isUserDefinedFunction(v)) then
                    local maybe = Levenshtein(v, gv, lv) or ""
                    output:append(table.concat({"read undefined function:", v, "at", filename, "pos:", col.line .. ":" .. col.col, "maybe:", maybe}, OutputSep)):append(NewLine)
                  end
                end
              else
                if not(args.noundefined) and not(args.noglobal) then
                  if not(UserDefined.isUserDefinedVariable(v)) then
                    local maybe = Levenshtein(v, gv, lv) or ""
                    output:append(table.concat({"read undefined variable:", v, "at", filename, "pos:", col.line .. ":" .. col.col, "maybe:", maybe}, OutputSep)):append(NewLine)
                  end
                end
              end
            end
          end
        elseif #line == 1 and not(opt.var_foreach)then
          gv[v].read = true
          if global and not(global[v].write) then
            if isFunc(col) then
              if not(args.noundefined) and not(args.noglobal) then
                if not(UserDefined.isUserDefinedFunction(v)) then
                  local maybe = Levenshtein(v, gv, lv) or ""
                  output:append(table.concat({"read undefined function:", v, "at", filename, "pos:", col.line .. ":" .. col.col, "maybe:", maybe}, OutputSep)):append(NewLine)
                end
              end
            else
              if not(args.noundefined) and not(args.noglobal) then
                if not(UserDefined.isUserDefinedVariable(v)) then
                  local maybe = Levenshtein(v, gv, lv) or ""
                  output:append(table.concat({"read undefined variable:", v, "at", filename, "pos:", col.line .. ":" .. col.col, "maybe:", maybe}, OutputSep)):append(NewLine)
                end
              end
            end
          end
        end
      end
      if col.func then
        recursive({col.func}, gv, lv, filename, funcname, global, {
          overwrite   = true,
          force_read  = true,
        })
      end
      if col.index then
        recursive({col.index}, gv, lv, filename, funcname, global, {
          overwrite   = true,
          force_read  = true,
        })
      end
    end
  end
  for k, v in pairs(lv) do
    if upper[k] == nil then
      if v.write and not(v.read) then
        if global then
          if not(args.nolocal) and not(args.nounused) then
            if not(UserDefined.isUserDefinedVariable(k)) then
              output:append(table.concat({"unused variable:", k, "at", filename, "pos:", v.line .. ":" .. v.col}, OutputSep)):append(NewLine)
            end
          end
        end
      end
    end
  end
end

local function interpret(data)
  local gv  = {}
  for _, file in ipairs(data) do
    --print("filename", file.filename)
    for _, func in ipairs(file) do
      --print("function", func.name)
      if gv[func.name] == nil then
        gv[func.name] = {
          read  = false,
          write = false,
          line  = func.line,
          col   = func.col,
        }
      end
      gv[func.name].write = true
      recursive(func.body, gv, {}, file.filename, func.name)
    end
  end
  --dump(gv)
  for _, file in ipairs(data) do
    args.no_unused_global  = UserDefined.isSuppressWarning(file.filename)
    for _, func in ipairs(file) do
      --print("function", func.name)
      local v = gv[func.name]
      if v.write and not(v.read) then
        if not(args.nounused) and not(args.nofunction) and not(args.no_unused_global) then
          if not(UserDefined.isUserUsedFunction(func.name)) then
            output:append(table.concat({"unused function:", func.name, "at", file.filename, "pos:", v.line .. ":" .. v.col}, OutputSep)):append(NewLine)
          end
        end
      end
      recursive(func.body, {}, {}, file.filename, func.name, gv)
    end
  end
  for k, v in pairs(gv) do
    --[[
    if v.write and not(v.read) then
      if not(args.nounused) and not(args.noglobal) then
        output:append(table.concat({"unused variable:", k}, OutputSep)):append(NewLine)
      end
    end
    --]]
  end
end

local function getFileList(path, filename, relative, ignore)

  local function include(file_list, path, filename)
    local t = getFileList(path, filename)
    for _, v in ipairs(t) do
      table.insert(file_list, v)
    end
  end

  local function includeEX(file_list, path, relative, filename, ignore)
    local tmp_path, tmp_filename = string.match(filename, "^(.*[/\\])(.*)")
    if not(tmp_path) then
      tmp_path  = ""
      tmp_filename  = filename
    end
    if tmp_filename then
      local t, err = getFileList(path, tmp_filename, relative .. tmp_path, ignore)
      if err then
        return false
      end
      for _, v in ipairs(t) do
        table.insert(file_list, v)
      end
    end
    return true
  end

  local function dicdir(file_list, path, relative, dirname)
    local c = string.sub(dirname, -1, -1)
    if not(c == "/") and not(c == "\\") then
      dirname = dirname .. DirSep
    end
    local ret = includeEX(file_list, path, relative .. dirname, "_loading_order_override.txt", true)
    if not(ret) then
      ret = includeEX(file_list, path, relative .. dirname, "_loading_order.txt", true)
    end
    if not(ret) and Lfs.attributes(path .. relative ..dirname) then
      local function recursiveGetFiles(path, relative, dirname)
        for name in Lfs.dir(path .. relative .. dirname) do
          local attr  = Lfs.attributes(path .. relative .. dirname .. name)
          if name == "." or name == ".." then
            -- NOP
          elseif attr.mode == "directory" then
            recursiveGetFiles(path, relative .. dirname, name .. DirSep)
          elseif attr.mode == "file" then
            --print(relative .. dirname .. name)
            table.insert(file_list, relative .. dirname ..name)
          end
        end
      end
      recursiveGetFiles(path, relative, dirname)
    elseif not(ret) then
      output:append(table.concat({"not found:", Path.normalize(path .. relative .. dirname, "win", {sep = "/"})}, OutputSep)):append(NewLine)
    end
  end

  relative  = relative or ""
  local file_list = {}
  --print(path, filename, relative)
  local filepath  = Path.normalize(relative .. filename, "win", {sep = "/"})
  local fh  = io.open(path .. filepath, "r")
  if not(fh) then
    if not(ignore) then
      output:append(table.concat({"not found:", Path.normalize(path .. relative .. filename, "win", {sep = "/"})}, OutputSep)):append(NewLine)
    end
    return {}, "not found"
  end
  local line_count  = 1
  for line in fh:lines() do
    line  = string.gsub(line, "//[^\x0a]*", "")
    local pos, filename   = string.match(line, "^( *include, *)([0-9a-zA-Z_./\\-]+)")
    ---[[
    if filename then
      local fh  = io.open(path .. filename, "r")
      if not(fh) then
        output:append(table.concat({"not found:", filename, "at", filepath, "pos", line_count .. ":" .. (#pos + 1) .. ":" .. (#pos + #filename)}, OutputSep)):append(NewLine)
      else
        fh:close()
        include(file_list, path, filename)
      end
    end
    --]]
    local pos, filename  = string.match(line, "^( *includeEX, *)([0-9a-zA-Z_./\\-]+)")
    ---[[
    if filename then
      local fh  = io.open(path .. relative .. filename, "r")
      if not(fh) then
        output:append(table.concat({"not found:", relative .. filename, "at", filepath, "pos:", line_count .. ":" .. (#pos + 1) .. ":" .. (#pos + #filename)}, OutputSep)):append(NewLine)
      else
        fh:close()
        includeEX(file_list, path, relative, filename)
      end
    end
    --]]
    local pos, dirname = string.match(line, "^( *dicdir, *)([0-9a-zA-Z_./\\-]+)")
    if dirname then
      local attr  = Lfs.attributes(path .. relative .. dirname) or {}
      if attr.mode == "directory" then
        dicdir(file_list, path, relative, dirname)
      else
        output:append(table.concat({"not found:", relative .. dirname, "at", filepath, "pos:", line_count .. ":" .. (#pos + 1) .. ":" .. (#pos + #dirname)}, OutputSep)):append(NewLine)
      end
    end
    local pos, filename  = string.match(line, "^( *dic, *)([0-9a-zA-Z_./\\-]+)")
    if filename then
      local fh  = io.open(path .. relative .. filename, "r")
      if not(fh) then
        output:append(table.concat({"not found:", relative .. filename, "at", filepath, "pos:", line_count .. ":" .. (#pos + 1) .. ":" .. (#pos + #filename)}, OutputSep)):append(NewLine)
      else
        fh:close()
        table.insert(file_list, relative .. filename)
      end
    end
    local filename  = string.match(line, "^ *dicif, *([0-9a-zA-Z_./\\-]+)")
    if filename then
      local fh  = io.open(path .. relative .. filename, "r")
      if fh then
        fh:close()
        table.insert(file_list, relative .. filename)
      end
    end
    line_count  = line_count  + 1
  end
  fh:close()
  return file_list
end

local function main(path_to_yaya_txt)
  local file_list = {}
  local global_define  = {}
  local data  = {}
  local path, filename  = string.match(path_to_yaya_txt, [[(.*[\/])(.*)]])
  if not(path) then
    path  = "./"
    filename  = path_to_yaya_txt
  end
  UserDefined.loadConfig(path)
  file_list = getFileList(path, filename)
  --dump(file_list)
  for _, v in ipairs(file_list) do
    --print(type(v), v)
    local t, err = parse(path, v, global_define)
    if err then
      output:append(err):append(NewLine)
    elseif t then
      table.insert(data, t)
      --dump(t)
    end
  end
  interpret(data)
end

local path  = args.path

main(path)

---[[
if output:strlen() > 0 then
  -- 末尾の改行を削除
  if DirSep == "/" then
    print(string.sub(output:tostring(), 1, -2))
  else
    --print(string.sub(Conv.conv(output:tostring(), "CP932", "UTF-8"), 1, -3))
    print(string.sub(output:tostring(), 1, -3))
  end
else
end
--]]
