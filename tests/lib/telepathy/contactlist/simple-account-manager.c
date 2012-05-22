/*
 * simple-account-manager.c - a simple account manager service.
 *
 * Copyright (C) 2007-2012 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright (C) 2007-2008 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#include "config.h"

#include "simple-account-manager.h"

#include <telepathy-glib/account.h>
#include <telepathy-glib/gtypes.h>
#include <telepathy-glib/interfaces.h>
#include <telepathy-glib/svc-generic.h>
#include <telepathy-glib/svc-account-manager.h>
#include <telepathy-glib/util.h>

static void account_manager_iface_init (gpointer, gpointer);

G_DEFINE_TYPE_WITH_CODE (TpTestsSimpleAccountManager,
    tp_tests_simple_account_manager,
    G_TYPE_OBJECT,
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_ACCOUNT_MANAGER,
        account_manager_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_DBUS_PROPERTIES,
        tp_dbus_properties_mixin_iface_init)
    )


/* TP_IFACE_ACCOUNT_MANAGER is implied */
static const char *ACCOUNT_MANAGER_INTERFACES[] = { NULL };

enum
{
  PROP_0,
  PROP_INTERFACES,
  PROP_VALID_ACCOUNTS,
  PROP_INVALID_ACCOUNTS,
};

struct _TpTestsSimpleAccountManagerPrivate
{
  GPtrArray *valid_accounts;
  GPtrArray *invalid_accounts;
};

static void
tp_tests_simple_account_manager_create_account (TpSvcAccountManager *svc,
    const gchar *in_Connection_Manager,
    const gchar *in_Protocol,
    const gchar *in_Display_Name,
    GHashTable *in_Parameters,
    GHashTable *in_Properties,
    DBusGMethodInvocation *context)
{
  TpTestsSimpleAccountManager *self = (TpTestsSimpleAccountManager *) svc;
  const gchar *out = TP_ACCOUNT_OBJECT_PATH_BASE "gabble/jabber/lospolloshermanos";

  /* if we have fail=yes as a parameter, make the call fail */
  if (!tp_strdiff (tp_asv_get_string (in_Parameters, "fail"), "yes"))
    {
      GError e = { TP_ERROR, TP_ERROR_INVALID_ARGUMENT, "loldongs" };
      dbus_g_method_return_error (context, &e);
      return;
    }

  self->create_cm = g_strdup (in_Connection_Manager);
  self->create_protocol = g_strdup (in_Protocol);
  self->create_display_name = g_strdup (in_Display_Name);
  self->create_parameters = g_hash_table_ref (in_Parameters);
  self->create_properties = g_hash_table_ref (in_Properties);

  tp_svc_account_manager_return_from_create_account (context, out);
}

static void
account_manager_iface_init (gpointer klass,
    gpointer unused G_GNUC_UNUSED)
{
#define IMPLEMENT(x) tp_svc_account_manager_implement_##x (\
  klass, tp_tests_simple_account_manager_##x)
  IMPLEMENT (create_account);
#undef IMPLEMENT
}


static void
tp_tests_simple_account_manager_init (TpTestsSimpleAccountManager *self)
{
  self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self,
      TP_TESTS_TYPE_SIMPLE_ACCOUNT_MANAGER, TpTestsSimpleAccountManagerPrivate);

  self->priv->valid_accounts = g_ptr_array_new_with_free_func (g_free);
  self->priv->invalid_accounts = g_ptr_array_new_with_free_func (g_free);
}

static void
tp_tests_simple_account_manager_get_property (GObject *object,
              guint property_id,
              GValue *value,
              GParamSpec *spec)
{
  TpTestsSimpleAccountManager *self = SIMPLE_ACCOUNT_MANAGER (object);

  switch (property_id) {
    case PROP_INTERFACES:
      g_value_set_boxed (value, ACCOUNT_MANAGER_INTERFACES);
      break;

    case PROP_VALID_ACCOUNTS:
      g_value_set_boxed (value, self->priv->valid_accounts);
      break;

    case PROP_INVALID_ACCOUNTS:
      g_value_set_boxed (value, self->priv->invalid_accounts);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, spec);
      break;
  }
}

