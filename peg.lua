local L       = require("lpeglabel")
local Tag     = require("tag")

local Ascii   = L.R("\x00\x7f")
local NumberZ = L.S("+-") ^ -1 * (L.P("0") + (L.R("19") * L.R("09") ^ 0))
local NumberX = L.S("+-") ^ -1 * L.P("0x") * (L.R("09") + L.R("af"))  ^ 1
local NumberB = L.S("+-") ^ -1 * L.P("0b") * (L.S("01"))  ^ 1
local NumberR = L.Cg(NumberX + NumberB + (NumberZ * (L.P(".") * L.R("09") ^ 1) ^ -1), "num")
local MBHead  = L.R("\xc2\xf4")
local MBData  = L.R("\x80\xbf")
local CharNL  = Ascii + (MBHead * (MBData ^ 1))
local RawChar = CharNL - L.P("\x0a")
local Char    = (L.P("/") * L.S(" \t") ^ 0 * L.P("\x0a"))^ 0 * RawChar
local RawNL   = (L.P("//") * Char ^ 0) ^ -1 * L.P("\x0a")
local NL      = (L.P("//") * L.Ct(L.Cg(L.Cp(), Tag.Position) * L.Cg(RawChar ^ 0, Tag.Comment))) ^ -1 * L.P("\x0a")
local Comment = L.P("/*") * L.Ct(L.Cg(L.Cp(), Tag.Position) * L.Cg((-L.P("*/") * CharNL) ^ 0, Tag.Comment)) * L.P("*/")
local Empty   = Comment ^ 0

local InvalidName = L.S(" !\"#$%&()+,-*/:;<=>?@[]'{|}\t")

local Reserve = L.P("if") + L.P("elseif") + L.P("else") + L.P("case") + L.P("when") + L.P("others") + L.P("switch") + L.P("while") + L.P("foreach") + L.P("for") + L.P("break") + L.P("continue") + L.P("return") + L.P("void") + L.P("parallel")

local Number  = NumberR * L.B( - (Char - InvalidName))
local InvalidNameHead = L.R("09") + InvalidName

local Name  = ((-(InvalidNameHead + (Reserve * (-1 + InvalidName + RawNL)))) + L.R("09") ^ 1) * ((-(InvalidName) * Comment ^ 0 * Char)) ^ 1

-- 予約語にはひっかからんし- Reserveはいらんやろ
local LocalVariable = L.Ct(L.Cg(L.Cp(), Tag.Position) * L.Cg(L.P("_") * (L.B(- InvalidName) * Char) ^ 0, Tag.Name))
local GlobalVariable  = L.B(- L.P("_")) * L.Ct(L.Cg(L.Cp(), Tag.Position) * L.Cg(Name, Tag.Name))

local Return    = L.Ct(L.Cg(L.P("return"), Tag.Special))
local Break     = L.Ct(L.Cg(L.P("break"), Tag.Special))
local Continue  = L.Ct(L.Cg(L.P("continue"), Tag.Special))

local Space = ((Comment + L.P("/\x0a")) ^ 0 * L.S(" \t") * (Comment + L.P("/\x0a")) ^ 0 + Comment)
local Space0  = Space ^ 0
local Space1  = Space ^ 1

local function uniq(t)
  if type(t) == "table" and #t == 1 then
    return uniq(t[1])
  end
  return t
end

local function delNL(s)
  local s = string.gsub(s, "/[ \t]*\x0a", "")
  return s
end

local function sepInString(s)
  local s = string.sub(s, 1, 1)
  return s
end

local function delIfNone(t)
  if next(t) then
    return t
  end
  return nil
end

local function func(s)
  print(s)
  return s
end

local StringDoubleSep = L.P("\"")
local StringSingleSep = L.P("'")
local StringSingleQuote = L.Ct(StringSingleSep * L.Ct(L.Cg(L.Ct(((((Char - StringSingleSep) ^ 1) / delNL) + ((StringSingleSep * StringSingleSep) / sepInString)) ^ 0) / table.concat, Tag.String)) * StringSingleSep)
local StringSingleQuoteDocument = L.P("<<") * StringSingleSep * L.Ct(L.Cg(((L.B(-(StringSingleSep * L.P(">>"))) * CharNL)) ^ 0, Tag.String)) * StringSingleSep * L.P(">>")

