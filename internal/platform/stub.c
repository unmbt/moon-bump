#ifdef _WIN32
#include <windows.h>
#endif

unsigned int bump_get_console_cp() {
#ifdef _WIN32
    return GetConsoleOutputCP();
#else
    return 0;
#endif
}

void bump_set_console_cp(unsigned int cp) {
#ifdef _WIN32
    SetConsoleOutputCP(cp);
#endif
}