static void
tp_tests_simple_account_manager_finalize (GObject *object)
{
  TpTestsSimpleAccountManager *self = SIMPLE_ACCOUNT_MANAGER (object);

  g_ptr_array_unref (self->priv->valid_accounts);
  g_ptr_array_unref (self->priv->invalid_accounts);

  tp_clear_pointer (&self->create_cm, g_free);
  tp_clear_pointer (&self->create_protocol, g_free);
  tp_clear_pointer (&self->create_display_name, g_free);
  tp_clear_pointer (&self->create_parameters, g_hash_table_unref);
  tp_clear_pointer (&self->create_properties, g_hash_table_unref);

  G_OBJECT_CLASS (tp_tests_simple_account_manager_parent_class)->finalize (
      object);
}

/**
  * This class currently only provides the minimum for
  * tp_account_manager_prepare to succeed. This turns out to be only a working
  * Properties.GetAll(). If we wanted later to check the case where
  * tp_account_prepare succeeds, we would need to implement an account object
  * too.
  */
static void
tp_tests_simple_account_manager_class_init (
    TpTestsSimpleAccountManagerClass *klass)
{
  GObjectClass *object_class = (GObjectClass *) klass;
  GParamSpec *param_spec;

  static TpDBusPropertiesMixinPropImpl am_props[] = {
        { "Interfaces", "interfaces", NULL },
        { "ValidAccounts", "valid-accounts", NULL },
        { "InvalidAccounts", "invalid-accounts", NULL },
        /*
        { "SupportedAccountProperties", "supported-account-properties", NULL },
        */
        { NULL }
  };

  static TpDBusPropertiesMixinIfaceImpl prop_interfaces[] = {
        { TP_IFACE_ACCOUNT_MANAGER,
          tp_dbus_properties_mixin_getter_gobject_properties,
          NULL,
          am_props
        },
        { NULL },
  };

  g_type_class_add_private (klass, sizeof (TpTestsSimpleAccountManagerPrivate));
  object_class->finalize = tp_tests_simple_account_manager_finalize;
  object_class->get_property = tp_tests_simple_account_manager_get_property;

  param_spec = g_param_spec_boxed ("interfaces", "Extra D-Bus interfaces",
      "In this case we only implement AccountManager, so none.",
      G_TYPE_STRV,
      G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_INTERFACES, param_spec);
  param_spec = g_param_spec_boxed ("valid-accounts", "Valid accounts",
      "The accounts which are valid on this account. This may be a lie.",
      TP_ARRAY_TYPE_OBJECT_PATH_LIST,
      G_PARAM_READABLE);
  g_object_class_install_property (object_class, PROP_VALID_ACCOUNTS, param_spec);
  param_spec = g_param_spec_boxed ("invalid-accounts", "Invalid accounts",
      "The accounts which are invalid on this account. This may be a lie.",
      TP_ARRAY_TYPE_OBJECT_PATH_LIST,
      G_PARAM_READABLE);
  g_object_class_install_property (object_class, PROP_INVALID_ACCOUNTS, param_spec);

  klass->dbus_props_class.interfaces = prop_interfaces;
  tp_dbus_properties_mixin_class_init (object_class,
      G_STRUCT_OFFSET (TpTestsSimpleAccountManagerClass, dbus_props_class));
}

static void
remove_from_array (GPtrArray *array, const gchar *str)
{
  guint i;

  for (i = 0; i < array->len; i++)
    if (!tp_strdiff (str, g_ptr_array_index (array, i)))
      {
        g_ptr_array_remove_index_fast (array, i);
        return;
      }
}

void
tp_tests_simple_account_manager_add_account (
    TpTestsSimpleAccountManager *self,
    const gchar *object_path,
    gboolean valid)
{
  remove_from_array (self->priv->valid_accounts, object_path);
  remove_from_array (self->priv->valid_accounts, object_path);

  if (valid)
    g_ptr_array_add (self->priv->valid_accounts, g_strdup (object_path));
  else
    g_ptr_array_add (self->priv->invalid_accounts, g_strdup (object_path));

  tp_svc_account_manager_emit_account_validity_changed (self, object_path, valid);
}

void
tp_tests_simple_account_manager_remove_account (
    TpTestsSimpleAccountManager *self,
    const gchar *object_path)
{
  remove_from_array (self->priv->valid_accounts, object_path);
  remove_from_array (self->priv->valid_accounts, object_path);

  tp_svc_account_manager_emit_account_removed (self, object_path);
}
