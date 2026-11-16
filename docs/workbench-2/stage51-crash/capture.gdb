set pagination off
set confirm off
handle SIGSEGV stop print nopass
run
thread apply all bt
info sharedlibrary
info registers
x/8i $pc
info files
