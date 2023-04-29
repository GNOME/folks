/*
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 * Copyright 2023 Collabora, Ltd.
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "folks-persona.h"
#include "folks-persona-priv.h"

#include <libtracker-sparql/tracker-sparql.h>

struct _FolksPersona
{
  GObject parent_instance;

  TrackerSparqlConnection *connection;
  char *persona_urn;
  char *alias;
  char *nickname;
  char *fullname;
  FolksStructuredName *structured_name;
  GIcon *avatar;
  GDateTime *birthday;
  GListModel *emails;
  GListModel *extended_fields;
  gboolean is_favourite;
  char *gender;
  GListModel *groups;
  GListModel *im_addresses;
  FolksLocation *location;
  GListModel *notes;
  GListModel *phone_numbers;
  GListModel *postal_addresses;
  GListModel *roles;
  GListModel *urls;
};

G_DEFINE_FINAL_TYPE (FolksPersona, folks_persona, G_TYPE_OBJECT)

enum {
  PROP_ALIAS = 1,
  PROP_NICKNAME,
  PROP_FULLNAME,
  PROP_STRUCTURED_NAME,
  PROP_AVATAR,
  PROP_BIRTHDAY,
  PROP_EMAILS,
  PROP_EXTENDED_FIELDS,
  PROP_IS_FAVOURITE,
  PROP_GENDER,
  PROP_GROUPS,
  PROP_IM_ADDRESSES,
  PROP_LOCATION,
  PROP_NOTES,
  PROP_PHONE_NUMBERS,
  PROP_POSTAL_ADDRESSES,
  PROP_ROLES,
  PROP_URLS,
  N_PROPS
};

static GParamSpec *properties [N_PROPS];

static void
folks_persona_dispose (GObject *object)
{
  FolksPersona *self = (FolksPersona *)object;

  g_clear_object (&self->structured_name);
  g_clear_object (&self->avatar);
  g_clear_object (&self->birthday);
  g_clear_object (&self->emails);
  g_clear_object (&self->extended_fields);
  g_clear_object (&self->groups);
  g_clear_object (&self->im_addresses);
  g_clear_object (&self->location);
  g_clear_object (&self->notes);
  g_clear_object (&self->phone_numbers);
  g_clear_object (&self->postal_addresses);
  g_clear_object (&self->roles);
  g_clear_object (&self->urls);
  g_clear_object (&self->connection);

  G_OBJECT_CLASS (folks_persona_parent_class)->dispose (object);
}

static void
folks_persona_finalize (GObject *object)
{
  FolksPersona *self = (FolksPersona *)object;

  g_clear_pointer (&self->alias, g_free);
  g_clear_pointer (&self->nickname, g_free);
  g_clear_pointer (&self->fullname, g_free);
  g_clear_pointer (&self->persona_urn, g_free);
  g_clear_pointer (&self->gender, g_free);

  G_OBJECT_CLASS (folks_persona_parent_class)->finalize (object);
}

static void
folks_persona_get_property (GObject    *object,
                            guint       prop_id,
                            GValue     *value,
                            GParamSpec *pspec)
{
  FolksPersona *self = FOLKS_PERSONA (object);

  switch (prop_id)
    {
    case PROP_ALIAS:
      g_value_take_string (value, folks_persona_get_alias (self));
      break;
    case PROP_NICKNAME:
      g_value_take_string (value, folks_persona_get_nickname (self));
      break;
    case PROP_FULLNAME:
      g_value_take_string (value, folks_persona_get_fullname (self));
      break;
    case PROP_STRUCTURED_NAME:
      g_value_take_object (value, folks_persona_get_structured_name (self));
      break;
    case PROP_AVATAR:
      g_value_take_object (value, folks_persona_get_avatar (self));
      break;
    case PROP_BIRTHDAY:
      g_value_take_object (value, folks_persona_get_birthday (self));
      break;
    case PROP_EMAILS:
      g_value_take_object (value, folks_persona_get_emails (self));
      break;
    case PROP_EXTENDED_FIELDS:
      g_value_take_object (value, folks_persona_get_extended_fields (self));
      break;
    case PROP_IS_FAVOURITE:
      g_value_set_boolean (value, folks_persona_get_is_favourite (self));
      break;
    case PROP_GENDER:
      g_value_take_string (value, folks_persona_get_gender (self));
      break;
    case PROP_GROUPS:
      g_value_take_object (value, folks_persona_get_groups (self));
      break;
    case PROP_IM_ADDRESSES:
      g_value_take_object (value, folks_persona_get_im_addresses (self));
      break;
    case PROP_LOCATION:
      g_value_take_object (value, folks_persona_get_location (self));
      break;
    case PROP_NOTES:
      g_value_take_object (value, folks_persona_get_notes (self));
      break;
    case PROP_PHONE_NUMBERS:
      g_value_take_object (value, folks_persona_get_phone_numbers (self));
      break;
    case PROP_POSTAL_ADDRESSES:
      g_value_take_object (value, folks_persona_get_postal_addresses (self));
      break;
    case PROP_ROLES:
      g_value_take_object (value, folks_persona_get_roles (self));
      break;
    case PROP_URLS:
      g_value_take_object (value, folks_persona_get_urls (self));
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
folks_persona_set_property (GObject      *object,
                            guint         prop_id,
                            const GValue *value,
                            GParamSpec   *pspec)
{
  FolksPersona *self = FOLKS_PERSONA (object);

  switch (prop_id)
    {
    case PROP_ALIAS:
      self->alias = g_value_dup_string (value);
      break;
    case PROP_NICKNAME:
      self->nickname = g_value_dup_string (value);
      break;
    case PROP_FULLNAME:
      self->fullname = g_value_dup_string (value);
      break;
    case PROP_STRUCTURED_NAME:
      self->structured_name = g_value_dup_object (value);
      break;
    case PROP_AVATAR:
      self->avatar = g_value_dup_object (value);
      break;
    case PROP_BIRTHDAY:
      self->birthday = g_value_dup_boxed (value);
      break;
    case PROP_EMAILS:
      self->emails = g_value_dup_object (value);
      break;
    case PROP_EXTENDED_FIELDS:
      self->extended_fields = g_value_dup_object (value);
      break;
    case PROP_IS_FAVOURITE:
      self->is_favourite = g_value_get_boolean (value);
      break;
    case PROP_GENDER:
      self->gender = g_value_dup_string (value);
      break;
    case PROP_GROUPS:
      self->groups = g_value_dup_object (value);
      break;
    case PROP_IM_ADDRESSES:
      self->im_addresses = g_value_dup_object (value);
      break;
    case PROP_LOCATION:
      self->location = g_value_dup_object (value);
      break;
    case PROP_NOTES:
      self->notes = g_value_dup_object (value);
      break;
    case PROP_PHONE_NUMBERS:
      self->phone_numbers = g_value_dup_object (value);
      break;
    case PROP_POSTAL_ADDRESSES:
      self->postal_addresses = g_value_dup_object (value);
      break;
    case PROP_ROLES:
      self->roles = g_value_dup_object (value);
      break;
    case PROP_URLS:
      self->urls = g_value_dup_object (value);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
folks_persona_class_init (FolksPersonaClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->finalize = folks_persona_finalize;
  object_class->dispose = folks_persona_dispose;
  object_class->get_property = folks_persona_get_property;
  object_class->set_property = folks_persona_set_property;

  properties[PROP_ALIAS] =
    g_param_spec_string ("alias", NULL, NULL,
                         NULL  /* default value */,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_NICKNAME] =
    g_param_spec_string ("nickname", NULL, NULL,
                         NULL  /* default value */,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_FULLNAME] =
    g_param_spec_string ("fullname", NULL, NULL,
                         NULL  /* default value */,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_STRUCTURED_NAME] =
    g_param_spec_object ("structured-name", NULL, NULL,
                         FOLKS_TYPE_STRUCTURED_NAME,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_AVATAR] =
    g_param_spec_object ("avatar", NULL, NULL,
                         G_TYPE_ICON,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_BIRTHDAY] =
    g_param_spec_boxed ("birthday", NULL, NULL,
                        G_TYPE_DATE_TIME,
                        G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_EMAILS] =
    g_param_spec_object ("emails", NULL, NULL,
                         G_TYPE_LIST_MODEL,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_EXTENDED_FIELDS] =
    g_param_spec_object ("extended-fields", NULL, NULL,
                         G_TYPE_LIST_MODEL,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_IS_FAVOURITE] =
    g_param_spec_boolean ("is-favourite", NULL, NULL,
                          FALSE,
                          G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_GENDER] =
    g_param_spec_string ("gender", NULL, NULL,
                         NULL,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_GROUPS] =
    g_param_spec_object ("groups", NULL, NULL,
                         G_TYPE_LIST_MODEL,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_IM_ADDRESSES] =
    g_param_spec_object ("im-addresses", NULL, NULL,
                         G_TYPE_LIST_MODEL,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_LOCATION] =
    g_param_spec_object ("location", NULL, NULL,
                         FOLKS_TYPE_LOCATION,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_NOTES] =
    g_param_spec_object ("notes", NULL, NULL,
                         G_TYPE_LIST_MODEL,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_PHONE_NUMBERS] =
    g_param_spec_object ("phone-numbers", NULL, NULL,
                         G_TYPE_LIST_MODEL,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_POSTAL_ADDRESSES] =
    g_param_spec_object ("postal-addresses", NULL, NULL,
                         G_TYPE_LIST_MODEL,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_ROLES] =
    g_param_spec_object ("roles", NULL, NULL,
                         G_TYPE_LIST_MODEL,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  properties[PROP_URLS] =
    g_param_spec_object ("urls", NULL, NULL,
                         G_TYPE_LIST_MODEL,
                         G_PARAM_STATIC_STRINGS | G_PARAM_READWRITE);

  g_object_class_install_properties (object_class,
                                     N_PROPS,
                                     properties);
}

