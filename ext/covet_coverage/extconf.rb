require 'mkmf'

have_func('rb_obj_hide')

extension_name = 'covet_coverage'
create_header
create_makefile(extension_name)
