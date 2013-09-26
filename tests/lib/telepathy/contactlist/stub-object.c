#include "config.h"

#include "stub-object.h"

G_DEFINE_TYPE (TpTestsStubObject, tp_tests_stub_object, G_TYPE_OBJECT)

enum {
    PROP_0,
    PROP_NAME,
    N_PROPS
};

static void
stub_object_get_property (GObject *object,
    guint prop_id,
    GValue *value,
    GParamSpec *param_spec)
{
  switch (prop_id)
    {
    case PROP_NAME:
      g_value_set_string (value, "Bruce");
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, param_spec);
      break;
    }
}

static void
stub_object_set_property (GObject *object,
    guint prop_id,
    const GValue *value,
    GParamSpec *param_spec)
{
  switch (prop_id)
    {
    case PROP_NAME:
      /* do nothing */
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, param_spec);
      break;
    }
}

static void
tp_tests_stub_object_class_init (TpTestsStubObjectClass *klass)
{
  GObjectClass *object_class = (GObjectClass *) klass;

  object_class->get_property = stub_object_get_property;
  object_class->set_property = stub_object_set_property;

  g_object_class_install_property (object_class, PROP_NAME,
      g_param_spec_string ("name",
          "Name",
          "The name of the stub object",
          "Bruce",
          G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE));
}

static void
tp_tests_stub_object_init (TpTestsStubObject *self)
{
}
