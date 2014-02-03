/* backend.vala
 *
 * Copyright © 2010 Collabora Ltd.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 *      Philip Withnall <philip.withnall@collabora.co.uk>
 */

public class KfTest.Backend
{
  private string key_file_name;

  public void set_up (string key_file_contents)
    {
      int fd;

      /* Create a temporary file */
      try
        {
          fd = FileUtils.open_tmp ("folks-kf-test-XXXXXX",
              out this.key_file_name);
        }
      catch (FileError e)
        {
          error ("Error opening temporary file: %s", e.message);
        }

      /* Populate it with the given content */
      IOChannel channel = new IOChannel.unix_new (fd);
      try
        {
          channel.write_chars ((char[]) key_file_contents, null);
        }
      catch (ConvertError e)
        {
          error ("Error converting for writing to temporary file '%s': %s\n%s",
              this.key_file_name, e.message, key_file_contents);
        }
      catch (IOChannelError e)
        {
          error ("Error writing to temporary file '%s': %s", this.key_file_name,
              e.message);
        }

      try
        {
          channel.shutdown (true);
        }
      catch (IOChannelError e) {}
      FileUtils.close (fd);

      /* Set the environment variable for the key file path to the temporary
       * file, causing the key-file backend to use it next time it's loaded */
      Environment.set_variable ("FOLKS_BACKEND_KEY_FILE_PATH",
          this.key_file_name, true);
    }

  public void tear_down ()
    {
      /* Remove the temporary file */
      if (this.key_file_name != null)
        FileUtils.remove (this.key_file_name);
      this.key_file_name = null;
    }
}
