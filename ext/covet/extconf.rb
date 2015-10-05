require 'mkmf'
require 'rbconfig'

$VPATH << '$(topdir)' << '$(top_srcdir)'
$INCFLAGS << " -I$(topdir) -I$(top_srcdir)"

extension_name = 'covet_coverage'
create_makefile(extension_name)