static void
folks_persona_init (FolksPersona *self)
{

}

/* Private */

FolksPersona *
folks_persona_new (TrackerSparqlCursor *cursor)
{
  FolksPersona *self;
  self = g_object_new (FOLKS_TYPE_PERSONA, NULL);
  self->connection = g_object_ref (tracker_sparql_cursor_get_connection (cursor));
  self->persona_urn = g_strdup (tracker_sparql_cursor_get_string (cursor, 0, NULL));

  for (int i = 1; i < tracker_sparql_cursor_get_n_columns (cursor); i++) {
    const char *var_name = tracker_sparql_cursor_get_variable_name (cursor, i);
    if (!tracker_sparql_cursor_is_bound (cursor, i))
      continue;

    switch (var_name[0]) {
    case 'a':
      if (!g_strcmp0 (var_name, "alias")) {
        g_object_set (self, "alias", tracker_sparql_cursor_get_string (cursor, i, NULL), NULL);
      } else if (!g_strcmp0 (var_name, "avatar")) {
        g_object_set (self, "avatar", tracker_sparql_cursor_get_string (cursor, i, NULL), NULL);
      } else {
        g_warning ("Invalid cursor variable: %s", var_name);
      }

      break;
    case 'b':
      if (!g_strcmp0 (var_name, "birthday")) {
        g_autoptr(GDateTime) birthday = tracker_sparql_cursor_get_datetime (cursor, i);
        g_object_set (self, "birthday", birthday, NULL);
      } else {
        g_warning ("Invalid cursor variable: %s", var_name);
      }

      break;
    case 'e':
      if (!g_strcmp0 (var_name, "emails")) {

      } else if (!g_strcmp0 (var_name, "extended_fields")) {

      } else {
        g_warning ("Invalid cursor variable: %s", var_name);
      }

      break;
    case 'f':
      if (!g_strcmp0 (var_name, "fullname")) {
        g_object_set (self, "fullname", tracker_sparql_cursor_get_string (cursor, i, NULL), NULL);
      } else {
        g_warning ("Invalid cursor variable: %s", var_name);
      }

      break;
    case 'g':
      if (!g_strcmp0 (var_name, "gender")) {
        g_object_set (self, "gender", tracker_sparql_cursor_get_string (cursor, i, NULL), NULL);
      } else if (!g_strcmp0 (var_name, "groups")) {

      } else {
        g_warning ("Invalid cursor variable: %s", var_name);
      }

      break;
    case 'i':
      if (!g_strcmp0 (var_name, "is_favourite")) {
        g_object_set (self, "is_favourite", tracker_sparql_cursor_get_boolean (cursor, i), NULL);
      } else if (!g_strcmp0 (var_name, "im_addresses")) {

      } else {
        g_warning ("Invalid cursor variable: %s", var_name);
      }

      break;
    case 'l':
      if (!g_strcmp0 (var_name, "location")) {

      } else {
        g_warning ("Invalid cursor variable: %s", var_name);
      }

      break;
    case 'n':
      if (!g_strcmp0 (var_name, "nickname")) {

      } else if (!g_strcmp0 (var_name, "notes")) {

      } else {
        g_warning ("Invalid cursor variable: %s", var_name);
      }

      break;
    case 'p':
      if (!g_strcmp0 (var_name, "phone_numbers")) {

      } else if (!g_strcmp0 (var_name, "postal_addresses")) {

      } else {
        g_warning ("Invalid cursor variable: %s", var_name);
      }

      break;
    case 'r':
      if (!g_strcmp0 (var_name, "roles")) {

      } else {
        g_warning ("Invalid cursor variable: %s", var_name);
      }

      break;
    case 's':
      if (!g_strcmp0 (var_name, "structured_name")) {

      } else {
        g_warning ("Invalid cursor variable: %s", var_name);
      }

      break;
    case 'u':
      if (!g_strcmp0 (var_name, "urls")) {

      } else {
        g_warning ("Invalid cursor variable: %s", var_name);
      }

      break;
    default:
      g_warning ("Invalid cursor variable: %s", var_name);
      break;
    }
  }

  return self;
}

