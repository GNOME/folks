/*
 * im-manager.h - header for an example channel manager
 *
 * Copyright (C) 2007 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright (C) 2007 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_TESTS_ECHO_IM_MANAGER_H__
#define __TP_TESTS_ECHO_IM_MANAGER_H__

#include <glib-object.h>

G_BEGIN_DECLS

typedef struct _TpTestsEchoImManager TpTestsEchoImManager;
typedef struct _TpTestsEchoImManagerClass TpTestsEchoImManagerClass;
typedef struct _TpTestsEchoImManagerPrivate TpTestsEchoImManagerPrivate;

struct _TpTestsEchoImManagerClass {
    GObjectClass parent_class;
};

struct _TpTestsEchoImManager {
    GObject parent;

    TpTestsEchoImManagerPrivate *priv;
};

GType tp_tests_echo_im_manager_get_type (void);

/* TYPE MACROS */
#define TP_TESTS_TYPE_ECHO_IM_MANAGER \
  (tp_tests_echo_im_manager_get_type ())
#define TP_TESTS_ECHO_IM_MANAGER(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TESTS_TYPE_ECHO_IM_MANAGER, \
                              TpTestsEchoImManager))
#define TP_TESTS_ECHO_IM_MANAGER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TESTS_TYPE_ECHO_IM_MANAGER, \
                           TpTestsEchoImManagerClass))
#define TP_TESTS_IS_ECHO_IM_MANAGER(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TESTS_TYPE_ECHO_IM_MANAGER))
#define TP_TESTS_IS_ECHO_IM_MANAGER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TESTS_TYPE_ECHO_IM_MANAGER))
#define TP_TESTS_ECHO_IM_MANAGER_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_ECHO_IM_MANAGER, \
                              TpTestsEchoImManagerClass))

G_END_DECLS

#endif
