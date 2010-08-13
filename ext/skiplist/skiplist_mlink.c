/* vi:set ts=3 sw=3:
 * vim:set sts=0 noet:
 */
/*
 * Copyright (c) 2010 KISHIMOTO, Makoto
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
#include <ruby.h>

static __inline__ int
cas(VALUE *addr, VALUE oldp, VALUE newp)
{
	return __sync_bool_compare_and_swap(addr, oldp, newp);
}

struct mlink {
	VALUE link;
};

static void
mlink_mark(struct mlink *lnkp)
{
	VALUE p = lnkp->link & ~1;

	rb_gc_mark(p);
}

static VALUE
mlink_alloc(VALUE klass)
{
	struct mlink *lnkp;
	VALUE obj = Data_Make_Struct(klass, struct mlink, mlink_mark, -1, lnkp);

	lnkp->link = 0;

	return obj;
}

static VALUE
mlink_initialize(VALUE obj, VALUE link)
{
	struct mlink *lnkp;

	if (link & 1) {
		rb_raise(rb_eArgError, "link must not be a Fixnum");
	}

	Data_Get_Struct(obj, struct mlink, lnkp);

	lnkp->link = link;

	return Qnil;
}

static VALUE
mlink_compare_and_set(VALUE obj, VALUE oldlink, VALUE newlink, VALUE oldmark, VALUE newmark)
{
	struct mlink *lnkp;
	VALUE olink, nlink;

	if ((oldlink & 1) || (newlink & 1)) {
		rb_raise(rb_eArgError, "link must not be a Fixnum");
	}
	if (((oldmark != Qfalse) && (oldmark != Qtrue)) ||
	    ((newmark != Qfalse) && (newmark != Qtrue))) {
		rb_raise(rb_eArgError, "mark must be a boolean");
	}

	Data_Get_Struct(obj, struct mlink, lnkp);

	olink = oldlink | !!oldmark;
	nlink = newlink | !!newmark;

	return cas(&lnkp->link, olink, nlink) ? Qtrue : Qfalse ;
}

static VALUE
mlink_get(VALUE obj)
{
	struct mlink *lnkp;
	VALUE link, mark;

	Data_Get_Struct(obj, struct mlink, lnkp);

	link = lnkp->link;
	mark = link & 1 ? Qtrue : Qfalse ;
	link &= ~1;

	return rb_ary_new3(2, link, mark);
}

static VALUE
mlink_get_link(VALUE obj)
{
	struct mlink *lnkp;

	Data_Get_Struct(obj, struct mlink, lnkp);

	return lnkp->link & ~1;
}

static VALUE
mlink_print_debug(VALUE obj)
{
	VALUE link_mark, arg[1], link, mark;

	link_mark = mlink_get(obj);
	arg[0] = INT2FIX(0);
	link = rb_ary_aref(1, arg, link_mark);
	arg[0] = INT2FIX(1);
	mark = rb_ary_aref(1, arg, link_mark);

	rb_funcall(obj, rb_intern("puts"), 1,
		rb_funcall(rb_str_new2("#<MLink: @mark = %s, @link = 0x%014x>"), rb_intern("%"), 1,
			rb_ary_new3(2, mark, rb_funcall(link, rb_intern("object_id"), 0)) ));

	return Qnil;
}

void
Init_skiplist_mlink(void)
{
	VALUE cSkipList = rb_define_class("SkipList", rb_cObject);
	VALUE cMLink = rb_define_class_under(cSkipList, "MLink", rb_cObject);

	rb_define_alloc_func(cMLink, &mlink_alloc);

	rb_define_method(cMLink, "initialize", &mlink_initialize, 1);
	rb_define_method(cMLink, "compare_and_set", &mlink_compare_and_set, 4);
	rb_define_method(cMLink, "get", &mlink_get, 0);
	rb_define_method(cMLink, "get_link", &mlink_get_link, 0);
	rb_define_method(cMLink, "print_debug", &mlink_print_debug, 0);
}