local StringDoubleQuoteConst = L.Ct(StringDoubleSep * L.Ct(L.Cg(L.Ct(((((Char - StringDoubleSep) ^ 1) / delNL) + ((StringDoubleSep * StringDoubleSep) / sepInString)) ^ 0) / table.concat, Tag.String)) * StringDoubleSep)
local StringDoubleQuoteDocumentConst = L.P("<<") * StringDoubleSep * L.Ct(L.Cg(((L.B(-(StringDoubleSep * L.P(">>"))) * CharNL)) ^ 0, Tag.String)) * StringDoubleSep * L.P(">>")

local Constant  = Number + StringSingleQuote + StringSingleQuoteDocument +
  StringDoubleQuoteConst + StringDoubleQuoteDocumentConst

local ExpOp1  = L.P(",")
local ExpOp2  = L.P("+=") + L.P("-=") + L.P("*=") + L.P("/=") + L.P("%=") + L.P("+:=") + L.P("-:=") + L.P("*:=") + L.P("/:=") + L.P("%:=") + L.P(",=")
local ExpOp3  = L.P("=") + L.P(":=")
local ExpOp4  = L.P("||")
local ExpOp5  = L.P("&&")
local ExpOp6  = L.P("==") + L.P("!=") + L.P("<=") + L.P(">=") + L.S("<>") + L.P("_in_") + L.P("!_in_")
local ExpOp7  = L.P("&")
local ExpOp8  = L.S("+-")
local ExpOp9  = L.S("*/%")
local ExpOp10 = L.P("++") + L.P("--")
local ExpOp11 = L.P("!")

local Exp1  = L.V("exp1")
local Exp2  = L.V("exp2")
local Exp3  = L.V("exp3")
local Exp4  = L.V("exp4")
local Exp5  = L.V("exp5")
local Exp6  = L.V("exp6")
local Exp7  = L.V("exp7")
local Exp8  = L.V("exp8")
local Exp9  = L.V("exp9")
local Exp10 = L.V("exp10")
local Exp11 = L.V("exp11")
local Exp12 = L.V("exp12")

local Index = L.V("index")
local Call  = L.V("call")

local StringDoubleQuote = L.V("string_double_quote")
local StringDoubleQuoteDocument = L.V("string_double_quote_document")

