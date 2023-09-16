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

local Lfs     = require("lfs")
local Path    = require("path.path")

local Re      = require("lpeglabel.relabel")
local Grammar = require("peg")
local Tag     = require("tag")
local Conv    = require("conv")
local StringBuffer  = require("string_buffer")
local ArgParse  = require("argparse.src.argparse")

local AycDecoder  = require("ayc_decoder")

local UserDefined = require("user_defined")
local VarInfo     = require("var_info")

local DirSep  = string.sub(package.config, 1, 1)
local NewLine = "\x0a"
if DirSep == "\\" then
  NewLine = "\x0d\x0a"
end

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
parser:flag("-a --noambiguous")

local args  = parser:parse()

local Lint  = {
  Warning = {
    NotFound      = "not found:",
    SyntaxError   = "syntax error:",
    UnusedVar     = "unused variable:",
    UnusedFunc    = "unused function:",
    UndefinedVar  = "read undefined variable:",
    UndefinedFunc = "read undefined function:",
    Redefinition  = "redefinition:",
    AssignInCond  = "assignment operator exists in conditional statement:",
    OddInCase     = "case statement contains a clause that is neither a when clause nor others clause:",
  }
}

local function ambiguousSearch(s, ...)
  local t = {...}
  local str, distance
  for _, v in ipairs(t) do
    local s, d  = v:search(s)
    if s then
      if not(distance) then
        str = s
        distance  = d
      elseif distance > d then
        str = s
        distance  = d
      end
    end
  end
  return str
end

local annotation  = {}
function Lint.appendAnnotation(str, filename, line)
  if not(annotation[filename]) then
    annotation[filename]  = {}
  end
  if string.match(str, "^lint on") or string.match(str, "^lint enable") then
    table.insert(annotation[filename], {
      type  = "enable",
      line  = line,
    })
  end
  if string.match(str, "^lint off") or string.match(str, "^lint disable") then
    table.insert(annotation[filename], {
      type  = "disable",
      line  = line,
    })
  end
end

function Lint.isEnable(filename, line)
  local t = annotation[filename] or {}
  local is_enable = true
  for _, v in ipairs(t) do
    if v.line <= line then
      if v.type == "enable" then
        is_enable = true
      elseif v.type == "disable" then
        is_enable = false
      end
    else
      break
    end
  end
  return is_enable
end

local lint_warning_data = {}

function Lint.appendWarning(data)
  if data.kind == Lint.Warning.NotFound and args.nofile then
    return
  end
  if data.kind == Lint.Warning.SyntaxError and args.nosyntaxerror then
    return
  end
  if (data.kind == Lint.Warning.OddInCase or data.kind == Lint.Warning.AssignInCond) and args.nowarning then
    return
  end
  if (data.kind == Lint.Warning.UnusedVar or data.kind == Lint.Warning.UnusedFunc) and args.nounused then
    return
  end
  if (data.kind == Lint.Warning.UndefinedVar or data.kind == Lint.Warning.UndefinedFunc) and args.noundefined then
    return
  end
  if (data.kind == Lint.Warning.UnusedFunc or data.kind == Lint.Warning.UndefinedFunc) and args.nofunction then
    return
  end
  if (data.kind == Lint.Warning.UnusedVar or data.kind == Lint.Warning.UndefinedVar) and string.sub(data.name, 1, 1) == "_" and args.nolocal then
    return
  end
  if (data.kind == Lint.Warning.UnusedVar or data.kind == Lint.Warning.UnusedFunc or data.kind == Lint.Warning.UndefinedVar or data.kind == Lint.Warning.UndefinedFunc) and string.sub(data.name, 1, 1) ~= "_" and args.noglobal then
    return
  end
  if data.filename and data.line and not(Lint.isEnable(data.filename, data.line)) then
    return
  end
  table.insert(lint_warning_data, data)
  table.sort(lint_warning_data, function(a, b)
    if not(a.filename) then
      if not(b.filename) then
        return a.name < b.name
      end
      return true
    end
    if not(b.filename) then
      return false
    end
    if a.filename < b.filename then
      return true
    elseif a.filename > b.filename then
      return false
    elseif a.line < b.line then
      return true
    elseif a.line > b.line then
      return false
    else
      return a.col < b.col
    end
  end)
