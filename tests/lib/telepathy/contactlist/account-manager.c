/*
 * account-manager.c - a simple account manager service.
 *
 * Copyright (C) 2007-2009 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright (C) 2007-2008 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 *
 * Copied from telepathy-glib/tests/lib/simple-account-manager.c.
 */

#include "account-manager.h"

#include <telepathy-glib/gtypes.h>
#include <telepathy-glib/interfaces.h>
#include <telepathy-glib/svc-generic.h>
#include <telepathy-glib/svc-account-manager.h>

static void account_manager_iface_init (gpointer, gpointer);

G_DEFINE_TYPE_WITH_CODE (TpTestsAccountManager,
    tp_tests_account_manager,
    G_TYPE_OBJECT,
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_ACCOUNT_MANAGER,
        account_manager_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_DBUS_PROPERTIES,
        tp_dbus_properties_mixin_iface_init)
    )


/* TP_IFACE_ACCOUNT_MANAGER is implied */
static const char *ACCOUNT_MANAGER_INTERFACES[] = { NULL };

static const gchar *INVALID_ACCOUNTS[] = {
  "/org/freedesktop/Telepathy/Account/fakecm/fakeproto/invalidaccount",
  NULL };

enum
{
  PROP_0,
  PROP_INTERFACES,
  PROP_VALID_ACCOUNTS,
  PROP_INVALID_ACCOUNTS,
};

struct _TpTestsAccountManagerPrivate
{
  GPtrArray *valid_accounts;
};

static void
tp_tests_account_manager_create_account (TpSvcAccountManager *self,
    const gchar *in_Connection_Manager,
    const gchar *in_Protocol,
    const gchar *in_Display_Name,
    GHashTable *in_Parameters,
    GHashTable *in_Properties,
    DBusGMethodInvocation *context)
{
  const gchar *out_Account = "/some/fake/account/i/think";

  tp_svc_account_manager_return_from_create_account (context, out_Account);
}

static void
account_manager_iface_init (gpointer klass,
    gpointer unused G_GNUC_UNUSED)
{
#define IMPLEMENT(x) tp_svc_account_manager_implement_##x (\
  klass, tp_tests_account_manager_##x)
  IMPLEMENT (create_account);
#undef IMPLEMENT
}


static void
tp_tests_account_manager_init (TpTestsAccountManager *self)
{
  self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self,
      TP_TESTS_TYPE_ACCOUNT_MANAGER, TpTestsAccountManagerPrivate);

  self->priv->valid_accounts =
      g_ptr_array_new_with_free_func ((GDestroyNotify) g_free);
}

static void
tp_tests_account_manager_finalize (GObject *obj)
{
  g_ptr_array_free (TP_TESTS_ACCOUNT_MANAGER (obj)->priv->valid_accounts, TRUE);

  G_OBJECT_CLASS (tp_tests_account_manager_parent_class)->finalize (obj);
}

static void
tp_tests_account_manager_get_property (GObject *object,
              guint property_id,
              GValue *value,
              GParamSpec *spec)
{
  TpTestsAccountManagerPrivate *priv = TP_TESTS_ACCOUNT_MANAGER (object)->priv;
  GPtrArray *accounts;
  guint i = 0;

  switch (property_id) {
    case PROP_INTERFACES:
      g_value_set_boxed (value, ACCOUNT_MANAGER_INTERFACES);
      break;

    case PROP_VALID_ACCOUNTS:
      accounts = g_ptr_array_new ();

      for (i = 0; i < priv->valid_accounts->len; i++)
        g_ptr_array_add (accounts, g_strdup (priv->valid_accounts->pdata[i]));

      g_value_take_boxed (value, accounts);
      break;

    case PROP_INVALID_ACCOUNTS:
      accounts = g_ptr_array_new ();

      for (i=0; INVALID_ACCOUNTS[i] != NULL; i++)
        g_ptr_array_add (accounts, g_strdup (INVALID_ACCOUNTS[i]));

      g_value_take_boxed (value, accounts);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, spec);
      break;
  }
}

/**
  * This class currently only provides the minimum for
  * tp_account_manager_prepare to succeed. This turns out to be only a working
  * Properties.GetAll(). If we wanted later to check the case where
  * tp_account_prepare succeeds, we would need to implement an account object
  * too.
  */
static void
tp_tests_account_manager_class_init (
    TpTestsAccountManagerClass *klass)
{
  GObjectClass *object_class = (GObjectClass *) klass;
  GParamSpec *param_spec;

  static TpDBusPropertiesMixinPropImpl am_props[] = {
        { "Interfaces", (gpointer) "interfaces", NULL },
        { "ValidAccounts", (gpointer) "valid-accounts", NULL },
        { "InvalidAccounts", (gpointer) "invalid-accounts", NULL },
        /*
        { "SupportedAccountProperties", (gpointer) "supported-account-properties", NULL },
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

  g_type_class_add_private (klass, sizeof (TpTestsAccountManagerPrivate));
  object_class->get_property = tp_tests_account_manager_get_property;
  object_class->finalize = tp_tests_account_manager_finalize;

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
      G_STRUCT_OFFSET (TpTestsAccountManagerClass, dbus_props_class));
}

TpTestsAccountManager *
tp_tests_account_manager_new (void)
{
  return g_object_new (TP_TESTS_TYPE_ACCOUNT_MANAGER, NULL);
}

void
tp_tests_account_manager_add_account (TpTestsAccountManager *self,
    const gchar *account_path)
{
  g_ptr_array_add (self->priv->valid_accounts, g_strdup (account_path));
  tp_svc_account_manager_emit_account_validity_changed (self, account_path, TRUE);
  g_object_notify (G_OBJECT (self), "valid-accounts");
}

void
tp_tests_account_manager_remove_account (TpTestsAccountManager *self,
    const gchar *account_path)
{
  TpTestsAccountManagerPrivate *priv = self->priv;
  guint i;

  for (i = 0; i < priv->valid_accounts->len; i++)
    {
      if (g_strcmp0 (account_path, priv->valid_accounts->pdata[0]) == 0)
        {
          g_ptr_array_remove_index_fast (priv->valid_accounts, i);
          break;
        }
    }

  g_object_notify (G_OBJECT (self), "valid-accounts");
  tp_svc_account_manager_emit_account_removed (self, account_path);
}
