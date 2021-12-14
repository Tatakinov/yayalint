#include <iostream>
#include <string>
#include <windows.h>

#define SOL_ALL_SAFETIES_ON 1
#include "sol/sol.hpp"

std::string conv(std::string input, int to, int from) {
  int w_len = 0, mb_len = 0;
  wchar_t *w_str;
  char  *mb_str;
  std::string str;
  if ( ! (from && to)) {
    goto error;
  }
  w_len = MultiByteToWideChar(from, MB_ERR_INVALID_CHARS, input.c_str(), input.length(), NULL, 0);
  if ( ! w_len) {
    goto error;
  }
  w_str = new wchar_t[w_len];
  if ( ! w_str) {
    goto error;
  }
  MultiByteToWideChar(from, 0, input.c_str(), input.length(), w_str, w_len);
  mb_len = WideCharToMultiByte(to, 0, w_str, w_len, NULL, 0, NULL, NULL);
  if ( ! mb_len) {
    goto error_w;
  }
  mb_str  = new char[mb_len];
  if ( ! mb_str) {
    goto error_w;
  }
  WideCharToMultiByte(to, 0, w_str, w_len, mb_str, mb_len, NULL, NULL);
  str = std::string(mb_str, mb_len);
  delete mb_str;
error_w:
  delete w_str;
error:
  return str;
}

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

__declspec(dllexport) int luaopen_conv_windows(lua_State *L) {
  sol::state_view lua(L);
  sol::table table = lua.create_table();
  table["conv"]  = &conv;
  sol::stack::push(lua, table);
  return 1;
}

#ifdef __cplusplus
}
#endif // __cplusplus