local function generateExpression(ExpInString, ExpInStringDocument)
  local String
  local Pattern
  if ExpInStringDocument then
    String  = L.V("string")
    Pattern = Exp1
  elseif ExpInString then
    ExpInStringDocument = L.V("dummy")
    String  = L.V("string_in_document")
    Pattern = String
    Pattern = Exp1
  else
    ExpInString = L.V("dummy")
    ExpInStringDocument = L.V("dummy")
    String  = L.V("string_single")
    Pattern = String
    Pattern = Exp1
  end
  local t = {
    Pattern,
    dummy = L.T("unreachable"),
    exp1  = L.Ct(Exp2 * (Space0 * L.Ct(L.Cg(ExpOp1, "enum")) * (Space0 * Exp2) ^ -1) ^ 0 +
      (Space0 * L.Ct(L.Cg(ExpOp1, "enum")) * (Space0 * Exp2) ^ -1) ^ 1) / uniq,
    exp2  = (Exp3 * (Space0 * L.Ct(L.Cg(L.Cp(), Tag.Position) * L.Cg(ExpOp2, "op_assign")) * Space0 * Exp3) ^ 0),
    exp3  = (Exp4 * (Space0 * L.Ct(L.Cg(L.Cp(), Tag.Position) * L.Cg(ExpOp3, "assign")) * Space0 * Exp4) ^ 0),
    exp4  = (Exp5 * (Space0 * L.Ct(L.Cg(ExpOp4, "or")) * Space0 * Exp5) ^ 0),
    exp5  = (Exp6 * (Space0 * L.Ct(L.Cg(ExpOp5, "and")) * Space0 * Exp6) ^ 0),
    exp6  = (Exp7 * (Space0 * L.Ct(L.Cg(ExpOp6, "comparison")) * Space0 * Exp7) ^ 0),
    exp7  = ((L.Ct(L.Cg(ExpOp7, "feedback")) * Space0) ^ -1 * Exp8),
    exp8  = (Exp9 * (Space0 * L.Ct(L.Cg(ExpOp8, "add")) * Space0 * Exp9) ^ 0 + (Space0 * L.Ct(L.Cg(ExpOp8, "add")) * Space0 * Exp9) ^ 1),
    exp9  = (Exp10 * (Space0 * L.Ct(L.Cg(ExpOp9, "multi")) * Space0 * Exp10) ^ 0),
    exp10 = (Exp11 * (Space0 * L.Ct(L.Cg(ExpOp10, "inc"))) ^ -1),
    exp11 = ((Space0 * L.Ct(L.Cg(ExpOp11, "not")) * Space0) ^ -1 * Exp12),
    exp12 = L.Ct(
      L.Cg(Number, Tag.Number) +
      L.Cg(String * (L.Ct(Index ^ 0) / delIfNone), Tag.String) +
      (L.Cg(LocalVariable, Tag.Local) * Space0 * L.Cg(L.Ct(Index ^ 0) / delIfNone, Tag.Append)) +
      ((L.Cg(GlobalVariable, Tag.Global) * Space0 * L.Cg(L.Ct(Call ^ -1 * Index ^ 0) / delIfNone, Tag.Append))) +
      L.P("(") * Space0 * L.Ct(Exp1) * Space0 * L.P(")") * (L.Ct(Index ^ 0) / delIfNone)
    ) / uniq,
    string_single = StringSingleQuote + StringSingleQuoteDocument,
    string_double_quote = StringDoubleSep * L.Ct(L.Cg(L.Ct(
      ((L.P("%(") * Space0 * ExpInString * Space0 * L.P(")")) + L.Ct(L.Cg(L.Ct(((((-(StringDoubleSep + L.P("%("))) * Char) ^ 1 / delNL) + (StringDoubleSep * StringDoubleSep) / sepInString) ^ 1) / table.concat, Tag.String))) ^ 0), Tag.String)) * StringDoubleSep,
    string_double_quote_document = L.P("<<") * StringDoubleSep * (Space0 * NL) * (L.Ct(L.Cg(
      (L.P("%(") * Space0 * ExpInStringDocument * Space0 * L.P(")") + L.Cg((((-(L.P("\x0a") * Space0 * StringDoubleSep * L.P(">>") + L.P("%("))) * CharNL) / delNL) ^ 1, Tag.String)) ^ 0, Tag.String)) * NL) ^ -1 * Space0 * StringDoubleSep * L.P(">>"),
    string_in_document = StringSingleQuote + StringSingleQuoteDocument + StringDoubleQuote,
    string        = StringSingleQuote + StringSingleQuoteDocument + StringDoubleQuote + StringDoubleQuoteDocument,
    call  = L.P("(") * Space0 * (L.Ct(L.Cg(Exp1, Tag.Call))) ^ -1 * Space0 * L.P(")"),
    index = L.P("[") * Space0 * L.Ct(L.Cg(Exp1, Tag.Index)) * Space0 * L.P("]"),
  }
  return L.P(t)
end

local ExpressionInString  = generateExpression()
local ExpressionInStringDocument  = generateExpression(ExpressionInString)
local Expression  = generateExpression(ExpressionInString, ExpressionInStringDocument)

local Alternative = L.P("void") + L.P("pool") + L.P("all") + L.P("last") + (L.P("melt_") ^ -1) * (L.P("random") + L.P("nonoverlap") + L.P("sequential") + L.P("array")) * (L.P("_pool") ^ -1)
local AlternativeSep  = L.Ct(L.Cg(L.P("--"), Tag.Output))
local ForCondSep  = L.P(";")
local ForCondition  = L.Ct(L.Cg(Expression, Tag.ForInit) * (Space0 * ForCondSep) ^ 1 * Space0 * L.Cg(Expression, Tag.Condition) * (Space0 * ForCondSep) ^ 1 * Space0 * L.Cg(Expression, Tag.ForLoop))
local ForeachCondition  = L.Ct(L.Cg(Expression, Tag.ForeachList) * (Space0 * ForCondSep) ^ 1 * Space0 * L.Cg(L.Ct(L.Cg(LocalVariable, Tag.Local) + L.Cg(GlobalVariable, Tag.Global)), Tag.ForeachElem))
local WhenCondition = L.Ct(L.Ct(L.Cg(Constant, Tag.WhenLabel)) * (L.Ct(Space0 * L.Cg(L.P(","), Tag.WhenOp) * Space0 * L.Cg(Constant, Tag.WhenLabel)) + L.Ct(Space0 * L.Cg(L.P("-"), Tag.WhenOp) * Space0 * L.Cg(Constant, Tag.WhenLabel))) ^ 0)