end

function Lint.generateOutput()
  local t = {}
  for _, v in ipairs(lint_warning_data) do
    if v.kind == Lint.Warning.NotFound then
      if v.filename then
        table.insert(t, string.format("%s\t%s\tat\t%s\tpos:\t%d:%d",
          v.kind, v.name, v.filename, v.line, v.col
        ))
      else
        table.insert(t, string.format("%s\t%s", v.kind, v.filename))
      end
    elseif v.kind == Lint.Warning.SyntaxError then
      table.insert(t, string.format("%s\t%s\tat\t%s\tpos:\t%d:%d",
        v.kind, v.name, v.filename, v.line, v.col
      ))
    elseif v.kind == Lint.Warning.UndefinedVar or v.kind == Lint.Warning.UndefinedFunc then
      table.insert(t, string.format("%s\t%s\tat\t%s\tpos:\t%d:%d\tdid you mean:\t%s",
        v.kind, v.name, v.filename, v.line, v.col, v.suggestion
      ))
    else
      table.insert(t, string.format("%s\t%s\tat\t%s\tpos:\t%d:%d",
        v.kind, v.name, v.filename, v.line, v.col
      ))
    end
  end
  return table.concat(t, NewLine)
end

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
    if t[Tag.Position] then
      local pos   = t[Tag.Position]
      local line  = 1
      -- + 1 は改行の分
      while pos > (#data[line] + 1) do
        pos   = pos - (#data[line] + 1)
        line  = line + 1
      end
      t.line  = line
      -- 直前の文字まで+1がcaptureした文字の開始位置
      t.col   = utf8.len(string.sub(data[line], 1, pos - 1)) + 1
      t[Tag.Position]  = nil
    end
  end
end

local function parse(path, filename, global_define)
  filename  = Path.normalize(filename, "win", {sep = "/"})
  local fh  = io.open(path .. filename, "rb")
  if not(fh) then
    Lint.appendWarning({
      kind  = Lint.Warning.NotFound,
      name  = path .. filename,
    })
    return nil, nil
  end
  local data  = fh:read("*a")
  fh:close()
  if not(data) then
    Lint.appendWarning({
      kind  = Lint.Warning.NotFound,
      name  = path .. filename,
    })
    return nil, nil
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
      for _, v in ipairs(define) do
        s = string.gsub(s, v.before, v.after)
      end
      for _, v in ipairs(global_define) do
        s = string.gsub(s, v.before, v.after)
      end
      s = string.gsub(s, "__AYA_SYSTEM_FILE__", filename)
      s = string.gsub(s, "__AYA_SYSTEM_LINE__", i)
      str:append(s):append("\x0a")
    end
    i = i + 1
  end

  data  = str:tostring()

  local t, label, pos = Grammar:match(data)
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
    Lint.appendWarning({
      kind  = Lint.Warning.SyntaxError,
      name  = c,
      filename  = filename,
      line  = line,
      col   = col,
    })
    return nil, nil
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
  if e[Tag.Append] then
    for i, v in ipairs(e[Tag.Append]) do
      if i == 1 and v[Tag.Call] then
        return true
      end
    end
  end
  return false
end

local function split(data)
  local rhs = {}
  local lhs = {}
  local assign  = nil
  for _, v in ipairs(data) do
    if v.assign or v.op_assign then
      assign  = v
    elseif not(assign) then
      table.insert(lhs, v)
    else
      table.insert(rhs, v)
    end
  end
  return lhs, rhs, assign
end

local function inReadVariable(info, var_outin, var_in, lint_info, opt)
  opt = opt or {}
  if not(opt.is_local) then
    -- ここではローカル変数の情報を取得しておく
    opt.suggestion  = var_in
  end
  local name  = info.name
  local v = var_outin:addRead(name, {
    filename  = lint_info.filename,
    line  = info.line,
    col   = info.col,
  }, opt)
  if not(v.write) and
      not(UserDefined.isUserDefinedVariable(name)) then
    if opt.is_local then
      if lint_info.pass2 then
        local suggestion = not(args.noambiguous) and ambiguousSearch(name, var_outin, var_in) or ""
        Lint.appendWarning({
          kind  = Lint.Warning.UndefinedVar,
          name  = name,
          filename  = lint_info.filename,
          line  = info.line,
          col   = info.col,
          suggestion = suggestion,
        })
      end
    end
  end
end

local function inWriteVariableIn(info, var_outin, var_in, lint_info, opt)
  opt = opt or {}
  local name  = info.name
  var_outin:addWrite(name, {
    filename  = lint_info.filename,
    line  = info.line,
    col   = info.col,
  }, opt)
end

local function inWriteVariableOut(name, info, lint_info, opt)
  if opt.is_local and not(info.read) and lint_info.pass2 and
      not(UserDefined.isUserUsedVariable(name)) then
    for _, pos in ipairs(info.pos) do
      Lint.appendWarning({
        kind  = Lint.Warning.UnusedVar,
        name  = name,
        filename  = lint_info.filename,
        line  = pos.line,
        col   = pos.col,
      })
    end
  end
end

local interpret = {}

function interpret.Variable(data, var_g, var_l, lint_info, opt)
  if type(data) ~= "table" then
    --
    return nil
  end
  if data[Tag.Append] then
    interpret.Append(data[Tag.Append], var_g, var_l, lint_info, {})
  end
  if data[Tag.Local] then
    inReadVariable(data[Tag.Local], var_l, var_g, lint_info, {is_local = true})
  elseif data[Tag.Global] then
    inReadVariable(data[Tag.Global], var_g, var_l, lint_info, {
      is_func = isFunc(data),
    })
  elseif data[Tag.String] then
    interpret.String(data[Tag.String], var_g, var_l, lint_info, {})
  elseif #data > 0 then
    for _, v in ipairs(data) do
      interpret.Variable(v, var_g, var_l, lint_info, {})
    end
  end
end

function interpret.String(data, var_g, var_l, lint_info, opt)
  if type(data) ~= "table" then
    return
  end
  if data[Tag.String] then
    interpret.String(data[Tag.String], var_g, var_l, lint_info, {})
  else
    interpret.Variable(data, var_g, var_l, lint_info, {})
  end
end

function interpret.ForeachElem(data, var_g, var_l, lint_info, opt)
  -- 値は一個しかないが代入の処理が行われている
  if data[Tag.Local] then
    inWriteVariableIn(data[Tag.Local], var_l, var_g, lint_info, {is_local = true})
  elseif data[Tag.Global] then
    local is_func = isFunc(data)
    if is_func then
      -- TODO warning
    end
    inWriteVariableIn(data[Tag.Global], var_g, var_l, lint_info, {
      is_func = is_func,
    })
  end
end

function interpret.Expression(data, var_g, var_l, lint_info, opt)
  if #data == 0 then
    interpret.Variable(data, var_g, var_l, lint_info, {})
    return
  end
  local lhs, rhs, assign  = split(data)
  if assign and opt.in_root_of_condition then
    if lint_info.pass2 then
      Lint.appendWarning({
        kind  = Lint.Warning.AssignInCond,
        name  = assign.assign or assign.op_assign,
        filename  = lint_info.filename,
        line  = assign.line,
        col   = assign.col,
      })
    end
  end
  -- 書き込み
  if #rhs > 0 then
    if lhs[1][Tag.Append] then
      interpret.Append(lhs[1][Tag.Append], var_g, var_l, lint_info, {})
    end
    if #lhs > 1 then
      -- lValueとして不適
    elseif lhs[1][Tag.Local] then
      inWriteVariableIn(lhs[1][Tag.Local], var_l, var_g, lint_info, {is_local = true})
    elseif lhs[1][Tag.Global] then
      local is_func = isFunc(lhs[1])
      if is_func then
        -- TODO warning
      end
      inWriteVariableIn(lhs[1][Tag.Global], var_g, var_l, lint_info, {is_func = is_func})
    end
    interpret.Expression(rhs, var_g, var_l, lint_info, {})
  -- 読み取り
  else
    for _, v in ipairs(lhs) do
      interpret.Expression(v, var_g, var_l, lint_info, {})
    end
  end
end

function interpret.Condition(data, var_g, var_l, lint_info, opt)
  local lv  = var_l
  if opt.overlay then
    lv  = var_l:clone()
  end
  interpret.Expression(data, var_g, lv, lint_info, {in_root_of_condition = true,})
end

function interpret.Append(data, var_g, var_l, lint_info, opt)
  for _, v in ipairs(data) do
    if v[Tag.Call] then
      interpret.Expression(v[Tag.Call], var_g, var_l, lint_info, opt)
    elseif v[Tag.Index] then
      interpret.Expression(v[Tag.Index], var_g, var_l, lint_info, opt)
    end
  end
end

function interpret.Body(data, var_g, var_l,  lint_info, opt)
  local lv  = {}
  if opt.overlay then
    lv  = var_l:clone()
  end
  if data[Tag.Body] then
    return interpret.Body(data[Tag.Body], var_g, lv, lint_info, {
      overlay = true,
    })
  end
  if #data == 0 then
    return interpret.Expression(data, var_g, lv, lint_info, {})
  end
  for _, v in ipairs(data) do
    if v[Tag.Comment] then
      Lint.appendAnnotation(v[Tag.Comment], lint_info.filename, v.line)
    elseif v[Tag.Body] then
      interpret.Body(v[Tag.Body], var_g, lv, lint_info, {
        overlay = true,
      })
    elseif v[Tag.ScopeCase] then
      local e = v[Tag.ScopeCase]
      interpret.Condition(v[Tag.ScopeCase].condition, var_g, lv, lint_info, {})
      -- case文内にwhen/others節以外が含まれていたらwarning
      local body  = e.body
      if lint_info.pass2 then
        if #body == 0 then
          if next(body, nil) ~= nil and
              not(body[Tag.ScopeWhen]) and not(body[Tag.ScopeOthers]) then
            -- TODO warning
            Lint.appendWarning({
              kind  = Lint.Warning.OddInCase,
              name  = Tag.ScopeCase,
              filename  = lint_info.filename,
              line  = e.line,
              col   = e.col,
            })
          end
        else
          for _, v in ipairs(body) do
            if not(v[Tag.ScopeWhen]) and not(v[Tag.ScopeOthers]) then
              -- TODO warning
              Lint.appendWarning({
                kind  = Lint.Warning.OddInCase,
                name  = Tag.ScopeCase,
                filename  = lint_info.filename,
                line  = e.line,
                col   = e.col,
              })
              break
            end
          end
        end
      end
      interpret.Body(v[Tag.ScopeCase].body, var_g, lv, lint_info, {
        in_case_statement = true,
        overlay = true,
      })
    elseif v[Tag.ScopeWhen] then
      interpret.Condition(v[Tag.ScopeWhen].condition, var_g, lv, lint_info, {})
      interpret.Body(v[Tag.ScopeWhen].body, var_g, lv, lint_info, {
        overlay = true,
      })
    elseif v[Tag.ScopeOthers] then
      interpret.Body(v[Tag.ScopeOthers].body, var_g, lv, lint_info, {
        overlay = true,
      })
    elseif v[Tag.ScopeFor] then
      interpret.Expression(v[Tag.ScopeFor].condition.for_init, var_g, lv, lint_info, {})
      interpret.Condition(v[Tag.ScopeFor].condition.condition, var_g, lv, lint_info, {})
      interpret.Expression(v[Tag.ScopeFor].condition.for_loop, var_g, lv, lint_info, {})
      interpret.Body(v[Tag.ScopeFor].body, var_g, lv, lint_info, {
        overlay = true,
      })
    elseif v[Tag.ScopeForeach] then
      interpret.Condition(v[Tag.ScopeForeach].condition.foreach_list, var_g, lv, lint_info, {})
      local tmp_lv  = lv:clone()
      interpret.ForeachElem(v[Tag.ScopeForeach].condition.foreach_elem, var_g, tmp_lv, lint_info, {})
      interpret.Body(v[Tag.ScopeForeach].body, var_g, tmp_lv, lint_info, {
        overlay = true,
      })
      for k, v in pairs(tmp_lv:data()) do
        if not(lv:get(k)) then
          inWriteVariableOut(k, v, lint_info, {is_local = true})
        end
      end
    elseif v[Tag.ScopeIf] then
      interpret.Condition(v[Tag.ScopeIf].condition, var_g, lv, lint_info, {})
      interpret.Body(v[Tag.ScopeIf].body, var_g, lv, lint_info, {
        overlay = true,
      })
    elseif v[Tag.ScopeElseIf] then
      interpret.Condition(v[Tag.ScopeElseIf].condition, var_g, lv, lint_info, {})
      interpret.Body(v[Tag.ScopeElseIf].body, var_g, lv, lint_info, {
        overlay = true,
      })
    elseif v[Tag.ScopeElse] then
      interpret.Body(v[Tag.ScopeElse].body, var_g, lv, lint_info, {
        overlay = true,
      })
    elseif v[Tag.ScopeParallel] then
      interpret.Condition(v[Tag.ScopeParallel].body, var_g, lv, lint_info, {})
    elseif v[Tag.ScopeSwitch] then
      interpret.Condition(v[Tag.ScopeSwitch].condition, var_g, lv, lint_info, {})
      interpret.Body(v[Tag.ScopeSwitch].body, var_g, lv, lint_info, {
        overlay = true,
      })
    elseif v[Tag.ScopeWhile] then
      interpret.Condition(v[Tag.ScopeWhile].condition, var_g, lv, lint_info, {})
      interpret.Body(v[Tag.ScopeWhile].body, var_g, lv, lint_info, {
        overlay = true,
      })
    else
      interpret.Expression(v, var_g, lv, lint_info, {})
    end
  end
  -- lvにあってvar.lに存在しない変数がunusedじゃないか調べる
  for k, v in pairs(lv:data()) do
    if not(var_l:get(k)) then
      inWriteVariableOut(k, v, lint_info, {is_local = true})
    end
  end
end

function interpret.main(data)
  --dump(data)
  local gv  = VarInfo(2)
  local lv  = VarInfo(2)
  for _, file in ipairs(data) do
    --print("filename", file.filename)
    --dump(file)
    for _, func in ipairs(file) do
      if func[Tag.Comment] then
        Lint.appendAnnotation(func.comment, file.filename, func.line)
      elseif func.name then
        gv:addWrite(func.name, {
          filename  = file.filename,
          line  = func.line,
          col   = func.col,
        }, {
          is_func = true,
        })
        interpret.Body(func.body, gv, lv, {filename = file.filename, funcname = func.name}, {overlay = true})
      end
    end
  end
  --dump(gv)
  if args.noglobal then
    return
  end
  for k, v in pairs(gv:data()) do
    if v.is_func then
      function checkRedefinition(list, lint_info, do_lint)
        local is_defined  = false
        for _, v in ipairs(list) do
          if v.write then
            if do_lint then
              -- redefinition
              Lint.appendWarning({
                kind  = Lint.Warning.Redefinition,
                name  = lint_info.name,
                filename  = v.filename,
                line  = v.line,
                col   = v.col,
              })
            else
              if is_defined then
                return checkRedefinition(list, lint_info, true)
              end
              is_defined = true
            end
          end
        end
      end
      checkRedefinition(v.pos, {name  = k}, false)
    end
    if v.write and not(v.read) then
      for _, pos in ipairs(v.pos) do
        if v.is_func then
          if not(UserDefined.isUserUsedFunction(k)) then
            Lint.appendWarning({
              kind  = Lint.Warning.UnusedFunc,
              name  = k,
              filename  = pos.filename,
              line  = pos.line,
              col   = pos.col,
            })
          end
        else
          if not(UserDefined.isUserUsedVariable(k)) then
            Lint.appendWarning({
              kind  = Lint.Warning.UnusedVar,
              name  = k,
              filename  = pos.filename,
              line  = pos.line,
              col   = pos.col,
            })
          end
        end
      end
    end
    if not(v.write) and v.read then
      local s
      for _, pos in ipairs(v.pos) do
        if v.is_func then
          if not(UserDefined.isUserDefinedFunction(k)) then
            local suggestion = s or not(args.noambiguous) and ambiguousSearch(k, gv, v.suggestion) or ""
            s = suggestion
            Lint.appendWarning({
              kind  = Lint.Warning.UndefinedFunc,
              name  = k,
              filename  = pos.filename,
              line  = pos.line,
              col   = pos.col,
              suggestion = suggestion,
            })
          end
        else
          if not(UserDefined.isUserDefinedVariable(k)) then
            local suggestion = s or not(args.noambiguous) and ambiguousSearch(k, gv, v.suggestion) or ""
            s = suggestion
            Lint.appendWarning({
              kind  = Lint.Warning.UndefinedVar,
              name  = k,
              filename  = pos.filename,
              line  = pos.line,
              col   = pos.col,
              suggestion = suggestion,
            })
          end
        end
      end
    end
  end
  for _, file in ipairs(data) do
    for _, func in ipairs(file) do
      if func[Tag.Comment] then
        -- nop
      elseif func.name then
        interpret.Body(func.body, gv, lv, {filename = file.filename, funcname = func.name, pass2  = true}, {overlay = true})
      end
    end
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
      Lint.appendWarning({
        kind  = Lint.Warning.NotFound,
        name  = Path.normalize(path .. relative .. dirname, "win", {sep = "/"}),
      })
    end
  end

  relative  = relative or ""
  local file_list = {}
  --print(path, filename, relative)
  local filepath  = Path.normalize(relative .. filename, "win", {sep = "/"})
  local fh  = io.open(path .. filepath, "r")
  if not(fh) then
    if not(ignore) then
      Lint.appendWarning({
        kind  = Lint.Warning.NotFound,
        name  = Path.normalize(path .. relative .. filename, "win", {sep = "/"}),
      })
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
        Lint.appendWarning({
          kind  = Lint.Warning.NotFound,
          name  = filename,
          filename  = filepath,
          line  = line_count,
          col   = (#pos + 1),
        })
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
        Lint.appendWarning({
          kind  = Lint.Warning.NotFound,
          name  = filename,
          filename  = filepath,
          line  = line_count,
          col   = (#pos + 1),
        })
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
        Lint.appendWarning({
          kind  = Lint.Warning.NotFound,
          name  = dirname,
          filename  = filepath,
          line  = line_count,
          col   = (#pos + 1),
        })
      end
    end
    local pos, filename  = string.match(line, "^( *dic, *)([0-9a-zA-Z_./\\-]+)")
    if filename then
      local fh  = io.open(path .. relative .. filename, "r")
      if not(fh) then
        Lint.appendWarning({
          kind  = Lint.Warning.NotFound,
          name  = filename,
          filename  = filepath,
          line  = line_count,
          col   = (#pos + 1),
        })
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
      -- nop
    elseif t then
      table.insert(data, t)
      --dump(t)
    end
  end
  interpret.main(data)
end

local path  = args.path

main(path)

---[[
local output  = Lint.generateOutput()
if #output > 0 then
  print(output)
else
end
--]]
