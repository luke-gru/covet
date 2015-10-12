require 'mkmf'
require 'rbconfig'

$VPATH << '$(topdir)' << '$(top_srcdir)'
$INCFLAGS << " -I$(topdir) -I$(top_srcdir)"
$CFLAGS +=  " $(CPPFLAGS)"

have_func('rb_obj_hide')

extension_name = 'covet_coverage'
create_header
create_makefile(extension_name)