const char *
folks_persona_get_urn (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return self->persona_urn;
}

/* Public */

/**
 * folks_persona_get_alias:
 * @self: the #FolksPersona
 *
 * Returns: (nullable): The alias
 */
char *
folks_persona_get_alias (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_strdup (self->alias);
}

/**
 * folks_persona_get_fullname:
 * @self: the #FolksPersona
 *
 * Returns: (nullable): The fullname
 */
char *
folks_persona_get_fullname (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_strdup (self->fullname);
}

/**
 * folks_persona_get_nickname:
 * @self: the #FolksPersona
 *
 * Returns: (nullable): The nickname
 */
char *
folks_persona_get_nickname (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_strdup (self->nickname);
}

/**
 * folks_persona_get_structured_name:
 * @self: the #FolksPersona
 *
 * Returns: (nullable) (transfer full): The structured name
 */
FolksStructuredName *
folks_persona_get_structured_name (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_object_ref (self->structured_name);
}

/**
 * folks_persona_get_avatar:
 * @self: the #FolksPersona
 *
 * Returns: (nullable) (transfer full): The avatar
 */
GIcon *
folks_persona_get_avatar (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_object_ref (self->avatar);
}

/**
 * folks_persona_get_birthday:
 * @self: the #FolksPersona
 *
 * Returns: (nullable) (transfer full): The birthday
 */