local Scope1          = L.V("scope1")
local Scope2          = L.V("scope2")
local Scope3          = L.V("scope3")
local ScopeInner      = L.V("scope_inner")
local ScopeCase       = L.V("scope_case")
local ScopeInnerInCase  = L.V("scope_inner_in_case")
local ScopeCaseCase   = L.V("scope_case_case")
local ScopeCaseWhen   = L.V("scope_case_when")
local ScopeCaseOthers = L.V("scope_case_others")
local ScopeFor        = L.V("scope_for")
local ScopeForeach    = L.V("scope_foreach")
local ScopeIf         = L.V("scope_if")
local ScopeIfIf       = L.V("scope_if_if")
local ScopeIfElseIf   = L.V("scope_if_elseif")
local ScopeIfElse     = L.V("scope_if_else")
local ScopeInIf       = L.V("scope_in_if")
local ScopeParallel   = L.V("scope_parallel")
local ScopeSwitch     = L.V("scope_switch")
local ScopeWhile      = L.V("scope_while")

local ScopeSep0  = (Space + NL) ^ 0
local ScopeSep1  = (Space + NL) ^ 1

local ScopeBegin  = L.P("{")
local ScopeEnd    = L.P("}")


local Scope = L.P({
  Scope2,
  scope1  = L.Ct(L.Cg(Alternative, Tag.Alternative) * Space0 * L.P(":") * ScopeSep1 * L.Cg(Scope2, Tag.Scope)),
  scope2  = ScopeBegin * L.Ct(L.Cg(L.Ct(((ScopeSep0 * (Scope1 + Scope2 + ScopeInner) * Space0 * (NL + L.P(";")) ^ -1) + Space0 * (NL + L.P(";"))) ^ 0), Tag.Body)) * Space0 * ScopeEnd,
  scope3  = L.Ct((((Space1 + ScopeSep1 + L.P(";"))) ^ 0) * (Scope1 + Scope2 + L.Ct(ScopeInner))) / uniq,
  scope_inner = (
    AlternativeSep + Return + Break + Continue + (Comment * (Space0 * Comment) ^ 0) + Expression +
    ScopeCase + ScopeFor + ScopeForeach +
    ScopeIf + ScopeParallel + ScopeSwitch + ScopeWhile
    ),
  scope_inner_in_case = (
    AlternativeSep + Return + Break + Continue + (Comment * (Space0 * Comment) ^ 0) + Expression +
    Scope1 + Scope2 + ScopeCase + ScopeCaseWhen + ScopeCaseOthers + ScopeFor + ScopeForeach +
    ScopeIf + ScopeParallel + ScopeSwitch + ScopeWhile
    ),
  scope_case  = ScopeCaseCase,
  --scope_case_case = L.Ct(L.Cg(L.Ct(L.P("case") * ScopeSep0 * L.Cg(Expression, Tag.Condition) * ScopeSep0 * ScopeBegin * L.Cg(L.Ct((ScopeSep0 * (Scope1 + Scope2 + ScopeInnerInCase) * Space0) ^ -1 * ((ScopeSep0 * (Scope1 + Scope2) + ((NL + L.P(";")) * ScopeSep0 * ScopeInnerInCase)) * Space0) ^ 0), Tag.Body) * ScopeEnd), Tag.ScopeCase)),
  scope_case_case = L.Ct(L.Cg(L.Ct(L.Cg(L.Cp(), Tag.Position) * L.P("case") * ScopeSep0 * L.Cg(Expression, Tag.Condition) * ScopeSep0 * ScopeBegin * L.Cg(L.Ct((ScopeSep0 * (Scope1 + Scope2 + ScopeInnerInCase) * Space0 * (NL + L.P(";")) ^ -1 + Space0 * (NL + L.P(";"))) ^ 0), Tag.Body) * Space0 * ScopeEnd), Tag.ScopeCase)),

  scope_case_when = L.Ct(L.Cg(L.Ct(L.P("when") * ScopeSep0 * L.Cg(WhenCondition, Tag.Condition)* Space0 * L.Cg(Scope3, Tag.Body)), Tag.ScopeWhen)),
  scope_case_others = L.Ct(L.Cg(L.Ct(L.P("others") * Space0 * L.Cg(Scope3, Tag.Body)), Tag.ScopeOthers)),
  scope_for = L.Ct(L.Cg(L.Ct(Space0 * L.P("for") * Space0 * L.Cg(ForCondition, Tag.Condition) * L.Cg(Scope3, Tag.Body)), Tag.ScopeFor)),
  scope_foreach = L.Ct(L.Cg(L.Ct(Space0 * L.P("foreach") * Space0 * L.Cg(ForeachCondition, Tag.Condition) * L.Cg(Scope3, Tag.Body)), Tag.ScopeForeach)),
  scope_if  = ScopeIfIf * ((ScopeSep1 + L.P(";")) ^ 0 * ScopeIfElseIf) ^ 0 * ((ScopeSep1 + L.P(";")) ^ 0 * ScopeIfElse) ^ -1,
  scope_if_if = L.Ct(L.Cg(L.Ct(Space0 * L.P("if") * Space0 * L.Cg(Expression, Tag.Condition) * L.Cg(ScopeInIf, Tag.Body)), Tag.ScopeIf)),
  scope_if_elseif = L.Ct(L.Cg(L.Ct(Space0 * L.P("elseif") * Space0 * L.Cg(Expression, Tag.Condition) * L.Cg(ScopeInIf, Tag.Body)), Tag.ScopeElseIf)),
  scope_if_else  = L.Ct(L.Cg(L.Ct(Space0 * L.P("else") * Space0 * L.Cg(ScopeInIf, Tag.Body)), Tag.ScopeElse)),
  scope_in_if = L.Ct(Space0 * (NL + L.P(";")) ^ 0 * Scope3 + (NL + L.P(";")) ^ 1 * ScopeSep0 * ScopeInner * Space0),
  scope_parallel  = L.Ct(L.Cg(L.Ct(L.Cg(L.P("parallel") + L.P("void"), Tag.Special) * Space1 * L.Cg(Expression, Tag.Body)), Tag.ScopeParallel)),
  scope_switch  = L.Ct(L.Cg(L.Ct(Space0 * L.P("switch") * Space0 * L.Cg(Expression, Tag.Condition) * L.Cg(Scope3, Tag.Body)), Tag.ScopeSwitch)),
  scope_while = L.Ct(L.Cg(L.Ct(Space0 * L.P("while") * Space0 * L.Cg(Expression, Tag.Condition) * L.Cg(Scope3, Tag.Body)), Tag.ScopeWhile)),
})

local Function  = L.Ct(Space0 * L.Cg(L.Cp(), Tag.Position) * L.Cg(Name, Tag.Name) * (ScopeSep0 * L.P(":") * ScopeSep0 * L.Cg(Alternative, Tag.Alternative)) ^ -1 * ScopeSep0 * L.Cg(Scope, Tag.Body))

local Grammar = L.Ct(((Function + Space0 + Empty) * Space0 * NL) ^ 0 * (Function + Empty) ^ -1) * -1


return Grammar
--return L.Ct(L.Cg(((-(Reserve * InvalidName))) * (Char) ^ 1, "name")) * NL ^ 0 * -1
--local Name  = (L.B( - (InvalidNameHead + (Reserve * (-1 + InvalidName + RawNL)))) + L.R("09") ^ 1) * (L.B( - (InvalidNameHead + (Reserve * (-1 + InvalidName + RawNL)))) * Comment ^ 0 * Char) ^ 1
--return Scope
--return Expression ^ 0
--return L.Ct(L.Cg(L.Ct(Space0 * L.P("foreach") * Space1 * L.Cg(ForeachCondition, Tag.Condition))))
