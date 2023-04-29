#include "folks-location.h"

struct _FolksLocation
{
        GObject parent_instance;
};

G_DEFINE_FINAL_TYPE (FolksLocation, folks_location, G_TYPE_OBJECT)

enum {
        PROP_0,
        N_PROPS
};

static GParamSpec *properties [N_PROPS];

FolksLocation *
folks_location_new (void)
{
        return g_object_new (FOLKS_TYPE_LOCATION, NULL);
}

static void
folks_location_finalize (GObject *object)
{
        FolksLocation *self = (FolksLocation *)object;

        G_OBJECT_CLASS (folks_location_parent_class)->finalize (object);
}

static void
folks_location_get_property (GObject    *object,
                             guint       prop_id,
                             GValue     *value,
                             GParamSpec *pspec)
{
        FolksLocation *self = FOLKS_LOCATION (object);

        switch (prop_id)
          {
          default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
          }
}

static void
folks_location_set_property (GObject      *object,
                             guint         prop_id,
                             const GValue *value,
                             GParamSpec   *pspec)
{
        FolksLocation *self = FOLKS_LOCATION (object);

        switch (prop_id)
          {
          default:
            G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
          }
}

static void
folks_location_class_init (FolksLocationClass *klass)
{
        GObjectClass *object_class = G_OBJECT_CLASS (klass);

        object_class->finalize = folks_location_finalize;
        object_class->get_property = folks_location_get_property;
        object_class->set_property = folks_location_set_property;
}

static void
folks_location_init (FolksLocation *self)
{

}
