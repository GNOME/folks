/*
 * simple-channel-manager.h
 *
 * Copyright (C) 2010 Collabora Ltd. <http://www.collabora.co.uk/>
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_TESTS_SIMPLE_CHANNEL_MANAGER_H__
#define __TP_TESTS_SIMPLE_CHANNEL_MANAGER_H__

#include <glib-object.h>

#include <telepathy-glib/telepathy-glib.h>

typedef struct _TpTestsSimpleChannelManager TpTestsSimpleChannelManager;
typedef struct _TpTestsSimpleChannelManagerClass TpTestsSimpleChannelManagerClass;

struct _TpTestsSimpleChannelManager
{
  GObject parent;

  TpBaseConnection *conn;
};

struct _TpTestsSimpleChannelManagerClass
{
  GObjectClass parent_class;
};

GType tp_tests_simple_channel_manager_get_type (void);

/* TYPE MACROS */
#define TP_TESTS_TYPE_SIMPLE_CHANNEL_MANAGER \
  (tp_tests_simple_channel_manager_get_type ())
#define TP_TESTS_SIMPLE_CHANNEL_MANAGER(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TESTS_TYPE_SIMPLE_CHANNEL_MANAGER, \
                              TpTestsSimpleChannelManager))
#define TP_TESTS_SIMPLE_CHANNEL_MANAGER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TESTS_TYPE_SIMPLE_CHANNEL_MANAGER, \
                           TpTestsSimpleChannelManagerClass))
#define TP_TESTS_IS_SIMPLE_CHANNEL_MANAGER(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TESTS_TYPE_SIMPLE_CHANNEL_MANAGER))
#define TP_TESTS_IS_SIMPLE_CHANNEL_MANAGER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TESTS_TYPE_SIMPLE_CHANNEL_MANAGER))
#define TP_TESTS_SIMPLE_CHANNEL_MANAGER_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_SIMPLE_CHANNEL_MANAGER, \
                              TpTestsSimpleChannelManagerClass))

G_END_DECLS

#endif /* #ifndef __TP_TESTS_SIMPLE_CHANNEL_MANAGER_H__ */
