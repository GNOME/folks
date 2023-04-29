#include "folks-structured-name.h"

struct _FolksStructuredName
{
        GObject parent_instance;
};

G_DEFINE_FINAL_TYPE (FolksStructuredName, folks_structured_name, G_TYPE_OBJECT)

enum {
        PROP_0,
        N_PROPS
};

static GParamSpec *properties [N_PROPS];

FolksStructuredName *
folks_structured_name_new (void)
{
        return g_object_new (FOLKS_TYPE_STRUCTURED_NAME, NULL);
}

static void
folks_structured_name_finalize (GObject *object)
{
        FolksStructuredName *self = (FolksStructuredName *)object;

        G_OBJECT_CLASS (folks_structured_name_parent_class)->finalize (object);
}

static void
folks_structured_name_get_property (GObject    *object,
                                    guint       prop_id,
                                    GValue     *value,
                                    GParamSpec *pspec)
{
        FolksStructuredName *self = FOLKS_STRUCTURED_NAME (object);

        switch (prop_id)
          {
          default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
          }
}

static void
folks_structured_name_set_property (GObject      *object,
                                    guint         prop_id,
                                    const GValue *value,
                                    GParamSpec   *pspec)
{
        FolksStructuredName *self = FOLKS_STRUCTURED_NAME (object);

        switch (prop_id)
          {
          default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
          }
}

static void
folks_structured_name_class_init (FolksStructuredNameClass *klass)
{
        GObjectClass *object_class = G_OBJECT_CLASS (klass);

        object_class->finalize = folks_structured_name_finalize;
        object_class->get_property = folks_structured_name_get_property;
        object_class->set_property = folks_structured_name_set_property;
}

static void
folks_structured_name_init (FolksStructuredName *self)
{

}
