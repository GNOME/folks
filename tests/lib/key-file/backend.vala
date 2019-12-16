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


const string KEY_FILE_NAME = "relationships.ini";

public class KfTest.Backend
{
  private string key_file_dir;

  public void set_up (string key_file_contents)
    {
      /* Create a temporary file */
      try
        {
          this.key_file_dir = DirUtils.make_tmp ("folks-kf-test-XXXXXX");
          FileUtils.set_contents (this.key_file_dir + "/" + KEY_FILE_NAME, key_file_contents);
        }
      catch (FileError e)
        {
          error ("Error writing to temporary file: %s", e.message);
        }

      /* Set the environment variable for the key file path to the temporary
       * file, causing the key-file backend to use it next time it's loaded */
      Environment.set_variable ("FOLKS_BACKEND_KEY_FILE_PATH",
          this.key_file_dir + "/" + KEY_FILE_NAME, true);
    }

  public void tear_down ()
    {
      /* Remove the temporary file */
      if (this.key_file_dir != null)
        DirUtils.remove (this.key_file_dir);
      this.key_file_dir = null;
    }
}
