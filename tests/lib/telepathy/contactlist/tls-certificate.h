/*
 * tls-certificate.h - Header for TpTestsTLSCertificate
 * Copyright (C) 2010 Collabora Ltd.
 * @author Cosimo Cecchi <cosimo.cecchi@collabora.co.uk>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

#ifndef __TP_TESTS_TLS_CERTIFICATE_H__
#define __TP_TESTS_TLS_CERTIFICATE_H__

#include <glib-object.h>

#include <telepathy-glib/telepathy-glib.h>

G_BEGIN_DECLS

typedef struct _TpTestsTLSCertificate TpTestsTLSCertificate;
typedef struct _TpTestsTLSCertificateClass TpTestsTLSCertificateClass;
typedef struct _TpTestsTLSCertificatePrivate TpTestsTLSCertificatePrivate;

struct _TpTestsTLSCertificateClass {
  GObjectClass parent_class;

  TpDBusPropertiesMixinClass dbus_props_class;
};

struct _TpTestsTLSCertificate {
  GObject parent;

  TpTestsTLSCertificatePrivate *priv;
};

GType tp_tests_tls_certificate_get_type (void);

#define TP_TESTS_TYPE_TLS_CERTIFICATE \
  (tp_tests_tls_certificate_get_type ())
#define TP_TESTS_TLS_CERTIFICATE(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TESTS_TYPE_TLS_CERTIFICATE, \
      TpTestsTLSCertificate))
#define TP_TESTS_TLS_CERTIFICATE_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TESTS_TYPE_TLS_CERTIFICATE, \
      TpTestsTLSCertificateClass))
#define TP_TESTS_IS_TLS_CERTIFICATE(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TESTS_TYPE_TLS_CERTIFICATE))
#define TP_TESTS_IS_TLS_CERTIFICATE_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TESTS_TYPE_TLS_CERTIFICATE))
#define TP_TESTS_TLS_CERTIFICATE_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_TLS_CERTIFICATE, \
      TpTestsTLSCertificateClass))

void tp_tests_tls_certificate_clear_rejection (TpTestsTLSCertificate *self);

G_END_DECLS

#endif /* #ifndef __TP_TESTS_TLS_CERTIFICATE_H__*/