GDateTime *
folks_persona_get_birthday (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_object_ref (self->birthday);
}

/**
 * folks_persona_get_emails:
 * @self: the #FolksPersona
 *
 * Returns: (nullable) (transfer full): The list of emails
 */
GListModel *
folks_persona_get_emails (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_object_ref (self->emails);
}

/**
 * folks_persona_get_extended_fields:
 * @self: the #FolksPersona
 *
 * Returns: (nullable) (transfer full): The list of other fields
 */
GListModel *
folks_persona_get_extended_fields (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_object_ref (self->extended_fields);
}

/**
 * folks_persona_get_is_favourite:
 * @self: the #FolksPersona
 *
 * Returns: whether @self is marked as favourite
 */
gboolean
folks_persona_get_is_favourite (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), FALSE);

  return self->is_favourite;
}

/**
 * folks_persona_get_gender:
 * @self: the #FolksPersona
 *
 * Returns: (nullable): The gender
 */
char *
folks_persona_get_gender (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_strdup (self->gender);
}

/**
 * folks_persona_get_groups:
 * @self: the #FolksPersona
 *
 * Returns: (nullable) (transfer full): The list of groups
 */
GListModel *
folks_persona_get_groups (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_object_ref (self->groups);
}

/**
 * folks_persona_get_im_addresses:
 * @self: the #FolksPersona
 *
 * Returns: (nullable) (transfer full): The list of im addresses
 */
GListModel *
folks_persona_get_im_addresses (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_object_ref (self->im_addresses);
}

/**
 * folks_persona_get_location:
 * @self: the #FolksPersona
 *
 * Returns: (nullable) (transfer full): The location
 */
FolksLocation *
folks_persona_get_location (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_object_ref (self->location);
}

/**
 * folks_persona_get_notes:
 * @self: the #FolksPersona
 *
 * Returns: (nullable) (transfer full): The list of notes
 */
GListModel *
folks_persona_get_notes (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_object_ref (self->notes);
}

/**
 * folks_persona_get_phone_numbers:
 * @self: the #FolksPersona
 *
 * Returns: (nullable) (transfer full): The list of phone numbers
 */
GListModel *
folks_persona_get_phone_numbers (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_object_ref (self->phone_numbers);
}

/**
 * folks_persona_get_postal_addresses:
 * @self: the #FolksPersona
 *
 * Returns: (nullable) (transfer full): The list of postal addresses
 */
GListModel *
folks_persona_get_postal_addresses (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_object_ref (self->postal_addresses);
}

/**
 * folks_persona_get_roles:
 * @self: the #FolksPersona
 *
 * Returns: (nullable) (transfer full): The list of roles
 */
GListModel *
folks_persona_get_roles (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_object_ref (self->roles);
}

/**
 * folks_persona_get_urls:
 * @self: the #FolksPersona
 *
 * Returns: (nullable) (transfer full): The list of urls
 */
GListModel *
folks_persona_get_urls (FolksPersona *self)
{
  g_return_val_if_fail (FOLKS_IS_PERSONA (self), NULL);

  return g_object_ref (self->urls);
}
