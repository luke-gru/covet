/************************************************

  coverage.c -

  $Author: $

  Copyright (c) 2008 Yusuke Endoh

************************************************/

#include "ruby.h"
#include "extconf.h"

extern VALUE rb_get_coverages(void);
extern void rb_set_coverages(VALUE);
extern void rb_reset_coverages(void);

#ifdef HAVE_RB_OBJ_HIDE
extern VALUE rb_obj_hide(VALUE);
static void hide_obj(VALUE val)
{
    rb_obj_hide(val);
}
#else
static void hide_obj(VALUE val)
{
    RBASIC(val)->klass = 0;
}
#endif

static VALUE rb_coverages = Qundef;


/*
 * call-seq:
 *    CovetCoverage.start  => nil
 * * Enables coverage measurement.
 */
static VALUE
rb_coverage_start(void)
{
    if (!RTEST(rb_get_coverages())) {
        if (rb_coverages == Qundef) {
            rb_coverages = rb_hash_new();
            hide_obj(rb_coverages);
        }
        rb_set_coverages(rb_coverages);
    }
    return Qnil;
}

static int
coverage_clear_result_i(st_data_t key, st_data_t val, st_data_t h)
{
    VALUE coverage = (VALUE)val;
    rb_ary_clear(coverage);
    return ST_CONTINUE;
}

static int
coverage_peek_result_i(st_data_t key, st_data_t val, st_data_t h)
{
    VALUE path = (VALUE)key;
    VALUE coverage = (VALUE)val;
    VALUE coverages = (VALUE)h;
    coverage = rb_ary_dup(coverage);
    rb_ary_freeze(coverage);
    rb_hash_aset(coverages, path, coverage);
    return ST_CONTINUE;
}

/*
 *  call-seq:
 *     CovetCoverage.peek_result  => hash
 *
 * Returns a hash that contains filename as key and coverage array as value.
 */
static VALUE
rb_coverage_peek_result(void)
{
    VALUE coverages = rb_get_coverages();
    VALUE ncoverages = rb_hash_new();
    if (!RTEST(coverages)) {
        rb_raise(rb_eRuntimeError, "coverage measurement is not enabled (covet)");
    }
    st_foreach(RHASH_TBL(coverages), coverage_peek_result_i, ncoverages);
    rb_hash_freeze(ncoverages);
    return ncoverages;
}

static int
coverage_result_i(st_data_t key, st_data_t val, st_data_t h)
{
    VALUE path = (VALUE)key;
    VALUE coverage = (VALUE)val;
    VALUE coverages = (VALUE)h;
    coverage = rb_ary_dup(coverage);
    rb_ary_clear((VALUE)val);
    rb_ary_freeze(coverage);
    rb_hash_aset(coverages, path, coverage);
    return ST_CONTINUE;
}

/*
 *  call-seq:
 *     CovetCoverage.result  => hash
 *
 * Returns a hash that contains filename as key and coverage array as value
 * and disables coverage measurement.
 */
static VALUE
rb_coverage_result(void)
{
    VALUE coverages = rb_get_coverages();
    VALUE ncoverages = rb_hash_new();
    if (!RTEST(coverages)) {
        rb_raise(rb_eRuntimeError, "coverage measurement is not enabled (covet)");
    }
    st_foreach(RHASH_TBL(coverages), coverage_result_i, ncoverages);
    rb_hash_freeze(ncoverages);
    rb_reset_coverages();
    return ncoverages;
}

static VALUE
rb_coverage_stop(void) {
    if (!RTEST(rb_get_coverages())) {
        rb_raise(rb_eRuntimeError, "coverage measurement is not enabled (covet)");
    }
    rb_reset_coverages();
    return Qnil;
}

static VALUE
rb_coverage_enabled_p(void) {
    if (RTEST(rb_get_coverages())) {
        return Qtrue;
    } else {
        return Qfalse;
    }
}

void
Init_covet_coverage(void)
{
    VALUE rb_mCoverage = rb_define_module("CovetCoverage");
    rb_define_module_function(rb_mCoverage, "start", rb_coverage_start, 0);
    rb_define_module_function(rb_mCoverage, "stop",  rb_coverage_stop, 0);
    rb_define_module_function(rb_mCoverage, "result", rb_coverage_result, 0);
    rb_define_module_function(rb_mCoverage, "peek_result", rb_coverage_peek_result, 0);
    rb_define_module_function(rb_mCoverage, "enabled?", rb_coverage_enabled_p, 0);
    rb_gc_register_address(&rb_coverages);
}
