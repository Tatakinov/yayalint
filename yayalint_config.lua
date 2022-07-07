--[[
--
-- you can use regexp to define function name
-- please read https://www.lua.org/pil/20.2.html
--
-- local file = {
--   no_unused_global  = {
--     "^example/yaya_useful_lib.dic$",
--     "^lib/",
--   },
-- }
--
-- local func = {
--   used  = {
--     "^EXAMPLE1$",   only EXAMPLE1
--     "^On",          OnSample, OnTest, OnMenu etc
--     "^OnTalk%d+$",  OnTalk1, OnTalk200, OnTalk003 etc
--     "^SHIORI3FW%.", SHIORI3FW.Test SHIORI3FW.Foo etc
--   },
-- }
--
--]]


local file  = {
  no_unused_global  = {
  },
}

local var = {
  used  = {
  },
  predefined  = {
    "^_argc$",
    "^_argv$",
  },
}

local func  = {
  used  = {
    "^load$",
    "^unload$",
    "^request$",
  },
  predefined = {
  },
  builtin = {
    "^ACOS$",
    "^ANY$",
    "^APPEND_RUNTIME_DIC$",
    "^ARRAYDEDUP$",
    "^ARRAYSIZE$",
    "^ASEARCH$",
    "^ASEARCHEX$",
    "^ASIN$",
    "^ASORT$",
    "^ATAN$",
    "^BINSTRTOI$",
    "^BITWISE_AND$",
    "^BITWISE_NOT$",
    "^BITWISE_OR$",
    "^BITWISE_SHIFT$",
    "^BITWISE_XOR$",
    "^CEIL$",
    "^CHARSETIDTOTEXT$",
    "^CHARSETLIB$",
    "^CHARSETLIBEX$",
    "^CHARSETTEXTTOID$",
    "^CHR$",
    "^CHRCODE$",
    "^CLEARERRORLOG$",
    "^COS$",
    "^COSH$",
    "^CUTSPACE$",
    "^CVAUTO$",
    "^CVINT$",
    "^CVREAL$",
    "^CVSTR$",
    "^DICLOAD$",
    "^DICUNLOAD$",
    "^DUMPVAR$",
    "^ERASE$",
    "^ERASEVAR$",
    "^EVAL$",
    "^EXECUTE$",
    "^EXECUTE_WAIT$",
    "^FATTRIB$",
    "^FCHARSET$",
    "^FCLOSE$",
    "^FCOPY$",
    "^FDEL$",
    "^FDIGEST$",
    "^FENUM$",
    "^FLOOR$",
    "^FMOVE$",
    "^FOPEN$",
    "^FREAD$",
    "^FREADBIN$",
    "^FREADENCODE$",
    "^FRENAME$",
    "^FSEEK$",
    "^FSIZE$",
    "^FTELL$",
    "^FUNCDECL_ERASE$",
    "^FUNCDECL_READ$",
    "^FUNCDECL_WRITE$",
    "^FUNCTIONEX$",
    "^FWRITE$",
    "^FWRITE2$",
    "^FWRITEBIN$",
    "^FWRITEDECODE$",
    "^GETCALLSTACK$",
    "^GETDELIM$",
    "^GETENV$",
    "^GETERRORLOG$",
    "^GETFUNCINFO$",
    "^GETFUNCLIST$",
    "^GETLASTERROR$",
    "^GETMEMINFO$",
    "^GETSECCOUNT$",
    "^GETSETTING$",
    "^GETSTRBYTES$",
    "^GETSYSTEMFUNCLIST$",
    "^GETTICKCOUNT$",
    "^GETTIME$",
    "^GETTYPE$",
    "^GETTYPEEX$",
    "^GETVARLIST$",
    "^HAN2ZEN$",
    "^HEXSTRTOI$",
    "^IARRAY$",
    "^INSERT$",
    "^ISEVALUABLE$",
    "^ISFUNC$",
    "^ISGLOBALDEFINE$",
    "^ISINTSTR$",
    "^ISREALSTR$",
    "^ISVAR$",
    "^LETTONAME$",
    "^LICENSE$",
    "^LINT.GetFuncUsedBy$",
    "^LINT.GetGlobalVarLetted$",
    "^LINT.GetGlobalVarUsedBy$",
    "^LINT.GetLocalVarLetted$",
    "^LINT.GetLocalVarUsedBy$",
    "^LINT.GetUserDefFuncUsedBy$",
    "^LOADLIB$",
    "^LOG$",
    "^LOG10$",
    "^LOGGING$",
    "^LSO$",
    "^MKDIR$",
    "^OUTPUTNUM$",
    "^POW$",
    "^PROCESSGLOBALDEFINE$",
    "^RAND$",
    "^READFMO$",
    "^REPLACE$",
    "^REQUESTLIB$",
    "^RESTOREVAR$",
    "^RE_ASEARCH$",
    "^RE_ASEARCHEX$",
    "^RE_GETLEN$",
    "^RE_GETPOS$",
    "^RE_GETSTR$",
    "^RE_GREP$",
    "^RE_MATCH$",
    "^RE_OPTION$",
    "^RE_REPLACE$",
    "^RE_REPLACEEX$",
    "^RE_SEARCH$",
    "^RE_SPLIT$",
    "^RMDIR$",
    "^ROUND$",
    "^SAVEVAR$",
    "^SETDELIM$",
    "^SETGLOBALDEFINE$",
    "^SETLASTERROR$",
    "^SETSETTING$",
    "^SETTAMAHWND$",
    "^SIN$",
    "^SINH$",
    "^SLEEP$",
    "^SPLIT$",
    "^SPLITPATH$",
    "^SQRT$",
    "^SRAND$",
    "^STRDECODE$",
    "^STRDIGEST$",
    "^STRENCODE$",
    "^STRFORM$",
    "^STRLEN$",
    "^STRSTR$",
    "^SUBSTR$",
    "^TAN$",
    "^TANH$",
    "^TOAUTO$",
    "^TOBINSTR$",
    "^TOHEXSTR$",
    "^TOINT$",
    "^TOLOWER$",
    "^TOREAL$",
    "^TOSTR$",
    "^TOUPPER$",
    "^TRANSLATE$",
    "^UNDEFFUNC$",
    "^UNDEFGLOBALDEFINE$",
    "^UNLOADLIB$",
    "^ZEN2HAN$",
  },
}


return {
  file  = file,
  var = var,
  func  = func,
}
