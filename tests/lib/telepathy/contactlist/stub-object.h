#ifndef __TP_TESTS_STUB_OBJECT_H__
#define __TP_TESTS_STUB_OBJECT_H__

#include <glib-object.h>

typedef struct { GObject p; } TpTestsStubObject;
typedef struct { GObjectClass p; } TpTestsStubObjectClass;

GType tp_tests_stub_object_get_type (void);

#endif /* #ifndef __TP_TESTS_STUB_OBJECT_H__ */
